"""Selective, snapshot-checked Geofabrik administrative polygons (HU pilot)."""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import gzip
import hashlib
import importlib.util
import io
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
URL = "https://download.geofabrik.de/europe/hungary-261108-free.shp.zip"
DIRECTORY = "geofabrik-HU-261108"
SPEC = "https://download.geofabrik.de/osm-data-in-gis-formats-free.pdf"
NATIONAL_ROLE = "https://www.ksh.gov.hu/teruletiatlasz_telepulesek?lang=en"
OSM_ROLE = "https://wiki.openstreetmap.org/wiki/Hungary/Boundaries"
LICENSE = "https://opendatacommons.org/licenses/odbl/1-0/"
MAX_RANGE = 64*1024*1024
NORMALIZER_VERSION = 3


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_json(path: Path, data) -> None:
    payload = (json.dumps(data, ensure_ascii=False, indent=2, allow_nan=False)+"\n").encode("utf-8")
    if path.exists() and path.read_bytes() == payload:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix+".tmp")
    temporary.write_bytes(payload)
    temporary.replace(path)


def parse_headers(text: str) -> dict:
    headers = {}
    for line in text.splitlines():
        if line.startswith("HTTP/"):
            headers = {"status":int(line.split()[1])}
        elif ":" in line:
            key, value = line.split(":",1)
            headers[key.lower()] = value.strip()
    return headers


def validate_range(headers: dict, start: int, end: int, total: int, etag: str, actual_bytes: int):
    if (headers.get("status") != 206 or headers.get("content-range") != f"bytes {start}-{end}/{total}"
            or headers.get("etag") != etag or actual_bytes != end-start+1):
        raise ValueError("HTTP range or immutable ETag snapshot mismatch")


class RemoteZip(io.RawIOBase):
    def __init__(self, size: int, fetch):
        self.size, self.fetch, self.position = size, fetch, 0

    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.position

    def seek(self, offset, whence=0):
        position = offset if whence == 0 else self.position+offset if whence == 1 else self.size+offset
        if not 0 <= position <= self.size:
            raise ValueError("Remote ZIP seek leaves the source file")
        self.position = position
        return position

    def read(self, size=-1):
        size = self.size-self.position if size is None or size < 0 else min(size, self.size-self.position)
        if size > MAX_RANGE:
            raise ValueError("Remote ZIP read exceeds the selective range budget")
        if not size:
            return b""
        data = self.fetch(self.position, self.position+size-1)
        if len(data) != size:
            raise ValueError("Incomplete remote ZIP range")
        self.position += size
        return data


def admin_members(members):
    return [item for item in members if PurePosixPath(item.filename).name == item.filename
        and re.fullmatch(r"gis_osm_adminareas_a_free_\d+\.(shp|dbf|shx|prj|cpg)", item.filename)]


def role_for(country: str, fclass: str, code: int):
    if country != "HU":
        return None
    roles = {6:("region","Vármegye/főváros"),7:("district","Járás"),
             8:("municipality","Település"),9:("local_admin","Kerület")}
    match = re.fullmatch(r"admin_level(\d+)", str(fclass))
    level = int(match[1]) if match else -1
    return roles.get(level) if code == 1200+level else None


def assign_country(geometry, references: dict):
    from atlas_administration import _equal_area
    total = _equal_area(geometry).area
    scores = {country:_equal_area(geometry.intersection(land)).area/total
              for country,land in references.items() if geometry.intersects(land)}
    ordered = sorted(scores.items(), key=lambda item:(-item[1],item[0]))
    first = ordered[0] if ordered else (None,0.0)
    second = ordered[1][1] if len(ordered)>1 else 0.0
    country = first[0] if first[1] > .5 and first[1]-second > .1 else None
    return country, {"fraction":first[1],"ambiguous":country is None or first[1]<.98 or second>.02,"fractions":scores}


def assign_verified_territory(geometry, country: str, territory, references: dict):
    from atlas_administration import _equal_area
    independent,detail = assign_country(geometry,references)
    fraction = _equal_area(geometry.intersection(territory)).area/_equal_area(geometry).area
    assigned = country if fraction>.5 else independent if independent != country else None
    detail.update(territorial_fraction=fraction,independent_land_country=independent,
        independent_land_disagreement=(independent != assigned),method="verified_iso_territorial_overlap",
        ambiguous=(.02<fraction<.98))
    if assigned == country:
        detail["fraction"] = fraction
    return assigned,detail


def validate_country_identity(properties: dict, relation: dict, country: str, snapshot: str):
    tags = relation.get("tags",{})
    if (relation.get("type") != "relation" or str(relation.get("id")) != properties.get("osm_id")
            or tags.get("ISO3166-1:alpha2",tags.get("ISO3166-1")) != country
            or tags.get("boundary") != "administrative" or tags.get("admin_level") != "2"
            or tags.get("name") != properties.get("name") or relation.get("timestamp","")>snapshot):
        raise ValueError("National boundary identity/ISO tags do not match the archive snapshot")


class RangeSource:
    def __init__(self, directory: Path, url=URL):
        self.directory, self.url = Path(directory), url
        self.directory.mkdir(parents=True, exist_ok=True)
        snapshot = self.directory / "snapshot.json"
        if snapshot.exists():
            self.snapshot = json.loads(snapshot.read_text(encoding="utf-8"))
            if self.snapshot["url"] != url:
                raise ValueError("Changed Geofabrik source URL")
        else:
            result = subprocess.run(["curl.exe","--head","--fail","--location","--silent","--show-error",
                "--connect-timeout","20","--max-time","45",url],capture_output=True,text=True,check=True)
            headers = parse_headers(result.stdout)
            if headers.get("status") != 200 or not headers.get("etag") or headers["etag"].startswith("W/"):
                raise ValueError("Remote ZIP needs a successful HEAD and a strong ETag")
            self.snapshot = {"url":url,"bytes":int(headers["content-length"]),"etag":headers["etag"],
                "last_modified":headers.get("last-modified"),"retrieved_utc":datetime.now(timezone.utc).isoformat(),"head_headers":headers}
            write_json(snapshot, self.snapshot)
        self.receipts = {}

    def fetch(self, start: int, end: int) -> bytes:
        if not 0 <= start <= end < self.snapshot["bytes"] or end-start+1>MAX_RANGE:
            raise ValueError("Invalid or over-budget HTTP range")
        directory = self.directory / "ranges"
        directory.mkdir(exist_ok=True)
        path = directory / f"{start}-{end}.bin"
        receipt_path = path.with_suffix(".receipt.json")
        if receipt_path.exists():
            receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
            data = path.read_bytes()
            if digest(data) != receipt["sha256"]:
                raise ValueError("Changed range-cache hash")
            validate_range(receipt["headers"], start,end,self.snapshot["bytes"],self.snapshot["etag"],len(data))
        else:
            temporary = path.with_suffix(".partial")
            header_path = path.with_suffix(".headers.txt")
            metrics = '{"http_code":%{http_code},"size_download":%{size_download},"speed_download":%{speed_download},"time_total":%{time_total},"time_starttransfer":%{time_starttransfer}}'
            result = subprocess.run(["curl.exe","--fail","--location","--silent","--show-error","--range",f"{start}-{end}",
                "--header","If-Match: "+self.snapshot["etag"],"--max-filesize",str(end-start+1),
                "--connect-timeout","20","--max-time","120","--dump-header",str(header_path),
                "--output",str(temporary),"--write-out",metrics,self.url],capture_output=True,text=True)
            headers = parse_headers(header_path.read_text(encoding="iso-8859-1"))
            if result.returncode:
                raise RuntimeError("Selective HTTP range failed: "+result.stderr.strip())
            data = temporary.read_bytes()
            validate_range(headers,start,end,self.snapshot["bytes"],self.snapshot["etag"],len(data))
            temporary.replace(path)
            receipt = {"start":start,"end":end,"sha256":digest(data),"bytes":len(data),"headers":headers,
                "metrics":json.loads(result.stdout),"url":self.url,"etag":self.snapshot["etag"]}
            write_json(receipt_path, receipt)
        self.receipts[f"{start}-{end}"] = receipt
        return data


def inspect_archive(cache: Path) -> dict:
    remote = RangeSource(Path(cache)/DIRECTORY)
    with zipfile.ZipFile(RemoteZip(remote.snapshot["bytes"],remote.fetch)) as archive:
        members = [{"name":item.filename,"compressed_bytes":item.compress_size,"bytes":item.file_size,"crc32":f"{item.CRC:08x}"}
                   for item in admin_members(archive.infolist())]
    report = {**remote.snapshot,"admin_members":members,"selected_compressed_bytes":sum(item["compressed_bytes"] for item in members),
        "range_bytes_read":sum(item["bytes"] for item in remote.receipts.values()),"ranges":list(remote.receipts.values())}
    write_json(Path(cache)/DIRECTORY/"inspection.json",report)
    return report


def extract_admin_members(archive: zipfile.ZipFile, directory: Path) -> list[dict]:
    directory.mkdir(parents=True, exist_ok=True)
    records = []
    for member in admin_members(archive.infolist()):
        path = directory/member.filename
        receipt_path = path.with_suffix(path.suffix+".receipt.json")
        if receipt_path.exists():
            record = json.loads(receipt_path.read_text(encoding="utf-8"))
            payload = path.read_bytes()
            if (digest(payload) != record["sha256"] or len(payload) != member.file_size
                    or record["crc32"] != f"{member.CRC:08x}"):
                raise ValueError("Changed extracted-member hash/CRC")
        else:
            payload = archive.read(member)  # ZipFile checks the original CRC before returning.
            if len(payload) != member.file_size:
                raise ValueError("Truncated uncompressed member")
            temporary = path.with_suffix(path.suffix+".partial")
            temporary.write_bytes(payload)
            temporary.replace(path)
            record = {"name":member.filename,"bytes":len(payload),"compressed_bytes":member.compress_size,
                "crc32":f"{member.CRC:08x}","sha256":digest(payload)}
            write_json(receipt_path,record)
        records.append(record)
    return records


def download_members(cache: Path) -> dict:
    directory = Path(cache)/DIRECTORY
    remote = RangeSource(directory)
    with zipfile.ZipFile(RemoteZip(remote.snapshot["bytes"],remote.fetch)) as archive:
        members = extract_admin_members(archive,directory/"members")
        readme = archive.read("README")
        (directory/"archive-README.txt").write_bytes(readme)
        timestamp = re.search(r"data as of (\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ)",readme.decode("utf-8"))
        if not timestamp:
            raise ValueError("Archive README does not identify an OSM timestamp")
        readme_receipt = {"name":"README","sha256":digest(readme),"bytes":len(readme),"crc32":f"{archive.getinfo('README').CRC:08x}"}
    ranges = [json.loads(path.read_text(encoding="utf-8")) for path in sorted((directory/"ranges").glob("*.receipt.json"))]
    if any(row["url"] != remote.url or row["etag"] != remote.snapshot["etag"] for row in ranges):
        raise ValueError("Range receipts mix different archive snapshots")
    report = {**remote.snapshot,"members":members,"osm_timestamp":timestamp[1],"readme":readme_receipt,
        "range_bytes_read":sum(row["bytes"] for row in ranges),"ranges":ranges}
    write_json(directory/"members-receipt.json",report)
    return report


def _shapefile():
    try:
        import shapefile
        return shapefile
    except ModuleNotFoundError:
        path = ROOT/".tools/atlas_env/Lib/site-packages/shapefile.py"
        if not path.exists():
            raise RuntimeError("Install pyshp==2.3.1 in .tools/atlas_env; cached reads do not need it")
        spec = importlib.util.spec_from_file_location("atlas_private_shapefile",path)
        library = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(library)
        return library


def normalize_record(properties: dict, geometry, country: str | None, assignment: dict):
    role = role_for(country,str(properties.get("fclass","")),int(properties.get("code",0)))
    if role is None:
        return None
    identifier = str(properties.get("osm_id") or "")
    if not identifier:
        raise ValueError("Administrative source ID is missing")
    level = int(str(properties["fclass"]).removeprefix("admin_level"))
    name = str(properties.get("name") or "").strip()
    row = {"id":f"geofabrik:HU-261108:{level}:{identifier}","country":country,"kind":role[0],"unit_type":role[1],
        "name":name or "Gebiet (Quellname fehlt)","name_known":bool(name),"original_name":properties.get("name"),
        "geometry":geometry,"admin_level":level,"raw_subtype":properties["fclass"],"native_type":role[1],
        "source":f"geofabrik-HU-261108-admin{level}","original_source_id":identifier,"original_source_version":None,
        "original_object_type":"not supplied by Geofabrik's common osm_id attribute",
        "original_properties":properties,"country_assignment_method":assignment.get("method","largest_independent_land_overlap"),
        "country_assignment_fraction":assignment["fraction"],"country_assignment_ambiguous":assignment["ambiguous"]}
    if level == 6 and name == "Budapest":
        row["local_government_role"] = "municipality"
        row["local_government_role_evidence"] = NATIONAL_ROLE
    if "territorial_fraction" in assignment:
        row.update(country_territorial_fraction=assignment["territorial_fraction"],
            independent_land_disagreement=assignment["independent_land_disagreement"])
    return row


def infer_parents(rows: list[dict]) -> None:
    from shapely.strtree import STRtree
    levels = sorted({row["admin_level"] for row in rows})
    tables = {level:[row for row in rows if row["admin_level"]==level] for level in levels}
    indexes = {level:STRtree([row["geometry"] for row in table]) for level,table in tables.items()}
    for row in rows:
        row["parent_id"],row["parent_relationship"] = "country:"+row["country"],"hierarchy-not-supplied"
        geometry = row["geometry"]
        for level in reversed([value for value in levels if value<row["admin_level"]]):
            candidates = []
            for index in indexes[level].query(geometry):
                parent = tables[level][int(index)]
                if parent["country"] != row["country"]:
                    continue
                fraction = 1.0 if parent["geometry"].covers(geometry) else parent["geometry"].intersection(geometry).area/geometry.area
                candidates.append((fraction,parent["id"]))
            candidates.sort(reverse=True)
            if candidates and candidates[0][0]>.98 and (len(candidates)==1 or candidates[0][0]-candidates[1][0]>.02):
                row["parent_id"],row["parent_relationship"] = candidates[0][1],"inferred-area-containment"
                row["parent_overlap_fraction"] = candidates[0][0]
                break


def reconcile_local_roles(rows: list[dict]) -> None:
    municipalities = [row for row in rows if row["kind"]=="municipality"]
    for row in rows:
        if row.get("local_government_role") != "municipality":
            continue
        matches = [other for other in municipalities if other["country"]==row["country"] and other["name"]==row["name"]
            and other["geometry"].intersection(row["geometry"]).area/max(other["geometry"].area,row["geometry"].area)>.99]
        if len(matches)==1:
            row.pop("local_government_role")
            row["local_government_represented_by"] = matches[0]["id"]


def _references(cache: Path, extent):
    import shapely
    from shapely.geometry import box, shape
    path = cache/"ne_10m_admin_0_countries.geojson"
    data = json.loads(path.read_text(encoding="utf-8"))
    result = {}
    for feature in data["features"]:
        properties = {key.lower():value for key,value in feature["properties"].items()}
        country = properties.get("iso_a2_eh") or properties.get("iso_a2")
        if not country or country == "-99":
            continue
        geometry = shapely.make_valid(shape(feature["geometry"]))
        if geometry.intersects(box(*extent)):
            result[country] = geometry
    return result,{"url":"https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_10m_admin_0_countries.geojson",
        "sha256":digest(path.read_bytes()),"license":"Public Domain","cache_file":path.relative_to(cache).as_posix(),
        "purpose":"Independent majority-overlap country assignment, not a union of target administrative units"}


def _territorial_reference(reader, directory: Path, snapshot: str, country="HU"):
    import shapely
    from shapely.geometry import shape, mapping
    for shape_record in reader.iterShapeRecords():
        properties = shape_record.record.as_dict()
        if properties["fclass"] != "national":
            continue
        identifier = str(properties["osm_id"])
        version,next_version = None,None
        for _ in range(12):
            suffix = f"-v{version}" if version is not None else ""
            path = directory/f"iso-country-relation-{identifier}{suffix}.json"
            url = f"https://api.openstreetmap.org/api/0.6/relation/{identifier}"+(f"/{version}" if version is not None else "")+".json"
            if not path.exists():
                temporary = path.with_suffix(".partial")
                subprocess.run(["curl.exe","--fail","--location","--silent","--show-error","--max-time","30",
                    "--max-filesize","2000000","--output",str(temporary),url],check=True)
                temporary.replace(path)
            relation = json.loads(path.read_text(encoding="utf-8"))["elements"][0]
            if relation["timestamp"] <= snapshot:
                break
            next_version = {"version":relation["version"],"timestamp":relation["timestamp"]}
            version = int(relation["version"])-1
        else:
            raise ValueError("National ISO identity exceeds the bounded version lookup")
        if relation.get("tags",{}).get("ISO3166-1:alpha2",relation.get("tags",{}).get("ISO3166-1")) != country:
            continue
        validate_country_identity(properties,relation,country,snapshot)
        geometry = shapely.make_valid(shape(shape_record.shape.__geo_interface__))
        proof = {"country":country,"source_osm_id":identifier,"identity_relation_version":relation["version"],
            "identity_timestamp":relation["timestamp"],"next_known_version":next_version,"snapshot":snapshot,
            "url":f"https://api.openstreetmap.org/api/0.6/relation/{identifier}/{relation['version']}.json",
            "identity_sha256":digest(path.read_bytes()),"geometry_sha256":digest(json.dumps(mapping(geometry),sort_keys=True).encode("utf-8")),
            "purpose":"Territorial attribution only; never a land/coverage denominator or a new country object",
            "independent_of_target_municipal_union":True,"national_feature_properties":properties}
        return geometry,proof
    raise ValueError("No snapshot-compatible ISO-tagged national boundary is available")


def _prepare_hu(cache: Path) -> dict:
    import shapely
    from shapely.geometry import shape, mapping
    cache = Path(cache)
    directory = cache/DIRECTORY
    archive = download_members(cache)
    base = directory/"members/gis_osm_adminareas_a_free_1"
    projection = base.with_suffix(".prj").read_text(encoding="ascii")
    if "WGS_1984" not in projection or "GEOGCS" not in projection:
        raise ValueError("Administrative shapefile CRS is not the reviewed geographic WGS84 CRS")
    encoding = base.with_suffix(".cpg").read_text(encoding="ascii").strip()
    reader = _shapefile().Reader(str(base),encoding=encoding)
    references,reference = _references(cache,reader.bbox)
    territory,territorial_proof = _territorial_reference(reader,directory,archive["osm_timestamp"])
    rows,grouped = [],{}
    raw_counts,assigned_counts = Counter(),Counter()
    foreign_examples,ambiguous = [],[]
    for shape_record in reader.iterShapeRecords():
        properties = shape_record.record.as_dict()
        raw_counts[properties["fclass"]] += 1
        if properties["fclass"] == "national":
            continue
        geometry = shapely.make_valid(shape(shape_record.shape.__geo_interface__))
        if geometry.is_empty or geometry.geom_type not in ("Polygon","MultiPolygon") or geometry.area<=0:
            raise ValueError("Invalid administrative polygon: "+str(properties["osm_id"]))
        country,assignment = assign_verified_territory(geometry,"HU",territory,references)
        assigned_counts[str(country)+":"+properties["fclass"]] += 1
        if country != "HU" and len(foreign_examples)<10:
            foreign_examples.append({"name":properties["name"],"osm_id":properties["osm_id"],"country":country,"assignment":assignment})
        if assignment["ambiguous"]:
            ambiguous.append({"name":properties["name"],"osm_id":properties["osm_id"],"country":country,"assignment":assignment})
        row = normalize_record(properties,geometry,country,assignment)
        if row is None:
            continue
        row["country_assignment_reference_sha256"] = reference["sha256"]
        if row["id"] in grouped:
            previous = grouped[row["id"]]
            if previous["name"] != row["name"]:
                raise ValueError("Split administrative source ID has conflicting names")
            previous["geometry"] = previous["geometry"].union(geometry)
        else:
            grouped[row["id"]] = row
    rows = [grouped[key] for key in sorted(grouped)]
    reconcile_local_roles(rows)
    infer_parents(rows)
    path = directory/"boundaries.jsonl.gz"
    with path.open("wb") as raw, gzip.GzipFile(filename="",mode="wb",fileobj=raw,mtime=0) as compressed, io.TextIOWrapper(compressed,encoding="utf-8",newline="\n") as output:
        for row in rows:
            output.write(json.dumps({**row,"geometry":mapping(row["geometry"])},ensure_ascii=False,separators=(",",":"),allow_nan=False)+"\n")
    counts = Counter(row["source"] for row in rows)
    sources = []
    for identifier in sorted(counts):
        example = next(row for row in rows if row["source"]==identifier)
        sources.append({"id":identifier,"country":"HU","scope_countries":["HU"],"kind":example["kind"],
            "unit_type":example["unit_type"],"admin_level":example["admin_level"],"source_unit_count":counts[identifier],
            "expected_unit_count":counts[identifier],"cache_file":path.relative_to(cache).as_posix(),
            "sha256":digest(path.read_bytes()),"bytes":path.stat().st_size,"url":URL,"date":"2026-11-08",
            "license":"ODbL-1.0","license_url":LICENSE,"attribution":"© OpenStreetMap contributors; Geofabrik GmbH",
            "specification_url":SPEC,"role_evidence_urls":[NATIONAL_ROLE,OSM_ROLE],
            "unit_semantics":{"render_role":example["kind"],"source_unit_type":example["unit_type"],
                "coverage_status":"Measured by the downstream independent land-mask audit; count alone is not completeness"}})
    receipt = {"schema":1,"normalizer_version":NORMALIZER_VERSION,"source_snapshot":archive,"sources":sources,"country_reference":reference,
        "territorial_assignment_reference":territorial_proof,
        "raw_counts":dict(raw_counts),"assigned_counts":dict(assigned_counts),"foreign_examples":foreign_examples,
        "ambiguous_country_assignments":ambiguous,"feature_count":len(rows),
        "parent_relationship_counts":dict(Counter(row["parent_relationship"] for row in rows)),
        "limits":["No OSM object type/version or source-tag hierarchy in this export; source IDs are preserved without inventing those fields",
            "No automatic municipality role outside the positively reviewed Hungarian admin levels",
            "Administrative polygons can contain territorial waters; country land clipping remains a downstream operation"]}
    write_json(directory/"receipt.json",receipt)
    return receipt


def prepare_sources(cache: Path) -> list[dict]:
    cache = Path(cache)
    collection_path=cache/"geofabrik-collection-v4.json"
    if collection_path.exists():
        collection=json.loads(collection_path.read_text(encoding="utf-8"))
        if collection.get("collection_version")==4 and collection.get("source_groups_version")==3:
            for source in collection["sources"]:
                target=cache/source["cache_file"]
                if digest(target.read_bytes())!=source["sha256"] or target.stat().st_size!=source["bytes"]:
                    raise ValueError("Changed normalized Geofabrik collection cache")
            write_json(ROOT/"data/atlas_geofabrik_sources.json",collection)
            return collection["sources"]
    path = cache/DIRECTORY/"receipt.json"
    receipt = json.loads(path.read_text(encoding="utf-8")) if path.exists() else _prepare_hu(cache)
    if receipt.get("normalizer_version") != NORMALIZER_VERSION:
        receipt = _prepare_hu(cache)
    sources = receipt["sources"]
    for source in sources:
        target = cache/source["cache_file"]
        if digest(target.read_bytes()) != source["sha256"] or target.stat().st_size != source["bytes"]:
            raise ValueError("Changed normalized Geofabrik cache")
    write_json(ROOT/"data/atlas_geofabrik_sources.json",receipt)
    _write_docs(receipt)
    return sources


def verified_source_alias(row,source,proof,audit):
    same=(proof.get("geofabrik_id")==row["id"] and proof.get("geofabrik_source")==row["source"]
        and str(proof.get("geofabrik_original_source_id"))==str(row.get("original_source_id"))
        and proof.get("country")==row["country"] and proof.get("admin_level")==row["admin_level"]
        and proof.get("geofabrik_name")==row.get("original_name")==proof.get("osm_name")
        and proof.get("geofabrik_kind")==row["kind"]==proof.get("osm_kind")
        and proof.get("name_match") is True and proof.get("kind_match") is True
        and proof.get("geometry_intersection_over_union",0)>.999
        and proof.get("geofabrik_cache_sha256")==source["sha256"])
    if not same:
        raise ValueError("Verified source alias differs from the actual immutable source row")
    return {"target_id":proof["osm_id"],"target_record_id":proof["osm_record_id"],"target_source":proof["osm_source"],
        "common_id":str(row["original_source_id"]),"country":row["country"],"admin_level":row["admin_level"],
        "original_name":row["original_name"],"geometry_intersection_over_union":proof["geometry_intersection_over_union"],
        "geofabrik_cache_sha256":source["sha256"],"audit_file":audit["file"],"audit_sha256":audit["sha256"]}


def iter_boundaries(cache: Path, sources: list[dict]):
    from shapely.geometry import shape
    selected = {source["id"]:source for source in sources}
    alias_proofs={}
    for source in sources:
        audit=source.get("verified_source_alias_audit")
        if not audit:
            continue
        path=Path(cache)/audit["file"]
        raw=path.read_bytes()
        if digest(raw)!=audit["sha256"] or len(raw)!=audit["bytes"]:
            raise ValueError("Changed verified source-alias audit")
        for proof in json.loads(raw)["candidate_pairs"]:
            if proof.get("geofabrik_source")==source["id"]:
                alias_proofs[proof["geofabrik_id"]]=(proof,audit)
    counts = Counter()
    for relative in sorted({source["cache_file"] for source in sources}):
        source = next(source for source in sources if source["cache_file"]==relative)
        path = Path(cache)/relative
        if digest(path.read_bytes()) != source["sha256"]:
            raise ValueError("Changed normalized Geofabrik cache hash")
        with gzip.open(path,"rt",encoding="utf-8") as stream:
            for line in stream:
                row = json.loads(line)
                if row["source"] not in selected:
                    continue
                row["geometry"] = shape(row["geometry"])
                if row["id"] in alias_proofs:
                    proof,audit=alias_proofs[row["id"]]
                    row["verified_source_alias"]=verified_source_alias(row,selected[row["source"]],proof,audit)
                counts[row["source"]] += 1
                yield row
    if any(counts[key] != value["source_unit_count"] for key,value in selected.items()):
        raise ValueError("Changed Geofabrik source feature count")


def _write_docs(receipt):
    snapshot = receipt["source_snapshot"]
    lines = ["# Selektive Geofabrik-Verwaltungsflächen", "",
        "Die kostenlose [Adminareas-Ebene](https://blog.geofabrik.de/index.php/2026/04/) enthält formale administrative Grenzpolygone. "
        f"Die [Formatspezifikation]({SPEC}), Stand 02.04.2026, ordnet `fclass` und `code` den OSM-Adminleveln zu. "
        "Eine länderübergreifende Gemeinderolle folgt daraus nicht automatisch.","",
        f"HU-Extrakt: [{URL}]({URL}), {snapshot['bytes']} Bytes; ETag `{snapshot['etag']}`, Last-Modified `{snapshot['last_modified']}`. "
        f"Selektiv tatsächlich gelesene Range-Bytes einschließlich ZIP-Verzeichnis: {snapshot['range_bytes_read']}. "
        "Jede Range verlangt HTTP 206, passende Content-Range-Länge und denselben starken ETag über If-Match. "
        "Die fünf Adminareas-Mitglieder sind mit Original-ZIP-CRC32, SHA-256 und Dateigröße belegt; andere Kartenebenen werden nicht geladen.","",
        "| Rolle | Native OSM-Ebene | Tatsächliche Einheiten nach Länderzuordnung |","|---|---:|---:|"]
    for source in receipt["sources"]:
        lines.append(f"| {source['unit_type']} (`{source['kind']}`) | {source['admin_level']} | {source['source_unit_count']} |")
    lines += ["",f"Die [ungarische Mapping-Dokumentation]({OSM_ROLE}) belegt die nationale Adminlevel-Bedeutung. "
        f"Das [KSH]({NATIONAL_ROLE}) beschreibt zum 01.01.2026 3.155 Siedlungen und behandelt Budapest-Bezirke gesondert. "
        "Die hier gemessenen OSM-Anzahlen sind keine stillschweigende Gleichsetzung mit amtlicher Vollständigkeit.","",
        "Pufferobjekte bekommen ihre Länderzuordnung über ein separat bestätigtes nationales Grenzpolygon. "
        "Seine ISO-Länderkennung, Identität und historische Relationsversion werden gegen den exakten OSM-Zeitstand aus dem Archiv-README geprüft. "
        "Diese Referenz dient ausschließlich der territorialen Zuordnung und erzeugt weder ein neues Landobjekt noch einen Coverage-Nenner. "
        "Die unabhängige Natural-Earth-10m-Landmaske bleibt separat erhalten; ihre gröberen Grenzabweichungen sind je Feature markiert. "
        "Eine Minderheits-/Grenzunsicherheit bleibt als Flag mit Anteil erhalten; unentschiedene Zuordnungen werden nicht importiert. "
        "Nachbareinheiten werden nicht anhand des Archivnamens in ungarische Gemeinden umbenannt. Nationale Level-2-Grenzen werden nie als zusätzliche Länder importiert.","",
        "Die Quelle liefert keine codierte Elternhierarchie. Eltern werden nur bei eindeutiger Flächenenthaltung abgeleitet und ausdrücklich als `inferred-area-containment` markiert. "
        "`osm_id` enthält laut Spezifikation weder zwingend den Objekttyp noch die Version und ist nicht universell eindeutig; beides wird nicht erfunden. "
        "Originalnamen, fclass, Code, ID, Mitglied-CRC/Hashes und Snapshot-Header stehen im Manifest.","",
        f"Daten: [ODbL 1.0]({LICENSE}), © OpenStreetMap contributors, Geofabrik GmbH. Unabhängige Länderreferenz: Natural Earth v5.1.2, Public Domain, "
        f"SHA-256 `{receipt['country_reference']['sha256']}`. Auf Land beschränkte Lücken-/Überlappungsprüfung erfolgt im Hauptimport.","",
        "Normaler Cache-Leser: Python und Shapely. Nur zur erstmaligen SHP-Aufbereitung wird pyshp 2.3.1 aus der isolierten `.tools/atlas_env` geladen; kein GDAL/DuckDB zur Laufzeit.","",
        "```powershell","python tools/atlas_geofabrik_sources.py --cache .tools/atlas_sources",
        "python -m unittest discover -s tools -p test_atlas_geofabrik_sources.py","```",""]
    target = ROOT/"docs/atlas-geofabrik-sources.md"
    target.write_text("\n".join(lines),encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache",type=Path,default=ROOT/".tools/atlas_sources")
    parser.add_argument("--inspect",action="store_true")
    args = parser.parse_args()
    if args.inspect:
        report = inspect_archive(args.cache)
        print(json.dumps({key:report[key] for key in ("url","bytes","etag","last_modified","selected_compressed_bytes","range_bytes_read","admin_members")},ensure_ascii=False,indent=2))
    else:
        sources = prepare_sources(args.cache)
        print(json.dumps({"sources":len(sources),"features":sum(row["source_unit_count"] for row in sources)}))
