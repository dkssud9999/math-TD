extends RefCounted
## The test bot (autotest --budget). It plays like a player who reads the wave preview, solves the
## puzzle, and spends by value.
##
## 1. Solve: for each enemy it searches the cheapest sequence of its operators that kills it (or leaves
##    the least core damage), using the real operators (TowerScript.transform / op_useful):
##    1000 → ÷2 ÷2 ÷2 → 125 → −1 …;  e²ˣ → e⁻ˣ· → eˣ → log → x → ÷x → 1 → −1.
## 2. Model: the path is cut into STEP-px pieces. An enemy walks its solution along the path; at every
##    piece the towers of its current operator that cover the piece deliver rate × (time spent there)
##    hits (zeno: more time, accel: more rate). Towers shared by many enemies deliver proportionally
##    less. What is left at the core is the expected core damage of the wave.
## 3. Spend by value: every candidate (a tower at one of the best slots, an upgrade, zeno / accel)
##    is valued as the core damage it removes per ρ, over the next waves and the boss wave. The best
##    one is bought; if it is not affordable yet the bot SAVES for it, unless the wait would be long
##    and something almost as good is affordable now. Income is bought while the defence holds and
##    it pays back quickly.
## `--oldbot` plays with the old rule-of-thumb bot (main._autotest_spend) for comparison.

const TowerScript := preload("res://scripts/tower.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const OPS := ["sub", "div", "divx", "sqrt", "log2", "neg", "diff", "damp", "dtl", "wave"]
const MAX_NODES := 900
const STEP := 24.0              # px per path piece in the model
const SAMPLES := 2              # expressions sampled per enemy group
const WAVE_SECONDS := 35.0      # rough game seconds per wave, for income payback
const BUSY := 0.7               # share of a wave's window a tower can actually spend firing
const SLOTS_PER_TYPE := 3       # candidate slots evaluated per tower type
const ALMOST := 0.75            # buy an affordable option instead of saving if it is this good

var main
var rng := RandomNumberGenerator.new()   # the bot's own: sampling must not shift the game's random stream
var stalls: Array = []              # [harm weight, seq, k, piece]: where solutions stop progressing
var solve_cache: Dictionary = {}    # expr text -> solution
var wave_cache: Dictionary = {}     # wave index -> packets
var pts: Array = []                 # path piece centres
var cover_cache: Dictionary = {}    # "x,y,r" -> PackedInt32Array of pieces within r
var leaked_seen: int = 0
var leaks_recent: int = 0
var wave_seen: int = -1
var plan: Dictionary = {}           # the action being saved for
var plan_dirty: bool = true
var stuck_t: float = 0.0
var eff: float = 0.6                # the model's efficiency, calibrated on what really leaks
var margin: float = 1.0             # --perfect: plan as if towers did only this share (no leak allowed)
var stress: float = 1.0             # < 1 while looking for a safety margin
var predicted: float = 0.0          # expected damage of the wave in progress
var integrity_at: int = -1
var leak_mem: Dictionary = {}       # template -> {"f": what it looked like at the core, "n": how often}
var leak_cool: float = 0.0


func _init(p_main) -> void:
	main = p_main
	rng.seed = 12345 + int(OS.get_environment("BOT_SEED")) if OS.get_environment("BOT_SEED") != "" else 12345
	if main.autotest_perfect:
		margin = 0.75
	var d := STEP * 0.5
	while d < main.map.total_length:
		pts.append(main.map.point_at(d))
		d += STEP


var _frac: Dictionary = {}


## "dtl2" is the time tower set to λ = 2: a different operator for the model, the same tower to build.
func rt(t: String) -> String:
	return "dtl" if t == "dtl2" else t


func avail(t: String) -> bool:
	if t == "dtl2":
		return main.available_towers.has("dtl") and Progress.has("dtl2")
	return main.available_towers.has(t)


## 0..1: how far along the path a slot sits.
func frac(c: Vector2i) -> float:
	if not _frac.has(c):
		_frac[c] = main._slot_progress(c) / maxf(1.0, main.map.total_length)
	return _frac[c]


func ops() -> Array:
	var out: Array = []
	for t in OPS:
		if main.available_towers.has(t):
			out.append(t)
	return out


# ---------------- 1. solving one enemy ----------------

## Price of one hit of this operator, in ρ·s: a tower's cost over its base fire rate.
func hit_price(t: String) -> float:
	var d: Dictionary = Data.TOWERS[rt(t)]
	return float(d["cost"]) / float(d["rate"][0])


func _harm(f: Expr) -> int:
	if f.is_zero():
		return 0
	return EnemyScript.harm(f.value_at(Game.x_end, 0.0))


## Moves from f: [op, params, hits]. Subtraction is taken in useful chunks (to the next even number,
## square or power of two, or all the way to 0) so the search stays small.
func _moves(f: Expr, avail: Array) -> Array:
	var out: Array = []
	for t in avail:
		match t:
			"sub":
				var c: Array = f.const_term()
				if Expr.rz(c) or int(c[1]) != 1:
					if not Expr.rz(c):
						out.append(["sub", {"k": 1}, 1])
					continue
				var v := absi(int(c[0]))
				var steps := {v: true, 1: true}
				if f.is_constant() and v > 2:
					var s := int(floor(sqrt(float(v))))
					if s * s < v and v - s * s <= 64 and main.available_towers.has("sqrt"):
						steps[v - s * s] = true
					var p := 1
					while p * 2 <= v and p < (1 << 61):
						p *= 2
					if p < v and v - p <= 64 and main.available_towers.has("log2"):
						steps[v - p] = true
				for d in steps:
					if int(d) > 0 and int(d) <= v and (int(d) <= 400 or int(d) == v):
						out.append(["sub", {"k": int(d)}, int(d)])
			"div":
				if TowerScript.op_useful("div", f, 2):
					out.append(["div", {"k": 2}, 1])
			"dtl":
				for lam in ([1, 2] if Progress.has("dtl2") else [1]):
					if f.has_t_mode(lam):
						out.append(["dtl" if lam == 1 else "dtl2", {"k": 1, "n": 1, "lam": lam}, 1])
			_:
				if TowerScript.op_useful(t, f, 1):
					out.append([t, {"k": 1, "n": 1, "mult": 1.0, "w": 1, "lam": 1}, 1])
	return out


## Cheapest operator sequence that kills f; else the one that leaves the least core damage.
## Returns {"seq": [[type, hits, harm after this step]…], "harm0": harm untouched, "dead": bool}.
func solve(f0: Expr) -> Dictionary:
	var key := f0.to_text()
	if solve_cache.has(key):
		return solve_cache[key]
	var avail := ops()
	var open: Array = [[0.0, f0.clone(), []]]
	var seen := {key: 0.0}
	var best = null
	var best_score := INF
	var expanded := 0
	while not open.is_empty() and expanded < MAX_NODES:
		var bi := 0
		for i in open.size():
			if open[i][0] < open[bi][0]:
				bi = i
		var node: Array = open[bi]
		open.remove_at(bi)
		expanded += 1
		var f: Expr = node[1]
		var dead := f.is_zero()
		var score: float = (0.0 if dead else 1e6 * (1 + _harm(f))) + float(node[0])
		if score < best_score:
			best_score = score
			best = node
		if dead:
			break
		for mv in _moves(f, avail):
			var g: Expr = f.clone()
			Expr.overflow = false
			var ok: bool = TowerScript.transform(rt(mv[0]), g, mv[1])
			if Expr.overflow:
				Expr.overflow = false
				continue
			if not ok:
				continue
			var cost: float = float(node[0]) + hit_price(rt(mv[0])) * float(mv[2])
			var k2 := g.to_text()
			if seen.has(k2) and float(seen[k2]) <= cost:
				continue
			seen[k2] = cost
			var seq: Array = node[2].duplicate()
			seq.append([mv[0], int(mv[2]), _harm(g)])
			open.append([cost, g, seq])
	var out := {"seq": [], "harm0": _harm(f0), "dead": false}
	if best != null:
		out["dead"] = best[1].is_zero()
		out["seq"] = best[2]
	solve_cache[key] = out
	return out


# ---------------- 2. the wave model ----------------

## A wave as packets: [{n, speed, seqs: [solution…], kind, window}]; window = seconds the wave lasts.
func packets(w: int) -> Array:
	if wave_cache.has(w):
		return wave_cache[w]
	var out: Array = []
	if w < 0 or w >= main.waves.size():
		return out
	var span := 0.0
	for g in main.waves[w]:
		span += float(g[1]) * float(g[2]) + 2.0
	for g in main.waves[w]:
		var tpl: String = g[0]
		var td: Dictionary = Data.TEMPLATES[tpl]
		if td.get("special", "") != "" or Data.COUNTERS.has(tpl):
			continue
		var sols: Array = []
		for s in SAMPLES:
			sols.append(solve(Data.make_expr(tpl, rng, w + 1)))
		var v := float(td.get("speed", 60)) * 1.2
		# what the towers really turn this enemy into (it leaked like this before): the rest of the path
		# must handle that form too. A player learns it the same way: "−eˣ keeps getting through".
		if leak_mem.has(tpl):
			var lm: Dictionary = leak_mem[tpl]
			out.append({"tpl": tpl + "*", "n": float(g[1]) * minf(1.0, float(lm["n"]) / 3.0), "speed": v,
				"sols": [solve(lm["f"])], "kind": td.get("kind", ""), "start": int(pts.size() * 0.45),
				"window": span + 300.0 / v, "boss": td.get("boss", false)})
		out.append({"tpl": tpl, "n": float(g[1]), "speed": v, "sols": sols, "kind": td.get("kind", ""),
			"window": span + 300.0 / v, "boss": td.get("boss", false)})
	wave_cache[w] = out
	return out


func cover(pos: Vector2, r: float) -> PackedInt32Array:
	var key := "%d,%d,%d" % [int(pos.x), int(pos.y), int(r)]
	if cover_cache.has(key):
		return cover_cache[key]
	var out := PackedInt32Array()
	for i in pts.size():
		if pts[i].distance_to(pos) <= r:
			out.append(i)
	cover_cache[key] = out
	return out


## A tower's hits per second for the model (subtraction counts k per hit, d²/dx² two derivatives).
func unit(t: String, lvl: int) -> float:
	var d: Dictionary = Data.TOWERS[rt(t)]
	var r := float(d["rate"][lvl - 1]) * Data.research_mult("rate", t)
	if t == "sub":
		r *= float(d["power"][lvl - 1]) * (1.3 if Progress.has("drill") else 1.0)
	if t == "diff" and lvl == 3:
		r *= 3.0 if Progress.has("d3") else (2.0 if Progress.has("d2") else 1.0)
	return r


func trange(t: String, lvl: int) -> float:
	return float(Data.TOWERS[rt(t)]["range"][lvl - 1]) * Data.research_mult("range", t)


## The defence as the model sees it: [{type, pos, lvl}] → supply per operator per piece, slow per piece.
func field(towers: Array) -> Dictionary:
	var n := pts.size()
	var slow := PackedFloat32Array()
	slow.resize(n)
	slow.fill(1.0)
	var hastes: Array = []
	for tw in towers:
		if tw["type"] == "zeno":
			var p := float(Data.TOWERS["zeno"]["power"][tw["lvl"] - 1])
			for i in cover(tw["pos"], trange("zeno", tw["lvl"])):
				slow[i] = minf(slow[i], p)
		elif tw["type"] == "accel":
			hastes.append(tw)
	var sup := {}
	var caps := {}
	for tw in towers:
		var t: String = tw["type"]
		if not OPS.has(t) and t != "dtl2":
			continue
		var r := unit(rt(t), tw["lvl"])
		var h := 1.0
		for a in hastes:
			if a["pos"].distance_to(tw["pos"]) <= trange("accel", a["lvl"]):
				h = maxf(h, float(Data.TOWERS["accel"]["power"][a["lvl"] - 1]))
		if not sup.has(t):
			var z := PackedFloat32Array()
			z.resize(n)
			sup[t] = z
		caps[t] = float(caps.get(t, 0.0)) + r * h * eff * stress * margin
		var arr: PackedFloat32Array = sup[t]
		for i in cover(tw["pos"], trange(rt(t), tw["lvl"])):
			arr[i] += r * h * eff * stress * margin
		sup[t] = arr
	return {"sup": sup, "slow": slow, "cap": caps}


## Expected core damage of wave w against this field; fills want[type][piece] with unmet demand.
func wave_harm(w: int, fd: Dictionary, want: Dictionary, record: bool = false) -> float:
	var pk := packets(w)
	if pk.is_empty():
		return 0.0
	var sup: Dictionary = fd["sup"]
	var slow: PackedFloat32Array = fd["slow"]
	var share := {}
	var total := 0.0
	for pass_i in 2:
		var used := {}
		total = 0.0
		for p in pk:
			var sw: float = float(p["n"]) / float(p["sols"].size())
			for sol in p["sols"]:
				var seq: Array = sol["seq"]
				var k := 0
				var last_i := 0
				var i0: int = int(p.get("start", 0))
				var left: float = float(seq[0][1]) if not seq.is_empty() else 0.0
				for i in range(i0, pts.size()):
					if k >= seq.size():
						break
					var t: String = seq[k][0]
					var dt: float = STEP / (float(p["speed"]) * slow[i])
					var s := 0.0
					if sup.has(t):
						s = sup[t][i] * dt * float(share.get(t, 1.0))
					if s <= 0.0:
						if pass_i == 1:
							if not want.has(t):
								var z := PackedFloat32Array()
								z.resize(pts.size())
								want[t] = z
							var wa: PackedFloat32Array = want[t]
							wa[i] += sw * dt
							want[t] = wa
						continue
					last_i = i
					var take := minf(s, left)
					used[t] = float(used.get(t, 0.0)) + take * sw
					left -= take
					if left <= 1e-6:
						k += 1
						if k < seq.size():
							left = float(seq[k][1])
				var h: float = float(sol["harm0"])
				if k > 0:
					h = float(seq[k - 1][2])
				if k >= seq.size() and sol["dead"]:
					h = 0.0
				elif k < seq.size() and seq.size() > 0:
					# partial credit: how far along its solution it got (smooth, so every useful tower counts)
					var need := maxf(1.0, float(seq[k][1]))
					var progress := (k + (need - left) / need) / float(seq.size())
					h = 0.5 * h + 0.5 * float(sol["harm0"]) * (1.0 - progress)
				if pass_i == 1 and record and k < seq.size() and h > 0.0:
					stalls.append([h * sw, seq, k, last_i])
				total += h * sw * (3.0 if p["boss"] else 1.0)
				if pass_i == 1 and record and OS.get_environment("BOTDBG") == "2":
					print("   [pk] w%d %s k=%d/%d h=%.1f x%.1f" % [w, p["tpl"], k, seq.size(), h, sw])
		if pass_i == 0:
			# towers shared by many enemies: no operator can deliver more than its capacity over the wave
			var win: float = float(pk[0]["window"])
			for t in used:
				var cap: float = maxf(float(fd["cap"].get(t, 0.0)), 0.01) * win * BUSY
				share[t] = minf(1.0, cap / maxf(0.001, float(used[t])))
	return total


## Expected damage over the waves that matter now: the next two, and the boss wave (always kept in view).
func outlook(towers: Array, want: Dictionary) -> float:
	var fd := field(towers)
	var w: int = Game.wave
	var rec := not want.is_empty() or want.has("__rec")
	want.erase("__rec")
	var h := wave_harm(w, fd, want, rec) + 0.6 * wave_harm(w + 1, fd, {}, rec)
	var last: int = main.waves.size() - 1
	if last > w + 1:
		h += 0.4 * wave_harm(last, fd, {}, rec)
	return h


# ---------------- 3. spending ----------------

func current() -> Array:
	var out: Array = []
	for tw in main.occupied.values():
		out.append({"type": "dtl2" if tw.type == "dtl" and tw.lam == 2 else tw.type, "pos": tw.position, "lvl": tw.level, "ref": tw})
	return out


func owned(t: String) -> int:
	var n := 0
	for tw in main.occupied.values():
		var tt: String = "dtl2" if tw.type == "dtl" and tw.lam == 2 else tw.type
		if tt == t or (t == "dtl" and tw.type == "dtl"):
			n += 1
	return n


func free_slots() -> Array:
	var out: Array = []
	for c in main.autotest_slots:
		if not main.occupied.has(c):
			out.append(c)
	return out


## Every action worth evaluating: [{kind, type, slot|tower, cost}].
func candidates(want: Dictionary) -> Array:
	var out: Array = []
	var free := free_slots()
	var types: Array = []
	for t in want:
		if avail(t):
			types.append(t)
	for t in OPS:
		if owned(t) > 0 and not types.has(t) and avail(t):
			types.append(t)
	for t in types:
		# slots that cover the most unmet demand of t (and towers of t that would gain most from a level)
		var r := trange(rt(t), 1)
		var ranked: Array = []
		for c in free:
			var sc := 0.0
			if want.has(t):
				for i in cover(Data.cell_center(c), r):
					sc += want[t][i]
			ranked.append([sc, c])
		ranked.sort_custom(func(a, b): return a[0] > b[0])
		for j in mini(SLOTS_PER_TYPE, ranked.size()):
			if float(ranked[j][0]) > 0.0:
				out.append({"kind": "build", "type": t, "slot": ranked[j][1], "cost": int(Data.TOWERS[rt(t)]["cost"])})
		var best_up = null
		var best_sc := -1.0
		for tw in main.occupied.values():
			var twt: String = "dtl2" if tw.type == "dtl" and tw.lam == 2 else tw.type
			if twt == t and tw.level < 3:
				var sc2 := 0.0
				if want.has(t):
					for i in cover(tw.position, trange(rt(t), tw.level)):
						sc2 += want[t][i]
				sc2 += 0.001 * tw.level
				if sc2 > best_sc:
					best_sc = sc2
					best_up = tw
		if best_up != null:
			out.append({"kind": "up", "type": t, "tower": best_up, "cost": best_up.upgrade_cost()})
	# bundles: where a solution stops progressing, one more tower is often worth nothing alone (÷x after a
	# log that sits at the very end, D → D → log → ÷x → −1 with no D). Value the rest of the chain together,
	# laid out in order on the path after the point where it stopped.
	stalls.sort_custom(func(a, b): return a[0] > b[0])
	var seen_b := {}
	for st in stalls.slice(0, 8):
		var seq: Array = st[1]
		var k: int = st[2]
		var start := float(st[3]) / maxf(1.0, pts.size())
		if k == 0:
			start = 0.0
		var rest: Array = []
		for i in range(k, seq.size()):
			if avail(seq[i][0]) and not rest.has(seq[i][0]):
				rest.append(seq[i][0])
		if rest.size() < 2 or rest.size() > 5:
			continue
		var key := ",".join(PackedStringArray(rest)) + "@%d" % int(start * 5)
		if seen_b.has(key):
			continue
		seen_b[key] = true
		var items: Array = []
		var cost := 0
		var taken := {}
		for j in rest.size():
			var f := start + (0.95 - start) * (j + 0.5) / float(rest.size())
			var c2 = _slot_near(f, trange(rt(rest[j]), 1), taken)
			if c2 == null:
				break
			taken[c2] = true
			items.append({"type": rest[j], "slot": c2})
			cost += int(Data.TOWERS[rt(rest[j])]["cost"])
		if items.size() == rest.size():
			out.append({"kind": "bundle", "type": key, "items": items, "cost": cost})
	# zeno / accel where the most towers stand
	for s in ["zeno", "accel"]:
		if not main.available_towers.has(s) or main.occupied.size() < 4:
			continue
		var ranked2: Array = []
		for c in free:
			var p: Vector2 = Data.cell_center(c)
			var sc3 := 0.0
			for tw in main.occupied.values():
				if OPS.has(tw.type) and tw.position.distance_to(p) <= trange(s, 1) + (40.0 if s == "zeno" else 0.0):
					sc3 += unit(tw.type, tw.level)
			ranked2.append([sc3, c])
		ranked2.sort_custom(func(a, b): return a[0] > b[0])
		for j in mini(2, ranked2.size()):
			out.append({"kind": "build", "type": s, "slot": ranked2[j][1], "cost": int(Data.TOWERS[rt(s)]["cost"])})
	return out


func _slot_near(frac: float, r: float, taken: Dictionary):
	var best = null
	var best_s := -INF
	for c in free_slots():
		if taken.has(c):
			continue
		var f: float = frac(c)
		var s := -absf(f - frac) * 60.0 + cover(Data.cell_center(c), r).size() * 0.3
		if s > best_s:
			best_s = s
			best = c
	return best


func _with(base: Array, a: Dictionary) -> Array:
	var out: Array = base.duplicate()
	if a["kind"] == "bundle":
		for it in a["items"]:
			out.append({"type": it["type"], "pos": Data.cell_center(it["slot"]), "lvl": 1})
	elif a["kind"] == "build":
		out.append({"type": a["type"], "pos": Data.cell_center(a["slot"]), "lvl": 1})
	else:
		for i in out.size():
			if out[i].get("ref") == a["tower"]:
				var e: Dictionary = out[i].duplicate()
				e["lvl"] = int(e["lvl"]) + 1
				out[i] = e
	return out


## Values every candidate; returns [best, best_affordable, base_harm] (best: {action…, value}).
var eval_us: int = 0
var eval_n: int = 0


func evaluate() -> Array:
	var t0 := Time.get_ticks_usec()
	var r := _evaluate()
	eval_us += Time.get_ticks_usec() - t0
	eval_n += 1
	return r


func _evaluate() -> Array:
	var base := current()
	var want := {"__rec": true}
	stalls.clear()
	var h0 := outlook(base, want)
	var best = null
	var best_aff = null
	var cands := candidates(want)
	var dbg: Array = []
	for a in cands:
		var h := outlook(_with(base, a), {})
		var v := (h0 - h) / float(maxi(1, int(a["cost"])))
		if main.autotest_verbose and OS.get_environment("BOTDBG") != "":
			dbg.append("%s %s %.1f" % [a["kind"], a["type"], h])
		if v <= 0.0:
			continue
		a["value"] = v
		if best == null or v > float(best["value"]):
			best = a
		if Game.rho >= int(a["cost"]) and (best_aff == null or v > float(best_aff["value"])):
			best_aff = a
	if not dbg.is_empty():
		print("[dbg] h0=%.1f want=%s cands: %s" % [h0, str(want.keys()), "; ".join(PackedStringArray(dbg))])
	# Σ: what no operator chain kills (trig pairs under the curse) needs D + Σ teamwork
	var sig = _merge_action(h0)
	if sig != null:
		if best == null or float(sig["value"]) > float(best["value"]):
			best = sig
		if Game.rho >= int(sig["cost"]) and (best_aff == null or float(sig["value"]) > float(best_aff["value"])):
			best_aff = sig
	return [best, best_aff, h0]


func _merge_action(h0: float):
	if not main.available_towers.has("merge"):
		return null
	var unsolved := 0.0
	var total := 0.0
	for p in packets(Game.wave):
		total += float(p["n"])
		for sol in p["sols"]:
			if not sol["dead"]:
				unsolved += float(p["n"]) / float(p["sols"].size())
	var nm := owned("merge")
	var v := 0.0
	var kind := "merge"
	if unsolved > 0.0:
		v = minf(h0, unsolved) * 0.6 / (1.0 + nm)
		# the teamwork is a kit: D turns cos into −sin (and sin into cos), Σ adds the pair to 0
		if main.available_towers.has("diff") and owned("diff") <= nm:
			kind = "diff"
	elif not Data.cursed() and total >= 18.0 and nm < 3:
		v = h0 * 0.15 / (1.0 + nm)   # like terms: one kill for many
	if v <= 0.0:
		return null
	var cost := int(Data.TOWERS[rt(kind)]["cost"])
	var free := free_slots()
	if free.is_empty():
		return null
	# Σ goes in the middle of the path, near the D towers
	var best_c = free[0]
	var best_s := -INF
	for c in free:
		var p: Vector2 = Data.cell_center(c)
		var s := -absf(frac(c) - (0.45 if kind == "diff" else 0.5)) * 100.0
		for tw in main.occupied.values():
			if tw.type == ("merge" if kind == "diff" else "diff") and tw.position.distance_to(p) <= 140.0:
				s += 10.0
		if s > best_s:
			best_s = s
			best_c = c
	return {"kind": "build", "type": kind, "slot": best_c, "cost": cost, "value": v / float(cost)}


func spend() -> void:
	leak_cool -= 0.5
	if Game.leaked > leaked_seen and leak_cool <= 0.0:
		leaks_recent += Game.leaked - leaked_seen
		leaked_seen = Game.leaked
		plan_dirty = true
		leak_cool = 3.0
	if Game.wave != wave_seen:
		wave_seen = Game.wave
		leaks_recent = int(leaks_recent / 2)
		plan_dirty = true
		_calibrate()
		if main.autotest_verbose:
			print("[bot] " + describe())
	_unstick()
	_ultimate()
	var guard := 0
	while guard < 12:
		guard += 1
		# re-plan only when something changed: a new wave, a leak, or the money for the plan is there
		if not plan_dirty and not plan.is_empty() and Game.rho < int(plan["cost"]):
			return
		plan_dirty = false
		var ev := evaluate()
		var best = ev[0]
		var aff = ev[1]
		var h0: float = ev[2]
		# income while the defence holds and it pays back fast
		if _income(h0, best):
			plan_dirty = true
			continue
		if best == null and stress >= 1.0 and Game.rho >= 250:
			# nothing helps by the model: buy a safety margin as if towers did half as well
			stress = 0.5
			ev = evaluate()
			stress = 1.0
			best = ev[0]
			aff = ev[1]
			if best != null and Game.rho < int(best["cost"]) and aff == null:
				best = null
		if best == null and Game.rho >= 600:
			best = _fallback()
			if best != null:
				_do(best)
				plan_dirty = true
				continue
		if best == null:
			plan = {"kind": "wait", "type": "", "cost": Game.rho + 100}   # look again when there is more money
			return
		if Game.rho >= int(best["cost"]):
			_do(best)
			plan_dirty = true
			continue
		# save for the best, unless the wait is long and something almost as good is affordable now
		var wait := (int(best["cost"]) - Game.rho) / maxf(1.0, float(Game.rho_rate()))
		if aff != null and (float(aff["value"]) >= ALMOST * float(best["value"]) or wait > WAVE_SECONDS * 0.8):
			_do(aff)
			plan_dirty = true
			continue
		plan = best
		if main.autotest_verbose and guard == 1:
			print("[save] w%d for %s %s (%dρ, have %d)" % [Game.wave, best["kind"], best["type"], int(best["cost"]), Game.rho])
		return


## After each wave: did more leak than the model expected? Then towers do less than it thinks.
func _calibrate() -> void:
	if integrity_at >= 0:
		var seen := float(integrity_at - Game.integrity)
		if seen > predicted + 1.0:
			eff = maxf(0.35, eff * sqrt((predicted + 1.0) / (seen + 1.0)))
		elif seen <= 0.0:
			eff = minf(1.0, eff * 1.08)
	integrity_at = Game.integrity
	var want := {}
	predicted = wave_harm(Game.wave, field(current()), want) if Game.wave < main.waves.size() else 0.0


## Money piles up and the model sees nothing: thicken the operator with the most unmet demand.
func _fallback():
	var want := {}
	outlook(current(), want)
	var bt := ""
	var bw := 0.0
	for t in want:
		if not avail(t) or Game.rho < int(Data.TOWERS[rt(t)]["cost"]):
			continue
		var tot := 0.0
		for v in want[t]:
			tot += v
		if tot > bw:
			bw = tot
			bt = t
	if bt == "":
		return null
	var best_c = null
	var best_s := 0.0
	for c in free_slots():
		var sc := 0.0
		for i in cover(Data.cell_center(c), trange(rt(bt), 1)):
			sc += want[bt][i]
		if sc > best_s:
			best_s = sc
			best_c = c
	if best_c == null:
		return null
	return {"kind": "build", "type": bt, "slot": best_c, "cost": int(Data.TOWERS[rt(bt)]["cost"]), "value": 0.0}


func _income(h0: float, best) -> bool:
	var t_left := maxf(0.0, (Data.WAVES_PER_STAGE - Game.wave) * WAVE_SECONDS)
	var safe := h0 < maxf(1.0, Game.integrity * 0.1)
	var limit := 0.4 if safe else 0.12
	if Game.c2_unlocked() and Game.rho >= Game.c2_cost() and Game.c2_cost() < Game.rho_rate() * t_left * limit:
		_log("c2")
		return Game.buy_c2()
	if Game.rho >= Game.c1_cost() and Game.c1_cost() < Game.c2() * t_left * limit:
		_log("c1")
		return Game.buy_c1()
	return false


func _do(a: Dictionary) -> void:
	plan = {}
	if a["kind"] == "bundle":
		for it in a["items"]:
			_do({"kind": "build", "type": it["type"], "slot": it["slot"], "value": a["value"]})
		return
	if a["kind"] == "up":
		_log("up %s→%d (v=%.4f)" % [a["type"], a["tower"].level + 1, float(a["value"])])
		main.selected_tower = a["tower"]
		main.upgrade_selected()
		return
	main.build_type = rt(a["type"])
	main.try_build(a["slot"])
	main.autotest_n += 1
	if main.occupied.has(a["slot"]):
		var tw = main.occupied[a["slot"]]
		if rt(a["type"]) == "dtl":
			tw.lam = 2 if a["type"] == "dtl2" else 1
	_log("build %s @%.2f (v=%.4f)" % [a["type"], frac(a["slot"]), float(a["value"])])


## The last wave can stall on harmless stragglers that zeno and springs keep holding back: a player would
## sell those towers so the stage can end.
func _unstick() -> void:
	if not (main.state == "wave" and main.wave_manager.finished() and Game.wave >= main.waves.size()):
		stuck_t = 0.0
		return
	stuck_t += main.get_process_delta_time()
	if stuck_t < 30.0:
		return
	for e in main.get_tree().get_nodes_in_group("enemies"):
		if e.alive and EnemyScript.harm(e.f.value_at(Game.x_end, e.tt)) > 0:
			return
	for c in main.occupied.keys():
		if main.occupied[c].type in ["spring", "zeno"]:
			main.selected_tower = main.occupied[c]
			main.sell_selected()
			_log("sell (stragglers)")
	stuck_t = 0.0


## An enemy reached the core: remember the form it arrived in (the latest one per template).
func on_leak(e) -> void:
	if e.special != "" or Data.COUNTERS.has(e.template):
		return
	var lm: Dictionary = leak_mem.get(e.template, {"n": 0})
	lm["f"] = e.f.clone()
	lm["n"] = int(lm["n"]) + 1
	leak_mem[e.template] = lm
	wave_cache.clear()
	plan_dirty = true


## x = 0 (twice a stage from chapter 2): every function on the field collapses to its constant term.
## Used like a player would: when the field could break the core, when it saves a large share of what is
## left, or on the last wave so it is not wasted.
func _ultimate() -> void:
	if Game.ult_left <= 0 or main.state != "wave":
		return
	var now := 0.0
	var gain := 0.0
	for e in main.get_tree().get_nodes_in_group("enemies"):
		if not e.alive or e.special != "" or Data.COUNTERS.has(e.template):
			continue
		var h := float(EnemyScript.harm(e.f.value_at(Game.x_end, e.tt)))
		now += h
		if not e.f.is_constant():
			var g: Expr = e.f.clone()
			g.subst_x0()
			gain += h - float(_harm_t(g, e.tt))
	if gain <= 0.0:
		return
	var last: bool = Game.wave >= main.waves.size() and main.wave_manager.finished()
	if now >= Game.integrity or gain >= maxf(3.0, Game.integrity * 0.4) or (last and gain >= 1.0):
		main.use_ultimate()
		_log("x=0 (field damage %d, saves %d)" % [int(now), int(gain)])


func _harm_t(f: Expr, tt: float) -> int:
	if f.is_zero():
		return 0
	return EnemyScript.harm(f.value_at(Game.x_end, tt))


func _log(what: String) -> void:
	if main.autotest_verbose:
		print("[buy] w%d %s  (rho %d)" % [Game.wave, what, Game.rho])


func describe() -> String:
	var want := {}
	var h := outlook(current(), want)
	var types: Array = []
	for t in want:
		types.append(t)
	return "wave %d: expected damage %.1f (integrity %d), eff %.2f, short of %s, rho %d, rate %d, towers %d" % [Game.wave + 1, h, Game.integrity, eff, str(types), Game.rho, Game.rho_rate(), main.occupied.size()]
