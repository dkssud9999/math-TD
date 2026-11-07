extends SceneTree
## The 64-bit guard in Expr (issues #14, #17): exact integer bounds, no false refusals of results that
## fit, and linear dependence only when it is proven.
## godot --headless --path . --script res://tests/test_bounds.gd

var checks := 0
var fails := 0
const L := 4611686018427387904   # 2⁶²


func check(ok: bool, name: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: " + name)


func ovf(f: Callable) -> bool:
	Expr.overflow = false
	f.call()
	var o := Expr.overflow
	Expr.overflow = false
	return o


func _init() -> void:
	# --- additions at the exact boundary (#14 A) ---
	check(ovf(func(): Expr._a(L, 1)), "2^62 + 1 overflows")
	check(ovf(func(): Expr._a(-L, -1)), "-2^62 - 1 overflows")
	check(not ovf(func(): Expr._a(L - 1, 1)), "(2^62 - 1) + 1 fits")
	check(not ovf(func(): Expr._a(L, -L)), "2^62 - 2^62 fits")
	Expr.overflow = false
	check(Expr._a(L, L) == L and Expr.overflow, "2^62 + 2^62 clamps to +2^62 (sign never wraps)")
	Expr.overflow = false
	check(Expr._a(-L, -L) == -L and Expr.overflow, "-2^62 - 2^62 clamps to -2^62")
	Expr.overflow = false
	# --- products at the exact boundary ---
	check(not ovf(func(): Expr._m(1 << 31, 1 << 31)), "2^31 * 2^31 = 2^62 fits")
	check(ovf(func(): Expr._m((1 << 31) + 1, 1 << 31)), "(2^31 + 1) * 2^31 overflows")
	check(not ovf(func(): Expr._m(-L, 1)), "-2^62 * 1 fits")
	check(ovf(func(): Expr._m(L, -2)), "2^62 * -2 overflows")
	# --- results that fit are not refused because of big intermediates (#14 B) ---
	var r: Array = []
	check(not ovf(func(): r.append(Expr.radd(Expr.rn(1, 1 << 32), Expr.rn(1, 1 << 32)))) and r[0] == [1, 1 << 31],
		"1/2^32 + 1/2^32 = 1/2^31")
	r.clear()
	check(not ovf(func(): r.append(Expr.rmul(Expr.rn(1 << 40, 3), Expr.rn(3, 1 << 40)))) and r[0] == [1, 1],
		"(2^40/3)(3/2^40) = 1")
	r.clear()
	check(not ovf(func(): r.append(Expr.rdiv(Expr.rn(L, 7), Expr.rn(L, 7)))) and r[0] == [1, 1], "x / x = 1 near 2^62")
	check(ovf(func(): Expr.rmul(Expr.rn(L, 1), Expr.rn(3, 1))), "2^62 * 3 overflows")
	# --- the real bosses ---
	var b := Expr.poly([L])
	check(not ovf(func(): b.sub_toward_zero(3)) and b.to_text() == "4611686018427387901", "2^62 boss minus 3")
	var x20 := Expr.poly([1]).times_x(20)
	check(not ovf(func():
		for i in 20:
			x20.derive()) and x20.to_text() == "2432902008176640000", "x^20 differentiated 20 times = 20!")
	var x21 := Expr.poly([1]).times_x(21)
	check(ovf(func():
		for i in 21:
			x21.derive()), "x^21 differentiated 21 times overflows (21! > 2^62)")
	# --- linear dependence only when proven (#17) ---
	var f := Expr.poly([1]).add_expr(_lin(L - 1, L))
	var g := Expr.poly([1]).add_expr(_lin(L - 2, L - 1))
	check(Expr.dependent_set([f, g]).is_empty(), "independent near the limit: not reported dependent")
	var h := Expr.poly([2, 3])
	var h2 := Expr.poly([4, 6])
	check(Expr.dependent_set([h, h2]) == [0, 1], "2·(2 + 3x) and 4 + 6x are dependent")
	check(Expr.dependent_set([Expr.poly([1]), Expr.poly([0, 1])]).is_empty(), "1 and x are independent")
	Expr.overflow = true
	Expr.dependent_set([h, h2])
	check(Expr.overflow, "dependent_set leaves the caller's overflow flag as it was")
	Expr.overflow = false
	print("bounds checks: %d, failures: %d" % [checks, fails])
	quit(1 if fails > 0 else 0)


## (n/d)·x
func _lin(n: int, d: int) -> Expr:
	var e := Expr.new()
	e._add(Expr.K(1), Expr.cre(Expr.rn(n, d)))
	return e
