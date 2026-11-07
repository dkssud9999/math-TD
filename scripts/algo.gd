class_name Algo
extends RefCounted
## A tower's attack algorithm: runs the player's .py file (PyVM) and exposes enemies and the tower to it.
## The script defines  def attack(enemies):  — enemies come front-first (closest to the core first) —
## and returns an enemy, a list of enemies (area towers act on exactly those), or None (wait).
##
## An enemy's function is an expression tree (e.f): sums split into terms, products into factors,
## and compositions like sin(2x) expose their inside (.inner). Thinking costs time: every step the
## script takes delays the tower's next shot (STEP_TIME per step).

const EnemyScript := preload("res://scripts/enemy.gd")
const TowerScript := preload("res://scripts/tower.gd")
const CONSOLE_MAX := 120
const STEP_TIME := 0.00025      # seconds of extra cooldown per interpreter step
const AFTER_COST := 40          # e.after() simulates the operator: expensive on purpose

static var console: Array = []          # [text, is_error] — shown in the editor
static var console_serial: int = 0      # bumps on every new line so the editor knows to redraw

var tower = null
var vm: PyVM = null
var vm_src: String = ""
var vm_name: String = ""
var last_error: String = ""
var last_steps: int = 0                 # steps the last call took (shown in the tower panel)
var _trees: Dictionary = {}             # Expr instance id -> tree, for one call
var compile_error: String = ""
var chosen = null                       # what attack() was given this run
var chose: bool = false


static func log_line(s: String, is_error: bool = false) -> void:
	console.append([s, is_error])
	while console.size() > CONSOLE_MAX:
		console.pop_front()
	console_serial += 1


func _init(p_tower) -> void:
	tower = p_tower


func dispose() -> void:
	if vm != null:
		vm.release()
		vm = null


func _tag() -> String:
	return "[%s %s]" % [tower.glyph(), tower.algo]


## Run the file from the top (recompiling if it changed). attack(x) fires and ends the run, like
## jumping to EOF; reaching EOF without attack() means "wait". Returns {"ok", "targets", "error", "delay"}.
func run(cands: Array, dry: bool = false) -> Dictionary:
	var src: String = Progress.read_script(tower.algo)
	if vm == null or src != vm_src or vm_name != tower.algo:
		dispose()
		vm = PyVM.new()
		vm.host = self
		vm_src = src
		vm_name = tower.algo
		compile_error = "" if vm.compile(src) else vm.error_text()
	if compile_error != "":
		return _error(compile_error)
	var ordered := cands.duplicate()
	ordered.sort_custom(func(a, b): return a.progress > b.progress)   # front first
	var proxies: Array = []
	for e in ordered:
		proxies.append({"__obj": "enemy", "node": e})
	var me := {"__obj": "tower"}
	var g := {"enemies": proxies, "me": me, "wave": Game.wave, "rho": int(Game.rho), "integrity": Game.integrity,
		"attack": {"__bm": "attack", "self": me}, "set_param": {"__bm": "set_param", "self": me}}
	chosen = null
	chose = false
	vm.output.clear()
	_trees.clear()
	vm.exec_program(g)
	if vm.ok() and not chose:
		var fv = vm.globals_env["vars"].get("attack")
		if fv is Dictionary and fv.has("__fn"):   # the older style: def attack(enemies): return …
			vm.err = ""
			var res = vm._call_value(fv, [proxies], {})
			if vm.ok():
				chosen = res
				chose = true
	last_steps = vm.steps
	_trees.clear()
	for line in vm.output:
		log_line("%s %s" % [_tag(), line])
	var failed := not vm.ok()
	var msg := vm.error_text()
	vm.dispose()   # globals are rebuilt every run; drop them now so nothing cycles
	if failed:
		return _error(msg)
	if last_error != "":
		last_error = ""
		if not dry:
			log_line("%s 오류가 사라졌습니다" % _tag())
	var targets: Array = []
	var items: Array = chosen if chosen is Array else ([] if (chosen == null or chosen is bool) else [chosen])
	for it in items:
		if not (it is Dictionary and it.has("__obj") and it["__obj"] in ["enemy", "snap"]):
			return _error("attack()에는 적, 적의 리스트, 또는 None을 주세요 (받은 것: %s)" % PyVM.new()._str(it, true))
		var node = it["node"]
		if is_instance_valid(node) and node.alive and node in cands and not node in targets:
			targets.append(node)
	return {"ok": true, "targets": targets, "error": "", "delay": last_steps * STEP_TIME * (0.5 if Progress.has("think_cheap") else 1.0)}


func _set_dynamic() -> void:
	vm.set_global("wave", Game.wave)
	vm.set_global("rho", int(Game.rho))
	vm.set_global("integrity", Game.integrity)


func _error(msg: String) -> Dictionary:
	if msg != last_error:
		log_line("%s %s" % [_tag(), msg], true)
		Sfx.play("ui", 0.6)
	last_error = msg
	return {"ok": false, "targets": [], "error": msg, "delay": 0.0}


# ---------- the expression tree ----------
# A node is {"kind", "args", "value", "text"}; kinds: add, mul, pow, exp, sin, cos, num, x, t.

static func _num(n: int, d: int = 1) -> Dictionary:
	return {"kind": "num", "args": [], "value": float(n) / float(d) if d != 1 else n,
		"text": str(n) if d == 1 else "%d/%d" % [n, d]}


static func _var(v: String) -> Dictionary:
	return {"kind": v, "args": [], "value": null, "text": v}


static func _scaled(c: int, v: String) -> Dictionary:
	if c == 1:
		return _var(v)
	return {"kind": "mul", "args": [_num(c), _var(v)], "value": null, "text": "%d%s" % [c, v]}


static func _fn(kind: String, inner: Dictionary) -> Dictionary:
	return {"kind": kind, "args": [inner], "value": null, "text": "%s(%s)" % [kind, inner["text"]]}


static func _pow(v: String, k: int) -> Dictionary:
	return {"kind": "pow", "args": [_var(v), _num(k)], "value": null, "text": "%s^%d" % [v, k]}


static func tree_of(f: Expr) -> Dictionary:
	var terms: Array = []
	for rt: Dictionary in f.real_terms():
		var facs: Array = []
		var n: int = rt["num"]
		var d: int = rt["den"]
		if rt["k"] > 0:
			facs.append(_var("x") if rt["k"] == 1 else _pow("x", rt["k"]))
		if rt["a"] != 0:
			facs.append(_fn("exp", _scaled(rt["a"], "x")))
		if rt["trig"] != "":
			facs.append(_fn(rt["trig"], _scaled(rt["b"], "x")))
		if rt["j"] > 0:
			facs.append(_var("t") if rt["j"] == 1 else _pow("t", rt["j"]))
		if rt["g"] != 0:
			facs.append(_fn("exp", _scaled(rt["g"], "t")))
		if not (n == 1 and d == 1) or facs.is_empty():
			facs.push_front(_num(n, d))
		if facs.size() == 1:
			terms.append(facs[0])
		else:
			var parts := PackedStringArray()
			for x in facs:
				parts.append(("(%s)" % x["text"]) if x["kind"] == "num" and x["value"] < 0 else x["text"])
			terms.append({"kind": "mul", "args": facs, "value": null, "text": "·".join(parts)})
	if terms.is_empty():
		return _num(0)
	if terms.size() == 1:
		return terms[0]
	var tt := PackedStringArray()
	for x in terms:
		tt.append(x["text"])
	return {"kind": "add", "args": terms, "value": null, "text": " + ".join(tt).replace("+ -", "- ")}


# Shared by every tower within one frame: the same function gives the same tree and the same
# simulated shot, so they are built once. Scripts are still charged the full cost every time
# (the cache is a speed-up for the computer, not a discount for the player).
static var _cache_frame: int = -1
static var _tree_cache: Dictionary = {}
static var _after_cache: Dictionary = {}


static func _fresh_cache() -> void:
	var fr := Engine.get_process_frames()
	if fr != _cache_frame:
		_cache_frame = fr
		_tree_cache.clear()
		_after_cache.clear()


func _tree(f: Expr, vm_: PyVM) -> Dictionary:
	vm_.steps += 2 * f.t.size()
	_fresh_cache()
	var key := str(f.t)
	if not _tree_cache.has(key):
		_tree_cache[key] = tree_of(f)
	return {"__obj": "node", "d": _tree_cache[key]}


## x-degree of a term (a product): x → 1, x^k → k, otherwise 0 per factor.
static func _degree(d: Dictionary, v: String = "x") -> int:
	match d["kind"]:
		"mul":
			var s := 0
			for a in d["args"]:
				s += _degree(a, v)
			return s
		"add":
			var m := 0
			for a in d["args"]:
				m = maxi(m, _degree(a, v))
			return m
		"pow":
			return int(d["args"][1]["value"]) if d["args"][0]["kind"] == v else 0
	return 1 if d["kind"] == v else 0


## The numeric coefficient of a term: 3·x^2 → 3, 2x → 2, x → 1, 7 → 7.
static func _coef(d: Dictionary):
	match d["kind"]:
		"num":
			return d["value"]
		"mul":
			var c = 1
			for a in d["args"]:
				if a["kind"] == "num":
					c = c * a["value"]
			return c
	return 1


## A term without its number: 3·sin(x) → "sin(x)", -x^2 → "x^2", 7 → "1".
static func _shape(d: Dictionary) -> String:
	if d["kind"] == "num":
		return "1"
	if d["kind"] != "mul":
		return d["text"]
	var parts := PackedStringArray()
	for a in d["args"]:
		if a["kind"] != "num":
			parts.append(a["text"])
	return "·".join(parts) if not parts.is_empty() else "1"


static func _has(d: Dictionary, kind: String) -> bool:
	if d["kind"] == kind:
		return true
	for a in d["args"]:
		if _has(a, kind):
			return true
	return false


func _node_attr(d: Dictionary, name: String, vm_: PyVM):
	vm_.steps += 1
	match name:
		"kind":
			return d["kind"]
		"args":
			return _wrap(d["args"])
		"value":
			return d["value"]
		"text":
			return d["text"]
		"terms":
			return _wrap(d["args"]) if d["kind"] == "add" else _wrap([d])
		"factors":
			return _wrap(d["args"]) if d["kind"] == "mul" else _wrap([d])
		"inner":
			if d["kind"] in ["exp", "sin", "cos"]:
				return {"__obj": "node", "d": d["args"][0]}
			return null
		"base":
			return {"__obj": "node", "d": d["args"][0]} if d["kind"] == "pow" else null
		"exponent":
			return d["args"][1]["value"] if d["kind"] == "pow" else null
		"coef":
			return _coef(d)
		"shape":
			return _shape(d)
		"degree":
			return _degree(d)
		"has":
			return {"__bm": "has", "self": {"__obj": "node", "d": d}}
	vm_.fail("식에는 .%s 가 없습니다 (kind, args, terms, factors, inner, coef, shape, degree, value, has())" % name)
	return null


static func _wrap(ds: Array) -> Array:
	var out: Array = []
	for d in ds:
		out.append({"__obj": "node", "d": d})
	return out


# ---------- what the script sees ----------

func _expr_of(obj: Dictionary) -> Expr:
	return obj["f"] if obj["__obj"] == "snap" else obj["node"].f


func _after(obj: Dictionary, vm_: PyVM) -> Dictionary:
	vm_.steps += AFTER_COST
	_fresh_cache()
	var src := _expr_of(obj)
	var params: Dictionary = tower.op_params()
	var key := "%s|%s|%s" % [str(src.t), tower.type, str(params)]
	if not _after_cache.has(key):
		var g := src.clone()
		match tower.type:
			"int":
				g.integrate()
			"merge", "newton", "bisect":
				pass
			_:
				TowerScript.transform(tower.type, g, params)
		_after_cache[key] = g
	return {"__obj": "snap", "node": obj["node"], "f": _after_cache[key]}


func py_attr(obj: Dictionary, name: String, vm_: PyVM):
	if obj["__obj"] == "node":
		return _node_attr(obj["d"], name, vm_)
	if obj["__obj"] == "tower":
		match name:
			"op":
				return tower.type
			"name":
				return tower.data["name"]
			"level":
				return tower.level
			"param":
				return tower.omega if tower.type == "harm" else tower.lam
			"range":
				return tower.range_px()
			"set_param":
				return {"__bm": "set_param", "self": obj}
		vm_.fail("타워(me)에는 .%s 가 없습니다" % name)
		return null
	var e = obj["node"]
	if not is_instance_valid(e):
		vm_.fail("이미 사라진 적입니다")
		return null
	var f := _expr_of(obj)
	var snap: bool = obj["__obj"] == "snap"
	match name:
		"f":
			return _tree(f, vm_)
		"text":
			return f.to_text()
		"value":
			return f.value_at(Game.x_end, e.tt)
		"damage":
			if not snap:
				return e.threat
			return 0 if f.is_zero() else EnemyScript.harm(f.value_at(Game.x_end, e.tt)) + e.members - 1
		"zero":
			return f.is_zero()
		"boss":
			return e.boss
		"members":
			return e.members
		"name":
			return Data.tpl_name(e.template)
		"special":
			return e.special
		"progress":
			return e.progress / maxf(1.0, e.main.map.total_length)
		"x":
			return e.x_now()
		"dist":
			return e.global_position.distance_to(tower.global_position)
		"speed":
			return e.speed()
		"after":
			return {"__bm": "after", "self": obj}
	vm_.fail("적에는 .%s 가 없습니다 (편집기 오른쪽의 API 목록 참고)" % name)
	return null


func py_call(obj: Dictionary, name: String, args: Array, _kwargs: Dictionary, vm_: PyVM):
	if obj["__obj"] == "tower" and name == "attack":
		if args.size() > 1:
			vm_.fail("attack()에는 적 하나, 또는 적의 리스트 하나를 주세요")
			return null
		chosen = args[0] if args.size() == 1 else null
		chose = true
		vm_.halt()   # jump to EOF: this run is over
		return null
	if obj["__obj"] == "node":
		if name == "has" and args.size() == 1 and args[0] is String:
			return _has(obj["d"], args[0])
		vm_.fail("has()에는 종류 이름 하나가 필요합니다: 예) f.has(\"sin\")")
		return null
	if obj["__obj"] == "tower":
		if name == "set_param":
			if args.size() != 1 or not args[0] is int:
				vm_.fail("set_param()에는 정수 하나가 필요합니다")
				return null
			if tower.type == "harm" and Progress.has("omega2") and args[0] in [1, 2]:
				tower.omega = args[0]
				return true
			if tower.type == "dtl" and Progress.has("dtl2") and args[0] in [1, 2]:
				tower.lam = args[0]
				return true
			return false
		vm_.fail("타워에는 %s()가 없습니다" % name)
		return null
	if not is_instance_valid(obj["node"]):
		vm_.fail("이미 사라진 적입니다")
		return null
	if name == "after":
		return _after(obj, vm_)
	vm_.fail("적에는 %s()가 없습니다" % name)
	return null


func py_repr(obj: Dictionary) -> String:
	match obj["__obj"]:
		"node":
			return obj["d"]["text"]
		"tower":
			return "<타워 %s>" % tower.data["name"]
		"snap":
			return "<예측 %s>" % (obj["f"] as Expr).to_text()
	if is_instance_valid(obj["node"]):
		return "<적 %s>" % obj["node"].f.to_text()
	return "<사라진 적>"
