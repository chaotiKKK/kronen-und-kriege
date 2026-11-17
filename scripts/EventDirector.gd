extends RefCounted
## Reine Auswahl: keine Zufallsquelle, Uhrzeit, UI oder Zustandsänderung.
static func eligible(pool: Array, context: Dictionary) -> Array:
	var result: Array = []
	for event in pool:
		var condition := str(event.get("condition", ""))
		if condition == "" or bool(context.get(condition, false)):
			result.append(event)
	result.sort_custom(func(a, b): return str(a.id) < str(b.id))
	return result

static func choose(pool: Array, context: Dictionary, recent: Array, roll: float) -> Dictionary:
	var available := eligible(pool, context)
	var candidates: Array = []
	for event in available:
		if not recent.has(str(event.id)):
			candidates.append(event)
	if candidates.is_empty():
		# Bei kleinen Fremdkatalogen möglichst wenigstens den letzten Fall meiden.
		for event in available:
			if recent.is_empty() or str(event.id) != str(recent[-1]):
				candidates.append(event)
	if candidates.is_empty():
		candidates = available
	if candidates.is_empty():
		return {}
	return candidates[mini(candidates.size() - 1, int(clampf(roll, 0.0, 1.0) * candidates.size()))].duplicate(true)
