extends Node2D
## Graph-paper battlefield: grid, path, Axiom Core, build hover preview.

var points: PackedVector2Array = PackedVector2Array()
var seg_len: Array = []
var total_length: float = 0.0
var path_cells: Dictionary = {}

var show_hover: bool = false
var hover_cell: Vector2i = Vector2i(-99, -99)
var hover_valid: bool = false
var hover_range: float = 0.0
var t: float = 0.0

var decor: Array = [
	["e^(iπ) + 1 = 0", Vector2(250, 80)],
	["∇ · E = ρ / ε₀", Vector2(560, 610)],
	["ζ(s) = Σ n⁻ˢ", Vector2(780, 100)],
	["∫ e^(−x²) dx = √π", Vector2(110, 640)],
	["det(A − λI) = 0", Vector2(300, 440)],
	["∂u/∂t = α ∇²u", Vector2(860, 300)],
	["lim (1 + 1/n)ⁿ = e", Vector2(540, 250)],
	["a² + b² = c²", Vector2(940, 660)],
	["p | ab ⇒ p | a ∨ p | b", Vector2(800, 470)],
]


var waypoints: Array = []
var numeric: bool = true
var complex_view: bool = false
var spacetime: bool = false
var spectrum: bool = false
var chapter: int = 1
var glitch: float = 0.0
var arith_decor: Array = [
	["1 + 1 = 2", Vector2(250, 80)],
	["7 × 8 = 56", Vector2(560, 610)],
	["144 = 12²", Vector2(780, 100)],
	["2¹⁰ = 1024", Vector2(110, 640)],
	["100 ÷ 4 = 25", Vector2(300, 440)],
	["17은 소수", Vector2(860, 300)],
	["9 − 9 = 0", Vector2(540, 250)],
	["√81 = 9", Vector2(940, 660)],
]


func _ready() -> void:
	waypoints = Data.MAPS[int(Data.STAGES[Game.stage_id]["map"])]
	numeric = Data.is_numeric_stage(Game.stage_id)
	chapter = Data.chapter_of(Game.stage_id)
	complex_view = chapter >= 4 and chapter != 8
	spacetime = chapter == 5 or chapter == 10
	spectrum = chapter == 8
	for wp in waypoints:
		points.append(Data.cell_center(wp))
	for i in range(points.size() - 1):
		var l := points[i].distance_to(points[i + 1])
		seg_len.append(l)
		total_length += l
	for i in range(waypoints.size() - 1):
		var a: Vector2i = waypoints[i]
		var b: Vector2i = waypoints[i + 1]
		var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		var c := a
		while true:
			if c.x >= 0:
				path_cells[c] = true
			if c == b:
				break
			c += step


func cell_at(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / Data.CELL), floori(p.y / Data.CELL))


func is_buildable(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < Data.COLS and c.y >= 1 and c.y < Data.ROWS and not path_cells.has(c)


func point_at(d: float) -> Vector2:
	var rem := clampf(d, 0.0, total_length)
	for i in seg_len.size():
		var l: float = seg_len[i]
		if rem <= l:
			return points[i].lerp(points[i + 1], rem / l if l > 0.0 else 0.0)
		rem -= l
	return points[points.size() - 1]


func core_position() -> Vector2:
	return points[points.size() - 1]


var _draw_sig: Array = []
var _anim_t: float = 0.0
var core_fx: Node2D = null


## The graph paper, path and axes do not change: redraw them only when something shown changes,
## or at 20 fps for the slowly moving chapter backdrops. The core animates every frame in its own node.
func _process(delta: float) -> void:
	t += delta
	_anim_t += delta
	if core_fx == null:
		core_fx = CoreFx.new()
		core_fx.map = self
		add_child(core_fx)
	core_fx.queue_redraw()
	var sig := [show_hover, hover_cell, hover_valid, hover_range, complex_view, spacetime, spectrum, Game.x_end,
		numeric, points.size()]
	var animated := complex_view or spacetime or spectrum
	if sig != _draw_sig or (animated and _anim_t >= 0.05):
		_draw_sig = sig
		_anim_t = 0.0
		queue_redraw()


class CoreFx extends Node2D:
	var map

	func _draw() -> void:
		map.draw_core(self)


func _draw() -> void:
	draw_rect(Rect2(0, 0, Data.PLAY_W, 720), Color("0a1424"))
	# graph paper
	for x in range(0, Data.PLAY_W + 1, Data.CELL):
		var major := x % 200 == 0
		draw_line(Vector2(x, Data.TOP), Vector2(x, 720), Color(1, 1, 1, 0.07 if major else 0.03), 1.0)
	for y in range(Data.TOP, 721, Data.CELL):
		var major_y := (y - Data.TOP) % 200 == 0
		draw_line(Vector2(0, y), Vector2(Data.PLAY_W, y), Color(1, 1, 1, 0.07 if major_y else 0.03), 1.0)
	for dcr in (arith_decor if numeric else decor):
		Data.draw_text_centered(self, dcr[0], dcr[1], 18, Color(0.75, 0.85, 1.0, 0.07))
	# path
	draw_polyline(points, Color("16233a"), 38.0, true)
	draw_polyline(points, Color("1f3150"), 30.0, true)
	for i in range(points.size() - 1):
		draw_dashed_line(points[i], points[i + 1], Color(0.75, 0.85, 1.0, 0.18), 2.0, 10.0)
	# from chapter 2 on, the path is revealed as the x-axis: 12 ticks, labelled at 0, the middle and the core
	var xe := Game.x_end
	if not numeric:
		for i in 13:
			var xv := xe * i / 12.0
			var d := total_length * i / 12.0
			var pt := point_at(d)
			var dir := (point_at(minf(total_length, d + 2.0)) - point_at(maxf(0.0, d - 2.0))).normalized()
			var nrm := dir.orthogonal()
			var major := i % 4 == 0
			var tl := 17.0 if major else 9.0
			draw_line(pt - nrm * tl, pt + nrm * tl, Color(0.75, 0.85, 1.0, 0.45 if major else 0.2), 2.0 if major else 1.0)
			if major and i < 12:
				Data.draw_text_centered(self, "x = " + Data.x_label(xv), pt + nrm * 30.0, 13, Color(0.75, 0.85, 1.0, 0.6))
	if complex_view:
		_draw_complex_plane()
	if spacetime:
		_draw_spacetime()
	if spectrum:
		_draw_frequency_axes()
	# hover preview (the core itself is drawn by CoreFx, every frame)
	if show_hover and hover_cell.x >= 0 and hover_cell.x < Data.COLS and hover_cell.y >= 1:
		var cc := Data.cell_center(hover_cell)
		var col := Color(0.4, 1.0, 0.6) if hover_valid else Color(1.0, 0.35, 0.35)
		draw_circle(cc, hover_range, Color(col, 0.05))
		draw_arc(cc, hover_range, 0, TAU, 64, Color(col, 0.6), 1.5, true)
		draw_rect(Rect2(cc - Vector2(20, 20), Vector2(40, 40)), Color(col, 0.25))


## The Axiom Core: pulse, glitch and labels (drawn on the CoreFx child every frame).
func draw_core(ci: CanvasItem) -> void:
	if points.is_empty():
		return
	var xe := Game.x_end
	var cp := core_position()
	var pulse := 0.5 + 0.5 * sin(t * 2.5)
	ci.draw_circle(cp, 30, Color(1.0, 0.82, 0.4, 0.06 + 0.06 * pulse))
	ci.draw_circle(cp, 22, Color("0d1b2a"))
	var core_col := Color("ffd166").lerp(Color("ef5350"), clampf(glitch, 0.0, 1.0))
	var jitter := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * glitch * 6.0
	ci.draw_arc(cp + jitter, 22, 0, TAU, 48, core_col, 2.5, true)
	ci.draw_arc(cp, 27 + pulse * 3, t, t + PI * 1.4, 32, Color(core_col, 0.5), 1.5, true)
	if glitch > 0.0:
		for k in 5:
			var a0 := randf() * TAU
			ci.draw_line(cp + Vector2.RIGHT.rotated(a0) * 8, cp + Vector2.RIGHT.rotated(a0 + randf_range(-0.4, 0.4)) * (26 + glitch * 30), Color("ef5350"), 1.5)
	Data.draw_text_centered(ci, "코어" if numeric else "f(%s)" % Data.x_label(xe), cp + jitter, 13, core_col)
	Data.draw_text_centered(ci, "CORE" if numeric else "x = " + Data.x_label(xe), cp + Vector2(0, 42), 11, Color(core_col, 0.7))


## Chapter 4+: the hidden imaginary axis behind the battlefield.
func _draw_complex_plane() -> void:
	var o := Vector2(Data.PLAY_W / 2.0, 380.0)
	var col := Color(0.70, 0.62, 0.86, 0.10)
	draw_line(Vector2(0, o.y), Vector2(Data.PLAY_W, o.y), col, 2.0)
	draw_line(Vector2(o.x, Data.TOP), Vector2(o.x, 720), col, 2.0)
	var r := 240.0
	draw_arc(o, r, 0, TAU, 96, col, 1.5, true)
	for k in 8:
		var a := k * TAU / 8.0 + t * 0.05
		draw_line(o, o + Vector2.RIGHT.rotated(a) * r, Color(col, 0.05), 1.0)
	var lc := Color(0.70, 0.62, 0.86, 0.28)
	Data.draw_text_centered(self, "Re", Vector2(Data.PLAY_W - 26, o.y - 16), 15, lc)
	Data.draw_text_centered(self, "Im", Vector2(o.x + 22, Data.TOP + 18), 15, lc)
	Data.draw_text_centered(self, "i", o + Vector2(12, -r - 12), 15, lc)
	Data.draw_text_centered(self, "−i", o + Vector2(14, r + 12), 15, lc)
	Data.draw_text_centered(self, "1", o + Vector2(r + 12, 14), 15, lc)
	Data.draw_text_centered(self, "−1", o + Vector2(-r - 16, 14), 15, lc)
	var spin := o + Vector2.RIGHT.rotated(-t * 0.6) * r
	draw_circle(spin, 4.0, Color(0.70, 0.62, 0.86, 0.35))
	Data.draw_text_centered(self, "e^{iθ}", spin + Vector2(0, -16), 12, lc)


## Chapter 7: time becomes a coordinate. A faint t-axis and light cones x ± t = const.
func _draw_spacetime() -> void:
	var col := Color(0.30, 0.82, 0.88, 0.10)
	draw_line(Vector2(24, 700), Vector2(24, Data.TOP + 10), col, 2.0)
	draw_line(Vector2(24, Data.TOP + 10), Vector2(16, Data.TOP + 24), col, 2.0)
	draw_line(Vector2(24, Data.TOP + 10), Vector2(32, Data.TOP + 24), col, 2.0)
	Data.draw_text_centered(self, "t", Vector2(40, Data.TOP + 20), 16, Color(0.30, 0.82, 0.88, 0.35))
	for i in range(-6, 14):
		var x0 := i * 120.0 + fmod(t * 20.0, 120.0)
		draw_line(Vector2(x0, 720), Vector2(x0 + 680, Data.TOP), Color(col, 0.05), 1.0)
		draw_line(Vector2(x0 + 680, 720), Vector2(x0, Data.TOP), Color(col, 0.05), 1.0)
	Data.draw_text_centered(self, "x − t = c", Vector2(860, 640), 13, Color(0.30, 0.82, 0.88, 0.25))
	Data.draw_text_centered(self, "x + t = c", Vector2(180, 640), 13, Color(0.30, 0.82, 0.88, 0.25))


## Chapter 8: the battlefield is the frequency domain.
func _draw_frequency_axes() -> void:
	var col := Color(0.96, 0.56, 0.69, 0.10)
	var base := 690.0
	draw_line(Vector2(30, base), Vector2(Data.PLAY_W - 20, base), col, 2.0)
	for k in 16:
		var x := 60.0 + k * 60.0
		var hgt := 40.0 + 30.0 * sin(t * 0.8 + k * 0.7) * sin(k * 0.45)
		draw_rect(Rect2(x - 8, base - absf(hgt), 16, absf(hgt)), Color(col, 0.06))
		Data.draw_text_centered(self, str(k), Vector2(x, base + 12), 11, Color(0.96, 0.56, 0.69, 0.25))
	Data.draw_text_centered(self, "ω", Vector2(Data.PLAY_W - 30, base - 14), 16, Color(0.96, 0.56, 0.69, 0.35))
	Data.draw_text_centered(self, "|F(ω)|", Vector2(50, Data.TOP + 22), 14, Color(0.96, 0.56, 0.69, 0.3))
	Data.draw_text_centered(self, "D ⟷ iω", Vector2(Data.PLAY_W / 2.0, Data.TOP + 22), 15, Color(0.96, 0.56, 0.69, 0.22))
