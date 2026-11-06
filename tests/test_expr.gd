extends SceneTree
## Run: godot --headless --path . --script res://tests/test_expr.gd
## Verifies the operator algebra is real mathematics.

const E := preload("res://scripts/expr.gd")

var fails := 0
var checks := 0


func check(cond: bool, name: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		if fails < 25:
			print("FAIL: ", name)


func txt(f) -> String:
	return f.to_text()


func _init() -> void:
	# ---------- chapter 1: arithmetic ----------
	var f = E.poly([7])
	f.scale(1, 2)
	check(txt(f) == "7/2", "7 ÷ 2 = 7/2  got " + txt(f))
	f = E.poly([10000])
	check(f.is_perfect_square(), "10000 is a perfect square")
	f.sqrt_const()
	check(txt(f) == "100", "√10000 = 100")
	check(not E.poly([7]).is_perfect_square() and not E.poly([1]).is_perfect_square(), "7, 1: no √")
	f = E.poly([65536])
	var logs := 0
	while not f.is_zero() and logs < 10:
		f.log2_const()
		logs += 1
	check(logs == 5, "65536 → 16 → 4 → 2 → 1 → 0 takes 5 logs")
	check(E.poly([6]).divisible_by(2) and not E.poly([7]).divisible_by(2), "6 | 2, 7 ∤ 2")
	check(not E.poly([0, 1]).divisible_by(2), "x is not divisible: the chapter-1 counterexample")
	f = E.poly([2])
	f.sub_toward_zero(3)
	check(f.is_zero(), "2 − 3 clamps to 0")

	# ---------- chapter 2: algebra before calculus ----------
	f = E.poly([5, 2, 1])
	check(not f.divisible_by_x(), "x² + 2x + 5 is not divisible by x (constant 5)")
	f.sub_toward_zero(5)
	check(f.divisible_by_x(), "x² + 2x is divisible by x")
	f.div_x()
	check(txt(f) == "x + 2", "(x² + 2x) / x = x + 2  got " + txt(f))
	f = E.poly([0, 1])
	f.div_x()
	check(txt(f) == "1", "x / x = 1")
	f = E.new().add_exp(1, 1)
	f.div_x()
	check(txt(f) == "eˣ", "xeˣ / x = eˣ  got " + txt(f))

	f = E.poly([9, 6, 1])
	check(f.is_perfect_square(), "x² + 6x + 9 is a perfect square")
	f.sqrt_const()
	check(txt(f) == "x + 3", "√(x² + 6x + 9) = x + 3  got " + txt(f))
	f = E.poly([1, 0, 2, 0, 1])
	f.sqrt_const()
	check(txt(f) == "x² + 1", "√(x⁴ + 2x² + 1) = x² + 1  got " + txt(f))
	f = E.poly([0, 0, 0, 0, 1])
	f.sqrt_const()
	check(txt(f) == "x²", "√x⁴ = x²")
	check(not E.poly([1, 0, 1]).is_perfect_square(), "x² + 1 is not a perfect square")
	check(not E.poly([0, 0, 0, 1]).is_perfect_square(), "x³ (odd degree) is not")
	check(not E.poly([4, 0, 4]).is_perfect_square() and E.poly([4, 8, 4]).is_perfect_square(), "4x² + 4 no, 4x² + 8x + 4 = (2x + 2)² yes")
	var rr = E.new()
	for r in 200:
		var ga = E.poly([randi_range(-6, 6), randi_range(-4, 4), randi_range(1, 3)])
		var prod = E.new()
		var gc: Array = ga._poly_coeffs()
		var sq: Array = []
		for p in 5:
			var acc := [0, 1]
			for i in gc.size():
				var j: int = p - i
				if j >= 0 and j < gc.size():
					acc = E.radd(acc, E.rmul(gc[i], gc[j]))
			sq.append(int(acc[0]))
		prod = E.poly(sq)
		check(prod.is_perfect_square(), "g² is a perfect square for g = " + ga.to_text())
		prod.sqrt_const()
		var back = prod.clone()
		check(back.to_text() == ga.to_text() or back.to_text() == ("−" + ga.to_text()), "√(g²) = g for g = " + ga.to_text())

	# ---------- chapter 2: calculus ----------
	f = E.poly([7])
	f.derive()
	check(f.is_zero(), "D 7 = 0")
	f = E.poly([0, 0, 0, 1])
	var n := 0
	while not f.is_zero() and n < 10:
		f.derive()
		n += 1
	check(n == 4, "x³ needs exactly 4 derivatives")
	f = E.poly([0, 0, 0, 1])
	f.derive()
	check(txt(f) == "3x²", "D x³ = 3x²  got " + txt(f))
	check(txt(E.poly([4, 1, 0, 1])) == "x³ + x + 4", "label x³ + x + 4  got " + txt(E.poly([4, 1, 0, 1])))
	f = E.poly([0, 0, 1])
	f.integrate()
	check(txt(f) == "x³/3", "∫₀ˣ x² = x³/3  got " + txt(f))

	# ---------- chapter 2 counterexample & chapter 3: exponentials ----------
	f = E.new().add_exp(1)
	f.derive()
	check(txt(f) == "eˣ", "D eˣ = eˣ  got " + txt(f))
	f.integrate()
	check(txt(f) == "eˣ − 1", "∫₀ˣ eˢ = eˣ − 1  got " + txt(f))
	f = E.new().add_exp(8)
	f.apply_dl(1)
	check(f.is_zero(), "(D−1) 8eˣ = 0")
	f = E.new().add_exp(1, 2)
	check(txt(f) == "x²eˣ", "label x²eˣ  got " + txt(f))
	check(f.annihilator() == "(D−1)³", "Ann(x²eˣ) = (D−1)³  got " + f.annihilator())
	f.apply_dl(1)
	f.apply_dl(1)
	check(not f.is_zero(), "(D−1)² x²eˣ ≠ 0")
	f.apply_dl(1)
	check(f.is_zero(), "(D−1)³ x²eˣ = 0")
	f = E.poly([5])
	f.apply_dl(1)
	check(txt(f) == "−5", "(D−1) 5 = −5 (wrong operator only flips)  got " + txt(f))
	f = E.new().add_exp(1, 0, 2)
	f.derive()
	check(txt(f) == "2e²ˣ", "D e²ˣ = 2e²ˣ (wrong operator amplifies)  got " + txt(f))
	f = E.poly([2, 0, 1]).add_exp(3, 1)
	check(f.annihilator() == "D³(D−1)²", "Ann(x² + 3xeˣ + 2) = D³(D−1)²  got " + f.annihilator())
	check(f.ann_degree() == 5, "deg Ann = 5")

	# ---------- chapter 3 counterexample & chapter 4: oscillation ----------
	f = E.new().add_trig(0, 1)
	check(txt(f) == "sin x", "label sin x  got " + txt(f))
	var g = f.clone()
	for i in 4:
		g.derive()
	check(g.equals(f), "sin cycles back after 4 derivatives")
	g = f.clone()
	g.derive()
	check(txt(g) == "cos x", "D sin = cos  got " + txt(g))
	g = f.clone()
	g.apply_dl(1)
	check(not g.is_zero() and g.has_trig(), "(D−1) sin x ≠ 0: the chapter-3 counterexample")
	check(f.annihilator() == "(D²+1)", "Ann(sin x) = D²+1  got " + f.annihilator())
	f.apply_quad(0, 1)
	check(f.is_zero(), "(D²+1) sin x = 0")
	f = E.new().add_trig(0, 1, 1)
	check(txt(f) == "x sin x", "label x sin x  got " + txt(f))
	f.apply_quad(0, 1)
	check(not f.is_zero(), "(D²+1) x sin x ≠ 0")
	f.apply_quad(0, 1)
	check(f.is_zero(), "(D²+1)² x sin x = 0")
	f = E.new().add_trig(4, 4).add_expr(E.poly([3, 0, 1]))
	check(txt(f) == "x² + 4cos x + 4sin x + 3", "trig label  got " + txt(f))
	f = E.new().add_trig(0, 1, 0, 1)
	check(f.annihilator() == "(D²−2D+2)", "Ann(eˣ sin x) = D²−2D+2  got " + f.annihilator())
	f.apply_quad(1, 1)
	check(f.is_zero(), "(D²−2D+2) eˣ sin x = 0")
	f = E.new().add_trig(0, 1)
	f.collapse()
	check(f.is_zero(), "sin 0 = 0")

	# ---------- chapter 4-5: frequency, linearity, damping ----------
	f = E.new().add_trig(0, 1, 0, 0, 2)
	check(txt(f) == "sin 2x", "label sin 2x  got " + txt(f))
	check(f.annihilator() == "(D²+4)", "Ann(sin 2x) = D²+4  got " + f.annihilator())
	g = f.clone()
	g.apply_quad(0, 1)
	check(txt(g) == "−3sin 2x", "(D²+1) sin 2x = −3 sin 2x (wrong ω amplifies)  got " + txt(g))
	f.apply_quad(0, 2)
	check(f.is_zero(), "(D²+4) sin 2x = 0")
	f = E.new().add_exp(3)
	g = E.new().add_exp(-3)
	f.add_expr(g)
	check(f.is_zero(), "3eˣ + (−3eˣ) = 0 (cancellation)")
	f = E.new().add_trig(0, 3)
	for i in 99:
		f.add_expr(E.new().add_trig(0, 3))
	check(txt(f) == "300sin x" and f.annihilator() == "(D²+1)", "100 × 3 sin x = 300 sin x, Ann unchanged  got " + txt(f))
	f = E.new().add_exp(1, 0, 2)
	f.apply_dl(1)
	check(txt(f) == "e²ˣ", "(D−1) e²ˣ = e²ˣ: the chapter-5 counterexample  got " + txt(f))
	f.shift(-1)
	check(txt(f) == "eˣ", "e⁻ˣ · e²ˣ = eˣ  got " + txt(f))
	f.apply_dl(1)
	check(f.is_zero(), "then (D−1) kills it")
	f = E.new().add_trig(0, 1, 0, 1)
	f.shift(-1)
	check(txt(f) == "sin x", "e⁻ˣ · eˣ sin x = sin x  got " + txt(f))
	f = E.poly([5])
	f.shift(-1)
	check(txt(f) == "5e⁻ˣ" and not f.has_growing(), "e⁻ˣ · 5 = 5e⁻ˣ (decays: harmless at the core)  got " + txt(f))
	f = E.poly([0, 0, 0, 0, 1])
	var fam: Array = []
	var seed = f.clone()
	while true:
		seed.derive()
		if seed.is_zero():
			break
		fam.append(seed.to_text())
	check(fam.size() == 4, "x⁴ begets exactly 4 descendants (dim of cyclic subspace − 1)")
	var tribe = f.clone()
	for d in fam.size():
		var kid = f.clone()
		for j in d + 1:
			kid.derive()
		tribe.add_expr(kid)
	var ann_n := 0
	while not tribe.is_zero() and ann_n < 10:
		tribe.derive()
		ann_n += 1
	check(ann_n == 5, "merged family of x⁴ dies to Ann(x⁴) = D⁵")

	# ---------- chapter 7-8: time, waves, filters ----------
	f = E.poly([9, 1, 0, 3, 0, 1])
	var sep = E.new()
	for key in f.t:
		sep._add([key[0], key[1], key[2], 0, 2], f.t[key])
	check(sep.has_t() and sep.t_annihilator() == "(∂ₜ−2)", "(x⁵+3x³+x+9)e²ᵗ has Ann_t = ∂ₜ−2  got " + sep.t_annihilator())
	var s2 = sep.clone()
	s2.apply_dtl(2)
	check(s2.is_zero(), "(∂ₜ − 2) kills the separable boss in one hit")
	var xs = E.poly([5])
	xs.apply_dtl(2)
	check(txt(xs) == "−10", "(∂ₜ − 2) on a t-independent 5 gives −10 (trap)  got " + txt(xs))
	check(absf(sep.value_at(2.0, 1.0) - 67.0 * exp(2.0)) < 1e-6, "f(2, 1) = 67e²")
	var wave = E.new().add_term(1, 3, 0, 0, 0).add_term(-3, 2, 0, 1, 0).add_term(3, 1, 0, 2, 0).add_term(-1, 0, 0, 3, 0)
	wave.add_term(1, 0, 1, 0, 1)
	check(txt(wave).contains("x³") and txt(wave).contains("eˣeᵗ"), "label (x−t)³ + e^{x+t}  got " + txt(wave))
	var w2 = wave.clone()
	w2.apply_wave()
	check(w2.is_zero(), "□[(x−t)³ + e^{x+t}] = 0 (d'Alembert)")
	var w3 = wave.clone()
	w3.add_expr(E.new().add_exp(7))
	w3.apply_wave()
	check(not w3.is_zero() and txt(w3) == "−7eˣ", "□ leaves the non-wave part: □(7eˣ) = −7eˣ  got " + txt(w3))
	var sq = E.new()
	for nn in [1, 3, 5, 7, 9, 11, 13, 15]:
		sq.add_trig_q([0, 1], E.rn(4, nn), 0, 0, nn)
	check(sq.max_freq() == 15, "square-wave partial sum has 8 frequencies up to 15")
	var lp = sq.clone()
	lp.lowpass(1)
	check(txt(lp) == "4sin x", "low-pass (cutoff 1) keeps only 4 sin x  got " + txt(lp))
	lp.apply_quad(0, 1)
	check(lp.is_zero(), "then D² + 1 finishes it")

	# ---------- the limited ultimate: substitute x = 0 ----------
	f = E.poly([4, 1, 0, 1]).add_exp(2).add_trig(3, 5)
	f.subst_x0()
	check(txt(f) == "9", "x³ + x + 4 + 2eˣ + 3cos x + 5sin x at x = 0 is 9  got " + txt(f))
	f = E.poly([2, 1]).times_t(0, 1)
	f.subst_x0()
	check(txt(f) == "2eᵗ", "(x + 2)eᵗ at x = 0 is 2eᵗ  got " + txt(f))

	# ---------- operator algebra ----------
	f = E.poly([1, 2, 3]).add_exp(2, 1).add_trig(1, 2)
	var p = f.clone()
	p.derive()
	p.apply_dl(1)
	var q = f.clone()
	q.apply_dl(1)
	q.derive()
	check(p.equals(q), "D(D−1) = (D−1)D (commute)")
	# conjugation: e^{x} · D · e^{−x} = D − 1
	p = f.clone()
	p.shift(-1)
	p.derive()
	p.shift(1)
	q = f.clone()
	q.apply_dl(1)
	check(p.equals(q), "eˣ D e⁻ˣ = D − 1")
	# commutator [D, M] = −M  with M = multiplication by e^{−x}
	p = f.clone()
	p.shift(-1)
	p.derive()
	q = f.clone()
	q.derive()
	q.shift(-1)
	var comm = p.clone()
	var negq = q.clone()
	negq.scale(-1, 1)
	comm.add_expr(negq)
	var mf = f.clone()
	mf.shift(-1)
	mf.scale(-1, 1)
	check(comm.equals(mf), "[D, e⁻ˣ] = −e⁻ˣ")

	# ---------- randomised identities ----------
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in 400:
		var r = E.poly([rng.randi_range(-9, 9), rng.randi_range(-4, 4), rng.randi_range(-3, 3), rng.randi_range(0, 2)])
		r.add_exp(rng.randi_range(-2, 2), rng.randi_range(0, 2), rng.randi_range(1, 2))
		r.add_trig(rng.randi_range(-3, 3), rng.randi_range(-3, 3), rng.randi_range(0, 1))
		if rng.randf() < 0.3:
			r.add_trig(rng.randi_range(-2, 2), rng.randi_range(-2, 2), 0, 1)
		var name: String = r.to_text()
		# Annihilator really annihilates
		var a = r.clone()
		var m: Dictionary = r.modes()
		for mu in m:
			for j in int(m[mu]) + 1:
				if mu.y == 0:
					a.apply_dl(mu.x)
				else:
					a.apply_quad(mu.x, mu.y)
		check(a.is_zero(), "Ann(f) f = 0 for " + name)
		# Fundamental theorem
		var big = r.clone()
		big.integrate()
		check(E.rz(big.eval0()), "F(0) = 0 for " + name)
		var back = big.clone()
		back.derive()
		check(back.equals(r), "(∫f)′ = f for " + name)
		# Simpson ∫₀¹ f vs F(1)
		var steps := 200
		var acc: float = r.value_at(0.0) + r.value_at(1.0)
		for k in range(1, steps):
			acc += (4.0 if k % 2 == 1 else 2.0) * r.value_at(float(k) / steps)
		var simpson := acc / (3.0 * steps)
		check(absf(simpson - big.value_at(1.0)) < 1e-6 * maxf(1.0, absf(simpson)), "F(1) = ∫₀¹ f for " + name)
		# derivative vs finite difference
		var d = r.clone()
		d.derive()
		var h := 1e-4
		var fd: float = (r.value_at(1.3 + h) - r.value_at(1.3 - h)) / (2.0 * h)
		check(absf(fd - d.value_at(1.3)) < 1e-3 * maxf(1.0, absf(fd)), "f′ numeric for " + name)
		# f(0)
		var z = r.clone()
		z.collapse()
		check(absf(z.value_at(5.0) - r.value_at(0.0)) < 1e-9 * maxf(1.0, absf(r.value_at(0.0))), "f(0) for " + name)

	# multiplicity armour and linear dependence (Σ with 「기저 정리」)
	var ar = E.new().add_exp(3).times_x(3)
	check(txt(ar) == "3x³eˣ", "x³ · 3eˣ  got " + txt(ar))
	var ac = ar.clone()
	for i in 3:
		ac.apply_dl(1)
	check(not ac.is_zero(), "(D − 1)³ does not kill x³eˣ")
	ac.apply_dl(1)
	check(ac.is_zero(), "(D − 1)⁴ kills x³eˣ")
	var ad = ar.clone()
	ad.derive()
	ad.div_x()
	ad.div_x()
	check(not ad.divisible_by_x(), "D(x³eˣ) = (3x² + x³)eˣ: divisible by x² only — D costs one layer of ÷x")
	check(E.dependent_set([E.new().add_exp(3), E.new().add_exp(5)]) == [0, 1], "3eˣ, 5eˣ dependent")
	check(E.dependent_set([E.new().add_exp(3), E.new().add_trig(0, 1)]) == [], "eˣ, sin x independent")
	check(E.dependent_set([E.new().add_trig(0, 1), E.poly([4]), E.new().add_trig(1, 0), E.new().add_trig(1, 2)]) == [0, 2, 3], "sin, 4, cos, 2sin+cos → {sin, cos, 2sin+cos}")
	check(E.dependent_set([E.new().add_exp(2).times_x(1), E.new().add_exp(2).times_x(2)]) == [], "xeˣ, x²eˣ independent")

	print("expr checks: %d, failures: %d" % [checks, fails])
	quit(1 if fails > 0 else 0)
