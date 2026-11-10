"""Fail-closed review of the eight dated AZ admin8 candidates.

OSM level 8 and overlap with a coarse national outline do not prove a
bələdiyyə. Keep every original record and geometry as excluded evidence.
No new municipal boundary is inferred from a city/district outline.
"""
from __future__ import annotations

from copy import deepcopy

PORTAL = "https://e-belediyye.gov.az/"
GANJA = "https://ganja-ih.gov.az/az/belediyyeler.html"
MUNICIPAL_TERRITORIES = "https://www.taxes.gov.az/az/post/195"
EXPECTED_NAMES = {
    "11825936": "Binəqədi rayonu", "11826962": "Nəsimi rayonu",
    "11827003": "Nərimanov rayonu", "11827201": "Nizami rayonu",
    "11901821": "Kəpəz rayonu", "11901822": "Nizami rayonu",
    "17032156": "آقاحسن بیگلو", "3912206": "Sumqayıt",
}


def qualify_row(row: dict) -> dict:
    """Preserve the source, but prevent an unproven role from entering coverage."""
    unit_id = str(row.get("original_source_id", ""))
    expected_name = EXPECTED_NAMES.get(unit_id)
    original = row.get("original_properties", {})
    if (expected_name is None or row.get("country") != "AZ"
            or row.get("source") != "geofabrik-AZ-admin8-municipality"
            or row.get("id") != "geofabrik:AZ:8:" + unit_id
            or row.get("kind") != "municipality" or row.get("admin_level") != 8
            or row.get("name") != expected_name or row.get("original_name") != expected_name
            or str(original.get("osm_id")) != unit_id or original.get("name") != expected_name
            or original.get("fclass") != "admin_level8" or original.get("code") != 1208):
        raise ValueError("AZ source identity changed; a new positive administrative review is required")
    result = deepcopy(row)
    if unit_id == "17032156":
        note = ("The national country assignment and municipal role are not independently qualified. "
                "Coarse national-land overlap cannot establish an Azerbaijani bələdiyyə; "
                "the original village record is preserved for territorial review.")
        evidence = MUNICIPAL_TERRITORIES
    elif unit_id == "3912206":
        note = ("This original record identifies the city of Sumqayıt. Its boundary has not been "
                "positively proved coextensive with a particular bələdiyyə; shared city names "
                "and admin_level=8 are insufficient municipal-boundary evidence.")
        evidence = MUNICIPAL_TERRITORIES
    else:
        note = ("The original OSM object identifies a city district (rayon), not a positively "
                "qualified municipal boundary. Municipality and district extents are not interchangeable; "
                "the official Kapaz description explicitly excludes Hajikend from that municipality.")
        evidence = GANJA if unit_id in {"11901821", "11901822"} else MUNICIPAL_TERRITORIES
    result.update(administrative_geometry_eligible=False,
                  administrative_ineligibility_note=note,
                  administrative_ineligibility_evidence_url=evidence,
                  administrative_qualification_date="2026-11-10",
                  administrative_qualification_rule="AZ-admin8-identity-review-v1",
                  administrative_original_inferred_role="municipality / Belediyye")
    return result
