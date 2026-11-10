"""Bounded current Iran provider: only explicitly typed native Dehestan polygons.

The archived gbOpen2021 source is separate. Shahr, generic unnamed local
levels, villages, urban subdivisions and built-up/place outlines are not
admitted by this reader. Original source geometry is never repaired or clipped.
"""
from __future__ import annotations
import gzip
import io
import json
from pathlib import Path
import re

import shapely
from shapely.geometry import mapping, shape
import atlas_geofabrik_sources as core


ROOT = Path(__file__).resolve().parents[1]
SNAPSHOT = "2026-11-08T21:21:00Z"
URL = "https://download.geofabrik.de/asia/iran-261108-free.shp.zip"
SOURCE_ID = "geofabrik-IR-Dehestan-20261108"
RAW = Path("audit/IR-qualification-20261110/geofabrik")
DIRECTORY = Path("iran-dehestan-261108/v1")
EVIDENCE = ["https://download.geofabrik.de/osm-data-in-gis-formats-free.pdf",
            "https://wiki.openstreetmap.org/wiki/Template:Admin_level",
            "https://download.geofabrik.de/asia/iran.html"]


def qualify_coverage_metadata(source):
    """The exact positive population is qualified for the atlas bbox, not a census.

    Its 52 excluded original candidates and missing Bushehr scope are all south
    of 33 degrees north. National inventory incompleteness is not a role error
    in this bbox. The independently measured remaining land stays unexplained.
    """
    if (source.get("id") != SOURCE_ID or source.get("kind") != "local_admin"
            or source.get("expected_unit_count") != 2679 or source.get("raw_positive_type_count") != 2731
            or source.get("sha256") != "d49610c674f9f9e46fb083988bbfd790359ef591fa45120c173f4d221b2226c8"):
        raise ValueError("Iranian bbox qualification belongs to the exact reviewed source population")
    return {**source, "blocks_full_coverage_claim": False,
        "coverage_note": "2.679 positiv qualifizierte Dehestan-Flächen mit originalen Kennungen und Verwaltungsrollen. "
            "Im geprüften Atlasstand sind 97,597428 % der Referenzlandfläche im Kartenausschnitt belegt; "
            "2,402572 % Restfläche bleiben räumlich noch nicht erklärt und werden nicht ergänzt. "
            "Dies sind örtliche Verwaltungsflächen, keine pauschalen Stadt- oder Gemeinderollen; "
            "eine aktuelle landesweit vollständige Behördenliste ist nicht belegt.",
        "territorial_scope_note": "Die Landeszuordnung beruht auf 30 positiv bestätigten ursprünglichen iranischen Provinzflächen. "
            "52 Dehestan außerhalb dieser Provinzreferenz wurden nicht aufgenommen. Alle 52 liegen vollständig südlich "
            "von 33° N (nördlichste Grenze: 30,2949624° N), ebenso die fehlende Bushehr-Provinzreferenz. "
            "Sie liegen außerhalb des Atlas-Kartenausschnitts (-12, 33, 52, 72) und erklären dessen Restfläche nicht. "
            "Die Originalgeometrien und die unabhängige Landreferenz bleiben unverändert."}


def candidate_role(properties):
    name=properties.get("name")
    if (properties.get("fclass")=="admin_level7" and properties.get("code")==1207
            and isinstance(name,str) and re.fullmatch(r"دهستان\s+\S.*",name)):
        return "local_admin","Dehestan / دهستان"
    return None


def verified_scope(regions, metadata):
    """Use producer province polygons with exact positive IR ISO identity."""
    elements={str(e["id"]):e for e in metadata["elements"] if e.get("type")=="relation"}
    polygons=[]; proof=[]
    for row in regions:
        p=row["properties"];identifier=str(p["osm_id"]);e=elements.get(identifier,{})
        tags=e.get("tags",{});geometry=row["geometry"]
        if (p.get("fclass")!="admin_level4" or p.get("code")!=1204
                or tags.get("name")!=p.get("name") or tags.get("boundary")!="administrative"
                or tags.get("admin_level")!="4" or not tags.get("ISO3166-2","").startswith("IR-")
                or not e.get("timestamp") or e["timestamp"]>SNAPSHOT
                or not isinstance(e.get("version"),int) or e["version"]<1
                or geometry.is_empty or not geometry.is_valid):
            raise ValueError("Unqualified Iranian source-province identity/snapshot/geometry")
        polygons.append(geometry)
        proof.append({"original_source_id":identifier,"name":p["name"],"iso3166_2":tags["ISO3166-2"],
                      "osm_relation_version":e["version"],"timestamp":e["timestamp"],
                      "geometry_sha256":core.digest(geometry.wkb)})
    if not polygons:
        raise ValueError("No positively verified Iranian source provinces")
    scope=shapely.union_all(polygons)
    if not scope.is_valid or scope.is_empty:
        raise ValueError("Invalid verified Iranian provincial scope")
    return scope,sorted(proof,key=lambda p:p["original_source_id"])


def normalize_candidate(properties, geometry, scope):
    """Country qualification precedes admission of the positive native role."""
    if geometry.is_empty or not geometry.is_valid or geometry.area<=0:
        return None
    if not scope.covers(geometry):
        fraction=geometry.intersection(scope).area/geometry.area
        if fraction<0.999:
            return None
    else:
        fraction=1.0
    role=candidate_role(properties)
    if role is None:
        return None
    identifier=str(properties.get("osm_id",""))
    if not identifier.isdecimal():
        raise ValueError("Missing native Iranian OSM relation identity")
    if not (-180<=geometry.bounds[0]<=geometry.bounds[2]<=180 and -90<=geometry.bounds[1]<=geometry.bounds[3]<=90):
        raise ValueError("Non-geographic Iranian source geometry")
    return {"id":f"geofabrik:IR:7:{identifier}","country":"IR","kind":role[0],"unit_type":role[1],
            "native_type":"دهستان","admin_level":7,"raw_subtype":"admin_level7",
            "name":properties["name"],"original_name":properties["name"],"name_known":True,
            "original_source_id":identifier,"original_properties":dict(properties),"geometry":geometry,
            "source":SOURCE_ID,"parent_id":"country:IR",
            "parent_relationship":"provincial-source-scope-confirmed; province is not added as a duplicate object",
            "country_assignment_method":"original-IR-ISO-province-union","country_assignment_fraction":fraction,
            "country_assignment_ambiguous":False,"source_snapshot":SNAPSHOT,
            "native_role_evidence_urls":EVIDENCE}


def _verify_cached(cache, source):
    path=cache/source["cache_file"]
    if path.stat().st_size!=source["bytes"] or core.digest(path.read_bytes())!=source["sha256"]:
        raise ValueError("Changed immutable current Iran cache")


def prepare_sources(cache:Path)->list[dict]:
    cache=Path(cache);directory=cache/DIRECTORY;receipt=directory/"sources.json"
    if receipt.exists():
        sources=[qualify_coverage_metadata(s) for s in json.loads(receipt.read_text(encoding="utf8"))["sources"]]
        for source in sources:_verify_cached(cache,source)
        return sources
    raw=cache/RAW;stage_path=raw/"staging-receipt.json"
    if not stage_path.exists():
        raise ValueError("Pinned Iranian administrative-only stage is required; see docs/atlas-iran-sources.md. Do not substitute the damaged gbOpen2021 source.")
    stage=json.loads(stage_path.read_text(encoding="utf8"))
    if stage.get("status")!="complete-cache-only" or stage.get("url")!=URL or stage.get("osm_timestamp")!=SNAPSHOT:
        raise ValueError("Incomplete or changed Iranian source stage")
    for member in stage["members"]:
        p=raw/"members"/member["name"]
        if p.stat().st_size!=member["bytes"] or core.digest(p.read_bytes())!=member["sha256"]:
            raise ValueError("Changed original Iranian administrative member")
    base=raw/"members/gis_osm_adminareas_a_free_1"
    if "WGS_1984" not in base.with_suffix(".prj").read_text(encoding="ascii"):
        raise ValueError("Unreviewed Iranian source CRS")
    reader=core._shapefile().Reader(str(base),encoding=base.with_suffix(".cpg").read_text(encoding="ascii").strip())
    source_rows=list(reader.iterShapeRecords())
    regions=[{"properties":r.record.as_dict(),"geometry":shape(r.shape.__geo_interface__)}
             for r in source_rows if r.record["fclass"]=="admin_level4"]
    metadata_path=raw/"regions-original-tags.json";metadata=json.loads(metadata_path.read_text(encoding="utf8"))
    metadata_receipt=json.loads(metadata_path.with_suffix(".receipt.json").read_text(encoding="utf8"))
    if core.digest(metadata_path.read_bytes())!=metadata_receipt["sha256"] or metadata_path.stat().st_size!=metadata_receipt["bytes"]:
        raise ValueError("Changed original Iranian province metadata")
    scope,scope_proof=verified_scope(regions,metadata);shapely.prepare(scope)
    rows=[];excluded=[];candidates=0
    for r in source_rows:
        properties=r.record.as_dict()
        if candidate_role(properties) is None:
            continue
        candidates+=1;geometry=shape(r.shape.__geo_interface__)
        row=normalize_candidate(properties,geometry,scope)
        if row is None:
            excluded.append({"original_properties":properties,"reason":"Outside positively ISO-verified provincial scope or invalid original geometry; no country/role inferred"})
        else:
            rows.append(row)
    if candidates!=2731 or len(regions)!=30:
        raise ValueError("Changed pinned Iranian positive-role/province inventory")
    if len({row["id"] for row in rows})!=len(rows):
        raise ValueError("Duplicate original Iranian administrative identity")
    directory.mkdir(parents=True,exist_ok=True);path=directory/"boundaries.jsonl.gz";buffer=io.BytesIO()
    with gzip.GzipFile(fileobj=buffer,filename="",mode="wb",mtime=0) as output:
        for row in sorted(rows,key=lambda r:r["id"]):
            output.write((json.dumps({**row,"geometry":mapping(row["geometry"])},ensure_ascii=False,separators=(",",":"),allow_nan=False)+"\n").encode("utf8"))
    payload=buffer.getvalue()
    if path.exists() and path.read_bytes()!=payload:
        raise ValueError("Immutable Iranian cache version differs; use a new revision")
    if not path.exists():path.write_bytes(payload)
    audit={"schema":1,"country":"IR","snapshot":SNAPSHOT,"raw_typed_dehestan_count":candidates,
           "admitted_count":len(rows),"excluded_typed_candidates":excluded,"verified_province_count":len(regions),
           "verified_provinces":scope_proof,"scope_geometry_sha256":core.digest(scope.wkb),
           "source_stage_file":stage_path.relative_to(cache).as_posix(),"source_stage_sha256":core.digest(stage_path.read_bytes()),
           "province_metadata":{**metadata_receipt,"cache_file":metadata_path.relative_to(cache).as_posix()},
           "country_reference_purpose":"Territorial admission only, not physical land denominator or new country object",
           "limitations":["Bushehr province is absent from the raw admin4 polygon file; no province is invented.",
                          "Only explicit Dehestan types; cities and all uncertain other source levels excluded.",
                          "No nationwide current legal authority completeness or fine-village completeness is claimed."]}
    auditpath=directory/"audit.json";core.write_json(auditpath,audit)
    source={"id":SOURCE_ID,"country":"IR","scope_countries":["IR"],"kind":"local_admin","unit_type":"Dehestan / دهستان",
            "native_type":"دهستان","admin_level":7,"url":URL,"date":"2026-11-08","osm_timestamp":SNAPSHOT,
            "source_unit_count":len(rows),"expected_unit_count":len(rows),"raw_positive_type_count":candidates,
            "cache_file":path.relative_to(cache).as_posix(),"sha256":core.digest(payload),"bytes":len(payload),
            "license":"ODbL-1.0","license_url":core.LICENSE,"attribution":"© OpenStreetMap contributors; Geofabrik GmbH",
            "replacement_scope":"feature","role_evidence_urls":EVIDENCE,"blocks_full_coverage_claim":True,
            "unit_semantics":{"render_role":"local_admin","native_role":"Explicit native Dehestan; not a blanket municipality promotion","coverage_status":"Partial source scope, not a national authority inventory"},
            "qualification_audit_file":auditpath.relative_to(cache).as_posix(),"qualification_audit_sha256":core.digest(auditpath.read_bytes()),
            "scope_note":"30 positively ISO-verified source provinces; unverified outside-scope typed areas retained in raw audit, not assigned by archive filename"}
    source=qualify_coverage_metadata(source)
    _verify_cached(cache,source);core.write_json(receipt,{"sources":[source]});core.write_json(ROOT/"data/atlas_iran_sources.json",{"schema":1,"sources":[source]})
    return [source]


def iter_boundaries(cache:Path,sources:list[dict]):
    for source in sources:
        if source.get("id")!=SOURCE_ID or source.get("country")!="IR" or source.get("kind")!="local_admin":
            raise ValueError("Unreviewed current Iran provider identity")
        _verify_cached(Path(cache),source);count=0;seen=set()
        with gzip.open(Path(cache)/source["cache_file"],"rt",encoding="utf8") as stream:
            for line in stream:
                row=json.loads(line)
                if row["id"] in seen or row["source"]!=SOURCE_ID or row["kind"]!="local_admin" or candidate_role(row["original_properties"]) is None:
                    raise ValueError("Changed typed Iranian source identity")
                row["geometry"]=shape(row["geometry"]);seen.add(row["id"]);count+=1;yield row
        if count!=source["expected_unit_count"]:raise ValueError("Changed current Iranian source count")


if __name__=="__main__":
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument("--cache",type=Path,default=ROOT/".tools/atlas_sources")
    args=parser.parse_args();sources=prepare_sources(args.cache)
    print(json.dumps({"sources":sources,"validated_records":sum(1 for _ in iter_boundaries(args.cache,sources))},ensure_ascii=True,indent=2))
