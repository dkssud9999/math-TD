extends Node2D
## An enemy IS a function f(x, t) (in chapter 1 just a number). It walks the x-axis to the core at x = X_END
## while its own clock t runs. Towers apply operators; f ≡ 0 means gone. Reaching the core deals the digit count of |f(X_END, t)|.
## Two special kinds: equations p(x) = 0 (solved by approximation) and Gödel sentences (unprovable).

const FONT_SIZE := 15
const T_RATE := 0.03       # t advances 0.03 per second on the field (≈1.5 by the core)
const ROOT_TOL := 1e-6

var main
var f: Expr
var fprime: Expr
var template: String = ""
var base_speed: float = 50.0
var boss: bool = false
var alive: bool = true
var progress: float = 0.0
var integrations: int = 0
var threat: int = 1
var reward: int = 1
var spawn_degree: int = 0
var label: String = ""
var sublabel: String = ""
var color: Color = Color.WHITE
var label_w: float = 20.0
var flash: float = 0.0
var t: float = 0.0
var tt: float = 0.0          # the function's own time variable
var t_refresh: float = 0.0
var numeric: bool = true
var ann_text: String = ""
var members: int = 1
var gen: bool = false
var gen_seed: Expr = null
var gen_timer: float = 3.0
var gen_left: int = 6
var special: String = ""     # "", "root", "godel"
var root_x: float = 0.0
var root_lo: float = 0.0
var root_hi: float = 1.0
var root_hist: Array = []
var trail: Array = []
var popup_t: float = 0.0
var trail_t: float = 0.0
var sb := StyleBoxFlat.new()


func setup(p_template: String, p_main, p_f: Expr, start_progress: float) -> void:
	template = p_template
	main = p_main
	f = p_f
	var meta: Dictionary = Data.TEMPLATES[template]
	base_speed = float(meta["speed"]) * (1.0 + 0.012 * (Game.wave - 1))
	var armor := 0   # xᵐ armour makes the slope steep; heavy enemies walk slower instead of faster
	var probe := f.clone()
	while armor < 8 and probe.divisible_by_x() and not probe.is_constant():
		probe.div_x()
		armor += 1
	if Data.chapter_of(Game.stage_id) >= 2 and armor > 1:
		base_speed /= 1.0 + 0.25 * (armor - 1)
	boss = meta.get("boss", false)
	gen = meta.get("gen", false)
	special = meta.get("special", "")
	if gen:
		gen_seed = f.clone()
	if special == "root":
		var r: Dictionary = Data.ROOTS[template]
		root_x = float(r["x0"])
		root_lo = float(r["lo"])
		root_hi = float(r["hi"])
	progress = start_progress
	spawn_degree = maxi(0, f.degree())
	numeric = f.is_constant() and special == ""
	if special != "":
		reward = 40 if boss else 12
	elif boss:
		reward = 30 if numeric else 60
	elif numeric:
		reward = 1 + str(int(absf(f.value_at(0.0)))).length()
	else:
		reward = 1 + f.ann_degree() * 2
	sb.bg_color = Color(0.04, 0.07, 0.13, 0.92)
	sb.set_corner_radius_all(13)
	sb.anti_aliasing = true
	_refresh()
	position = main.map.point_at(progress)
	add_to_group("enemies")


## Every chapter: an enemy damages the core by the number of digits of |f(X_END, t)| (⌊log₁₀|f|⌋ + 1).
## The core sits at x = chapter number, so 3x²eˣ in chapter 3 is 543 → 3. Below 0.5 is harmless.
static func harm(v: float) -> int:
	var a := absf(v)
	if is_nan(a) or is_inf(a):
		return 99
	if a < 0.5:
		return 0
	if a < 10.0:
		return 1
	return floori(log(a) / log(10.0) + 1e-9) + 1


func _refresh() -> void:
	fprime = f.clone()
	fprime.derive()
	match special:
		"root":
			label = f.to_text() + " = 0"
			var pv := absf(f.value_at(root_x))
			threat = clampi(ceili(log(maxf(pv, ROOT_TOL) / ROOT_TOL) / log(10.0) / 3.0), 1, 3)   # digits of precision still missing, ÷3
			sublabel = "x ≈ %.6f    |p| = %s" % [root_x, _sci(pv)]
		"godel":
			label = "G"
			threat = 3
			sublabel = "「이 적은 이 체계 안에서 처치할 수 없다」"
		_:
			label = _short(f.to_text())
			threat = harm(f.value_at(Game.x_end, tt)) + (members - 1)   # each function Σ merged in adds 1
			ann_text = "Ann " + f.annihilator()
			if f.has_t():
				ann_text += "   ·   ᵗ " + f.t_annihilator()
	numeric = f.is_constant() and special == ""
	color = _form_color()
	label_w = Data.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	sb.border_color = color
	sb.set_border_width_all(3 if boss else 2)
	sb.set_corner_radius_all(13 if numeric else (2 if special != "" else 8))
	queue_redraw()


static func _compact(v: float) -> String:
	var a := absf(v)
	if a < 1000.0:
		return str(int(round(v)))
	return ("−" if v < 0 else "") + _sci(a)


static func _sci(v: float) -> String:
	if v == 0.0:
		return "0"
	var e := floori(log(v) / log(10.0))
	return "%.1f·10%s" % [v / pow(10.0, e), Expr.sup(e)]


## Very large integers are shown as powers when exact (2³², 10⁶) so labels stay readable.
func _short(txt: String) -> String:
	if not f.is_constant() or txt.length() <= 7 or txt.contains("/"):
		return txt
	var n := int(f.value_at(0.0))
	for b in [2, 10]:
		var k := 0
		var m := n
		while m > 1 and m % b == 0:
			m /= b
			k += 1
		if m == 1 and k > 1:
			return str(b) + Expr.sup(k)
	return txt


func _form_color() -> Color:
	if special == "root":
		return Color("ffe082")
	if special == "godel":
		return Color("ef5350").lerp(Color.BLACK, 0.25)
	if boss:
		return Color("ef5350")
	if f.has_t():
		return Color("4dd0e1")
	if f.has_exp():
		return Color("81c784")
	if f.has_trig():
		return Color("b39ddb")
	match f.degree():
		-1, 0:
			if threat == 0:
				return Color("78909c")
			return Color("eceff1")
		1:
			return Color("80deea")
		2:
			return Color("4fc3f7")
		_:
			return Color("7986cb")


func x_now() -> float:
	return Game.x_end * progress / main.map.total_length


## Movement follows the math: speed grows with the slope |∂f/∂x|.
func speed() -> float:
	if special != "":
		return base_speed
	var slope := absf(fprime.value_at(x_now(), tt))
	return base_speed * minf(2.5, 1.0 + 0.3 * log(1.0 + minf(slope, 1e6)))


func apply_op(op: String, params: Dictionary) -> void:
	if not alive:
		return
	if special == "godel":
		if Progress.axiom("ax_g"):
			main.spawn_text(global_position + Vector2(0, -30), "공리로부터 증명됨", Color("ffd166"), 14)
			_die()
		else:
			main.spawn_text(global_position + Vector2(0, -30), "증명 불가", Color("ef5350"), 13)
		return
	if special == "root":
		_root_step(op)
		return
	var old_label := label
	if op != "int":
		var before := f.clone()
		if not main.TowerScript.transform(op, f, params):
			if op in ["diff", "dm1", "harm", "dtl", "wave"] and f.equals(before):
				var sym: String = {"diff": "D", "dm1": "(D−1)", "harm": "(D²+%d)" % (int(params.get("w", 1)) ** 2),
					"dtl": "(∂ₜ−%d)" % int(params.get("lam", 1)), "wave": "□"}[op]
				main.spawn_text(global_position + Vector2(0, -30), "%s f = f" % sym, Color("ef5350"), 14)
			return
		match op:
			"sub":
				Sfx.play("sub", 1.0 + 0.05 * f.degree())
			"div", "divx":
				Sfx.play("mod", 0.8 if op == "divx" else 1.0)
			"sqrt", "log2":
				Sfx.play("eval", 0.8 if op == "log2" else 1.0)
			"diff":
				Sfx.play("diff")
			"dm1", "dtl":
				Sfx.play("int")
			"harm", "wave":
				Sfx.play("pulse")
	match op:
		"int":
			if integrations >= Data.MAX_INTEGRATIONS:
				return
			f.integrate()
			integrations += 1
			var g := maxi(1, int(round(absf(f.value_at(1.0, tt)) * float(params["mult"]))))
			Game.add_rho(g)
			Game.harvested += g
			main.spawn_text(global_position + Vector2(0, -34), "∫₀¹ → +%dρ" % g, Color("81c784"), 13)
			Sfx.play("int")
			Sfx.play("coin")
	flash = 0.12
	if f.is_zero():
		_die()
		return
	_popup_change(old_label)
	if Progress.axiom("ax_inf") and absf(f.value_at(Game.x_end, tt)) < 1.0:
		main.spawn_text(global_position + Vector2(0, -34), "≈ 0  (무한소)", Color("ffd166"), 13)
		_die()
		return
	_refresh()


## A short "→ new form" over the enemy, so each transform is readable (throttled per enemy).
func _popup_change(old_label: String) -> void:
	var nl := _short(f.to_text())
	if nl == old_label or popup_t > 0.0 or nl.length() > 22:
		return
	popup_t = 0.35
	main.spawn_text(global_position + Vector2(0, -46), "→ " + nl, Color(color, 0.9), 11, 0.6)


## One step of Newton's method or bisection on p(x) = 0.
func _root_step(op: String) -> void:
	var px := f.value_at(root_x)
	match op:
		"newton":
			var dp := fprime.value_at(root_x)
			if absf(dp) < 1e-9:
				main.spawn_text(global_position + Vector2(0, -30), "p′(x) = 0 — 튕겨 나감", Color("ef5350"), 13)
				root_x += 1.0
			else:
				var nx := root_x - px / dp
				if is_nan(nx) or absf(nx) > 1e6:
					main.spawn_text(global_position + Vector2(0, -30), "발산", Color("ef5350"), 14)
					nx = float(Data.ROOTS[template]["x0"])
				root_hist.append(root_x)
				if root_hist.size() > 2:
					root_hist.pop_front()
				if root_hist.size() == 2 and absf(nx - float(root_hist[0])) < 1e-9 and absf(px) > ROOT_TOL:
					main.spawn_text(global_position + Vector2(0, -30), "순환!  %.3f ⇄ %.3f" % [root_hist[0], root_hist[1]], Color("ef5350"), 13)
				root_x = nx
			Sfx.play("diff", 1.2)
		"bisect":
			var mid := (root_lo + root_hi) / 2.0
			var plo := f.value_at(root_lo)
			var pm := f.value_at(mid)
			if (plo < 0.0) == (pm < 0.0):
				root_lo = mid
			else:
				root_hi = mid
			root_x = (root_lo + root_hi) / 2.0
			Sfx.play("mod")
		_:
			return
	flash = 0.12
	if absf(f.value_at(root_x)) < ROOT_TOL:
		main.spawn_text(global_position + Vector2(0, -40), "x = %.6f" % root_x, Color("ffe082"), 14)
		_die()
		return
	_refresh()


## Σ: o's function is added into this one (linearity). Opposite functions cancel.
func absorb(o) -> void:
	if not alive or not o.alive or o == self or special != "" or o.special != "":
		return
	f.add_expr(o.f)
	if Data.COUNTERS.has(o.template) and not Data.COUNTERS.has(template):
		template = o.template   # a counterexample swallowed by Σ is still the counterexample
	reward += o.reward
	members += o.members
	boss = boss or o.boss
	integrations = maxi(integrations, o.integrations)
	tt = maxf(tt, o.tt)
	o.alive = false
	o.queue_free()
	flash = 0.2
	if f.is_zero():
		main.spawn_text(global_position + Vector2(0, -44), "상쇄!", Color("ffd166"), 18)
		_die()
		return
	_refresh()


func _die(by_induction: bool = false) -> void:
	if not alive:
		return
	alive = false
	Game.kills += members
	var bonus := 0
	for i in members:
		bonus += int(main.on_enemy_killed(global_position))
	Game.add_rho(reward + bonus)
	var tag := "0" if numeric else ("풀림" if special == "root" else "≡ 0")
	main.spawn_text(global_position + Vector2(0, -20), "%s   +%dρ" % [tag, reward + bonus], Color("ffd166"), 14)
	main.spawn_burst(global_position, color)
	Sfx.play("kill%d" % clampi(spawn_degree, 0, 4), pow(1.06, mini(main.combo, 12)))
	if not by_induction and special == "" and Progress.axiom("ax_ind"):
		main.induct(self)
	queue_free()


func _reach_core() -> void:
	alive = false
	if Data.COUNTERS.has(template) and not Progress.flag(Data.COUNTERS[template]["flag"]):
		if main.counter_reach(template, members):
			queue_free()
			return
	if threat == 0:
		main.spawn_text(main.map.core_position() + Vector2(0, -40), "무해", Color("78909c"), 15)
		queue_free()
		return
	if main.autotest and OS.get_cmdline_user_args().has("--leaks"):
		print("[leak] w%d %s (%s)" % [Game.wave, f.to_text(), template])
	var msg := ("−%d" % threat) if (numeric or special != "") else ("f(%s) ≈ %s  →  −%d" % [_xe(), _compact(f.value_at(Game.x_end, tt)), threat])
	main.spawn_text(main.map.core_position() + Vector2(0, -40), msg, Color("ef5350"), 18)
	Sfx.play("leak")
	main.shake(6.0 + minf(14.0, threat * 0.2))
	Game.damage(threat)
	queue_free()


func _xe() -> String:
	return Data.x_label(Game.x_end)


func _process(delta: float) -> void:
	if not alive:
		return
	t += delta
	tt += delta * T_RATE
	popup_t = maxf(0.0, popup_t - delta)
	flash = maxf(0.0, flash - delta)
	progress += speed() * delta
	if special == "" and f.has_t():
		t_refresh -= delta
		if t_refresh <= 0.0:
			t_refresh = 0.25
			threat = harm(f.value_at(Game.x_end, tt)) + (members - 1)   # each function Σ merged in adds 1
		trail_t -= delta
		if trail_t <= 0.0:
			trail_t = 0.2
			trail.append(global_position)
			if trail.size() > 14:
				trail.pop_front()
	if gen and gen_left > 0:
		gen_timer -= delta
		if gen_timer <= 0.0:
			gen_timer = 3.0
			gen_seed.derive()
			if gen_seed.is_zero():
				gen_left = 0
			else:
				gen_left -= 1
				main.spawn_child(gen_seed.clone(), maxf(0.0, progress - 18.0), global_position)
	if progress >= main.map.total_length:
		_reach_core()
		return
	position = main.map.point_at(progress)
	queue_redraw()


func _draw() -> void:
	if trail.size() > 1:
		var pts := PackedVector2Array()
		for p in trail:
			pts.append(p - global_position)
		pts.append(Vector2.ZERO)
		draw_polyline(pts, Color(color, 0.25), 2.0, true)
	if main.map.spectrum and special == "":
		_draw_spectrum()
		return
	var w := maxf(label_w + 18.0, 28.0)
	var h := 26.0
	if gen and gen_left > 0:
		var ring := 1.0 - gen_timer / 3.0
		draw_arc(Vector2.ZERO, w / 2 + 6 + ring * 6, 0, TAU * ring, 24, Color(color, 0.5), 1.5)
	if members > 1:
		Data.draw_text_centered(self, "×%d" % members, Vector2(w / 2 + 12, -h / 2), 11, Color("ffb74d"))
	if boss:
		var pulse := 3.0 + 2.0 * sin(t * 4.0)
		draw_rect(Rect2(-w / 2 - pulse, -h / 2 - pulse, w + 2 * pulse, h + 2 * pulse), Color(color, 0.18), false, 2.0)
	var old_bg := sb.bg_color
	if flash > 0.0:
		sb.bg_color = Color(color, 0.45)
	if special == "godel":
		sb.bg_color = Color(0.0, 0.0, 0.0, 0.95)
	draw_style_box(sb, Rect2(-w / 2, -h / 2, w, h))
	sb.bg_color = old_bg
	Data.draw_text_centered(self, label, Vector2.ZERO, FONT_SIZE, color.lerp(Color.WHITE, 0.25))
	for i in integrations:
		draw_circle(Vector2(-w / 2 + 6 + i * 6, -h / 2 - 4), 2.2, Color("81c784"))
	if special != "":
		Data.draw_text_centered(self, sublabel, Vector2(0, h / 2 + 9), 10, Color(color, 0.8))
	elif not numeric:
		var tc := Color(1.0, 0.45, 0.45, 0.85) if threat >= 4 else Color(1.0, 0.75, 0.75, 0.6)
		var where := "f(%s)" % _xe() if not f.has_t() else "f(%s, %.1f)" % [_xe(), tt]
		Data.draw_text_centered(self, "%s≈%s  −%d" % [where, _compact(f.value_at(Game.x_end, tt)), threat], Vector2(0, h / 2 + 9), 10, tc)
		if Progress.has("ann"):
			Data.draw_text_centered(self, ann_text, Vector2(0, -h / 2 - 9), 10, Color("80deea"))
	elif threat == 0:
		Data.draw_text_centered(self, "무해", Vector2(0, h / 2 + 9), 10, Color("78909c"))


## Chapter 8: the enemy is drawn as its spectrum — one bar per mode, x position = frequency.
func _draw_spectrum() -> void:
	var bars := {}
	for key: Array in f.t:
		var b := int(key[2])
		if b < 0:
			continue
		var z: Array = f.t[key]
		var mag := sqrt(pow(Expr.rf(z[0]), 2) + pow(Expr.rf(z[1]), 2)) * (2.0 if b > 0 else 1.0)
		var slot := Vector2i(b, int(key[1]))
		bars[slot] = float(bars.get(slot, 0.0)) + mag
	var keys: Array = bars.keys()
	keys.sort_custom(func(p, q): return p.x < q.x if p.x != q.x else p.y < q.y)
	var bw := 6.0
	var w := maxf(24.0, keys.size() * (bw + 2) + 8)
	draw_rect(Rect2(-w / 2, -14, w, 28), Color(0.03, 0.05, 0.1, 0.85))
	draw_line(Vector2(-w / 2 + 3, 12), Vector2(w / 2 - 3, 12), Color(color, 0.6), 1.0)
	var x := -w / 2 + 5
	for k in keys:
		var hgt := clampf(4.0 + 5.0 * log(1.0 + float(bars[k])) / log(2.0), 3.0, 24.0)
		var c := Color("eceff1") if (k.x == 0 and k.y == 0) else (Color("81c784") if k.x == 0 else Color("b39ddb").lerp(Color("f48fb1"), clampf(k.x / 8.0, 0.0, 1.0)))
		if flash > 0.0:
			c = c.lerp(Color.WHITE, 0.6)
		draw_rect(Rect2(x, 12 - hgt, bw, hgt), c)
		x += bw + 2
	var freqs := PackedStringArray()
	for k in keys:
		if k.x > 0 and not freqs.has(str(k.x)):
			freqs.append(str(k.x))
	var cap := ("ω " + "·".join(freqs)) if freqs.size() > 0 else "ω 0"
	Data.draw_text_centered(self, cap, Vector2(0, -22), 10, Color(color, 0.85))
	Data.draw_text_centered(self, "|f|=%d" % threat, Vector2(0, 22), 10, Color(1.0, 0.6, 0.6, 0.8))
