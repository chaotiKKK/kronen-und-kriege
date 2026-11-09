"""Country-role validation and staged administrative extracts; HU v3 stays immutable."""
from __future__ import annotations
from collections import Counter
import gzip
import io
import json
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

import shapely
from shapely.geometry import mapping, shape
import atlas_geofabrik_sources as core

VERSION = 4
STAGES = {"SK":"slovakia","EE":"estonia","AL":"albania","MK":"macedonia","MD":"moldova",
          "GG":"guernsey-jersey","JE":"guernsey-jersey","IM":"isle-of-man","FO":"faroe-islands"}
ROLE_ROWS = {
    "CZ":{4:("region","Kraj"),5:("district","Okres"),6:("district","Správní obvod ORP"),7:("district","Správní obvod POÚ"),8:("municipality","Obec"),9:("local_admin","Městská část")},
    "SK":{4:("region","Kraj"),6:("district","Okres"),8:("municipality","Obec/mesto"),9:("local_admin","Mestská časť")},
    "EE":{6:("region","Maakond"),7:("municipality","Vald/linn")},
    "NO":{4:("region","Fylke"),7:("municipality","Kommune"),9:("local_admin","Bydel")},
    "AL":{6:("region","Qark"),7:("municipality","Bashkia"),8:("local_admin","Njësia administrative"),9:("local_admin","Lagje")},
    "MK":{6:("region","Град Скопје (aggregated city)"),7:("municipality","Општина")},
    "MD":{4:("region","Raion/autonomous area/municipiu II"),6:("municipality","Municipiu I"),7:("local_admin","Sector"),8:("municipality","Oraș/comună/sat")},
    "GG":{4:("region","Jurisdiction"),8:("municipality","Parish"),9:("local_admin","Parish subdivision"),10:("local_admin","Canton")},
    "JE":{8:("municipality","Parish"),9:("local_admin","Vingtaine/Cueillette"),10:("local_admin","Canton")},
    "FO":{6:("region","Sýsla"),7:("municipality","Kommuna")},
    "RU":{4:("region","Субъект РФ"),5:("district","Административный округ"),6:("district","Муниципальный район/городской округ"),
          8:("municipality","Муниципальное образование"),9:("local_admin","Административный район")},
    "TR":{4:("region","İl"),6:("district","İlçe"),7:("municipality","Belde"),8:("local_admin","Mahalle/Köy")}}
EVIDENCE = {
    "SK":["https://wiki.openstreetmap.org/wiki/Mechanical_Edits/Fjana/reorganization_of_boundaries_in_Slovakia"],
    "EE":["https://wiki.openstreetmap.org/wiki/User:Apo_lemus/admin_level%3D%2A_Estonia_specific_values","https://fin.ee/riik-ja-omavalitsused-planeeringud/kohalikud-omavalitsused/asustusjaotus"],
    "AL":["https://wiki.openstreetmap.org/wiki/Template:Admin_level","https://www.instat.gov.al/media/11124/regional-statistical-yearbook-2022_04.pdf"],
    "MK":["https://wiki.openstreetmap.org/wiki/Mk:WikiProject_Macedonia/Administrative_Boundaries","https://www.stat.gov.mk/oblastopsto_en.aspx?id=1"],
    "MD":["https://wiki.openstreetmap.org/wiki/Template:Admin_level","https://gov.md/en/node/10566"],
    "GG":["https://wiki.openstreetmap.org/wiki/Template:Admin_level","https://valeparish.gg/douzaine/about-us/"],
    "JE":["https://wiki.openstreetmap.org/wiki/Template:Admin_level","https://www.gov.je/LifeEvents/MovingToJersey/SettlingIn/Pages/ParishLife.aspx"]}
EVIDENCE["EE"].append("https://agri.ee/regionaalareng-uhistransport/kohalikud-omavalitsused")
MANX_NAMES = {"Andreas","Arbory and Rushen","Ballaugh","Braddan","Bride","Castletown","Douglas","Garff","German","Jurby",
              "Lezayre","Malew","Marown","Michael","Onchan","Patrick","Peel","Port Erin","Port St Mary","Ramsey","Santon"}
MANX_MERGERS = {
    "Garff":({"1061137","1061136","1061140"},"2016-05-01","https://www.gov.im/categories/home-and-neighbourhood/local-authorities/local-authority-contacts/garff/"),
    "Arbory and Rushen":({"1029669","1029670"},"2020-05-01","https://legislation.gov.im/cms/images/LEGISLATION/SUBORDINATE/2019/2019-0498/2019-0498_3.pdf")}
EVIDENCE["IM"]=["https://www.gov.im/categories/home-and-neighbourhood/local-authorities/local-authority-contacts/",*[value[2] for value in MANX_MERGERS.values()]]
EVIDENCE["FO"]=["https://gis.us.fo/arcgis/rest/services/fyrisitingarlig_kort/us_kommunur/MapServer/0","https://www.foroyakort.fo/vevtaenastur"]
EVIDENCE["CZ"]=["https://wiki.openstreetmap.org/wiki/Creation_of_administrative_districts_in_Czechia","https://csu.gov.cz/territorial-units-methodology"]
EVIDENCE["NO"]=["https://wiki.openstreetmap.org/wiki/Norway/Administrative_grenser","https://lovdata.no/dokument/NLE/lov/2018-06-22-83/%C2%A73-2"]
EVIDENCE["RU"]=["https://wiki.openstreetmap.org/wiki/RU%3ATag%3Aboundary%3Dadministrative","https://wiki.openstreetmap.org/wiki/RU%3AKey%3Aadmin_level"]
EVIDENCE["TR"]=["https://wiki.openstreetmap.org/wiki/Template:Admin_level"]
MENA_PROFILES={
    "LB":("lebanon",{4:("region","Mouhafazah"),5:("district","Qadaa"),7:("municipality","Baladiya")},"https://legallaw.ul.edu.lb/Law.aspx?lawId=244078"),
    "BY":("belarus",{4:("region","Voblast"),6:("district","Raion"),8:("municipality","Selsovet / local council")},"https://natlex.ilo.org/dyn/natlex2/natlex2/files/download/86988/BLR86988.pdf"),
    "IQ":("iraq",{4:("region","Muhafazah"),6:("district","Qadaa"),7:("local_admin","Nahiya")},"https://www.cosit.gov.iq/documents/AAS2020/1.pdf"),
    "SY":("syria",{4:("region","Muhafazah"),5:("district","Mantiqa"),6:("local_admin","Nahiya")},"https://www.humanitarianatlas.org/syria/"),
    "TN":("tunisia",{4:("region","Gouvernorat"),5:("district","Delegation"),6:("local_admin","Imada / sector")},"https://www.cgdr.nat.tn/upload/files/Etudes/Etude/Evaluation_PRD_Rapport%20Phase2%20VFinale.pdf"),
    "KZ":("kazakhstan",{4:("region","Oblys"),6:("district","Audan"),8:("municipality","Rural okrug")},"https://old.adilet.zan.kz/eng/docs/Z010000148_"),
    "IL":("israel-and-palestine",{4:("region","Mehoz"),5:("district","Nafa"),8:("municipality","Local Authority (city/local/regional council)")},"https://www.cbs.gov.il/he/publications/DocLib/isr_in_n/sr_in_n21e.pdf"),
    "JO":("jordan",{4:("region","Muhafazah")},"https://www.iec.jo/node/37691"),
    "LY":("libya",{4:("region","Shabiya")},"https://www.undp.org/sites/g/files/zskgke326/files/2022-06/UN-Startegic-Framework-for-Libya-2019-2022.pdf"),
    "AZ":("azerbaijan",{8:("municipality","Belediyye")},"https://justice.gov.az/az/news/edliyye-nazirliyi-belediyyelerle-bagli-tovsiye-hazirlayib")}
for _country,(_slug,_roles,_primary) in MENA_PROFILES.items():
    ROLE_ROWS[_country]=_roles
    EVIDENCE[_country]=["https://wiki.openstreetmap.org/wiki/Template:Admin_level",_primary]
REGIONAL_SLUGS={
    "CZ":["jihocesky","jihomoravsky","karlovarsky","kralovehradecky","liberecky","moravskoslezky","olomoucky","pardubicky","plzensky","praha","stredocesky","ustecky","vysocina","zlinsky"],
    "NO":["nord-norge","ostlandet","sorlandet","trondelag","vestlandet"],
    "RU":["central-fed-district","north-caucasus-fed-district","northwestern-fed-district","south-fed-district","volga-fed-district"]}
REGIONAL_PREFIX={"CZ":"czech-republic","NO":"norway","RU":"russia"}


def classify_role(country: str, properties: dict, tags=None):
    match = re.fullmatch(r"admin_level(\d+)",str(properties.get("fclass","")))
    if not match:
        return None
    level = int(match[1])
    if properties.get("code") != 1200+level:
        return None
    tags = tags or {}
    if country=="CZ" and level in (7,8):
        if tags.get("border_type")=="military_area" or tags.get("place")=="military_area":
            return "local_admin","Vojenský újezd"
        if "vojenský újezd" in str(properties.get("name","")).casefold():
            raise ValueError("Czech military-area qualification is required")
    if country=="SK":
        if level==5:
            return ("municipality","Mesto") if tags.get("border_type")=="city" and tags.get("official_status")=="sk:mesto" else None
        if level==8 and (tags.get("border_type")=="military_area" or tags.get("place")=="military_area"):
            return "local_admin","Vojenský obvod"
        if level==8 and "vojenský obvod" in str(properties.get("name","")).casefold():
            raise ValueError("Slovak military-area qualification is required")
    return ROLE_ROWS.get(country,{}).get(level)


def feature_id(country: str, level: int, identifier: str):
    return f"geofabrik:{country}:{level}:{identifier}"


def merge_by_id(rows):
    grouped = {}
    for row in rows:
        if row["id"] not in grouped:
            grouped[row["id"]] = row.copy()
            continue
        previous = grouped[row["id"]]
        if (previous["country"],previous["kind"]) != (row["country"],row["kind"]):
            raise ValueError("Conflicting regional administrative identity")
        previous["geometry"] = shapely.union(previous["geometry"],row["geometry"])
        previous["source_snapshots"] = sorted(set(previous["source_snapshots"]+row["source_snapshots"]))
        if previous["name"] != row["name"]:
            previous["name_conflict"] = sorted(set(previous.get("name_conflict",[previous["name"]])+[row["name"]]))
    return [grouped[key] for key in sorted(grouped)]


def source_groups(rows):
    groups = {}
    for row in rows:
        row["source"] = row.get("provider_source_id",f"geofabrik-{row['country']}-admin{row['admin_level']}-{row['kind']}")
        groups.setdefault(row["source"],[]).append(row)
    return groups


def current_manx_authorities(rows):
    indexed={row["original_source_id"]:row for row in rows}
    consumed,result=set(),[]
    for name,(identifiers,date,evidence) in MANX_MERGERS.items():
        present=identifiers & set(indexed)
        if present and present!=identifiers:
            raise ValueError("Incomplete constituent set for an official Manx authority merger")
        if not present:
            continue
        parts=[indexed[key] for key in sorted(identifiers)]
        geometry=shapely.union_all([row["geometry"] for row in parts])
        if not geometry.is_valid or abs(geometry.area-sum(row["geometry"].area for row in parts))>max(1e-12,geometry.area*1e-8):
            raise ValueError("Official merger constituent polygons overlap or form an invalid area")
        first=parts[0]
        result.append({**first,"id":"geofabrik:IM:authority:"+name.casefold().replace(" ","-"),"name":name,
            "kind":"municipality","unit_type":"Local Authority","native_type":"Local Authority","geometry":geometry,
            "original_source_id":None,"constituent_source_ids":sorted(identifiers),"original_name":None,
            "constituent_names":[row["name"] for row in parts],"source_geometry_derivation":"official-local-authority-merger",
            "government_effective_date":date,"government_evidence_url":evidence,
            "source_snapshots":sorted({snapshot for row in parts for snapshot in row["source_snapshots"]})})
        consumed.update(identifiers)
    for row in rows:
        if row["original_source_id"] in consumed:
            continue
        name="Port St Mary" if row["name"]=="Port Saint Mary" else row["name"]
        if name not in MANX_NAMES:
            raise ValueError("Unmatched old Manx unit is not an accepted current Local Authority: "+name)
        result.append({**row,"name":name,"kind":"municipality","unit_type":"Local Authority","native_type":"Local Authority",
            "government_evidence_url":EVIDENCE["IM"][0]})
    return sorted(result,key=lambda row:row["id"])


def regional_iso_scope(rows, country: str):
    selected,geometries=[],[]
    for row in rows:
        tags=row.get("tags",{})
        codes=[code.strip() for code in str(tags.get("ISO3166-2","")).split(";") if code.strip()]
        if (not codes or any(not code.startswith(country+"-") for code in codes)
                or tags.get("boundary")!="administrative" or tags.get("name")!=row["name"]):
            continue
        selected.extend(codes)
        geometries.append(row["geometry"])
    if not geometries:
        raise ValueError("No positively ISO-tagged regional territorial scope")
    geometry=shapely.union_all(geometries)
    if geometry.is_empty or not geometry.is_valid:
        raise ValueError("Invalid union of verified regional territorial areas")
    return geometry,sorted(set(selected))


def assign_scoped_country(geometry,country,territory,references):
    if not territory.covers(geometry):
        return core.assign_verified_territory(geometry,country,territory,references)
    independent,detail=core.assign_country(geometry,references)
    detail.update(fraction=1.0,territorial_fraction=1.0,independent_land_country=independent,
        independent_land_disagreement=independent!=country,method="verified_iso_territorial_overlap",ambiguous=False)
    return country,detail


def worker_scope(serialized):
    geometry=shapely.from_wkb(serialized if isinstance(serialized,bytes) else serialized.wkb)
    shapely.prepare(geometry)
    return geometry


def _regional_territorial_reference(reader,directory: Path,snapshot: str,country: str):
    supplemental=list(directory.glob(country+"-*-territorial-reference.receipt.json"))
    if supplemental:
        if len(supplemental)!=1:
            raise ValueError("Ambiguous supplemental regional territorial reference")
        stem=supplemental[0].name.removesuffix(".receipt.json")
        geometry,proof=_verified_geojson(directory,stem,snapshot)
        return geometry,proof
    by_level={}
    for index,record in enumerate(reader.iterRecords()):
        properties=record.as_dict()
        if properties["fclass"] in {"admin_level4","admin_level5","admin_level6"}:
            by_level.setdefault(int(properties["fclass"].removeprefix("admin_level")),[]).append((index,properties))
    candidates=by_level[min(by_level)] if by_level else []
    if not candidates:
        raise ValueError("Regional extract has no coarse administrative country-scope candidates")
    key=core.digest(",".join(sorted(row["osm_id"] for _,row in candidates)).encode("ascii"))[:16]
    path=directory/("regional-iso-identities-"+key+".xml")
    if not path.exists():
        identifiers=",".join(row["osm_id"] for _,row in candidates)
        url="https://api.openstreetmap.org/api/0.6/relations?relations="+identifiers
        temporary=path.with_suffix(".partial")
        subprocess.run(["curl.exe","--fail","--location","--silent","--show-error","--max-time","45",
            "--max-filesize","4000000","--output",str(temporary),url],check=True)
        temporary.replace(path)
    metadata={}
    for relation in ET.parse(path).getroot().findall("relation"):
        tags={tag.get("k"):tag.get("v") for tag in relation.findall("tag")}
        version=int(relation.get("version"))
        timestamp=relation.get("timestamp")
        for _ in range(12):
            if timestamp<=snapshot:
                break
            version-=1
            historical=directory/f"regional-iso-{relation.get('id')}-v{version}.json"
            if not historical.exists():
                subprocess.run(["curl.exe","--fail","--location","--silent","--show-error","--max-time","30",
                    "--max-filesize","2000000","--output",str(historical),
                    f"https://api.openstreetmap.org/api/0.6/relation/{relation.get('id')}/{version}.json"],check=True)
            row=json.loads(historical.read_text(encoding="utf-8"))["elements"][0]
            tags,timestamp=row.get("tags",{}),row["timestamp"]
        else:
            raise ValueError("Regional ISO identity exceeds the bounded snapshot lookup")
        metadata[relation.get("id")]={"tags":tags,"version":version,"timestamp":timestamp}
    rows=[]
    for index,properties in candidates:
        if properties["osm_id"] not in metadata:
            continue
        identity=metadata[properties["osm_id"]]
        rows.append({"name":properties["name"],"tags":identity["tags"],
            "geometry":shapely.make_valid(shape(reader.shape(index).__geo_interface__))})
    geometry,codes=regional_iso_scope(rows,country)
    return geometry,{"country":country,"source_admin_level":min(by_level),"iso3166_2_codes":codes,"identity_payload_sha256":core.digest(path.read_bytes()),
        "identities":metadata,"snapshot":snapshot,"purpose":"Verified regional territorial attribution only; not a national land denominator or municipality union",
        "scope":"One regional Geofabrik extract; no claim that this reference alone covers the entire country"}


def _czech_military_qualifications(reader,directory: Path,snapshot: str):
    result={}
    for record in reader.iterRecords():
        properties=record.as_dict()
        if "vojenský újezd" not in properties["name"].casefold():
            continue
        identifier=properties["osm_id"]
        path=directory/f"qualification-cz-{identifier}.json"
        if not path.exists():
            subprocess.run(["curl.exe","--fail","--location","--silent","--show-error","--max-time","30",
                "--max-filesize","2000000","--output",str(path),f"https://api.openstreetmap.org/api/0.6/relation/{identifier}.json"],check=True)
        relation=json.loads(path.read_text(encoding="utf-8"))["elements"][0]
        if relation["timestamp"]>snapshot:
            raise ValueError("Czech military qualification needs a historical snapshot-compatible version")
        result[identifier]={"tags":relation.get("tags",{}),"version":relation["version"],"timestamp":relation["timestamp"],
            "source_url":f"https://api.openstreetmap.org/api/0.6/relation/{identifier}/{relation['version']}.json",
            "evidence_file_sha256":core.digest(path.read_bytes())}
    return result


def _qualifications(directory: Path, timestamp: str):
    path = directory/"qualification-current-relations.xml"
    if not path.exists():
        url = "https://api.openstreetmap.org/api/0.6/relations?relations=2265034,2322594,2206956,1702499,1690324"
        temporary = path.with_suffix(".partial")
        subprocess.run(["curl.exe","--fail","--location","--silent","--show-error","--max-time","30",
            "--max-filesize","2000000","--output",str(temporary),url],check=True)
        temporary.replace(path)
    result = {}
    for relation in ET.parse(path).getroot().findall("relation"):
        if relation.get("timestamp","")>timestamp:
            raise ValueError("Special administrative qualification is newer than the archive snapshot")
        identifier = relation.get("id")
        tags = {tag.get("k"):tag.get("v") for tag in relation.findall("tag")}
        if tags.get("boundary")!="administrative":
            raise ValueError("Special qualification is not an administrative boundary")
        result[identifier] = {"tags":tags,"version":int(relation.get("version")),"timestamp":relation.get("timestamp"),
            "source_url":f"https://api.openstreetmap.org/api/0.6/relation/{identifier}/{relation.get('version')}.json",
            "evidence_file_sha256":core.digest(path.read_bytes())}
    return result


def _verified_geojson(directory: Path, stem: str, snapshot: str):
    path,receipt_path=directory/(stem+".geojson"),directory/(stem+".receipt.json")
    receipt=json.loads(receipt_path.read_text(encoding="utf-8"))
    if core.digest(path.read_bytes())!=receipt["geojson_file_sha256"] or receipt["snapshot"]!=snapshot or receipt["latest_member_timestamp"]>snapshot:
        raise ValueError("Supplemental geometry hash/snapshot does not match")
    data=json.loads(path.read_text(encoding="utf-8"))
    geometry=shape(data["geometry"] if data.get("type")=="Feature" else data)
    if geometry.is_empty or not geometry.is_valid or geometry.geom_type not in ("Polygon","MultiPolygon"):
        raise ValueError("Invalid supplemental polygon")
    return geometry,receipt


def staged_polygon(source_shape,properties):
    if not len(source_shape.points):
        return None,{"original_source_id":str(properties["osm_id"]),"original_properties":properties,
            "reason":"zero-point-source-polygon","point_count":0,"shape_type":source_shape.shapeType,
            "country_assignment":"unresolved-no-geometry","geometry_created":False}
    geometry=shapely.make_valid(shape(source_shape.__geo_interface__))
    if geometry.is_empty or geometry.geom_type not in ("Polygon","MultiPolygon") or geometry.area<=0:
        raise ValueError("Invalid nonempty staged administrative polygon")
    return geometry,None


def apply_regional_qualifications(rows,qualifications):
    for row in rows:
        proof=qualifications.get(row.get("original_source_id"))
        if proof is None:
            continue
        tags=proof.get("tags",{})
        if (row["country"]!="CZ" or tags.get("name")!=row["name"]
                or tags.get("boundary")!="administrative" or tags.get("admin_level")!=str(row["admin_level"])):
            raise ValueError("Regional display qualification identity mismatch")
        if row["admin_level"]==4 and tags.get("official_status")=="cz:hlavní město" and tags.get("border_type")=="city":
            if proof.get("government_evidence_url")!="https://apl2.czso.cz/iSMS/cisinfo.jsp?kodcis=69":
                raise ValueError("Capital municipality role requires its official role evidence")
            row["local_government_role"]="municipality"
            row["local_government_role_evidence"]=proof["government_evidence_url"]
        elif row["admin_level"]==5 and tags.get("official_status")=="cz:obvod" and tags.get("border_type")=="district":
            row["unit_type"]=row["native_type"]="Obvod hlavního města"
        else:
            raise ValueError("Unrecognized positively qualified regional display role")
        row["native_role_qualification"]=proof
    core.reconcile_local_roles(rows)


def verified_country_replacement(rows,audit):
    local=[row for row in rows if row["kind"]=="municipality"]
    expected={str(row["original_source_id"]):row["osm_name"] for row in audit.get("matches",[])}
    actual={str(row["original_source_id"]):row["name"] for row in local}
    if (audit.get("official_count")!=78 or audit.get("matched_count")!=78 or audit.get("missing")!=[]
            or audit.get("extra")!=[] or len(local)!=78 or len(expected)!=78 or actual!=expected):
        raise ValueError("Complete municipal identity audit differs from the actual source cache")
    return {"replacement_scope":"country","replacement_basis":"Complete positive current official municipality identity/name audit; not a land-coverage measurement",
        "official_municipality_count":78,"verified_source_identity_count":78}


GG_TERMINAL={
    "geofabrik:GG:4:1973199":("Sark","Chief Pleas","https://sarkgov.co.uk/living-on-sark"),
    "geofabrik:GG:4:1973200":("Alderney","States of Alderney","https://www.alderneyelections.gg/how-government-works/structure/")}


def annotate_guernsey_terminal_roles(rows):
    selected={row["id"]:row for row in rows if row["id"] in GG_TERMINAL}
    for identifier,(name,government,url) in GG_TERMINAL.items():
        row=selected.get(identifier,{})
        if (row.get("country")!="GG" or row.get("name")!=name or row.get("kind")!="region"
                or row.get("admin_level")!=4 or row.get("unit_type")!="Jurisdiction"):
            raise ValueError("Terminal jurisdiction identity is not the explicitly qualified original region")
    for identifier,(name,government,url) in GG_TERMINAL.items():
        selected[identifier].update(local_government_role="local_admin",local_government_role_evidence=url,
            local_government_native_role=government,terminal_territorial_administration=True,
            local_government_role_limits="Terminal self-governing jurisdiction, not an invented municipality or parish; source polygon and independent land coverage remain separate")


def prepare_guernsey_terminal_roles(cache,dataset):
    evidence_dir=cache/"audit/gg-terminal-role-evidence"
    evidence_path=evidence_dir/"receipt.json"
    evidence=json.loads(evidence_path.read_text(encoding="utf-8"))
    for source in evidence["sources"].values():
        if core.digest((evidence_dir/source["file"]).read_bytes())!=source["sha256"]:
            raise ValueError("Changed original jurisdiction-government evidence")
    if {entry["url"] for entry in evidence["sources"].values()}!={*(value[2] for value in GG_TERMINAL.values()),
            "https://www.gov.uk/government/publications/crown-dependencies-jersey-guernsey-and-the-isle-of-man"}:
        raise ValueError("Terminal jurisdiction source set differs from the independently checked primary evidence")
    rows=list(core.iter_boundaries(cache,dataset["sources"]))
    annotate_guernsey_terminal_roles(rows)
    fingerprint=core.digest((dataset["sources"][0]["sha256"]+core.digest(evidence_path.read_bytes())).encode())[:12]
    directory=cache/"geofabrik-stage/guernsey-jersey"
    path=directory/f"normalized-GG-v4-r4-terminal-{fingerprint}.jsonl.gz"
    temporary=path.with_suffix(path.suffix+".partial")
    with temporary.open("wb") as raw,gzip.GzipFile(filename="",mode="wb",fileobj=raw,mtime=0) as compressed,io.TextIOWrapper(compressed,encoding="utf-8",newline="\n") as output:
        for row in rows:
            output.write(json.dumps({**row,"geometry":mapping(row["geometry"])},ensure_ascii=False,separators=(",",":"),allow_nan=False)+"\n")
    if path.exists() and core.digest(path.read_bytes())!=core.digest(temporary.read_bytes()):
        raise ValueError("Changed immutable terminal-jurisdiction cache revision")
    temporary.replace(path)
    evidence_proof={"file":evidence_path.relative_to(cache).as_posix(),"sha256":core.digest(evidence_path.read_bytes()),"sources":evidence["sources"]}
    sources=[]
    for source in dataset["sources"]:
        updated={**source,"cache_file":path.relative_to(cache).as_posix(),"sha256":core.digest(path.read_bytes()),"bytes":path.stat().st_size}
        if source["kind"]=="region":
            updated.update(terminal_local_roles=[{"id":identifier,"name":value[0],"local_government_role":"local_admin","native_role":value[1],"evidence_url":value[2]} for identifier,value in GG_TERMINAL.items()],
                terminal_role_evidence=evidence_proof,
                terminal_role_limits="Exactly Sark/Alderney keep region/Jurisdiction plus local territorial self-government; Guernsey's ten actual parishes remain its local tier. No duplicate municipality/parish or land denominator is introduced")
        sources.append(updated)
    result={**dataset,"sources":sources,"cache_revision":4,"terminal_role_evidence":evidence_proof,
        "previous_immutable_cache_files":sorted({source["cache_file"] for source in dataset["sources"]})}
    core.write_json(directory/"normalized-GG-v4-r4-terminal.receipt.json",result)
    return result


def annotate_turkish_metropolitan_roles(rows,proof):
    index={row["id"]:row for row in rows}
    for match in proof["matches"]:
        row=index.get(match["id"],{})
        iso=match.get("iso_3166_2","")
        if (row.get("country")!="TR" or row.get("kind")!="region" or row.get("admin_level")!=4
                or row.get("unit_type")!="İl" or row.get("name")!=match["name"]
                or str(row.get("original_source_id"))!=str(match["original_source_id"])
                or re.fullmatch(r"TR-(0[1-9]|[1-7][0-9]|8[01])",iso) is None):
            raise ValueError("Metropolitan province identity differs from the positively qualified original source")
    for match in proof["matches"]:
        index[match["id"]].update(local_government_role="municipality",
            local_government_role_evidence=proof["law_evidence_url"],
            local_government_role_identity_evidence=proof["identity_evidence_url"],
            local_government_native_role="Büyükşehir Belediyesi",local_government_name=match["authority_name"],
            local_government_iso_3166_2=match["iso_3166_2"],
            local_government_geometry_scope="Exactly coextensive original province polygon under6360Art6 amending5216Art5; no duplicate municipal geometry",
            local_government_role_limits="This is the larger metropolitan authority, not every ordinary provincial or district municipality and not a completed fine local layer")


def quarantine_turkish_former_beldes(rows,proof):
    index={row["id"]:row for row in rows}
    for match in proof["matches"]:
        row,parent=index.get(match["id"],{}),index.get(match["metropolitan_parent"],{})
        if (row.get("country")!="TR" or row.get("kind")!="municipality" or row.get("admin_level")!=7
                or row.get("unit_type")!="Belde" or row.get("name")!=match["name"]
                or parent.get("name")!=match["province_name"] or parent.get("local_government_role")!="municipality"
                or row["geometry"].intersection(parent["geometry"]).area/row["geometry"].area<.9999):
            raise ValueError("Former metropolitan Belde identity/territorial scope is not positively qualified")
    for match in proof["matches"]:
        index[match["id"]].update(administrative_geometry_eligible=False,
            administrative_ineligibility_note="Original admin7Belde polygon retained as source evidence; independent Belde municipality personality inside this metropolitan province was abolished by6360Art1(3). No present-day administrative replacement is invented.",
            administrative_ineligibility_evidence_url=proof["law_evidence_url"],
            administrative_ineligibility_act=proof["act_number"],administrative_ineligibility_article=proof["article"],
            administrative_ineligibility_act_adopted_date=proof["act_adopted_date"],administrative_ineligibility_review_date=proof["review_date"],
            administrative_ineligibility_metropolitan_parent_id=match["metropolitan_parent"],
            administrative_ineligibility_metropolitan_parent_name=match["province_name"],
            administrative_ineligibility_metropolitan_parent_iso=match["province_iso_3166_2"])


def prepare_turkish_metropolitan_roles(cache,dataset):
    directory=cache/"audit/TR-metropolitan-roles-2026"
    audit_path=directory/"audit.json"
    audit=json.loads(audit_path.read_text(encoding="utf-8"))
    if (audit.get("matched_count")!=30 or audit.get("current_TBB_metropolitan_count")!=30
            or audit.get("missing")!=[] or audit.get("extra")!=[] or audit.get("snapshot")!="2026-11-08T21:21:00Z"
            or len({m["id"] for m in audit["matches"]})!=30 or len({m["iso_3166_2"] for m in audit["matches"]})!=30
            or any(s["sha256"]!=audit["base_cache_sha256"] for s in dataset["sources"])):
        raise ValueError("Current thirty-metropolis identity audit differs from the admitted original province cache")
    for evidence in audit["files"]:
        raw=(directory/evidence["file"]).read_bytes()
        if len(raw)!=evidence["bytes"] or core.digest(raw)!=evidence["sha256"]:
            raise ValueError("Changed primary Turkish metropolitan role evidence")
    metadata={str(r["id"]):r for r in json.loads((directory/"OSM-provinces.json").read_text(encoding="utf-8"))["elements"]}
    for match in audit["matches"]:
        relation=metadata[match["original_source_id"]];tags=relation.get("tags",{})
        if (relation["timestamp"]>audit["snapshot"] or tags.get("boundary")!="administrative" or tags.get("admin_level")!="4"
                or tags.get("ISO3166-2")!=match["iso_3166_2"] or tags.get("name")!=match["name"]
                or relation["version"]!=match["relation_version"]):
            raise ValueError("Changed native province ISO identity or snapshot")
    proof={"matches":audit["matches"],"law_evidence_url":audit["files"][1]["url"],"identity_evidence_url":audit["files"][0]["url"]}
    rows=list(core.iter_boundaries(cache,dataset["sources"]))
    for row in rows:
        row.pop("verified_source_alias",None)
    annotate_turkish_metropolitan_roles(rows,proof)
    quarantine_path=directory/"former-belde-quarantine-audit.json"
    quarantine=json.loads(quarantine_path.read_text(encoding="utf-8"))
    if (quarantine.get("qualified_count")!=11 or len({r["id"] for r in quarantine["matches"]})!=11
            or quarantine.get("law_sha256")!=audit["files"][1]["sha256"] or quarantine.get("base_cache_sha256")!=audit["base_cache_sha256"]):
        raise ValueError("Former Belde scope differs from the eleven individually reviewed records")
    quarantine_turkish_former_beldes(rows,quarantine)
    fingerprint=core.digest(audit_path.read_bytes()+quarantine_path.read_bytes())[:12]
    path=cache/"geofabrik-stage/turkey"/f"normalized-TR-v4-r5-metropolitan-{fingerprint}.jsonl.gz"
    temporary=path.with_suffix(path.suffix+".partial")
    with temporary.open("wb") as raw,gzip.GzipFile(filename="",mode="wb",fileobj=raw,mtime=0) as compressed,io.TextIOWrapper(compressed,encoding="utf-8",newline="\n") as output:
        for row in rows:
            output.write(json.dumps({**row,"geometry":mapping(row["geometry"])},ensure_ascii=False,separators=(",",":"),allow_nan=False)+"\n")
    if path.exists() and core.digest(path.read_bytes())!=core.digest(temporary.read_bytes()):
        raise ValueError("Changed immutable Turkish metropolitan-role revision")
    temporary.replace(path)
    sha=core.digest(path.read_bytes())
    old_alias_path=cache/dataset["sources"][0].get("verified_source_alias_audit",{"file":"audit/OSM-Geofabrik-TR-RU-alias-audit.json"})["file"]
    old_alias=json.loads(old_alias_path.read_text(encoding="utf-8"))
    pairs=[{**pair,"geofabrik_cache_sha256":sha,"prior_original_geometry_cache_sha256":pair["geofabrik_cache_sha256"],
        "cache_revision_note":"Only30 province municipal roles annotated; every original polygon/identity and all alias geometry remain unchanged"}
        for pair in old_alias["candidate_pairs"] if pair["country"]=="TR"]
    alias_path=cache/"audit"/f"OSM-Geofabrik-TR-alias-audit-{sha[:12]}.json"
    core.write_json(alias_path,{**old_alias,"candidate_pairs":pairs,"matched_count":len(pairs),
        "prior_audit_sha256":core.digest(old_alias_path.read_bytes()),"production_modified":False})
    alias_proof={"file":alias_path.relative_to(cache).as_posix(),"sha256":core.digest(alias_path.read_bytes()),"bytes":alias_path.stat().st_size}
    sources=[]
    for source in dataset["sources"]:
        updated={**source,"cache_file":path.relative_to(cache).as_posix(),"sha256":sha,"bytes":path.stat().st_size,
            "verified_source_alias_audit":alias_proof}
        if source["admin_level"]==4:
            updated.update(metropolitan_coextensive_authority_count=30,metropolitan_authority_matches=audit["matches"],
                metropolitan_role_evidence={"file":audit_path.relative_to(cache).as_posix(),"sha256":core.digest(audit_path.read_bytes()),
                    "law_url":proof["law_evidence_url"],"identity_url":proof["identity_evidence_url"],"basis":"6360Art6 amending5216Art5; current TBB thirty-authority list; original source province ISO/name/version",
                    "limits":audit["limits"]})
        if source["admin_level"]==7:
            updated.update(quarantined_administrative_unit_count=11,quarantined_administrative_unit_ids=sorted(r["id"] for r in quarantine["matches"]),
                admitted_source_unit_count=source["source_unit_count"]-11,
                administrative_eligibility_note="Mixed source: all85 original Belde records retained; exactly11 obsolete metropolitan Belde municipal claims are individually quarantined without relabeling geometry or type",
                administrative_quarantine_evidence={"file":quarantine_path.relative_to(cache).as_posix(),"sha256":core.digest(quarantine_path.read_bytes()),
                    "law_url":quarantine["law_evidence_url"],"act":"6360Art1(3)","act_adopted_date":"2012-11-12","review_date":"2026-11-09"})
        sources.append(updated)
    result={**dataset,"sources":sources,"cache_revision":5,"metropolitan_role_audit_sha256":core.digest(audit_path.read_bytes()),
        "former_belde_quarantine_sha256":core.digest(quarantine_path.read_bytes()),
        "previous_immutable_cache_files":sorted({s["cache_file"] for s in dataset["sources"]})}
    core.write_json(path.parent/"normalized-TR-v4-r5-metropolitan.receipt.json",result)
    return result


def prepare_country(cache: Path, country: str, directory: Path | None = None, *, territory_override=None) -> dict:
    directory = Path(directory) if directory is not None else cache/"geofabrik-stage"/STAGES[country]
    revision="r5-"+territory_override[1]["geometry_sha256"][:12] if territory_override is not None else "r3"
    receipt_path = directory/f"normalized-{country}-v{VERSION}-{revision}.receipt.json"
    if receipt_path.exists():
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        for source in receipt["sources"]:
            path = cache/source["cache_file"]
            if core.digest(path.read_bytes())!=source["sha256"]:
                raise ValueError("Changed normalized collection cache")
        return receipt
    stage = json.loads((directory/"staging-receipt.json").read_text(encoding="utf-8"))
    if stage.get("status")!="complete-cache-only":
        raise ValueError("An incomplete source stage cannot be normalized")
    for member in stage["members"]:
        path = directory/"members"/member["name"]
        if core.digest(path.read_bytes())!=member["sha256"] or path.stat().st_size!=member["bytes"]:
            raise ValueError("Changed staged member hash/size")
    base = directory/"members/gis_osm_adminareas_a_free_1"
    if "WGS_1984" not in base.with_suffix(".prj").read_text(encoding="ascii"):
        raise ValueError("Unreviewed collection CRS")
    reader = core._shapefile().Reader(str(base),encoding=base.with_suffix(".cpg").read_text(encoding="ascii").strip())
    official_matches={}
    if country=="FO":
        audit=json.loads((directory/"role-name-audit.json").read_text(encoding="utf-8"))
        if (audit.get("country")!="FO" or audit.get("matched_count")!=29 or audit.get("official_count")!=29
                or audit.get("unmatched_source_names") or audit.get("unmatched_official_names")
                or audit.get("source_dbf_sha256")!=core.digest(base.with_suffix(".dbf").read_bytes())):
            raise ValueError("Faroese municipality role/name audit does not match the staged DBF")
        official_matches={str(row["osm_id"]):row for row in audit["matches"]}
        if len(official_matches)!=29:
            raise ValueError("Faroese official-name join is not one-to-one")
    references,land_reference = core._references(cache,reader.bbox)
    try:
        regional=any(part in stage["url"] for part in ("/czech-republic/","/norway/","/russia/"))
        if territory_override is not None:
            territory,territorial_reference=territory_override
            territory=worker_scope(territory)
        elif regional:
            territory,territorial_reference=_regional_territorial_reference(reader,directory,stage["osm_timestamp"],country)
        elif country=="JE" and (directory/"JE-national-reference.receipt.json").exists():
            territory,territorial_reference=_verified_geojson(directory,"JE-national-reference",stage["osm_timestamp"])
        else:
            territory,territorial_reference = core._territorial_reference(reader,directory,stage["osm_timestamp"],country)
    except ValueError as error:
        if "No snapshot-compatible" not in str(error):
            raise
        territory,territorial_reference = None,{"purpose":"Independent NE land-majority fallback; no national ISO polygon in this extract",
            "limitation":"Coastal attribution is retained as an ambiguity flag; this is not a full-territory proof"}
    qualifications = (_qualifications(directory,stage["osm_timestamp"]) if country=="SK" else
        _czech_military_qualifications(reader,directory,stage["osm_timestamp"]) if country=="CZ" else {})
    rows,assigned_counts = [],Counter()
    ambiguous,land_conflicts,geometry_defects = [],[],[]
    for shape_record in reader.iterShapeRecords():
        properties = shape_record.record.as_dict()
        level_match = re.fullmatch(r"admin_level(\d+)",properties["fclass"])
        if not level_match:
            continue
        level = int(level_match[1])
        if level not in ROLE_ROWS.get(country,{}) and not (country=="SK" and level==5) and not (country=="IM" and level==8):
            continue
        geometry,defect=staged_polygon(shape_record.shape,properties)
        if defect is not None:
            geometry_defects.append(defect)
            continue
        original_bounds=list(geometry.bounds)
        if country=="RU":
            from shapely.geometry import box
            geometry=geometry.intersection(box(-12,33,52,72))
            if geometry.geom_type=="GeometryCollection":
                geometry=shapely.union_all([part for part in shapely.get_parts(geometry) if part.geom_type in ("Polygon","MultiPolygon")])
            if geometry.is_empty or geometry.area<=0:
                continue
        if geometry.is_empty or geometry.geom_type not in ("Polygon","MultiPolygon") or geometry.area<=0:
            raise ValueError("Invalid staged administrative polygon")
        assigned,assignment = assign_scoped_country(geometry,country,territory,references) if territory is not None else core.assign_country(geometry,references)
        assigned_counts[str(assigned)+":"+properties["fclass"]] += 1
        if assigned != country:
            continue
        qualification = qualifications.get(str(properties["osm_id"]),{})
        tags = qualification.get("tags",{})
        if tags and (tags.get("name")!=properties["name"] or tags.get("admin_level")!=str(level)):
            raise ValueError("Source identity differs from its native-role qualification")
        role = ("local_admin","Legacy Local Authority Area") if country=="IM" and level==8 else classify_role(country,properties,tags)
        if role is None:
            continue
        identifier = str(properties["osm_id"])
        row = {"id":feature_id(country,level,identifier),"country":country,"kind":role[0],"unit_type":role[1],
            "native_type":role[1],"admin_level":level,"raw_subtype":properties["fclass"],"geometry":geometry,
            "name":properties["name"] or "Gebiet (Quellname fehlt)","name_known":bool(properties["name"]),
            "original_name":properties["name"],"original_source_id":identifier,"original_source_version":None,
            "original_properties":properties,"source":f"geofabrik-{country}-admin{level}",
            "source_snapshots":[stage["url"]+"#"+stage["snapshot"]["etag"]],
            "country_assignment_method":assignment.get("method","largest_independent_land_overlap"),
            "country_assignment_fraction":assignment["fraction"],"country_assignment_ambiguous":assignment["ambiguous"],
            "country_assignment_reference_sha256":land_reference["sha256"]}
        if country=="RU":
            row["unclipped_source_bounds"],row["render_clip_bounds"]=original_bounds,[-12,33,52,72]
            if level==6:
                row["local_government_role"]="municipality"
                row["local_government_role_evidence"]=EVIDENCE["RU"][0]
        if qualification:
            row["native_role_qualification"] = qualification
        if country=="FO" and level==7:
            match=official_matches.get(identifier)
            if match is None or match["osm_name"]!=properties["name"]:
                raise ValueError("Faroese municipal polygon lacks its reviewed official name/ID join")
            row["official_municipality_id"],row["official_name"]=match["official_municipality_id"],match["official_name"]
        if "territorial_fraction" in assignment:
            row["country_territorial_fraction"] = assignment["territorial_fraction"]
            row["independent_land_disagreement"] = assignment["independent_land_disagreement"]
        if assignment["ambiguous"]:
            ambiguous.append({"id":row["id"],"name":row["name"],"assignment":assignment})
        if assignment.get("independent_land_disagreement"):
            land_conflicts.append(row["id"])
        rows.append(row)
    if country=="IM":
        rows=current_manx_authorities(rows)
        if len(rows)!=21 or {row["name"] for row in rows}!=MANX_NAMES:
            raise ValueError("Current Manx authority count/name-list does not match the official 21")
    if country=="JE" and (directory/"JE-Grouville-supplement.receipt.json").exists():
        geometry,proof=_verified_geojson(directory,"JE-Grouville-supplement",stage["osm_timestamp"])
        assigned,assignment=core.assign_verified_territory(geometry,country,territory,references) if territory is not None else core.assign_country(geometry,references)
        if assigned!="JE":
            raise ValueError("Grouville supplemental parish is not assigned to the verified Jersey territory")
        rows.append({"id":"osm:relation:"+str(proof["relation_id"]),"country":"JE","kind":"municipality","admin_level":8,
            "unit_type":"Parish","native_type":"Parish","name":"Grouville","name_known":True,"original_name":"Grouville",
            "geometry":geometry,"source_snapshots":[proof["source_url"]+"#"+proof["source_sha256"]],
            "provider_source_id":"osm-JE-Grouville-20261108","original_source_id":str(proof["relation_id"]),
            "original_source_version":proof["relation_version"],"native_role_qualification":proof,
            "country_assignment_method":assignment.get("method","largest_independent_land_overlap"),
            "country_assignment_fraction":assignment["fraction"],"country_assignment_ambiguous":assignment["ambiguous"],
            "source_metadata_override":{"url":proof["source_url"],"attribution":"© OpenStreetMap contributors; direct API geometry supplement, absent from Geofabrik extract",
                "provider":"OpenStreetMap API","source_geometry_sha256":proof["source_sha256"]}})
    rows = merge_by_id(rows)
    core.infer_parents(rows)
    grouped_sources = source_groups(rows)
    path = directory/f"normalized-{country}-v{VERSION}-{revision}.jsonl.gz"
    temporary = path.with_suffix(path.suffix+".partial")
    with temporary.open("wb") as raw,gzip.GzipFile(filename="",mode="wb",fileobj=raw,mtime=0) as compressed,io.TextIOWrapper(compressed,encoding="utf-8",newline="\n") as output:
        for row in rows:
            output.write(json.dumps({**row,"geometry":mapping(row["geometry"])},ensure_ascii=False,separators=(",",":"),allow_nan=False)+"\n")
    temporary.replace(path)
    sources = []
    sha,byte_count = core.digest(path.read_bytes()),path.stat().st_size
    for identifier in sorted(grouped_sources):
        same = grouped_sources[identifier]
        example = same[0]
        unit_types = sorted({row["unit_type"] for row in same})
        sources.append({"id":identifier,"country":country,"scope_countries":[country],"kind":example["kind"],
            "unit_type":"; ".join(unit_types),"unit_types":unit_types,"admin_level":example["admin_level"],
            "source_unit_count":len(same),"expected_unit_count":len(same),"cache_file":path.relative_to(cache).as_posix(),
            "sha256":sha,"bytes":byte_count,"url":stage["url"],"date":stage["osm_timestamp"][:10],"osm_timestamp":stage["osm_timestamp"],
            "license":"ODbL-1.0","license_url":core.LICENSE,"attribution":"© OpenStreetMap contributors; Geofabrik GmbH",
            "specification_url":core.SPEC,"role_evidence_urls":EVIDENCE.get(country,[]),"replacement_scope":"feature",
            "unit_semantics":{"render_role":example["kind"],"source_unit_types":unit_types,
                "coverage_status":"Independent land-mask coverage is measured downstream; actual extraction count is not completeness"},
            **example.get("source_metadata_override",{})})
    receipt = {"country":country,"normalizer_version":VERSION,"sources":sources,"source_snapshot":stage,
        "country_reference":land_reference,"territorial_assignment_reference":territorial_reference,
        "assigned_counts":dict(assigned_counts),"feature_count":len(rows),"ambiguous_country_assignments":ambiguous,
        "independent_land_disagreement_ids":land_conflicts,"native_role_qualifications":qualifications,
        "source_geometry_defects":geometry_defects,
        "parent_relationship_counts":dict(Counter(row["parent_relationship"] for row in rows))}
    core.write_json(receipt_path,receipt)
    return receipt


def prepare_regional_country(cache: Path,country: str,workers=2) -> dict:
    from concurrent.futures import ThreadPoolExecutor,as_completed
    directory=cache/"geofabrik-regional-collections"
    directory.mkdir(exist_ok=True)
    receipt_path=directory/f"{country}-v4-r5.receipt.json"
    paths=[cache/"geofabrik-stage"/REGIONAL_PREFIX[country]/slug for slug in REGIONAL_SLUGS[country]]
    missing=[str(path.relative_to(cache)) for path in paths if not (path/"staging-receipt.json").exists()]
    if missing:
        raise ValueError("Regional stages are not all complete: "+", ".join(missing))
    scope_geometries,scope_proofs=[],[]
    for regional_directory in paths:
        stage=json.loads((regional_directory/"staging-receipt.json").read_text(encoding="utf-8"))
        base=regional_directory/"members/gis_osm_adminareas_a_free_1"
        reader=core._shapefile().Reader(str(base),encoding=base.with_suffix(".cpg").read_text(encoding="ascii").strip())
        geometry,proof=_regional_territorial_reference(reader,regional_directory,stage["osm_timestamp"],country)
        scope_geometries.append(geometry)
        scope_proofs.append({"archive_url":stage["url"],"snapshot":stage["osm_timestamp"],"proof":proof})
    common_scope=shapely.union_all(scope_geometries)
    scope_path=directory/f"{country}-territorial-scope-v4.geojson"
    core.write_json(scope_path,mapping(common_scope))
    shared_proof={"country":country,"purpose":"Country attribution from all ISO-verified coarse regional areas; never a land denominator or target municipal union",
        "geometry_sha256":core.digest(scope_path.read_bytes()),"cache_file":scope_path.relative_to(cache).as_posix(),"regional_inputs":scope_proofs}
    core.write_json(directory/f"{country}-territorial-scope-v4.receipt.json",shared_proof)
    if receipt_path.exists():
        receipt=json.loads(receipt_path.read_text(encoding="utf-8"))
        if receipt.get("territorial_assignment_reference",{}).get("geometry_sha256")==shared_proof["geometry_sha256"]:
            for source in receipt["sources"]:
                if core.digest((cache/source["cache_file"]).read_bytes())!=source["sha256"]:
                    raise ValueError("Changed combined regional cache")
            return receipt
    parts=[]
    with ThreadPoolExecutor(max_workers=workers) as executor:
        serialized_scope=common_scope.wkb
        jobs={executor.submit(prepare_country,cache,country,path,territory_override=(serialized_scope,shared_proof)):path for path in paths}
        for job in as_completed(jobs):
            part=job.result()
            parts.append(part)
            print(json.dumps({"country":country,"normalized_parts":len(parts),"total_parts":len(paths),"features_in_part":part["feature_count"]}),flush=True)
    parts.sort(key=lambda part:part["source_snapshot"]["url"])
    rows=[]
    for part in parts:
        rows.extend(core.iter_boundaries(cache,part["sources"]))
    before=len(rows)
    rows=merge_by_id(rows)
    core.infer_parents(rows)
    groups=source_groups(rows)
    path=directory/f"{country}-v4-r5-{shared_proof['geometry_sha256'][:12]}.jsonl.gz"
    temporary=path.with_suffix(path.suffix+".partial")
    with temporary.open("wb") as raw,gzip.GzipFile(filename="",mode="wb",fileobj=raw,mtime=0) as compressed,io.TextIOWrapper(compressed,encoding="utf-8",newline="\n") as output:
        for row in rows:
            output.write(json.dumps({**row,"geometry":mapping(row["geometry"])},ensure_ascii=False,separators=(",",":"),allow_nan=False)+"\n")
    temporary.replace(path)
    sha,byte_count=core.digest(path.read_bytes()),path.stat().st_size
    examples={source["id"]:source for part in parts for source in part["sources"]}
    sources=[]
    snapshots=sorted({part["source_snapshot"]["osm_timestamp"] for part in parts})
    for identifier in sorted(groups):
        same=groups[identifier]
        unit_types=sorted({row["unit_type"] for row in same})
        sources.append({**examples[identifier],"cache_file":path.relative_to(cache).as_posix(),"sha256":sha,"bytes":byte_count,
            "source_unit_count":len(same),"expected_unit_count":len(same),"unit_types":unit_types,"unit_type":"; ".join(unit_types),
            "source_archive_urls":sorted({part["source_snapshot"]["url"] for part in parts}),
            "osm_timestamps":snapshots,"date":snapshots[0][:10],"replacement_scope":"feature",
            "scope":"All listed regional extracts; source IDs deduplicated; independent land coverage remains a separate audit"})
    receipt={"country":country,"normalizer_version":4,"sources":sources,"parts":parts,"feature_count":len(rows),
        "regional_extract_count":len(parts),"rows_before_source_id_union":before,"duplicate_rows_united":before-len(rows),
        "territorial_assignment_reference":shared_proof,
        "source_snapshots":snapshots,"raw_range_bytes":sum(part["source_snapshot"]["total_range_bytes"] for part in parts),
        "parent_relationship_counts":dict(Counter(row["parent_relationship"] for row in rows)),
        "note":"Regional overlaps retain one source entity; every input archive and qualification receipt is retained; no invented partition cells"}
    core.write_json(receipt_path,receipt)
    return receipt


def regional_api_row(country,geometry,proof,relation,*,level=4):
    """Qualify the native role of an independently attributed API supplement."""
    tags=relation.get("tags",{})
    if (relation.get("type")!="relation" or relation.get("id")!=proof["relation_id"]
            or relation.get("version")!=proof["relation_version"]):
        raise ValueError("Regional API identity differs from the pinned receipt")
    if relation.get("timestamp", "9999")>proof["snapshot"]:
        raise ValueError("Regional relation is newer than the fixed snapshot")
    is_region=country in ("CZ","NO") and level==4 and tags.get("ISO3166-2","").startswith(country+"-")
    official_code=proof.get("validation",{}).get("ssb2026_municipality_code")
    is_municipality=(country=="NO" and level==7 and official_code and tags.get("ref")==official_code
        and tags.get("place")=="municipality" and proof["validation"].get("ssb2026_primary_url")=="https://data.ssb.no/api/klass/v1/versions/3262")
    if country=="CZ" and level==8:
        official_code=proof.get("municipality_code")
        is_municipality=(bool(official_code) and tags.get("ref")==str(proof.get("district_code",""))+str(official_code)
            and tags.get("border_type") in {"municipality","town","city"}
            and proof.get("validation",{}).get("ref_matches_official_CISOB_and_OKRES") is True)
    if (not(is_region or is_municipality) or tags.get("boundary")!="administrative"
            or tags.get("admin_level")!=str(level) or not tags.get("name")):
        raise ValueError("Regional API ISO/native role is not positively qualified")
    if geometry.is_empty or not geometry.is_valid or geometry.geom_type not in ("Polygon","MultiPolygon"):
        raise ValueError("Invalid regional API polygon")
    kind,unit_type=ROLE_ROWS[country][level]
    source_id=f"osm-{country}-{kind}-{proof['relation_id']}-{proof['snapshot'][:10].replace('-','')}"
    row={"id":"osm:relation:"+str(proof["relation_id"]),"country":country,"kind":kind,"admin_level":level,
        "unit_type":unit_type,"native_type":unit_type,"name":tags["name"],
        "name_known":True,"original_name":tags["name"],"geometry":geometry,"raw_subtype":"admin_level"+str(level),
        "source":source_id,"provider_source_id":source_id,"original_source_id":str(proof["relation_id"]),
        "original_source_version":proof["relation_version"],"original_properties":tags,
        "source_snapshots":[proof["source_url"]+"#"+proof["source_sha256"]],
        "native_role_qualification":{"tags":tags,"relation_version":relation["version"],
            "source_url":proof["source_url"],"source_sha256":proof["source_sha256"],"snapshot":proof["snapshot"]},
        "country_assignment_method":"verified_native_regional_ISO3166_2" if is_region else "verified_native_ref_and_official_SSB_code",
        "country_assignment_ambiguous":False,
        "source_metadata_override":{"url":proof["source_url"],"attribution":"© OpenStreetMap contributors; direct API administrative geometry supplement",
            "provider":"OpenStreetMap API","source_geometry_sha256":proof["source_sha256"]}}
    if is_municipality:
        row["official_municipality_id"]=official_code
    return row


def _czech_display_qualifications(cache,snapshot):
    directory=cache/"audit"
    audit_path=directory/"CZ-Praha-combined-role-audit.json"
    audit=json.loads(audit_path.read_text(encoding="utf-8"))
    if core.digest((directory/audit["primary_source_raw_file"]).read_bytes())!=audit["primary_source_sha256"]:
        raise ValueError("Changed official Prague municipality-role evidence")
    metadata=core.ROOT/audit["cached_osm_metadata"]
    if core.digest(metadata.read_bytes())!=audit["cached_osm_metadata_sha256"]:
        raise ValueError("Changed Prague native identity evidence")
    paths=[metadata,directory/"CZ-Praha-obvod-identities.xml"]
    result={}
    for path in paths:
        for relation in ET.fromstring(path.read_bytes()).findall("relation"):
            identifier=relation.get("id")
            if path==metadata and identifier!=str(audit["source_relation_id"]):
                continue
            if relation.get("timestamp")>snapshot:
                raise ValueError("Czech display role is newer than the source snapshot")
            proof={"tags":{tag.get("k"):tag.get("v") for tag in relation.findall("tag")},
                "version":int(relation.get("version")),"timestamp":relation.get("timestamp"),
                "source_url":f"https://api.openstreetmap.org/api/0.6/relation/{identifier}/{relation.get('version')}.json",
                "evidence_file_sha256":core.digest(path.read_bytes())}
            if identifier==str(audit["source_relation_id"]):
                proof.update(government_evidence_url=audit["primary_source_url"],government_evidence_sha256=audit["primary_source_sha256"])
            result[identifier]=proof
    return result


def complete_regional_frame(cache: Path,country: str) -> dict:
    """Add verified missing regional API polygons in a new, immutable cache revision."""
    directory=cache/"geofabrik-regional-collections"
    original=json.loads((directory/f"{country}-v4-r7.receipt.json").read_text(encoding="utf-8"))
    rows=list(core.iter_boundaries(cache,original["sources"]))
    snapshot=original["source_snapshots"][0]
    supplements=[]
    for slug in REGIONAL_SLUGS[country]:
        stage=cache/"geofabrik-stage"/REGIONAL_PREFIX[country]/slug
        for receipt_path in sorted([*stage.glob(f"{country}-*-territorial-reference.receipt.json"),*stage.glob(f"{country}-*-supplement.receipt.json")]):
            stem=receipt_path.name.removesuffix(".receipt.json")
            geometry,proof=_verified_geojson(stage,stem,snapshot)
            for key,hash_key in (("official_audit_file","official_audit_sha256"),("metadata_file","metadata_sha256")):
                if key in proof and core.digest(Path(proof[key]).read_bytes())!=proof[hash_key]:
                    raise ValueError("Changed supplemental official identity/snapshot metadata evidence")
            raw=(stage/proof["raw_api_file"]).read_bytes()
            if core.digest(raw)!=proof["source_sha256"]:
                raise ValueError("Regional API raw response hash differs")
            matches=[element for element in json.loads(raw)["elements"] if element.get("type")=="relation" and element.get("id")==proof["relation_id"]]
            if len(matches)!=1:
                raise ValueError("Regional API source relation not unique")
            if any(row.get("original_source_id")==str(proof["relation_id"]) for row in rows):
                continue
            level=int(matches[0].get("tags",{}).get("admin_level","0"))
            row=regional_api_row(country,geometry,proof,matches[0],level=level)
            rows.append(row)
            supplements.append({"proof":proof,"role":row["kind"],"source_id":row["source"],
                "qualification":"Actual native administrative tags with independent ISO/official municipal-code role evidence"})
    qualifications=_czech_display_qualifications(cache,snapshot) if country=="CZ" else {}
    if qualifications:
        apply_regional_qualifications(rows,qualifications)
    if supplements:
        core.infer_parents(rows)
    groups=source_groups(rows)
    fingerprint=core.digest(json.dumps({"base":original["sources"][0]["sha256"],"supplements":supplements,"qualifications":qualifications},sort_keys=True).encode())[:12]
    path=directory/f"{country}-v4-r8-{fingerprint}.jsonl.gz"
    temporary=path.with_suffix(path.suffix+".partial")
    with temporary.open("wb") as raw,gzip.GzipFile(filename="",mode="wb",fileobj=raw,mtime=0) as compressed,io.TextIOWrapper(compressed,encoding="utf-8",newline="\n") as output:
        for row in rows:
            output.write(json.dumps({**row,"geometry":mapping(row["geometry"])},ensure_ascii=False,separators=(",",":"),allow_nan=False)+"\n")
    if path.exists() and core.digest(path.read_bytes())!=core.digest(temporary.read_bytes()):
        raise ValueError("Immutable regional revision already exists with different bytes")
    temporary.replace(path)
    examples={source["id"]:source for source in original["sources"]}
    sources=[]
    sha,byte_count=core.digest(path.read_bytes()),path.stat().st_size
    for identifier,same in sorted(groups.items()):
        example=same[0]
        unit_types=sorted({row["unit_type"] for row in same})
        metadata=examples.get(identifier,{"id":identifier,"country":country,"scope_countries":[country],
            "kind":example["kind"],"admin_level":example["admin_level"],"date":snapshot[:10],"osm_timestamp":snapshot,
            "license":"ODbL-1.0","license_url":core.LICENSE,"role_evidence_urls":EVIDENCE[country],"replacement_scope":"feature",
            "unit_semantics":{"render_role":example["kind"],"coverage_status":"Verified regional supplement; independent land coverage is audited downstream"},
            **example.get("source_metadata_override",{})})
        sources.append({**metadata,"cache_file":path.relative_to(cache).as_posix(),"sha256":sha,"bytes":byte_count,
            "source_unit_count":len(same),"expected_unit_count":len(same),"unit_type":"; ".join(unit_types),"unit_types":unit_types,
            "unit_semantics":{**metadata.get("unit_semantics",{}),"source_unit_types":unit_types,"render_role":example["kind"]}})
    receipt={**original,"sources":sources,"feature_count":len(rows),"regional_frame_supplements":original.get("regional_frame_supplements",[])+supplements,
        "cache_revision":8,"display_role_qualifications":qualifications,"parent_relationship_counts":dict(Counter(row["parent_relationship"] for row in rows)),
        "previous_immutable_cache_files":sorted({source["cache_file"] for source in original["sources"]})}
    core.write_json(directory/f"{country}-v4-r8.receipt.json",receipt)
    return receipt


def prepare_collection(cache: Path) -> dict:
    cache = Path(cache)
    hu = json.loads((cache/core.DIRECTORY/"receipt.json").read_text(encoding="utf-8"))
    if hu.get("normalizer_version")!=3:
        raise ValueError("The audited HU v3 baseline must remain immutable")
    datasets,blockers = [{"country":"HU",**hu}],{}
    for country in ("SK","EE","AL","MK","MD","GG","JE","IM","FO"):
        try:
            dataset = prepare_country(cache,country)
            if country=="GG" and (cache/"audit/gg-terminal-role-evidence/receipt.json").exists():
                dataset=prepare_guernsey_terminal_roles(cache,dataset)
            datasets.append(dataset)
            print(json.dumps({"country":country,"features":dataset["feature_count"],"counts":{source['id']:source['source_unit_count'] for source in dataset['sources']}}),flush=True)
        except (ValueError,OSError,subprocess.SubprocessError) as error:
            blockers[country] = str(error)
            print(json.dumps({"country":country,"state":"blocked","reason":str(error)}),flush=True)
    for country in ("CZ","NO"):
        ready=cache/"geofabrik-regional-collections"/f"{country}-v4-r8.receipt.json"
        if not ready.exists():
            continue
        dataset=json.loads(ready.read_text(encoding="utf-8"))
        actual=sum(1 for _ in core.iter_boundaries(cache,dataset["sources"]))
        if actual!=dataset["feature_count"]:
            raise ValueError("Regional collection count differs from its complete receipt")
        datasets.append(dataset)
    additional=[("TR",cache/"geofabrik-stage/turkey/normalized-TR-v4-r3.receipt.json"),
        ("RU",cache/"geofabrik-regional-collections/RU-v4-r5.receipt.json")]
    additional.extend((country,cache/"geofabrik-mena-stage"/profile[0]/f"normalized-{country}-v4-r3.receipt.json") for country,profile in MENA_PROFILES.items())
    for country,path in additional:
        if not path.exists():
            blockers[country]="Prepared normalized country cache is not available"
            continue
        dataset=json.loads(path.read_text(encoding="utf-8"))
        if country=="TR" and (cache/"audit/TR-metropolitan-roles-2026/audit.json").exists():
            dataset=prepare_turkish_metropolitan_roles(cache,dataset)
        rows=list(core.iter_boundaries(cache,dataset["sources"]))
        if len(rows)!=dataset["feature_count"] or len({row["id"] for row in rows})!=len(rows):
            raise ValueError("Additional country collection identity/count mismatch")
        if any(not row["geometry"].is_valid or row["geometry"].is_empty or row["country"]!=country for row in rows):
            raise ValueError("Additional country collection has invalid geometry/country")
        datasets.append(dataset)
    for dataset in datasets:
        if dataset["country"]!="EE":
            continue
        audit_path=cache/"audit/EE-2026-municipality-audit.json"
        audit=json.loads(audit_path.read_text(encoding="utf-8"))
        official=audit["official_source"]
        if core.digest((audit_path.parent/official["raw_file"]).read_bytes())!=official["raw_sha256"]:
            raise ValueError("Changed official Estonian municipal identity source")
        rows=list(core.iter_boundaries(cache,dataset["sources"]))
        if any(source["sha256"]!=audit["source_cache_sha256"] for source in dataset["sources"]):
            raise ValueError("Estonian identity audit targets another source cache")
        contract=verified_country_replacement(rows,audit)
        for source in dataset["sources"]:
            if source["kind"]=="municipality":
                source.update(contract,replacement_identity_audit_sha256=core.digest(audit_path.read_bytes()),
                    replacement_identity_audit_file=audit_path.relative_to(cache).as_posix(),
                    replacement_official_identity_url=official["url"])
    alias_path=cache/"audit/OSM-Geofabrik-TR-RU-alias-audit.json"
    aliases={"file":alias_path.relative_to(cache).as_posix(),"sha256":core.digest(alias_path.read_bytes()),"bytes":alias_path.stat().st_size}
    for dataset in datasets:
        defects=dataset.get("source_geometry_defects",[])+[defect for part in dataset.get("parts",[]) for defect in part.get("source_geometry_defects",[])]
        for source in dataset["sources"]:
            relevant=[d for d in defects if d["original_properties"]["fclass"]==f"admin_level{source['admin_level']}"]
            if relevant:
                source.update(blocks_full_coverage_claim=True,source_geometry_defect_count=len(relevant),
                    source_geometry_defect_ids=sorted({d["original_source_id"] for d in relevant}),
                    source_geometry_defect_note="Actual zero-point source polygons omitted with unresolved country; no substitute geometry generated")
            if dataset["country"] in ("TR","RU"):
                source.setdefault("verified_source_alias_audit",aliases)
            if dataset["country"]=="RU" and source["admin_level"]==6:
                source["combined_role_basis"]={"source_convention_url":"https://wiki.openstreetmap.org/wiki/RU:Tag:boundary=administrative#Административные_уровни_(admin_level)_в_Российской_Федерации",
                    "native_level_6":"Municipal raions, municipal okrugs and urban okrugs, explicitly named in the original producer convention",
                    "render_role":"district","additional_local_government_role":"municipality",
                    "geometry_policy":"One existing source polygon carries both roles; no duplicate local boundary is invented",
                    "limits":"Producer-declared native municipal hierarchy; not a current nationwide legal authority count or individual official cadastral boundary attestation"}
    sources = [source for dataset in datasets for source in dataset["sources"]]
    result = {"schema":2,"collection_version":VERSION,"source_groups_version":3,"sources":sources,"datasets":datasets,"blockers":blockers,
        "note":"HU v3 byte-for-byte baseline retained; later country collections use separate v4 cache files",
        "limitations":{"TR":"Exactly30 current TBB metropolitan governments match original admin4 province ISO/name identities and are legally coextensive under6360Art6/5216Art5. The other51 provinces and974 district roles are not blindly promoted; fine local-layer completeness remains separate",
            "AZ":"Only8 municipal source polygons; official685-count proves the local source is partial; coarser administrative level conventions conflict and remain unqualified",
            "JO":"Only the12 governorates admitted; local municipality/subdistrict source roles are not yet independently qualified",
            "LY":"Only23 source Shabiya polygons; no actual municipal layer is present",
            "municipal_vs_local":"Iraqi/Syrian Nahiya and Tunisian Imada are native local_admin, not municipal self-government",
            "coverage":"All source counts describe actual extracted records; independent visible land coverage and official identity completeness are separate audits"}}
    core.write_json(cache/f"geofabrik-collection-v{VERSION}.json",result)
    core.write_json(core.ROOT/"data/atlas_geofabrik_sources.json",result)
    write_docs(result)
    return result


def write_docs(receipt):
    lines=["# Geofabrik-Verwaltungsquellen und belegte Ergänzungen","",
        "Die [kostenlose Geofabrik-Adminareas-Ebene](https://blog.geofabrik.de/index.php/2026/04/) liefert formale administrative Grenzpolygone. "
        f"Die [Formatspezifikation]({core.SPEC}) erklärt fclass/code und die fehlende native Elternhierarchie. "
        "Pro Archiv werden ausschließlich ZIP-Verzeichnis, Adminareas-Mitglieder und README über geprüfte HTTP206-Ranges gelesen; "
        "starke ETag/If-Match, Content-Range, Bytezahl, ZIP-CRC32 und SHA-256 bleiben im Manifest erhalten.","",
        "| Land | Originale Ebene | Darstellungsrolle | tatsächlicher Einheitstyp | Einheiten |","|---|---:|---|---|---:|"]
    for source in receipt["sources"]:
        lines.append(f"| {source['country']} | {source['admin_level']} | {source['kind']} | {source['unit_type']} | {source['source_unit_count']} |")
    lines += ["","## Nationale Rollen und Prüfgrenzen","",
        "Eine Gemeinderolle folgt ausschließlich aus einer positiv belegten Landesdefinition. "
        "SK-Militärgebiete sind mit tatsächlichen historischen OSM-Tags als local_admin getrennt; Bratislava/Košice sind mit ihren Stadt-Tags auf5 Gemeinden. "
        "AL7 sind die61 Bashki, AL8 ihre Unterverwaltungen. MK7 umfasst80 Gemeinden, Skopje6 bleibt das übergeordnete Aggregat. "
        "EE7 hat aktuell78 Gemeinden: Jõhvi und Toila fusionierten nach2025; die offiziellen78 Namen stimmen mit dem Datenbestand überein. "
        "Tallinn und Kohtla-Järve auf8 bleiben Siedlungseinheiten und werden nicht nochmals als Gemeinden eingefügt. "
        "Ausschließlich dieser vollständig positiv namen-/ID-abgeglichene EE-Gemeindesatz erhält replacement_scope=country. "
        "Dadurch bleiben keine veralteten Natural-Earth-Gemeindereste zusätzlich bestehen; konkret war region:EST-2352 (Kreis Saare) betroffen. "
        "Amtliche Identitätsvollständigkeit und separat gemessene Landflächenabdeckung bleiben verschiedene Belege.","",
        "IM verwendet die amtlichen21 heutigen Local Authorities. Garff ist die belegte Union Laxey/Lonan/Maughold (2016), "
        "Arbory and Rushen die belegte Union der beiden alten Parish Districts (2020). Alle Quellteile/IDs und Rechtsbelege bleiben erhalten; "
        "benachbarte eigenständige Authorities werden nicht einbezogen. FO7 ist durch einen eindeutigen amtlichen Namen-/ID-Abgleich aller29 Kommunen belegt.","",
        "GG8 erfasst die10 Hauptinsel-Parishes; Alderney/Sark sind eigene Jurisdiktionen. "
        "[Sarks eigene Regierung](https://sarkgov.co.uk/living-on-sark) und die [amtliche Alderney-Regierungsbeschreibung](https://www.alderneyelections.gg/how-government-works/structure/) "
        "belegen Chief Pleas beziehungsweise States of Alderney als tatsächliche territoriale Eigenregierungen; "
        "[GOV.UK](https://www.gov.uk/government/publications/crown-dependencies-jersey-guernsey-and-the-isle-of-man) bestätigt die drei getrennten Jurisdiktionen im Bailiwick. "
        "Genau die vorhandenen Regionen Sark1973199 und Alderney1973200 tragen deshalb zusätzlich local_admin mit Primärbeleg. "
        "Sie bleiben region/Jurisdiction und werden weder umbenannt noch geometrisch dupliziert oder als weitere Gemeinden/Parishes ausgegeben. "
        "Guernsey1711291 erhält keine zusätzliche Leafrolle neben seinen10Parishes. Die unabhängige physische Landflächenprüfung bleibt offen. "
        "JE erhält seine12.Parish Grouville aus einer separat attribuierten, Snapshot-geprüften OSM-API-Geometrie, da sie im Geofabrik-Extrakt fehlt. "
        "Das nationale JE-Polygon ist ebenfalls eine ausdrücklich belegte API-Referenz ausschließlich für territoriale Zuordnung.","",
        "CZ verwendet sämtliche14 geprüften Regionalextrakte, NO sämtliche5 kontinentalen Regionalextrakte; regionale Puffer werden anhand gemeinsamer, "
        "durch native ISO-Tags belegter Territorialreferenzen zugeordnet und danach über stabile Quellkennung dedupliziert. "
        "Die fehlenden dargestellten Regionen Ústecký kraj und Trøndelag kommen aus separat attribuierten vollständigen OSM-API-Geometrien. "
        "Ihre tatsächlichen admin4-/ISO-Tags und sämtliche Memberstände wurden gegen den08.11.2026,21:21UTC geprüft. "
        "Diese Darstellung erzeugt keine Länderobjekte und verwendet die Referenzen nicht als Landflächennenner. "
        "CZ enthält6243 Geofabrik-Gemeinden plus10 durch amtliche CISOB-/Okres-Codes belegte direkte OSM-Gemeindegrenzen und4 gesonderte Militärgebiete. "
        "Die10 fehlten tatsächlich in sämtlichen14 rohen Regional-DBFs; ihre echten Originalgeometrien ersetzen keine erfundenen Zellen. "
        "Praha trägt auf seiner bestehenden Kraj-Geometrie zusätzlich "
        "die amtlich belegte Gemeinderolle; ein zweites Geometrieobjekt entsteht nicht. Die10 Praha-Obvod-Flächen haben ihre tatsächliche "
        "native Bezirksrolle statt des pauschalen Okres-Namens. NO enthält356 Geofabrik-Gemeinden plus die separat attribuierte Originalgrenze "
        "der fehlenden Gemeinde Røros (SSB-Code5025). Die vollständige amtliche SSB2026-Namens-/Codeprüfung belegt357 wirkliche Gemeinden "
        "und einen gesonderten Unbekannt-Code9999, der nicht als Gemeinde importiert wird. "
        "Oslo ist bereits als echte eigene Level7-Gemeinde vorhanden und wird nicht über die zusätzliche Fylke-Geometrie nochmals kommunal gezählt. "
        "Diese realen Quellanzahlen ersetzen keine unabhängige amtliche Behördenvollzählung; kein fehlender Eintrag wird erfunden. "
        "Der Bestand umfasst danach6253 explizite Gemeindeobjekte plus die zusätzliche Praha-Gemeinderolle. "
        "Der amtliche zivile Namensbestand umfasst6254 Behörden, wobei vier Militärgebiete gesondert bleiben.","",
        "RU wurde aus allen5 bereitliegenden europäischen Föderalextrakten zusammengeführt und auf den tatsächlichen Atlasrahmen begrenzt; "
        "die [originale russische OSM-Produzentenkonvention](https://wiki.openstreetmap.org/wiki/RU:Tag:boundary=administrative#Административные_уровни_(admin_level)_в_Российской_Федерации) "
        "benennt6 ausdrücklich als kommunale Rajons sowie kommunale/städtische Okrugs,8 als kommunale Siedlungen und9 als subkommunale Einheiten. "
        "Deshalb behält6 seine gröbere district-Darstellung und trägt zusätzlich die belegte native municipality-Rolle auf derselben Originalgeometrie. "
        "Diese Produzentenkonvention ersetzt weder eine aktuelle nationale Behördenvollzählung noch die einzelne amtliche Kataster-/Rechtsgrenzenabnahme. "
        "TR aus dem vollständigen Landesextrakt. Mahalle/Köy bleiben local_admin, Belde bleiben municipality. "
        "Genau30 bestehende TR4-Provinzen tragen zusätzlich ihre aktuelle TBB-Metropolgemeinderolle: "
        "[6360Art.6](https://cdn.tbmm.gov.tr/KKBSPublicFile/D24/Y3/T1/KanunMetni/6fd1dca0-c56a-40ef-bc98-fb463d9ac578.html) "
        "fasst5216Art.5 mit ausdrücklich flächengleicher Metropol-/Provinzgrenze neu. Die [aktuelle TBB-Liste](https://www.tbb.gov.tr/tr/buyuksehir-belediyeleri) "
        "liefert genau30 Behörden; jede wurde eindeutig mit dem Originalnamen, der administrativen Provinzkennung und dem nativen TR-ISO-Code vor dem Geofabrik-Snapshot abgeglichen. "
        "Keine neue Geometrie entsteht, kindregion/İl bleiben erhalten. Die anderen51 Provinzen und974 Kreisgemeinderollen bleiben ungeprüft und werden nicht pauschal kommunal markiert; "
        "11 der85 ursprünglichen Belde-Quellpolygone liegen vollständig in den bestätigten Metropolprovinzen Kayseri, Ankara oder Tekirdağ. "
        "6360Art.1(3) hebt dort die eigenständige frühere Belde-Rechtspersönlichkeit auf. Genau diese11 Datensätze bleiben mit unveränderter municipality/Belde-Originalrolle und Geometrie im Quellcache, "
        "sind jedoch administrativ quarantänisiert und werden nicht als heutige Gemeinden dargestellt oder gezählt. Die konkrete Metropolzuordnung, Gesetz, Primär-URL, Datum und ID bleiben erhalten; "
        "der Reader gibt weiterhin alle85 ursprünglichen Belde-Records aus. "
        "flächengleiche größere Metropolregierungen stellen keine vollständig rekonstruierte feinere Mahalle-/Köy-Ebene her. "
        "136 tatsächliche direkte OSM-/Geofabrik-Doppelrepräsentationen sind nach Kennung, Land, Ebene, Originalnamen und Polygon-IoU>0,999 belegt. "
        "Der Reader liefert einen geprüften verified_source_alias samt Zielversion und Audit-/Cachehash; erst der Hauptmerger entscheidet nach erneuter Geometrieprüfung über die Zusammenführung. "
        "Es gibt keine allgemeine Gleichsetzung nur nach common osm_id.","",
        "Die zusätzlichen Länder behalten ihre tatsächlich belegten Rollen: LB7 Baladiya, BY8 örtliche Räte, KZ8 Rural Okrug, IL8 kommunale Local Authorities; "
        "IQ7 und SY6 Nahiya sowie TN6 Imada sind örtliche Verwaltung, ausdrücklich keine pauschalen selbstverwalteten Gemeinden. "
        "Libanesische Katastergebiete auf8 und tunesische Gemeinde-Kandidaten auf8 werden nicht automatisch zugelassen. "
        "AZ hat lediglich8 tatsächliche Gemeindequellflächen gegenüber685 amtlichen Gemeinden und bleibt partiell. JO enthält nur12 Gouvernorate, "
        "LY nur23 Shabiya-Flächen: für beide ist damit keine örtliche Gemeindeebene hergestellt. "
        "TR hat zwei relevante leere admin8-Quellpolygone, KZ ein leeres admin8-Polygon. Sie werden mit Originalkennung, Eigenschaften und ungeklärter Landeszuordnung dokumentiert; "
        "keine Ersatzgeometrien entstehen, und die betroffenen Quellen blockieren eine vollständige Abdeckungsbehauptung. "
        "Source counts beziehen sich auf den tatsächlichen Quellbestand vor dem im Hauptimport angewandten sichtbaren Atlas-Ausschnitt.","",
        "Country-Zuordnung erfolgt vor der Rollenvergabe: Ein Archivpuffer allein belegt kein Land. "
        "Bestätigte nationale ISO-Grenzpolygone dienen nur zur territorialen Zuordnung, niemals als neues Landobjekt oder als Landflächennenner. "
        "Der unabhängige Natural-Earth-Landbeleg und seine Abweichungen bleiben separat erhalten. "
        "Eltern werden bei eindeutiger geometrischer Enthaltung als inferred-area-containment markiert; die Quelle liefert keine native Rechts-/Enginehierarchie.","",
        "HU-Normalizer3 bleibt bytegleich erhalten. Seine ursprünglichen Cachepfade und die zusätzliche v3-Sicherung werden von den späteren Sammlungen nicht überschrieben. "
        "Die späteren Länder verwenden eigene versionierte Cachedateien. Tatsächliche Extraktanzahlen sind keine pauschale Vollständigkeitsbehauptung: "
        "Lücken, Überlappungen, Rollen und Landesreferenzqualität werden im Hauptimport anhand unabhängiger Landmasken geprüft.","",
        f"Datenlizenz: [ODbL1.0]({core.LICENSE}), © OpenStreetMap contributors; Geofabrik GmbH. "
        "Direkte API-Ergänzungen tragen ihre eigene Herkunft. Natural Earth ist Public Domain. "
        "Unveränderte OSM-Elementversionen können wegen wechselnder API-Generator-Header andere Rohantwortbytes haben; maßgeblich sind jeweils die tatsächlich gespeicherten vollständigen Rohantwort- und Geometriehashes.","",
        "## Rollenbelege",""
    ]
    for country,urls in EVIDENCE.items():
        lines.append(country+": "+", ".join(f"[Quelle{index+1}]({url})" for index,url in enumerate(urls))+".")
    if receipt["blockers"]:
        lines += ["","## Offene Quellenabnahmen",""]+[f"- {country}: {message}" for country,message in receipt["blockers"].items()]
    if receipt.get("limitations"):
        lines += ["","## Ausdrücklich erhaltene Grenzen",""]+[f"- {country}: {message}" for country,message in receipt["limitations"].items()]
    lines += ["","```powershell","python tools/atlas_geofabrik_collections.py --cache .tools/atlas_sources",
        "python -m unittest discover -s tools -p test_atlas_geofabrik_*.py","```",""]
    (core.ROOT/"docs/atlas-geofabrik-sources.md").write_text("\n".join(lines),encoding="utf-8")


if __name__=="__main__":
    import argparse
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache",type=Path,default=core.ROOT/".tools/atlas_sources")
    args=parser.parse_args()
    result=prepare_collection(args.cache)
    print(json.dumps({"sources":len(result["sources"]),"features":sum(row["source_unit_count"] for row in result["sources"]),"blockers":result["blockers"]}))
