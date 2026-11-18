extends RefCounted
## Gemeinsame reine Definitionen für Modell, Oberfläche und Inhaltsfingerprint.
const ORDER := ["balanced", "agriculture", "trade", "workshops"]
const LOCK_MONTHS := 12
const FOCI := {
	"balanced": {"name":"Ausgewogen", "description":"Bisheriger Grund- und Marktertrag; normale örtliche Versorgung.", "income_multiplier":1.0, "supply_multiplier":1.0},
	"agriculture": {"name":"Kornkammer", "description":"−15 % Grund- und Marktertrag; +50 % örtliche Versorgung. Freier Landwirtschaftsbonus kann über eigene fertige Straßen andere Heere versorgen.", "income_multiplier":0.85, "supply_multiplier":1.5},
	"trade": {"name":"Handelsort", "description":"+15 % Grund- und Marktertrag; −20 % örtliche Versorgung.", "income_multiplier":1.15, "supply_multiplier":0.8},
	"workshops": {"name":"Werkstätten", "description":"Vierfache Baustoffausbeute je Produktionsarbeit; −20 % Grund- und Marktertrag, −25 % örtliche Versorgung. Bau und Produktion teilen dieselbe örtliche Arbeit.", "income_multiplier":0.8, "supply_multiplier":0.75},
}

static func change_cost(region: Dictionary) -> int:
	return maxi(1, roundi(20.0 * float(region.get("economic_share", 1.0))))

static func income_multiplier(focus: String) -> float:
	return float(FOCI.get(focus,FOCI.balanced).income_multiplier)

static func supply_multiplier(focus: String) -> float:
	return float(FOCI.get(focus,FOCI.balanced).supply_multiplier)
