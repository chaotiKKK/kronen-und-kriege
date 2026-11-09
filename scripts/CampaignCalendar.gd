extends RefCounted
## Kalender ohne Jahr null. Indizes zählen seit Januar 2000 v. Chr.
const LAST_MONTH := 50399

static func to_index(year: int, month: int) -> int:
	if year == 0 or year < -2000 or month < 1 or month > 12:
		return -1
	return (year + 2000 - (1 if year > 0 else 0)) * 12 + month - 1

static func from_index(index: int) -> Dictionary:
	if index < 0:
		return {}
	var year := int(index / 12) - 2000
	if year >= 0:
		year += 1
	return {"year": year, "month": index % 12 + 1}
