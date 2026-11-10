"""Exact, evidence-backed Beirut exception; original GF rows remain immutable evidence.

Lebanon's general OSM level7 convention cannot turn twelve quarters of Beirut
into twelve independent municipal councils.  MoIM's 2025 election table lists
the same Beirut identity at governorate, district and municipality, with one
24-seat municipal council. No other Lebanese area is changed by this module.
"""
from copy import deepcopy


BEIRUT_REGION_ID = "geofabrik:LB:4:316552"
ELECTION_URL = "https://moim.gov.lb/wp-content/uploads/2025/07/نتائج-الانتخابات-البلدية2025-محافظة-بيروت.pdf"
ACT_URL = "https://legallaw.ul.edu.lb/Law.aspx?lawId=244078"
EVIDENCE_URLS = [ELECTION_URL, ACT_URL,
                 "https://openjicareport.jica.go.jp/pdf/12269353.pdf"]
QUARTER_NAMES = {
    "3074290": "الأشرفية", "3074291": "باشورة", "3074292": "دار المريسة",
    "3074293": "مزرعة", "3074294": "مدور", "3074295": "ميناء الحصن",
    "3074296": "مصيطبة", "3074297": "المرفأ", "3074298": "رأس بيروت",
    "3074299": "الرميل", "3074300": "الصيفي", "3074301": "زقاق البلاط",
}


def qualify_row(row):
    """Return a new row; guard exact OSM/DBF identity before any special role."""
    result = deepcopy(row)
    identifier = str(row.get("original_source_id", ""))
    if row.get("country") != "LB" or identifier not in {*QUARTER_NAMES, "316552"}:
        return result
    is_region = identifier == "316552"
    level, kind = (4, "region") if is_region else (7, "municipality")
    name = "محافظة بيروت" if is_region else QUARTER_NAMES[identifier]
    expected_properties = {"osm_id": identifier, "code": 1200+level,
                           "fclass": f"admin_level{level}", "name": name}
    if (row.get("id") != f"geofabrik:LB:{level}:{identifier}"
            or row.get("admin_level") != level or row.get("kind") != kind
            or row.get("name") != name or row.get("original_name") != name
            or row.get("source") != f"geofabrik-LB-admin{level}-{kind}"
            or any(row.get("original_properties", {}).get(k) != v
                   for k, v in expected_properties.items())):
        raise ValueError("Changed Beirut special-role original identity")
    if row.get("parent_id") != ("country:LB" if is_region else BEIRUT_REGION_ID):
        raise ValueError("Changed Beirut special-role territorial parent")
    if is_region:
        result.update(local_government_role="municipality",
                      local_government_role_evidence={
                          "type": "combined-governorate-and-single-municipality",
                          "source_urls": EVIDENCE_URLS,
                          "government_inventory_date": "2025",
                          "official_municipality_name": "بيروت",
                          "municipal_council_seats": 24,
                          "geometry_changed": False,
                          "scope": "Beirut only; no role inferred for other governorates",
                      })
    else:
        result.update(administrative_geometry_eligible=False,
                      administrative_ineligibility_note=
                      "Beirut quarter, not an independent Baladiya; the 2025 MoIM results identify one Beirut municipality with 24 seats. Original geometry and source classification retained as excluded evidence, not converted into an invented local-government boundary.",
                      administrative_ineligibility_evidence_url=ELECTION_URL,
                      source_role_qualification={
                          "review_date": "2026-11-10",
                          "actual_identity": "Beirut quarter; not an independent Baladiya",
                          "municipality_id": BEIRUT_REGION_ID,
                          "evidence_urls": EVIDENCE_URLS,
                      })
    return result
