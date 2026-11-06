extends Node2D
## An operator tower. It only targets enemies its operator would actually change.

const TARGET_MODES := ["선두", "최대 위협", "최근접"]

var type: String = ""
var data: Dictionary = {}
var main
var cell: Vector2i = Vector2i.ZERO
var level: int = 1
var spent: int = 0
var cooldown: float = 0.0
var target_mode: int = 0
var omega: int = 1
var lam: int = 1
var flash: float = 0.0
var aim: Vector2 = Vector2.RIGHT
var t: float = 0.0
var algo: String = ""          # .py file this tower runs ("" = built-in targeting)
var algo_host: Algo = null
var algo_error: String = ""


func setup(p_type: String, p_main, p_cell: Vector2i) -> void:
	type = p_type
	data = Data.TOWERS[type]
	main = p_main
	cell = p_cell
	spent = int(data["cost"])
	position = Data.cell_center(cell)
	if type in ["sqrt", "log2", "div", "newton", "bisect"]:
		target_mode = 1   # biggest first
	if Progress.has("code"):
		algo = String(Progress.algo_default.get(type, ""))


func stat(key: String) -> float:
	return float(data[key][level - 1])


## Operator power, including research-gated upgrades.
func power() -> float:
	if type == "div" and level == 3 and Progress.has("div3"):
		return 3.0
	if type == "diff" and level == 3 and Progress.has("d3"):
		return 3.0
	if type == "diff" and level == 3 and Progress.has("d2"):
		return 2.0
	if type == "dm1" and level == 3 and Progress.has("dbl"):
		return 2.0
	if type == "int" and Progress.has("int2"):
		return stat("power") * 1.5
	if type == "harm" and level == 3 and Progress.has("harm2"):
		return 2.0
	if type == "damp" and level == 3 and Progress.has("damp2"):
		return 2.0
	if type == "merge" and Progress.axiom("ax_choice"):
		return 99.0
	return stat("power")


func glyph() -> String:
	match type:
		"div":
			return "÷%d" % int(power())
		"diff":
			return ["d/dx", "d/dx", "d²/dx²", "d³/dx³"][int(power())]
		"dm1":
			return "(D−1)²" if int(power()) == 2 else "D−1"
		"harm":
			var q := "D²+%d" % (omega * omega)
			return "(%s)²" % q if int(power()) == 2 else q
		"merge":
			return "Σ∞" if int(power()) >= 99 else "Σ%d" % int(power())
		"damp":
			return "e⁻²ˣ·" if int(power()) == 2 else "e⁻ˣ·"
		"dtl":
			return "∂ₜ−%d" % lam
		"lpf":
			return "LPF" + ["₀", "₁", "₂", "₃"][int(power())]
	return data["glyph"][level - 1]


func range_px() -> float:
	return stat("range")


func rate() -> float:
	var r := stat("rate")
	if type == "sub" and Progress.has("drill"):
		r *= 1.3
	return r


func upgrade_cost() -> int:
	return int(data["upgrade"][level - 1]) if level < 3 else 0


func sell_value() -> int:
	return int(spent * 0.7)


func uses_targeting() -> bool:
	return type not in ["merge", "damp", "lpf"]


## The second parameter some towers expose: ω for the harmonic tower, λ for the time tower.
func param_label() -> String:
	if type == "harm" and Progress.has("omega2"):
		return "진동수 ω = %d  [W]" % omega
	if type == "dtl" and Progress.has("dtl2"):
		return "성장률 λ = %d  [W]" % lam
	return ""


func cycle_param() -> bool:
	if type == "harm" and Progress.has("omega2"):
		omega = 3 - omega
		return true
	if type == "dtl" and Progress.has("dtl2"):
		lam = 3 - lam
		return true
	return false


func upgrade() -> bool:
	if level >= 3:
		return false
	var c := upgrade_cost()
	if not Game.spend(c):
		return false
	spent += c
	level += 1
	flash = 0.4
	main.spawn_text(global_position + Vector2(0, -28), "Lv %d" % level, data["color"], 16)
	return true


func op_params() -> Dictionary:
	var pw := power()
	return {"k": int(pw), "n": int(pw), "mult": pw, "w": omega, "lam": lam}


## The operator itself, applied to a bare function (used by real hits AND by the pipeline prediction).
## Returns whether f changed. Integration and equation-solving live on the enemy (they have side effects).
static func transform(op: String, f: Expr, params: Dictionary) -> bool:
	match op:
		"sub":
			return f.sub_toward_zero(int(params["k"]))
		"divx":
			if not f.divisible_by_x():
				return false
			f.div_x()
			return true
		"div":
			if not f.divisible_by(int(params["k"])):
				return false
			f.scale(1, int(params["k"]))
			return true
		"sqrt":
			if not f.is_perfect_square() or (not f.is_constant() and not Progress.has("psqrt")):
				return false
			f.sqrt_const()
			return true
		"log2":
			if not f.is_pow2():
				return false
			f.log2_const()
			return true
		"damp":
			f.shift(-int(params["k"]))
			return true
		"lpf":
			return f.lowpass(int(params["k"]))
		"diff", "dm1", "harm", "dtl", "wave":
			var before := f.clone()
			for i in int(params["n"]):
				match op:
					"diff":
						f.derive()
					"dm1":
						f.apply_dl(1)
					"harm":
						f.apply_quad(0, int(params.get("w", 1)))
					"dtl":
						f.apply_dtl(int(params.get("lam", 1)))
					_:
						f.apply_wave()
			return not f.equals(before)
	return false


## Would this tower's operator make progress on the bare function f?
func useful_f(f: Expr) -> bool:
	match type:
		"harm":
			return f.has_mode(0, omega)
		"dtl":
			return f.has_t_mode(lam)
		"lpf":
			return f.max_freq() > int(power())
		"int", "merge", "newton", "bisect":
			return false
	return op_useful(type, f, int(power()))


## Would this operator change f at all (and help)?
func useful(e) -> bool:
	if e.special == "root":
		return type in ["newton", "bisect"]
	if e.special == "godel":
		return Progress.axiom("ax_g") or Data.COUNTERS.has(e.template)
	if type in ["newton", "bisect"]:
		return false
	if type == "int":
		return e.integrations < Data.MAX_INTEGRATIONS
	if type == "dtl":
		return e.f.has_t_mode(lam) or Data.COUNTERS.has(e.template)
	if type == "lpf":
		return e.f.max_freq() > int(power())
	if type == "harm":
		return e.f.has_mode(0, omega) or Data.COUNTERS.has(e.template)
	return op_useful(type, e.f, int(power())) or (type in ["diff", "dm1", "harm"] and Data.COUNTERS.has(e.template))


## Does operator `type` (with power k) make progress on f?
static func op_useful(type: String, f: Expr, k: int = 1) -> bool:
	match type:
		"sub":
			return not Expr.rz(f.const_term())
		"div":
			return f.divisible_by(maxi(2, k))
		"divx":
			return f.divisible_by_x()
		"sqrt":
			return f.is_perfect_square() and (f.is_constant() or Progress.has("psqrt"))
		"log2":
			return f.is_pow2()
		"diff":
			return f.degree() >= 0
		"dm1":
			return f.has_mode(1, 0)
		"harm":
			return f.has_mode(0, 1)
		"damp":
			return f.has_growing()
		"dtl":
			return f.has_t_mode(maxi(1, k))
		"wave":
			return f.has_t()
		"lpf":
			return f.max_freq() > k
		"merge":
			return true
		"int":
			return not f.is_constant()
	return false


## Every living enemy in range, useful or not (what an attack algorithm gets to choose from).
func in_range(r: float) -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.alive and e.global_position.distance_to(global_position) <= r:
			out.append(e)
	return out


func candidates(r: float) -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.alive and e.global_position.distance_to(global_position) <= r and useful(e):
			out.append(e)
	return out


func pick_target(cands: Array):
	var best = null
	var best_score := -INF
	for e in cands:
		var sc: float
		match target_mode:
			0:
				sc = e.progress
			1:
				sc = e.threat + e.progress * 0.001
			_:
				sc = -e.global_position.distance_to(global_position)
		if sc > best_score:
			best_score = sc
			best = e
	return best


func _process(delta: float) -> void:
	t += delta
	flash = maxf(0.0, flash - delta)
	cooldown -= delta
	queue_redraw()
	if cooldown > 0.0:
		return
	var cands: Array = []
	var scripted := false
	if algo != "" and Progress.has("code"):
		var near := in_range(range_px())
		if near.is_empty():
			return
		if algo_host == null:
			algo_host = Algo.new(self)
		var res: Dictionary = algo_host.run(near)
		algo_error = res["error"]
		if res["ok"]:
			scripted = true
			cands = res["targets"]
			if cands.is_empty():
				cooldown = 0.12   # the algorithm chose to wait; ask again shortly
				return
	if not scripted:
		cands = candidates(range_px())
	if cands.is_empty():
		return
	if type == "merge":
		if not _do_merge(cands):
			return
		cooldown = 1.0 / rate()
		return
	cooldown = 1.0 / rate()
	if type == "damp" or type == "lpf":
		for e in cands:
			e.apply_op(type, op_params())
		main.spawn_ring(global_position, range_px(), data["color"])
		Sfx.play("pulse", 0.7 if type == "damp" else 1.5)
		flash = 0.2
		return
	var tg = cands[0] if scripted else pick_target(cands)
	aim = (tg.global_position - global_position).normalized()
	if type in ["sqrt", "log2", "newton", "bisect"]:
		main.spawn_zap(global_position, tg.global_position, data["color"])
		main.spawn_text(tg.global_position + Vector2(0, -32), glyph(), data["color"], 13)
		tg.apply_op(type, op_params())
		flash = 0.2
		return
	main.spawn_projectile(global_position + aim * 16.0, tg, type, op_params(), data["color"])


## Σ: add up to k functions in range into the leader (the one furthest along).
## With 「기저 정리」 it first looks for a linearly dependent subset and cancels it to 0.
func _do_merge(cands: Array) -> bool:
	if cands.size() < 2:
		return false
	var k := int(power())
	cands.sort_custom(func(a, b): return a.progress > b.progress)
	var pool: Array = cands.slice(0, k)
	if Progress.has("merge2"):
		var fs: Array = []
		for e in pool:
			fs.append(e.f)
		var dep: Array = Expr.dependent_set(fs)
		if dep.size() >= 2:
			var at: Vector2 = pool[dep[0]].global_position
			for i in dep:
				main.spawn_zap(global_position, pool[i].global_position, data["color"])
			main.spawn_text(at + Vector2(0, -34), "선형 종속 → 0", data["color"], 16)
			for i in dep:
				pool[i]._die()
			Sfx.play("pulse", 1.5)
			flash = 0.2
			return true
	var leader = pool[0]
	for i in range(1, pool.size()):
		var o = pool[i]
		main.spawn_zap(o.global_position, leader.global_position, data["color"])
		leader.absorb(o)
		if not leader.alive:
			break
	main.spawn_text(leader.global_position + Vector2(0, -34), "Σ", data["color"], 16)
	Sfx.play("pulse", 1.3)
	flash = 0.2
	return true


func describe() -> String:
	var lines: Array = [data["desc"], ""]
	match type:
		"sub":
			lines.append("연산: f → f − %d" % int(power()))
		"div":
			lines.append("연산: f → f / %d" % int(power()))
		"divx":
			lines.append("연산: f → f / x")
		"sqrt":
			lines.append("연산: n² → n")
		"log2":
			lines.append("연산: 2ⁿ → n")
		"diff":
			lines.append("연산: f → D%s f" % (Expr.sup(int(power())) if int(power()) > 1 else ""))
		"dm1":
			lines.append("연산: f → (D − 1)%s f" % (Expr.sup(int(power())) if int(power()) > 1 else ""))
		"harm":
			lines.append("연산: f → (D² + %d)%s f" % [omega * omega, Expr.sup(int(power())) if int(power()) > 1 else ""])
		"merge":
			lines.append("연산: 최대 %d개를 f₁ + f₂ + … 로 합침%s" % [int(power()), "  · 선형 종속이면 0으로 소거" if Progress.has("merge2") else ""])
		"damp":
			lines.append("연산: f → e⁻%sˣ · f  (μ → μ − %d)" % ["" if int(power()) == 1 else "²", int(power())])
		"dtl":
			lines.append("연산: f → (∂ₜ − %d) f" % lam)
		"wave":
			lines.append("연산: f → ∂ₜ²f − ∂ₓ²f")
		"lpf":
			lines.append("연산: 진동수 |ω| > %d 인 성분을 모두 제거" % int(power()))
		"newton":
			lines.append("연산: x → x − p(x)/p′(x)")
		"bisect":
			lines.append("연산: [a, b] → 부호가 바뀌는 절반")
		"int":
			lines.append("연산: f → ∫₀ˣ f,  수확 ×%.1f" % power())
	lines.append("속도: 초당 %.2f회   사거리: %.0f" % [rate(), range_px()])
	lines.append("투자액: %dρ" % spent)
	return "\n".join(PackedStringArray(lines))


func _exit_tree() -> void:
	if algo_host != null:
		algo_host.dispose()
		algo_host = null


func _draw() -> void:
	var c: Color = data["color"]
	var r := range_px()
	if main.selected_tower == self:
		draw_circle(Vector2.ZERO, r, Color(c, 0.07))
		draw_arc(Vector2.ZERO, r, 0, TAU, 72, Color(c, 0.55), 1.5, true)
	var s := 17.0
	draw_rect(Rect2(-s, -s, 2 * s, 2 * s), Color("0d1b2a"))
	draw_rect(Rect2(-s, -s, 2 * s, 2 * s), c.lerp(Color.WHITE, minf(1.0, flash * 2.0)), false, 2.0 + flash * 6.0)
	draw_line(aim * 18.0, aim * 23.0, c, 3.0)
	var g := glyph()
	var fs := 22 if g.length() <= 1 else (16 if g.length() <= 2 else (13 if g.length() <= 4 else 10))
	Data.draw_text_centered(self, g, Vector2(0, -2), fs, c)
	for i in level:
		draw_circle(Vector2(-6 + i * 6, 12), 1.8, c)
	if algo != "" and Progress.has("code"):
		Data.draw_text_centered(self, "</>", Vector2(12, -21), 9, Color("ef5350") if algo_error != "" else Color("80cbc4"))
