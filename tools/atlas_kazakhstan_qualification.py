"""Three exact city-administration roles; no blanket promotion of Kazakh Audans."""
from copy import deepcopy


LAW_URL = "https://old.adilet.zan.kz/rus/docs/Z010000148_"
UNIT_TYPE = "Қалалық әкімдік / City administration"
UNITS = {
    "3389541": {"name":"Атырау қалалық әкімдігі", "parent":"214834", "version":21,
                "timestamp":"2026-04-23T14:04:39Z",
                "url":"https://old.adilet.zan.kz/rus/docs/G22TA00877A"},
    "3767383": {"name":"Орал қалалық әкімдігі", "parent":"215441", "version":22,
                "timestamp":"2026-04-23T08:24:31Z", "url":"https://www.gov.kz/org/uralsk?lang=ru"},
    "5515125": {"name":"Ақтау қалалық әкімдігі", "parent":"215686", "version":21,
                "timestamp":"2025-12-08T19:53:43Z",
                "url":"https://www.gov.kz/org/akimat-goroda-aktau?lang=ru"},
}


def qualify_row(row):
    result = deepcopy(row)
    identifier = str(row.get("original_source_id", ""))
    if row.get("country") != "KZ" or identifier not in UNITS:
        return result
    unit = UNITS[identifier]
    properties = {"osm_id":identifier,"code":1206,"fclass":"admin_level6","name":unit["name"]}
    if (row.get("id") != f"geofabrik:KZ:6:{identifier}" or row.get("kind") != "district"
            or row.get("admin_level") != 6 or row.get("source") != "geofabrik-KZ-admin6-district"
            or row.get("name") != unit["name"] or row.get("original_name") != unit["name"]
            or any(row.get("original_properties",{}).get(k) != v for k,v in properties.items())):
        raise ValueError("Changed Kazakh city-administration original identity")
    if row.get("parent_id") != f"geofabrik:KZ:4:{unit['parent']}":
        raise ValueError("Changed Kazakh city-administration territorial parent")
    result.update(unit_type=UNIT_TYPE, native_type="Қалалық әкімдік",
                  previous_normalizer_unit_type="Audan",
                  local_government_role="local_admin",
                  local_government_role_evidence={
                      "type":"exact-native-city-administration",
                      "source_urls":[LAW_URL,unit["url"]],
                      "law_basis":"Law148 art1(4): city akimat exercises local state administration and self-government on its respective territory",
                      "osm_relation_id":int(identifier),"osm_relation_version":unit["version"],
                      "osm_relation_timestamp":unit["timestamp"],
                      "native_osm_boundary":"administrative","native_osm_admin_level":6,
                      "country":"KZ","scope":"Only this exact city-administration identity; not other Audans",
                      "review_date":"2026-11-10","geometry_changed":False,
                      "limitation":"Producer boundary and native government role; no cadastral-coordinate legal attestation or western municipality equivalence claimed",
                  })
    return result
