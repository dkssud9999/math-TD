class_name Expr
extends RefCounted
## An enemy's body: an exponential polynomial in x and t
##     f(x, t) = Σ c · xᵏ · e^{μx} · tʲ · e^{γt},   μ = a + bi (a, b integers), γ an integer,
## with c an exact complex rational. Conjugate x-modes are stored in pairs, so f is always real.
## Every tower is a linear operator on this space; an enemy dies when f ≡ 0 (it lies in the kernel).
## Key layout: [k, a, b, j, γ].

const SUP := {"0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "-": "⁻"}

var t: Dictionary = {}   # [k, a, b, j, γ] -> [re, im], each a rational [num, den]


# ======================= exact arithmetic =======================

static func _gcd(a: int, b: int) -> int:
	while b != 0:
		var r := a % b
		a = b
		b = r
	return a


@warning_ignore("integer_division")
static func rn(n: int, d: int = 1) -> Array:
	if d == 0 or n == 0:
		return [0, 1]
	if d < 0:
		n = -n
		d = -d
	var g := _gcd(absi(n), d)
	return [n / g, d / g]


static func radd(a: Array, b: Array) -> Array:
	return rn(int(a[0]) * int(b[1]) + int(b[0]) * int(a[1]), int(a[1]) * int(b[1]))


static func rneg(a: Array) -> Array:
	return [-int(a[0]), int(a[1])]


static func rsub(a: Array, b: Array) -> Array:
	return radd(a, rneg(b))


static func rmul(a: Array, b: Array) -> Array:
	return rn(int(a[0]) * int(b[0]), int(a[1]) * int(b[1]))


static func rdiv(a: Array, b: Array) -> Array:
	return rn(int(a[0]) * int(b[1]), int(a[1]) * int(b[0]))


static func rscale(a: Array, num: int, den: int = 1) -> Array:
	return rn(int(a[0]) * num, int(a[1]) * den)


static func rf(a: Array) -> float:
	return float(a[0]) / float(a[1])


static func rz(a: Array) -> bool:
	return int(a[0]) == 0


static func Z() -> Array:
	return [[0, 1], [0, 1]]


static func cre(r: Array) -> Array:
	return [r, [0, 1]]


static func cz(z: Array) -> bool:
	return rz(z[0]) and rz(z[1])


static func cadd(z: Array, w: Array) -> Array:
	return [radd(z[0], w[0]), radd(z[1], w[1])]


static func cneg(z: Array) -> Array:
	return [rneg(z[0]), rneg(z[1])]


static func cmul(z: Array, w: Array) -> Array:
	return [rsub(rmul(z[0], w[0]), rmul(z[1], w[1])), radd(rmul(z[0], w[1]), rmul(z[1], w[0]))]


static func cdiv(z: Array, w: Array) -> Array:
	var den := radd(rmul(w[0], w[0]), rmul(w[1], w[1]))
	var num := cmul(z, [w[0], rneg(w[1])])
	return [rdiv(num[0], den), rdiv(num[1], den)]


static func cscale(z: Array, num: int, den: int = 1) -> Array:
	return [rscale(z[0], num, den), rscale(z[1], num, den)]


static func cmu(a: int, b: int) -> Array:
	return [[a, 1], [b, 1]]


static func sup(n: int) -> String:
	var out := ""
	for ch in str(n):
		out += SUP.get(ch, ch)
	return out


static func K(k: int, a: int = 0, b: int = 0, j: int = 0, g: int = 0) -> Array:
	return [k, a, b, j, g]


static func CONST() -> Array:
	return [0, 0, 0, 0, 0]


# ======================= construction =======================

func _add(key: Array, z: Array) -> void:
	var nz := cadd(t.get(key, Z()), z)
	if cz(nz):
		t.erase(key)
	else:
		t[key] = nz


## Integer polynomial in x, lowest power first: poly([4, 1, 0, 1]) = x³ + x + 4
static func poly(coeffs: Array) -> Expr:
	var f := Expr.new()
	for i in coeffs.size():
		if int(coeffs[i]) != 0:
			f._add(K(i), cre(rn(int(coeffs[i]))))
	return f


## Adds coef · xᵏ · e^{ax}. Returns self for chaining.
func add_exp(coef: int, k: int = 0, a: int = 1) -> Expr:
	_add(K(k, a), cre(rn(coef)))
	return self


## Adds xᵏ e^{ax} (A cos bx + B sin bx) as the conjugate pair ((A − iB)/2) e^{(a+bi)x} + c.c.
func add_trig(cos_coef: int, sin_coef: int, k: int = 0, a: int = 0, b: int = 1) -> Expr:
	return add_trig_q(rn(cos_coef), rn(sin_coef), k, a, b)


func add_trig_q(cos_q: Array, sin_q: Array, k: int = 0, a: int = 0, b: int = 1, j: int = 0, g: int = 0) -> Expr:
	var z := [rscale(cos_q, 1, 2), rscale(sin_q, -1, 2)]
	_add(K(k, a, b, j, g), z)
	_add(K(k, a, -b, j, g), [z[0], rneg(z[1])])
	return self


## Adds coef · xᵏ e^{ax} · tʲ e^{γt}  (real modes only).
func add_term(coef: int, k: int, a: int, j: int, g: int) -> Expr:
	_add(K(k, a, 0, j, g), cre(rn(coef)))
	return self


## Multiplies every term by tʲ e^{γt} (separable time factor).
func times_t(j: int, g: int) -> Expr:
	var old := t
	t = {}
	for key: Array in old:
		_add(K(key[0], key[1], key[2], int(key[3]) + j, int(key[4]) + g), old[key])
	return self


func add_expr(g: Expr) -> Expr:
	for key: Array in g.t:
		_add(key, g.t[key])
	return self


func clone() -> Expr:
	var f := Expr.new()
	f.t = t.duplicate(true)
	return f


func equals(g: Expr) -> bool:
	if t.size() != g.t.size():
		return false
	for key: Array in t:
		if not g.t.has(key):
			return false
		var a: Array = t[key]
		var b: Array = g.t[key]
		if a[0] != b[0] or a[1] != b[1]:
			return false
	return true


# ======================= queries =======================

func is_zero() -> bool:
	return t.is_empty()


## Max power of x per x-mode μ (b ≥ 0), treating any t-dependence as a coefficient.
func modes() -> Dictionary:
	var m := {}
	for key: Array in t:
		if int(key[2]) < 0:
			continue
		var mu := Vector2i(key[1], key[2])
		m[mu] = maxi(int(m.get(mu, -1)), int(key[0]))
	return m


## Max power of t per t-mode γ.
func t_modes() -> Dictionary:
	var m := {}
	for key: Array in t:
		var gk := int(key[4])
		m[gk] = maxi(int(m.get(gk, -1)), int(key[3]))
	return m


func has_mode(a: int, b: int) -> bool:
	for key: Array in t:
		if int(key[1]) == a and absi(int(key[2])) == b:
			return true
	return false


func has_t() -> bool:
	for key: Array in t:
		if int(key[3]) != 0 or int(key[4]) != 0:
			return true
	return false


func has_t_mode(g: int) -> bool:
	for key: Array in t:
		if int(key[4]) == g:
			return true
	return false


## Degree of the x-polynomial (μ = 0) part, −1 if none.
func degree() -> int:
	var d := -1
	for key: Array in t:
		if int(key[1]) == 0 and int(key[2]) == 0:
			d = maxi(d, int(key[0]))
	return d


func max_freq() -> int:
	var w := 0
	for key: Array in t:
		w = maxi(w, absi(int(key[2])))
	return w


func has_exp() -> bool:
	for key: Array in t:
		if int(key[2]) == 0 and int(key[1]) != 0:
			return true
	return false


func has_trig() -> bool:
	for key: Array in t:
		if int(key[2]) != 0:
			return true
	return false


## Any x-mode that grows or stays level along the path (Re μ ≥ 1)?
func has_growing() -> bool:
	for key: Array in t:
		if int(key[1]) >= 1:
			return true
	return false


func const_term() -> Array:
	var z: Array = t.get(CONST(), Z())
	return z[0]


func is_constant() -> bool:
	return t.is_empty() or (t.size() == 1 and t.has(CONST()))


func is_pure_exp() -> bool:
	return not t.is_empty() and degree() < 0 and not has_trig()


func term_count() -> int:
	var n := 0
	for key: Array in t:
		if int(key[2]) >= 0:
			n += 1
	return n


func value_at(x: float, tt: float = 0.0) -> float:
	var v := 0.0
	for key: Array in t:
		var z: Array = t[key]
		var mag := pow(x, int(key[0])) * exp(int(key[1]) * x) * pow(tt, int(key[3])) * exp(int(key[4]) * tt)
		var ang := int(key[2]) * x
		v += mag * (rf(z[0]) * cos(ang) - rf(z[1]) * sin(ang))
	return v


## f(0) for the t-independent part (exact).
func eval0() -> Array:
	var v := [0, 1]
	for key: Array in t:
		if int(key[0]) == 0 and int(key[3]) == 0 and int(key[4]) == 0:
			v = radd(v, t[key][0])
	return v


## Minimal annihilating polynomial in D = ∂/∂x, e.g. "D⁴(D−1)³(D²+1)".
func annihilator() -> String:
	if t.is_empty():
		return "1"
	var m := modes()
	var keys: Array = m.keys()
	keys.sort_custom(func(p, q): return p.y < q.y if p.y != q.y else p.x < q.x)
	var out := ""
	for mu: Vector2i in keys:
		var pw := int(m[mu]) + 1
		var s := ""
		if mu.y == 0:
			if mu.x == 0:
				s = "D"
			elif mu.x > 0:
				s = "(D−%d)" % mu.x if mu.x != 1 else "(D−1)"
			else:
				s = "(D+%d)" % -mu.x if mu.x != -1 else "(D+1)"
		else:
			var a: int = mu.x
			var q: int = a * a + mu.y * mu.y
			if a == 0:
				s = "(D²+%d)" % q
			else:
				s = "(D²%s%dD+%d)" % ["−" if a > 0 else "+", absi(2 * a), q]
		out += s + (sup(pw) if pw > 1 else "")
	return out


## Annihilator in ∂ₜ (only meaningful when f depends on t), e.g. "(∂ₜ−2)".
func t_annihilator() -> String:
	var m := t_modes()
	var keys: Array = m.keys()
	keys.sort()
	var out := ""
	for gk in keys:
		var pw := int(m[gk]) + 1
		var s := "∂ₜ" if gk == 0 else ("(∂ₜ−%d)" % gk if gk > 0 else "(∂ₜ+%d)" % -gk)
		out += s + (sup(pw) if pw > 1 else "")
	return out


func ann_degree() -> int:
	var n := 0
	var m := modes()
	for mu: Vector2i in m:
		n += (int(m[mu]) + 1) * (2 if mu.y != 0 else 1)
	return n


# ======================= operators =======================

## f → ∂f/∂x
func derive() -> void:
	var old := t
	t = {}
	for key: Array in old:
		var z: Array = old[key]
		var k := int(key[0])
		if k > 0:
			_add(K(k - 1, key[1], key[2], key[3], key[4]), cscale(z, k))
		if int(key[1]) != 0 or int(key[2]) != 0:
			_add(key, cmul(z, cmu(key[1], key[2])))


## f → ∂f/∂t
func dt() -> void:
	var old := t
	t = {}
	for key: Array in old:
		var z: Array = old[key]
		var j := int(key[3])
		if j > 0:
			_add(K(key[0], key[1], key[2], j - 1, key[4]), cscale(z, j))
		if int(key[4]) != 0:
			_add(key, cscale(z, int(key[4])))


## f → (D − a) f, a real.
func apply_dl(a: int) -> void:
	var g := clone()
	derive()
	for key: Array in g.t:
		_add(key, cscale(g.t[key], -a))


## f → (∂ₜ − λ) f
func apply_dtl(lam: int) -> void:
	var g := clone()
	dt()
	for key: Array in g.t:
		_add(key, cscale(g.t[key], -lam))


## f → (D² − 2aD + a² + b²) f  (a=0, b=1 is D² + 1)
func apply_quad(a: int, b: int) -> void:
	var f0 := clone()
	var f1 := clone()
	f1.derive()
	derive()
	derive()
	for key: Array in f1.t:
		_add(key, cscale(f1.t[key], -2 * a))
	for key: Array in f0.t:
		_add(key, cscale(f0.t[key], a * a + b * b))


## f → □f = ∂ₜ²f − ∂ₓ²f   (kills every travelling wave g(x − t) + h(x + t))
func apply_wave() -> void:
	var fx := clone()
	fx.derive()
	fx.derive()
	dt()
	dt()
	for key: Array in fx.t:
		_add(key, cneg(fx.t[key]))


## Low-pass filter: removes every oscillation with frequency |b| > cutoff (a Fourier multiplier).
func lowpass(cutoff: int) -> bool:
	var changed := false
	for key: Array in t.keys():
		if absi(int(key[2])) > cutoff:
			t.erase(key)
			changed = true
	return changed


## f → ∫₀ˣ f(s, t) ds   (the result always satisfies F(0, t) = 0)
## ∫₀ˣ sᵏ e^{μs} ds = e^{μx} Σⱼ (−1)ʲ k!/(k−j)! x^{k−j} / μ^{j+1}  −  (−1)ᵏ k! / μ^{k+1}
func integrate() -> void:
	var old := t
	t = {}
	for key: Array in old:
		var z: Array = old[key]
		var k := int(key[0])
		var a := int(key[1])
		var b := int(key[2])
		if a == 0 and b == 0:
			_add(K(k + 1, 0, 0, key[3], key[4]), cscale(z, 1, k + 1))
			continue
		var mu := cmu(a, b)
		var mu_pow := mu
		var falling := 1
		for jj in k + 1:
			var coef := cdiv(cscale(z, falling * (1 if jj % 2 == 0 else -1)), mu_pow)
			_add(K(k - jj, a, b, key[3], key[4]), coef)
			if jj < k:
				falling *= (k - jj)
				mu_pow = cmul(mu_pow, mu)
		var kf := 1
		for i in range(2, k + 1):
			kf *= i
		_add(K(0, 0, 0, key[3], key[4]), cneg(cdiv(cscale(z, kf * (1 if k % 2 == 0 else -1)), mu_pow)))


## f(x, t) → f(0, t): every term with x⁰ survives (e⁰ = 1, cos 0 = 1, sin 0 = 0), the rest vanish.
func subst_x0() -> void:
	var old := t
	t = {}
	for key: Array in old:
		if int(key[0]) == 0:
			_add(K(0, 0, 0, key[3], key[4]), old[key])


## f → f(0)  (t-independent part only)
func collapse() -> void:
	var v := eval0()
	t = {}
	if not rz(v):
		_add(CONST(), cre(v))


## f → e^{dx}·f  (shifts every x-mode μ → μ + d)
func shift(d: int) -> void:
	var old := t
	t = {}
	for key: Array in old:
		_add(K(key[0], int(key[1]) + d, key[2], key[3], key[4]), old[key])


## f → (num/den)·f
func scale(num: int, den: int) -> void:
	for key: Array in t.keys():
		t[key] = cscale(t[key], num, den)


## Constant term moves k toward zero (never overshoots).
func sub_toward_zero(k: int) -> bool:
	var v := const_term()
	if rz(v):
		return false
	var fv := rf(v)
	var nv: Array
	if absf(fv) <= k:
		nv = [0, 1]
	elif fv > 0.0:
		nv = rsub(v, [k, 1])
	else:
		nv = radd(v, [k, 1])
	t.erase(CONST())
	if not rz(nv):
		t[CONST()] = cre(nv)
	return true


## Exact integer division: every coefficient is an integer multiple of k (and f ≠ 0).
func divisible_by(k: int) -> bool:
	if t.is_empty():
		return false
	for key: Array in t:
		var z: Array = t[key]
		for part in z:
			if int(part[1]) != 1 or int(part[0]) % k != 0:
				return false
	return true


## f / x is exact only when every term carries x (the constant term — and every x⁰ term — is 0).
func divisible_by_x() -> bool:
	if t.is_empty():
		return false
	for key: Array in t:
		if int(key[0]) == 0:
			return false
	return true


## f → xᵐ · f  (raises the multiplicity of every mode by m: Ann gains m factors per mode)
func times_x(m: int) -> Expr:
	var old := t
	t = {}
	for key: Array in old:
		_add(K(int(key[0]) + m, key[1], key[2], key[3], key[4]), old[key])
	return self


## Indices of a linearly dependent subset of fs (Σ cᵢfᵢ = 0 with every listed cᵢ ≠ 0), or [] if independent.
## Exact Gaussian elimination over ℚ(i), one function at a time.
static func dependent_set(fs: Array) -> Array:
	var rows: Array = []   # {piv, vec, combo}
	for i in fs.size():
		var vec: Dictionary = (fs[i] as Expr).t.duplicate(true)
		if vec.is_empty():
			return [i]
		var combo := {i: cre(rn(1))}
		for row: Dictionary in rows:
			var piv: Array = row["piv"]
			if not vec.has(piv):
				continue
			var c := cdiv(vec[piv], row["vec"][piv])
			for key: Array in row["vec"]:
				var nz := cadd(vec.get(key, Z()), cneg(cmul(c, row["vec"][key])))
				if cz(nz):
					vec.erase(key)
				else:
					vec[key] = nz
			for j in row["combo"]:
				var nc := cadd(combo.get(j, Z()), cneg(cmul(c, row["combo"][j])))
				if cz(nc):
					combo.erase(j)
				else:
					combo[j] = nc
		if vec.is_empty():
			var out: Array = combo.keys()
			out.sort()
			return out
		rows.append({"piv": vec.keys()[0], "vec": vec, "combo": combo})
	return []


## f → f / x
func div_x() -> void:
	var old := t
	t = {}
	for key: Array in old:
		_add(K(int(key[0]) - 1, key[1], key[2], key[3], key[4]), old[key])


static func _isqrt(n: int) -> int:
	if n < 0:
		return -1
	var r := int(round(sqrt(float(n))))
	while r * r > n:
		r -= 1
	while (r + 1) * (r + 1) <= n:
		r += 1
	return r


## Pure x-polynomial coefficients (lowest first) as rationals, or [] if f has any other kind of term.
func _poly_coeffs() -> Array:
	var deg := -1
	for key: Array in t:
		if int(key[1]) != 0 or int(key[2]) != 0 or int(key[3]) != 0 or int(key[4]) != 0:
			return []
		if not rz(t[key][1]):
			return []
		deg = maxi(deg, int(key[0]))
	var c: Array = []
	for i in deg + 1:
		var z: Array = t.get(K(i), Z())
		c.append(z[0])
	return c


static func _rsqrt(r: Array) -> Array:
	var n: int = r[0]
	var d: int = r[1]
	if n < 0:
		return []
	var a := _isqrt(n)
	var b := _isqrt(d)
	if a * a != n or b * b != d:
		return []
	return [a, b]


## g with g² = f for a polynomial f of even degree ≥ 2 (positive leading coefficient), or [] if none exists.
func _poly_sqrt() -> Array:
	var c := _poly_coeffs()
	if c.size() < 3 or (c.size() - 1) % 2 != 0:
		return []
	var n := int((c.size() - 1) / 2.0)
	var lead := _rsqrt(c[2 * n])
	if lead.is_empty():
		return []
	var g: Array = []
	g.resize(n + 1)
	g[n] = rn(int(lead[0]), int(lead[1]))
	# coefficient of x^{n+k} in g² is Σ g_i g_j (i + j = n + k); solve for g_k from the top down
	for k in range(n - 1, -1, -1):
		var acc: Array = c[n + k]
		for i in range(k + 1, n + 1):
			var j := n + k - i
			if j > k and j <= n and j != i:
				acc = rsub(acc, rmul(g[i], g[j]))
			elif j == i:
				acc = rsub(acc, rmul(g[i], g[j]))
		g[k] = rdiv(acc, rscale(g[n], 2))
	# verify g² = f exactly
	for p in range(2 * n + 1):
		var s := [0, 1]
		for i in range(n + 1):
			var j := p - i
			if j >= 0 and j <= n:
				s = radd(s, rmul(g[i], g[j]))
		if s[0] != c[p][0] or s[1] != c[p][1]:
			return []
	return g


func is_perfect_square() -> bool:
	if not is_constant() and not t.is_empty():
		return not _poly_sqrt().is_empty()
	if not is_constant() or t.is_empty():
		return false
	var v := const_term()
	var n: int = v[0]
	var d: int = v[1]
	if n <= 1 and d == 1:
		return false
	var rn_ := _isqrt(n)
	var rd := _isqrt(d)
	return rn_ >= 0 and rn_ * rn_ == n and rd * rd == d


func sqrt_const() -> void:
	if not is_constant():
		var g := _poly_sqrt()
		t = {}
		for i in g.size():
			if not rz(g[i]):
				_add(K(i), cre(g[i]))
		return
	var v := const_term()
	t = {}
	_add(CONST(), cre(rn(_isqrt(int(v[0])), _isqrt(int(v[1])))))


func is_pow2() -> bool:
	if not is_constant() or t.is_empty():
		return false
	var v := const_term()
	var n: int = v[0]
	return int(v[1]) == 1 and n >= 1 and (n & (n - 1)) == 0


func log2_const() -> void:
	var n: int = const_term()[0]
	var k := 0
	while n > 1:
		n >>= 1
		k += 1
	t = {}
	if k != 0:
		_add(CONST(), cre(rn(k)))


# ======================= display =======================

static func _xpart(k: int) -> String:
	return "" if k == 0 else ("x" if k == 1 else "x" + sup(k))


static func _epart(a: int) -> String:
	match a:
		0:
			return ""
		1:
			return "eˣ"
		-1:
			return "e⁻ˣ"
	return "e" + sup(a) + "ˣ"


static func _tpart(j: int, g: int) -> String:
	var s := "" if j == 0 else ("t" if j == 1 else "t" + sup(j))
	match g:
		0:
			pass
		1:
			s += "eᵗ"
		-1:
			s += "e⁻ᵗ"
		_:
			s += "e" + sup(g) + "ᵗ"
	return s


static func _arg(b: int) -> String:
	return "x" if b == 1 else "%dx" % b


static func _fmt(m: Array, body: String, starts_with_x: bool) -> String:
	var n: int = m[0]
	var d: int = m[1]
	if body == "":
		return str(n) if d == 1 else "%d/%d" % [n, d]
	if d == 1:
		return body if n == 1 else str(n) + body
	if starts_with_x:
		return (body if n == 1 else str(n) + body) + "/" + str(d)
	return "(%d/%d)%s" % [n, d, body]


## The real terms of f, in display order: [{num, den, k, a, trig ("", "cos", "sin"), b, j, g}].
## c·xᵏ·e^{ax}·cos(bx)·tʲ·e^{gt}  — the same split to_text() prints.
func real_terms() -> Array:
	var items: Array = []
	for key: Array in t:
		var z: Array = t[key]
		var k := int(key[0])
		var a := int(key[1])
		var b := int(key[2])
		var j := int(key[3])
		var g := int(key[4])
		if b < 0:
			continue
		if b == 0:
			var grp := 0 if (a == 0 and k > 0) else (1 if a != 0 else (3 if j == 0 and g == 0 else 2))
			items.append([[grp, -a, -k, -g, -j], z[0], k, a, "", 0, j, g])
		else:
			var cos_c := rscale(z[0], 2)
			var sin_c := rscale(z[1], -2)
			if not rz(cos_c):
				items.append([[2, -a, b, -k, 0, -g, -j], cos_c, k, a, "cos", b, j, g])
			if not rz(sin_c):
				items.append([[2, -a, b, -k, 1, -g, -j], sin_c, k, a, "sin", b, j, g])
	items.sort_custom(func(p, q): return _lex_less(p[0], q[0]))
	var out: Array = []
	for it in items:
		var c: Array = it[1]
		out.append({"num": int(c[0]), "den": int(c[1]), "k": it[2], "a": it[3], "trig": it[4], "b": it[5], "j": it[6], "g": it[7]})
	return out


func to_text() -> String:
	if t.is_empty():
		return "0"
	var items: Array = []   # [sort_key Array, coef rational, body]
	for key: Array in t:
		var z: Array = t[key]
		var k := int(key[0])
		var a := int(key[1])
		var b := int(key[2])
		var j := int(key[3])
		var g := int(key[4])
		if b < 0:
			continue
		var base := _xpart(k) + _epart(a)
		var tp := _tpart(j, g)
		if b == 0:
			var grp := 0 if (a == 0 and k > 0) else (1 if a != 0 else (3 if tp == "" else 2))
			items.append([[grp, -a, -k, -g, -j], z[0], base + tp])
		else:
			var sep := " " if base != "" else ""
			var cos_c := rscale(z[0], 2)
			var sin_c := rscale(z[1], -2)
			var tail := (" " + tp) if tp != "" else ""
			if not rz(cos_c):
				items.append([[2, -a, b, -k, 0, -g, -j], cos_c, base + sep + "cos " + _arg(b) + tail])
			if not rz(sin_c):
				items.append([[2, -a, b, -k, 1, -g, -j], sin_c, base + sep + "sin " + _arg(b) + tail])
	items.sort_custom(func(p, q): return _lex_less(p[0], q[0]))
	var out := ""
	for idx in items.size():
		var c: Array = items[idx][1]
		var body: String = items[idx][2]
		var neg := int(c[0]) < 0
		var piece := _fmt([absi(int(c[0])), int(c[1])], body, body.begins_with("x") or body.begins_with("t"))
		if idx == 0:
			out += ("−" if neg else "") + piece
		else:
			out += (" − " if neg else " + ") + piece
	return out


static func _lex_less(p: Array, q: Array) -> bool:
	for i in mini(p.size(), q.size()):
		if p[i] != q[i]:
			return p[i] < q[i]
	return p.size() < q.size()
