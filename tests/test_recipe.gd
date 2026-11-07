extends SceneTree
## Enemies built from their solution (scripts/recipe.gd): every recipe must replay forward to exactly 0
## with the real operators, and known bosses can be rebuilt from a recipe.
## Run: godot --headless --path . -s res://tests/test_recipe.gd

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: " + msg)


func run() -> void:
	var P = root.get_node("Progress")
	var D = root.get_node("Data")
	P.persist = false
	for id in ["psqrt", "ln", "diff", "divx", "sqrt", "log2", "damp"]:
		P.research[id] = true
	var R = load("res://scripts/recipe.gd")
	# known bosses, rebuilt from their solution
	var cases := [
		["6장 boss_e3 · x⁴", [["divx", 4], ["sub", 4], ["damp", 2], ["diff", 2, [2, 1]], ["log"], ["divx", 1], ["sub", 1]], "4x⁴ + x⁴e³ˣ + x⁵e²ˣ"],
		["256", [["sqrt", 1], ["div", 2], ["sub", 4]], "256"],
		["x⁶ + 3x² + 9", [["sub", 9], ["divx", 2], ["sub", 3], ["divx", 4], ["sub", 1]], "x⁶ + 3x² + 9"],
		["(wrong) −0", [["sub", 4], ["div", 1], ["sub", 0], ["log"], ["divx", 1], ["sub", 1]], "!"],
		["(x² + 2x + 3)²", [["sqrt", 1], ["sub", 3], ["divx", 1], ["sub", 2], ["divx", 1], ["sub", 1]], "x⁴ + 4x³ + 10x² + 12x + 9"],
		["2⁶²", [["log2", 1], ["div", 1], ["sub", 1], ["div", 1], ["sub", 1], ["div", 1], ["sub", 7]], "4611686018427387904"],
	]
	for c in cases:
		var steps: Array = c[1]
		var f: Expr = R.build(steps)
		var why: String = R.check(f, steps)
		if c[2] == "!":
			ok(why != "", "%s must be rejected (a tower would not fire)" % c[0])   # the check catches bad recipes
		else:
			ok(f.to_text() == c[2], "%s builds %s (expected %s)" % [c[0], f.to_text(), c[2]])
			ok(why == "", "%s: %s" % [c[0], why])
		print("  %-22s %-36s hits %2d  %s" % [c[0], f.to_text(), R.hits(steps), "ok" if why == "" else why])
	# every recipe template in the game
	for tpl in D.TEMPLATES:
		if D.TEMPLATES[tpl].has("recipe"):
			for key in ["recipe", "recipe_hard"]:
				if D.TEMPLATES[tpl].has(key):
					var st: Array = D.TEMPLATES[tpl][key]
					var g: Expr = R.build(st)
					var w: String = R.check(g, st)
					ok(w == "", "%s.%s: %s" % [tpl, key, w])
	print("recipe checks: %d, failures: %d" % [checks, failures])
	quit()
