extends RefCounted
## Enemies built from their own solution. A recipe is the KILL, in order (what the towers do, first to
## last); the enemy is made by undoing it backwards from 0, so it is killable by construction and the
## recipe is a known answer (tests/test_recipe.gd replays every recipe forward to exactly 0).
##
## Steps (forward = what the tower does · build = its inverse):
##   ["sub", k]          −k (k hits of −1)            · +k on the constant term (away from 0)
##   ["div", n]          ÷2, n times                   · ×2ⁿ
##   ["divx", n]         ÷x, n times                   · ×xⁿ
##   ["sqrt", n]         √ (perfect squares), n times  · squaring
##   ["log2", n]         2ᵐ → m, n times (numbers)     · m → 2ᵐ
##   ["log"]             c·eᵃˣ → ax (natural log)      · ax → eᵃˣ  (the rest must be exactly a·x)
##   ["diff", n, c]      D, n times                    · ∫₀ˣ then + c, n times (c: constant of integration;
##                                                       a list gives one per integration, in BUILD order)
##   ["damp", n]         e⁻ˣ·, n times                 · ×eˣ, n times
##   ["neg"]             −f                            · −g
## Example (the 6장 boss 4x⁴ + x⁴e³ˣ + x⁵e²ˣ):
##   [["divx", 4], ["sub", 4], ["damp", 2], ["diff", 2, [2, 1]], ["log"], ["divx", 1], ["sub", 1]]
##   built: 0 → 1 → x → eˣ → eˣ + 1 → eˣ + x → e³ˣ + xe²ˣ → + 4 → ×x⁴

const TowerScript := preload("res://scripts/tower.gd")


static func build(steps: Array) -> Expr:
	var f := Expr.new()
	for i in range(steps.size() - 1, -1, -1):
		f = _undo(steps[i], f)
	return f


static func _n(st: Array, i: int, d) -> Variant:
	return st[i] if st.size() > i else d


static func _undo(st: Array, g: Expr) -> Expr:
	var f := g.clone()
	match String(st[0]):
		"sub":
			var c: Array = f.const_term()
			var k := int(st[1])
			f.add_expr(Expr.poly([k if Expr.rf(c) >= 0.0 else -k]))   # moving toward 0 forward = away from 0 back
		"div":
			f.scale(1 << int(_n(st, 1, 1)), 1)
		"divx":
			f = f.times_x(int(_n(st, 1, 1)))
		"sqrt":
			for i in int(_n(st, 1, 1)):
				f = mul(f, f)
		"log2":
			for i in int(_n(st, 1, 1)):
				f = Expr.poly([1 << int(round(Expr.rf(f.const_term())))])
		"log":
			# g must be a·x exactly: undo gives e^{ax}
			var z = f.t.get(Expr.K(1), null)
			var a := int(round(Expr.rf(z[0]))) if z != null else 1
			f = Expr.new().add_exp(1, 0, a)
		"diff":
			var cs = _n(st, 2, 0)
			for i in int(_n(st, 1, 1)):
				f.integrate()
				var c := int(cs[i]) if cs is Array else int(cs)
				if c != 0:
					f.add_expr(Expr.poly([c]))
		"damp":
			f.shift(int(_n(st, 1, 1)))
		"neg":
			f.scale(-1, 1)
	return f


## Product of two exponential polynomials: the term keys [xᵏ, eᵃˣ, e^{ibx}, tʲ, e^{gt}] add, coefficients multiply.
static func mul(f: Expr, g: Expr) -> Expr:
	var out := Expr.new()
	for k1: Array in f.t:
		for k2: Array in g.t:
			var key := Expr.K(int(k1[0]) + int(k2[0]), int(k1[1]) + int(k2[1]), int(k1[2]) + int(k2[2]), int(k1[3]) + int(k2[3]), int(k1[4]) + int(k2[4]))
			out._add(key, Expr.cmul(f.t[k1], g.t[k2]))
	return out


## Plays the recipe forward with the real operators. "" = it ends at exactly 0 and every step was a
## legal shot (the tower would fire and the operator changes f); otherwise what went wrong.
static func check(f0: Expr, steps: Array) -> String:
	var f := f0.clone()
	for idx in steps.size():
		var st: Array = steps[idx]
		var op := String(st[0])
		var reps := 1 if op in ["sub", "log", "neg"] else int(_n(st, 1, 1))
		for r in reps:
			var tower := op
			var p := {"k": 1, "n": 1, "mult": 1.0, "w": 1, "lam": 1}
			match op:
				"sub":
					p["k"] = int(st[1])
				"div":
					p["k"] = 2
				"log":
					tower = "log2"
			if not TowerScript.op_useful(tower, f, int(p["k"]) if op != "sub" else 1):
				return "step %d (%s) would not fire on %s" % [idx + 1, op, f.to_text()]
			Expr.overflow = false
			if not TowerScript.transform(tower, f, p):
				return "step %d (%s) does nothing to %s" % [idx + 1, op, f.to_text()]
			if Expr.overflow:
				Expr.overflow = false
				return "step %d (%s) overflows" % [idx + 1, op]
	return "" if f.is_zero() else "ends at %s, not 0" % f.to_text()


## Hits of level-1 towers the recipe takes (−k counts k).
static func hits(steps: Array) -> int:
	var n := 0
	for st in steps:
		match String(st[0]):
			"sub":
				n += int(st[1])
			"log", "neg":
				n += 1
			_:
				n += int(_n(st, 1, 1))
	return n
