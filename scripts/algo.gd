class_name Algo
extends RefCounted
## A tower's attack algorithm: runs the player's .py file (PyVM) and exposes enemies and the tower to it.
## The script defines  def attack(enemies):  and returns an enemy, a list of enemies, or None.

const EnemyScript := preload("res://scripts/enemy.gd")
const TowerScript := preload("res://scripts/tower.gd")
const CONSOLE_MAX := 120

static var console: Array = []          # [text, is_error] — shown in the editor
static var console_serial: int = 0      # bumps on every new line so the editor knows to redraw

var tower = null
var vm: PyVM = null
var vm_src: String = ""
var vm_name: String = ""
var last_error: String = ""


static func log_line(s: String, is_error: bool = false) -> void:
	console.append([s, is_error])
	while console.size() > CONSOLE_MAX:
		console.pop_front()
	console_serial += 1


func _init(p_tower) -> void:
	tower = p_tower


func dispose() -> void:
	if vm != null:
		vm.dispose()
		vm = null


func _tag() -> String:
	return "[%s %s]" % [tower.glyph(), tower.algo]


## Compile (if the file changed) and run attack(). Returns {"ok", "targets": Array of enemy nodes, "error"}.
func run(cands: Array, dry: bool = false) -> Dictionary:
	var src: String = Progress.read_script(tower.algo)
	if vm == null or src != vm_src or vm_name != tower.algo:
		dispose()
		vm = PyVM.new()
		vm.host = self
		vm_src = src
		vm_name = tower.algo
		vm.set_global("me", {"__obj": "tower"})
		vm.set_global("set_param", {"__bm": "set_param", "self": {"__obj": "tower"}})
		_set_dynamic()
		if not vm.load_source(src):
			return _error(vm.error_text())
	_set_dynamic()
	var proxies: Array = []
	for e in cands:
		proxies.append({"__obj": "enemy", "node": e})
	vm.output.clear()
	var res = vm.run_fn("attack", [proxies])
	for line in vm.output:
		log_line("%s %s" % [_tag(), line])
	if vm.err != "":
		return _error(vm.error_text())
	if last_error != "":
		last_error = ""
		if not dry:
			log_line("%s 오류가 사라졌습니다" % _tag())
	var targets: Array = []
	var items: Array = res if res is Array else ([] if (res == null or res is bool) else [res])
	for it in items:
		if not (it is Dictionary and it.has("__obj") and it["__obj"] in ["enemy", "snap"]):
			return _error("attack()은 적, 적의 리스트, 또는 None을 돌려줘야 합니다 (받은 것: %s)" % vm._str(it, true))
		var node = it["node"]
		if is_instance_valid(node) and node.alive and node in cands and not node in targets:
			targets.append(node)
	return {"ok": true, "targets": targets, "error": "", "value": res}


func _set_dynamic() -> void:
	vm.set_global("wave", Game.wave)
	vm.set_global("rho", int(Game.rho))
	vm.set_global("integrity", Game.integrity)


func _error(msg: String) -> Dictionary:
	if msg != last_error:
		log_line("%s %s" % [_tag(), msg], true)
		Sfx.play("ui", 0.6)
	last_error = msg
	return {"ok": false, "targets": [], "error": msg}


# ---------- what the script sees ----------

func _expr_of(obj: Dictionary) -> Expr:
	return obj["f"] if obj["__obj"] == "snap" else obj["node"].f


static func _armor(f: Expr) -> int:
	var n := 0
	var p := f.clone()
	while n < 12 and p.divisible_by_x() and not p.is_constant():
		p.div_x()
		n += 1
	return n


func _after(obj: Dictionary) -> Dictionary:
	var g := _expr_of(obj).clone()
	match tower.type:
		"int":
			g.integrate()
		"merge", "newton", "bisect":
			pass
		_:
			TowerScript.transform(tower.type, g, tower.op_params())
	return {"__obj": "snap", "node": obj["node"], "f": g}


func py_attr(obj: Dictionary, name: String, vm_: PyVM):
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
		"f", "text":
			return f.to_text()
		"value":
			return f.value_at(Game.x_end, e.tt)
		"damage":
			if not snap:
				return e.threat
			return 0 if f.is_zero() else EnemyScript.harm(f.value_at(Game.x_end, e.tt)) + e.members - 1
		"zero":
			return f.is_zero()
		"const":
			return f.is_constant()
		"degree":
			return f.degree()
		"ann":
			var out: Array = []
			var m := f.modes()
			for mu: Vector2i in m:
				out.append([mu.x, mu.y, int(m[mu]) + 1])
			out.sort_custom(func(p, q): return p[1] < q[1] if p[1] != q[1] else p[0] < q[0])
			return out
		"ann_degree":
			return f.ann_degree()
		"armor":
			return _armor(f)
		"growing":
			return f.has_growing()
		"has_t":
			return f.has_t()
		"freq":
			return f.max_freq()
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
		"useful":
			return tower.useful_f(f) if snap else tower.useful(e)
		"mult", "after", "has_mode":
			return {"__bm": name, "self": obj}
	vm_.fail("적에는 .%s 가 없습니다 (편집기 오른쪽의 API 목록 참고)" % name)
	return null


func py_call(obj: Dictionary, name: String, args: Array, _kwargs: Dictionary, vm_: PyVM):
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
	var f := _expr_of(obj)
	match name:
		"after":
			return _after(obj)
		"mult", "has_mode":
			if args.is_empty() or args.size() > 2 or not (args[0] is int) or (args.size() == 2 and not args[1] is int):
				vm_.fail("%s(a, b=0)에는 정수가 필요합니다: 고윳값 a + bi" % name)
				return null
			var a: int = args[0]
			var b: int = absi(args[1]) if args.size() == 2 else 0
			var mu := Vector2i(a, b)
			var m := f.modes()
			var k: int = int(m[mu]) + 1 if m.has(mu) else 0
			return k if name == "mult" else k > 0
	vm_.fail("적에는 %s()가 없습니다" % name)
	return null


func py_repr(obj: Dictionary) -> String:
	match obj["__obj"]:
		"tower":
			return "<타워 %s>" % tower.data["name"]
		"snap":
			return "<예측 %s>" % (obj["f"] as Expr).to_text()
	if is_instance_valid(obj["node"]):
		return "<적 %s>" % obj["node"].f.to_text()
	return "<사라진 적>"
