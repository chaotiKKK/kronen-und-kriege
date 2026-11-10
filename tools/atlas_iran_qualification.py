"""Label qualification for the exact damaged gbOpen2021 Iran release.

This module only marks lost source names. It grants no administrative role,
reconstructs no lost characters and changes no geometry or authority identity.
The original producer DBF contains the same literal ASCII question marks.
"""
from copy import deepcopy
import re


SOURCE_ID = "gbOpen-IRN-ADM4"
SOURCE_COMMIT = "9469f09"
SOURCE_SHA256 = "89d50a325cda34b4420b8b10ecbebe585825011a3c5969a3a813ef5ac386185c"
RAW_PRODUCER_SHA256 = "909ddf98c95aa32198f94adee78941efddd1dbc1338ebfc0003aeb42c69bb874"


def qualify_row(row, source):
    result = deepcopy(row)
    if (source.get("id") != SOURCE_ID or source.get("country") != "IR"
            or row.get("source") != SOURCE_ID or row.get("country") != "IR"):
        return result
    if source.get("source_commit") != SOURCE_COMMIT or source.get("sha256") != SOURCE_SHA256:
        raise ValueError("Changed pinned Iran name-qualification source")
    if not re.fullmatch(r"gbOpen:IRN:ADM4:25652852B\d+", str(row.get("id", ""))):
        raise ValueError("Wrong original Iran source identity")
    original = row.get("original_name")
    if not isinstance(original, str) or "?" not in original:
        return result
    result.update(name_known=False,
                  name="Verwaltungsgebiet (Name in Quelle beschädigt)",
                  name_quality="source-name-corrupted",
                  name_qualification_evidence={
                      "source_commit": SOURCE_COMMIT,
                      "source_file_sha256": SOURCE_SHA256,
                      "original_producer_zip_sha256": RAW_PRODUCER_SHA256,
                      "cause": "Literal ASCII question marks already present in producer DBF; no encoding repair inferred",
                  })
    return result
