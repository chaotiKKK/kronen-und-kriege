extends Control
## Kleines Liniendiagramm für die Chronik. Zeichnet Achsenrahmen, Titel und je
## Reihe eine Linie über die aufgezeichneten Monatswerte.

var title := ""
var series: Array = []
var points: Array = []
var show_legend := true

func _init(chart_title: String = "", chart_series: Array = [], chart_points: Array = [], w: float = 720.0, h: float = 132.0, legend_visible: bool = true) -> void:
	title = chart_title
	series = chart_series
	points = chart_points
	show_legend = legend_visible
	custom_minimum_size = Vector2(w, h)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.07, 0.05, 0.62), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.43, 0.24, 0.85), false, 1.0)
	draw_string(font, Vector2(9, 16), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.97, 0.87, 0.60))
	if points.is_empty():
		draw_string(font, Vector2(9, size.y - 8), "Keine Verlaufsdaten", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.72, 0.66, 0.54))
		return
	var top := 26.0
	var bottom: float = size.y - 16.0
	var data_min := INF
	var data_max := -INF
	for s in series:
		for p in points:
			var v: float = float(p.get(str(s[0]), 0))
			data_min = minf(data_min, v)
			data_max = maxf(data_max, v)
	if not is_finite(data_min):
		data_min = 0.0
	if not is_finite(data_max):
		data_max = 0.0
	# Ausschnitt um die tatsächlichen Werte legen, damit auch dicht beieinander
	# liegende Hauskurven unterscheidbar bleiben. Negative Werte gibt es nicht.
	var lo := data_min
	var hi := data_max
	if hi - lo < 1.0:
		lo -= 1.0
		hi += 1.0
	else:
		var pad: float = (hi - lo) * 0.12
		lo -= pad
		hi += pad
	lo = maxf(0.0, lo)
	if hi <= lo:
		hi = lo + 1.0
	var n: int = points.size()
	var last_point := Vector2.ZERO
	for s in series:
		var col: Color = s[1]
		var prev := Vector2.ZERO
		for i in n:
			var value: float = float(points[i].get(str(s[0]), 0))
			var frac: float = 0.5 if n == 1 else float(i) / float(n - 1)
			var x: float = 9.0 + (size.x - 18.0) * frac
			var y: float = bottom - (bottom - top) * clampf((value - lo) / (hi - lo), 0.0, 1.0)
			var pt := Vector2(x, y)
			if i > 0:
				draw_line(prev, pt, col, 2.0, true)
			prev = pt
		if n == 1:
			draw_circle(prev, 3.0, col)
		last_point = prev
	var last: Dictionary = points[n - 1]
	if show_legend:
		var legend := ""
		for s in series:
			legend += "%s %d   " % [str(s[2]), int(last.get(str(s[0]), 0))]
		draw_string(font, Vector2(9, size.y - 4), legend, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.90, 0.86, 0.76))
	draw_string(font, Vector2(size.x - 92, 14), "Max %d" % int(round(data_max)), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.72, 0.66, 0.54))
	draw_string(font, Vector2(size.x - 92, size.y - 4), "Min %d" % int(round(data_min)), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.72, 0.66, 0.54))
	if last_point != Vector2.ZERO:
		draw_circle(last_point, 4.0, Color(1, 1, 1, 0.25))
