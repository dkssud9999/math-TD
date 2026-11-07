extends SceneTree
## The script-side function API: f + g, -f, 2 * f, f / 2, f == 0, derivative(f), f.at(x).
## Run: godot --headless --path . -s res://tests/test_mathapi.gd

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


var AlgoS


func run() -> void:
	AlgoS = load("res://scripts/algo.gd")
	var sinx := Expr.new().add_trig(0, 1)                 # sin x
	var msinx := Expr.new().add_trig(0, -1)               # −sin x
	var cos2 := Expr.new().add_trig(1, 0, 0, 0, 2)        # cos 2x
	var sin2 := Expr.new().add_trig(0, 1, 0, 0, 2)        # sin 2x
	var mix := Expr.poly([5, 0, 1]).add_exp(3)            # x² + 5 + 3eˣ
	var host = AlgoS.new(null)
	var g := {"a": _node(sinx), "b": _node(msinx), "c": _node(cos2), "s2": _node(sin2), "m": _node(mix),
		"derivative": {"__bm": "derivative", "self": {"__obj": "math"}}}
	_ok(host, g, "a + b == 0", true)
	_ok(host, g, "(a + b).is_zero", true)
	_ok(host, g, "a == -b", true)
	_ok(host, g, "a - b == 2 * a", true)
	_ok(host, g, "a != b", true)
	_ok(host, g, "derivative(derivative(a)) + a == 0", true)
	_ok(host, g, "a.derivative().derivative() == b", true)
	_ok(host, g, "derivative(c) / 2 + s2 == 0", true)              # D cos 2x = −2 sin 2x
	_ok(host, g, "derivative(derivative(s2)) / 4 == -s2", true)
	_ok(host, g, "s2 * 0.5 * 2 == s2", true)
	_ok(host, g, "sum(m.terms) == m", true)
	_ok(host, g, "len(m.terms)", 3)
	_ok(host, g, "m.terms[2].is_number", true)
	_ok(host, g, "m.terms[2] == 5", true)
	_ok(host, g, "round(a.at(0), 6)", 0.0)
	_ok(host, g, "str(a + b)", "0")
	_ok(host, g, "[t for t in m.terms if t.has(\"exp\")][0] / 3 == [t for t in m.terms if t.has(\"exp\")][0].factors[-1]", true)
	_ok(host, g, "a in [b, -b]", true)
	_ok(host, g, "a == \"sin(x)\"", false)
	_err(host, g, "a * b")
	_err(host, g, "a / b")
	_err(host, g, "a + \"x\"")
	print("math api checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _node(f: Expr) -> Dictionary:
	return {"__obj": "node", "d": AlgoS.tree_of(f)}


func _run(host, g: Dictionary, expr: String) -> Array:
	var vm := PyVM.new()
	vm.host = host
	var ok := vm.compile("r = " + expr + "\n")
	if not ok:
		return [false, vm.error_text()]
	vm.exec_program(g.duplicate())
	if not vm.ok():
		return [false, vm.error_text()]
	return [true, vm.globals_env["vars"].get("r")]


func _ok(host, g: Dictionary, expr: String, want) -> void:
	checks += 1
	var r := _run(host, g, expr)
	var good: bool = r[0] and typeof(r[1]) == typeof(want) and r[1] == want
	if not good:
		failures += 1
		print("FAIL ", expr, " → ", r)


func _err(host, g: Dictionary, expr: String) -> void:
	checks += 1
	var r := _run(host, g, expr)
	if r[0]:
		failures += 1
		print("FAIL (expected an error) ", expr, " → ", r)
