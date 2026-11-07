extends Node2D
## Game scene for one stage: world, input, flow, combos, the chapter-1 fake ending.

const MapScript := preload("res://scripts/map.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const TowerScript := preload("res://scripts/tower.gd")
const CodeEditorScript := preload("res://scripts/code_editor.gd")
var code_editor = null
const ProjectileScript := preload("res://scripts/projectile.gd")
const EffectScript := preload("res://scripts/effect.gd")
const WaveScript := preload("res://scripts/wave_manager.gd")
const HudScript := preload("res://scripts/hud.gd")
const SPEEDS := [1.0, 2.0, 3.0]
const COMBO_WINDOW := 1.2

var map
var towers_node: Node2D
var enemies_node: Node2D
var projectiles_node: Node2D
var effects_node: Node2D
var wave_manager
var hud
var state: String = "intro"   # intro, build, wave, credits, result
var build_type: String = ""
var selected_tower = null
var occupied: Dictionary = {}
var speed_index: int = 0
var rng := RandomNumberGenerator.new()
var waves: Array = []
var wave_levels: Array = []   # original wave number of each played wave (short mode skips some)
var available_towers: Array = []
var combo: int = 0
var combo_timer: float = 0.0
var shake_amt: float = 0.0
var credits_paused: bool = false
var credits_timer: float = 0.0
var auto_timer: float = -1.0
const AUTO_DELAY := 1.5
var x_spawned: bool = false
var counter_hits: Dictionary = {}
var autotest: bool = false
var autotest_budget: bool = false
var autotest_slots: Array = []
var autotest_n: int = 0
var autotest_ts: float = 4.0
var autotest_plan: Array = []
var autotest_t0: int = 0
var autotest_order: bool = false   # stage needs "pre-processor first, then the rest"
var autotest_pre: String = "damp"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1.0
	rng.randomize()
	_parse_autotest_args()
	Game.reset()
	var full: Array = Data.stage_waves(Game.stage_id)
	wave_levels = Data.wave_levels()
	for lv in wave_levels:
		waves.append(full[int(lv) - 1])
	var allowed: Array = Data.chapter_towers(Data.chapter_of(Game.stage_id))
	for type in Data.TOWER_ORDER:
		if allowed.has(type) and Progress.has(Data.TOWERS[type]["research"]):
			available_towers.append(type)
	map = MapScript.new()
	_add_world(map)
	towers_node = _add_world(Node2D.new()) as Node2D
	enemies_node = _add_world(Node2D.new()) as Node2D
	projectiles_node = _add_world(Node2D.new()) as Node2D
	effects_node = _add_world(Node2D.new()) as Node2D
	wave_manager = WaveScript.new()
	wave_manager.main = self
	_add_world(wave_manager)
	var ui := CanvasLayer.new()
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	hud = HudScript.new()
	hud.main = self
	ui.add_child(hud)
	Game.integrity_depleted.connect(_on_lost)
	if autotest:
		_autotest_start.call_deferred()
	else:
		hud.show_intro()


func _add_world(n: Node) -> Node:
	n.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(n)
	return n


# ---------- flow ----------

func begin_game() -> void:
	hud.close_overlay()
	state = "build"
	Sfx.play("ui")
	hud.refresh()


## Early call: once the current wave has finished spawning, the next one may be called in for a bonus.
func can_call_early() -> bool:
	return state == "wave" and wave_manager.finished() and Game.wave < waves.size()


func early_bonus() -> int:
	return 5 + 3 * Game.wave


func start_wave() -> void:
	if can_call_early():
		var b := early_bonus()
		Game.add_rho(b)
		spawn_text(Vector2(Data.PLAY_W / 2.0, 290), "조기 호출  +%dρ" % b, Color("ffd166"), 20, 1.2)
		Game.wave += 1
		wave_manager.start_wave(Game.wave)
		spawn_text(Vector2(Data.PLAY_W / 2.0, 330), "웨이브 %d" % Game.wave, Color("ffd166"), 34, 1.4)
		Sfx.play("wave", 1.15)
		Game.changed.emit()
		return
	if state != "build" or Game.wave >= waves.size():
		return
	Game.wave += 1
	state = "wave"
	wave_manager.start_wave(Game.wave)
	spawn_text(Vector2(Data.PLAY_W / 2.0, 330), "웨이브 %d" % Game.wave, Color("ffd166"), 34, 1.4)
	Sfx.play("wave")
	Game.changed.emit()


var prof_enemy_max := 0
var _prof_t0 := 0


func _process(delta: float) -> void:
	if autotest:
		if _prof_t0 > 0:
			Algo.prof_frame_us += Time.get_ticks_usec() - _prof_t0
			Algo.prof_frames += 1
		_prof_t0 = Time.get_ticks_usec()
		prof_enemy_max = maxi(prof_enemy_max, enemies_node.get_child_count())
	if autotest:
		_autotest_tick()
	_update_shake(delta)
	if state == "credits":
		_credits_tick(delta)
	if get_tree().paused:
		return
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
	if build_type != "":
		_update_hover()   # colour follows the money, not only the mouse
	if state == "build" and Progress.auto_wave and Game.wave > 0:
		if auto_timer < 0.0:
			auto_timer = AUTO_DELAY
		auto_timer -= delta / maxf(Engine.time_scale, 0.01)   # real seconds, whatever the speed
		if auto_timer <= 0.0:
			auto_timer = -1.0
			start_wave()
	if state == "wave":
		Game.add_rho(Game.rho_rate() * delta)
		if wave_manager.finished() and alive_enemy_count() == 0:
			_on_wave_cleared()


func _on_wave_cleared() -> void:
	var bonus := 10 + 4 * Game.wave
	Game.add_rho(bonus)
	spawn_text(Vector2(Data.PLAY_W / 2.0, 380), "웨이브 %d 해결   +%dρ" % [Game.wave, bonus], Color("80deea"), 22, 1.8)
	for p in projectiles_node.get_children():
		p.queue_free()
	if Game.wave >= waves.size():
		_on_won()
		return
	state = "build"
	Sfx.play("clear")
	auto_timer = AUTO_DELAY
	hud.refresh()


func _stars() -> int:
	var s := 1
	if Game.integrity * 2 >= Game.start_integrity:
		s += 1
	if Game.leaked == 0:
		s += 1
	return s


func _on_won() -> void:
	var s := _stars()
	var gain := Progress.record_stage(Game.stage_id, s, Game.wave, Game.hard)
	cleared_recorded = true
	if Game.stage_id == "1-6" and not Progress.flag("fake_ending"):
		_start_credits()
		return
	# a finale cleared without the counterexample ever reaching the core (F9, x = 0, …) must still open the next chapter
	var ctr: String = Data.STAGES[Game.stage_id].get("counter", "")
	if ctr != "" and not Progress.flag(Data.COUNTERS[ctr]["flag"]):
		on_counterexample(ctr)
		return
	if Data.STAGES[Game.stage_id].get("final", false):
		Progress.set_flag("true_end")
		state = "credits"
		_freeze_world()
		Sfx.play("win")
		hud.show_true_end(s, gain)
		return
	state = "result"
	Sfx.play("win")
	hud.refresh()
	hud.show_result(true, s, gain)


func _on_lost() -> void:
	if state == "result" or state == "credits":
		return
	state = "result"
	_freeze_world()
	var gain := Progress.record_stage(Game.stage_id, 0, maxi(0, Game.wave - 1), Game.hard)
	Sfx.play("lose")
	hud.refresh()
	hud.show_result(false, 0, gain)


func _freeze_world() -> void:
	for n in [towers_node, enemies_node, projectiles_node, wave_manager]:
		n.process_mode = Node.PROCESS_MODE_DISABLED


func next_stage() -> String:
	var idx: int = Data.STAGE_ORDER.find(Game.stage_id)
	if idx < 0 or idx + 1 >= Data.STAGE_ORDER.size():
		return ""
	var nx: String = Data.STAGE_ORDER[idx + 1]
	return nx if Progress.stage_unlocked(nx) else ""


func go_stage(sid: String) -> void:
	Progress.current_stage = sid
	restart()


func restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


# ---------- the chapter-1 "ending" ----------

func _start_credits() -> void:
	state = "credits"
	credits_timer = 0.0
	Sfx.play("win")
	hud.show_credits()
	towers_node.process_mode = Node.PROCESS_MODE_DISABLED
	for p in projectiles_node.get_children():
		p.queue_free()


func _credits_tick(delta: float) -> void:
	credits_timer += delta
	if credits_timer > 9.0 and not x_spawned:
		x_spawned = true
		credits_paused = true
		Sfx.play("leak", 0.6)
		spawn_enemy("x_counter", 0.0)
		hud.credits_glitch("LIMIT BREAK\n수 방어전\n\n\n— THE END —\n\n\n?")
		for tw in occupied.values():
			spawn_text(tw.global_position + Vector2(0, -26), "?", Color("ef5350"), 18, 3.0)


## A counterexample reached the core. Returns true once it has reached `need` times and the reveal fires.
var cleared_recorded: bool = false   # this run's clear is already in the save (counter reveal or win)


func counter_reach(tpl: String, count: int = 1) -> bool:
	counter_hits[tpl] = int(counter_hits.get(tpl, 0)) + count
	if int(counter_hits[tpl]) >= int(Data.COUNTERS[tpl].get("need", 1)):
		on_counterexample(tpl)
		return true
	return false


func on_counterexample(tpl: String) -> void:
	var info: Dictionary = Data.COUNTERS[tpl].duplicate()
	# meeting the counterexample IS finishing the stage: record the clear (no need to play it again)
	if not cleared_recorded:
		cleared_recorded = true
		var s := maxi(1, _stars())
		var gain := Progress.record_stage(Game.stage_id, s, Game.wave, Game.hard)
		info["body"] = String(info["body"]) + "\n\n%s 클리어로 기록했습니다  %s%s" % [Game.stage_id,
			"★".repeat(s) + "☆".repeat(3 - s), ("   통찰 +%d" % gain) if gain > 0 else ""]
	map.glitch = 1.0
	shake(24.0)
	Sfx.play("lose")
	Progress.set_flag(info["flag"])
	if info.has("extra_flag"):
		Progress.set_flag(info["extra_flag"])
	Progress.add_insight(int(info["insight"]))
	state = "result"
	_freeze_world()
	hud.show_counterexample(info)


# ---------- combos & juice ----------

## Called by an enemy as it dies; returns the combo bonus ρ.
func on_enemy_killed(pos: Vector2) -> int:
	combo += 1
	combo_timer = COMBO_WINDOW
	Game.max_combo = maxi(Game.max_combo, combo)
	if combo >= 3:
		spawn_text(pos + Vector2(0, -40), "×%d 연쇄!" % combo, Color("ffd166"), 14 + mini(combo, 12))
		if combo % 5 == 0:
			shake(3.0 + combo * 0.3)
		return combo - 2
	return 0


func shake(amount: float) -> void:
	shake_amt = maxf(shake_amt, amount)


func _update_shake(delta: float) -> void:
	if map.glitch > 0.0:
		map.glitch = maxf(0.0, map.glitch - delta * 0.15)
	if shake_amt <= 0.01:
		position = Vector2.ZERO
		return
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt
	shake_amt = lerpf(shake_amt, 0.0, minf(1.0, delta * 12.0))


## G1: what the next wave holds.
func preview_text() -> String:
	if state not in ["build", "intro"] or Game.wave >= waves.size():
		return ""
	var groups: Array = waves[Game.wave]
	var parts := PackedStringArray()
	var lv: int = int(wave_levels[Game.wave]) if Game.wave < wave_levels.size() else Game.wave + 1
	for g in groups:
		var armor := Data.armor_power(g[0], lv)
		var tag := ""
		if armor > 0:   # multiplicity armour: bosses carry exactly xᵐ, others anywhere from 1 to xᵐ
			tag = (" · x%s" if Data.TEMPLATES[g[0]].get("boss", false) else " · ≤x%s") % (Expr.sup(armor) if armor > 1 else "")
		parts.append("%s%s ×%d" % [_tpl_name(g[0]), tag, int(g[1])])
	return "다음 웨이브 %d:   %s" % [Game.wave + 1, "   ·   ".join(parts)]


func _tpl_name(tpl: String) -> String:
	if Data.COUNTERS.has(tpl) and not Progress.flag(Data.COUNTERS[tpl]["flag"]):
		return "???"
	return Data.tpl_name(tpl)


# ---------- options ----------

func toggle_speed() -> void:
	speed_index = (speed_index + 1) % SPEEDS.size()
	Engine.time_scale = SPEEDS[speed_index]
	Sfx.play("ui")
	hud.refresh()


## Ultimate (chapter 2+): substitute x = 0 everywhere on the field, twice per stage.
func use_ultimate() -> void:
	if Game.ult_left <= 0 or state not in ["build", "wave"]:
		return
	var hit := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if Data.COUNTERS.has(e.template) and not Progress.flag(Data.COUNTERS[e.template]["flag"]):
			spawn_text(e.global_position + Vector2(0, -40), "반례에는 대입이 통하지 않습니다", Color("ef5350"), 14)
			continue
		if e.alive and e.special == "" and not e.f.is_constant():
			e.f.subst_x0()
			e.flash = 0.4
			hit += 1
			if e.f.is_zero():
				e._die()
			else:
				e._refresh()
	if hit == 0:
		spawn_text(Vector2(Data.PLAY_W / 2.0, 360), "대입할 함수가 없습니다", Color("b0bec5"), 16)
		return
	Game.ult_left -= 1
	shake(10.0)
	Sfx.play("eval", 0.6)
	spawn_text(Vector2(Data.PLAY_W / 2.0, 340), "x = 0 대입!   %d개의 함수가 상수가 되었습니다" % hit, Color("fff176"), 24, 1.6)
	Game.changed.emit()


## Pipeline prediction: what this enemy becomes if it walks past the current towers undisturbed.
## Each tower gets the number of shots it can fire while the enemy is inside its range, in path order.
func predict(e) -> Dictionary:
	var steps: Array = []
	if e.special != "":
		return {"steps": steps, "dead": false, "f": e.f, "dmg": e.leak_damage(e.threat)}
	var g: Expr = e.f.clone()
	var events: Array = []
	var spd: float = maxf(1.0, e.speed())
	for tw in occupied.values():
		if tw.type in ["int", "merge", "newton", "bisect"]:
			continue
		var first := -1.0
		var covered := 0.0
		var d: float = e.progress
		var r: float = tw.range_px()
		while d < map.total_length:
			if map.point_at(d).distance_to(tw.global_position) <= r:
				if first < 0.0:
					first = d
				covered += 10.0
			d += 10.0
		if first < 0.0:
			continue
		var shots := clampi(int(covered / spd * tw.rate()), 0, 12)
		if shots > 0:
			events.append([first, tw, shots])
	events.sort_custom(func(a, b): return a[0] < b[0])
	for ev in events:
		var tw = ev[1]
		for i in int(ev[2]):
			if g.is_zero() or not tw.useful_f(g):
				break
			var before := g.to_text()
			TowerScript.transform(tw.type, g, tw.op_params())
			if g.to_text() != before:
				steps.append([tw.glyph(), g.to_text()])
		if g.is_zero():
			break
	var dmg: int = 0 if g.is_zero() else EnemyScript.harm(g.value_at(Game.x_end, e.tt)) + int(e.members) - 1
	return {"steps": steps, "dead": g.is_zero(), "f": g, "dmg": e.leak_damage(dmg)}


func hovered_enemy():
	if state not in ["build", "wave"] or build_type != "":
		return null
	var m := get_global_mouse_position()
	var best = null
	var bd := 22.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.alive:
			var dd: float = e.global_position.distance_to(m)
			if dd < bd:
				bd = dd
				best = e
	return best


func toggle_auto() -> void:
	Progress.auto_wave = not Progress.auto_wave
	Progress.save_game()
	auto_timer = AUTO_DELAY
	Sfx.play("ui")
	hud.refresh()


func toggle_pause() -> void:
	if state not in ["build", "wave"]:
		return
	get_tree().paused = not get_tree().paused
	Sfx.play("ui")
	hud.refresh()


func toggle_sound() -> void:
	Sfx.cycle_mode()
	Sfx.play("ui")
	hud.refresh()


func buy_c1() -> void:
	if Game.buy_c1():
		Sfx.play("coin")


func buy_c2() -> void:
	if Game.buy_c2():
		Sfx.play("coin")


# ---------- building ----------

func select_build(type: String) -> void:
	if state not in ["build", "wave"]:
		hud.refresh()
		return
	build_type = "" if build_type == type else type
	selected_tower = null
	Sfx.play("ui")
	_update_hover()
	hud.refresh()


func cancel() -> void:
	build_type = ""
	selected_tower = null
	map.show_hover = false
	hud.refresh()


func try_build(c: Vector2i) -> void:
	if not map.is_buildable(c) or occupied.has(c):
		spawn_text(Data.cell_center(c), "지을 수 없는 칸", Color("ef5350"), 13)
		return
	var d: Dictionary = Data.TOWERS[build_type]
	if not Game.spend(int(d["cost"])):
		spawn_text(Data.cell_center(c), "ρ가 부족합니다", Color("ef5350"), 13)
		return
	var tw = TowerScript.new()
	tw.setup(build_type, self, c)
	towers_node.add_child(tw)
	occupied[c] = tw
	spawn_burst(tw.global_position, d["color"])
	Sfx.play("build")
	if not Input.is_key_pressed(KEY_SHIFT):
		build_type = ""
		selected_tower = tw
		map.show_hover = false
	hud.refresh()


func upgrade_selected() -> void:
	if is_instance_valid(selected_tower) and selected_tower.upgrade():
		Sfx.play("build", 1.25)
		hud.refresh()


func sell_selected() -> void:
	if not is_instance_valid(selected_tower):
		return
	var tw = selected_tower
	Game.add_rho(tw.sell_value())
	spawn_text(tw.global_position, "+%dρ" % tw.sell_value(), Color("ffd166"), 15)
	occupied.erase(tw.cell)
	tw.queue_free()
	selected_tower = null
	Sfx.play("ui")
	hud.refresh()


func cycle_omega() -> void:
	if is_instance_valid(selected_tower) and selected_tower.cycle_param():
		Sfx.play("pulse")
		hud.refresh()


## Axiom of induction: every enemy with exactly the same function falls with this one.
func induct(src) -> void:
	var txt: String = src.f.to_text()
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != src and e.alive and e.special == "" and e.f.to_text() == txt:
			spawn_zap(src.global_position, e.global_position, Color("ffd166"))
			e._die(true)
			n += 1
	if n > 0:
		spawn_text(src.global_position + Vector2(0, -50), "귀납: ×%d" % (n + 1), Color("ffd166"), 18)


func cycle_target() -> void:
	if is_instance_valid(selected_tower):
		selected_tower.target_mode = (selected_tower.target_mode + 1) % 3
		Sfx.play("ui")
		hud.refresh()


# ---------- input ----------

func _unhandled_input(event: InputEvent) -> void:
	if state not in ["build", "wave"] or (code_editor != null and code_editor.visible):
		return
	if event is InputEventMouseMotion:
		_update_hover()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_click(get_global_mouse_position())
	elif event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.keycode
		if kc == KEY_ESCAPE:
			cancel()
		elif kc == KEY_SPACE:
			start_wave()
		elif kc == KEY_U:
			upgrade_selected()
		elif kc == KEY_DELETE or kc == KEY_BACKSPACE:
			sell_selected()
		elif kc == KEY_T:
			cycle_target()
		elif kc == KEY_A:
			toggle_auto()
		elif kc == KEY_X:
			use_ultimate()
		elif kc == KEY_P:
			toggle_pause()
		elif kc == KEY_W:
			cycle_omega()
		elif kc == KEY_E:
			open_code_editor()
		elif kc == KEY_F9 and Progress.dev_mode:
			_dev_clear()
		elif kc == KEY_0 and available_towers.size() >= 10:
			select_build(available_towers[9])
		elif kc >= KEY_1 and kc <= KEY_9 and kc - KEY_1 < available_towers.size():
			select_build(available_towers[kc - KEY_1])


## 제논 towers: the strongest slow factor covering this point (1.0 = no field).
func slow_at(p: Vector2) -> float:
	var f := 1.0
	if state == "credits":
		return f
	for tw in occupied.values():
		if tw.type == "zeno" and tw.global_position.distance_to(p) <= tw.range_px():
			f = minf(f, float(tw.power()))
	return f


## 가속도 towers: the strongest rate boost covering this tower (1.0 = none; never boosts itself).
func haste_at(tw) -> float:
	var f := 1.0
	for a in occupied.values():
		if a.type == "accel" and a != tw and a.global_position.distance_to(tw.global_position) <= a.range_px():
			f = maxf(f, float(a.power()))
	return f


## The attack-algorithm editor (research 「알고리즘」). Opens on the selected tower, pauses the game.
func open_code_editor() -> void:
	if not Progress.has("code"):
		spawn_text(Vector2(Data.PLAY_W / 2.0, 360), "알고리즘 편집기는 4장부터 열립니다", Color("b0bec5"), 16)
		return
	if code_editor == null:
		code_editor = CodeEditorScript.new()
		code_editor.main = self
		add_child(code_editor)
	cancel_build_only()
	code_editor.open(selected_tower if is_instance_valid(selected_tower) else null)


func cancel_build_only() -> void:
	if build_type != "":
		build_type = ""
		map.show_hover = false


func _update_hover() -> void:
	map.show_hover = build_type != ""
	if build_type == "":
		return
	var c: Vector2i = map.cell_at(get_global_mouse_position())
	map.hover_cell = c
	map.hover_valid = map.is_buildable(c) and not occupied.has(c) and Game.rho >= int(Data.TOWERS[build_type]["cost"])
	map.hover_range = float(Data.TOWERS[build_type]["range"][0])


func _click(pos: Vector2) -> void:
	if pos.x >= Data.PLAY_W or pos.y < Data.TOP:
		return
	var c: Vector2i = map.cell_at(pos)
	if build_type != "":
		try_build(c)
		return
	selected_tower = occupied.get(c, null)
	if selected_tower != null:
		Sfx.play("ui")
	hud.refresh()


# ---------- spawning helpers ----------

func alive_enemy_count() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.alive:
			n += 1
	return n


func spawn_enemy(template: String, progress: float) -> void:
	var e = EnemyScript.new()
	var lv: int = int(wave_levels[clampi(Game.wave - 1, 0, wave_levels.size() - 1)]) if not wave_levels.is_empty() else Game.wave
	e.setup(template, self, Data.make_expr(template, rng, lv), progress)
	enemies_node.add_child(e)
	if Progress.see(template) and not autotest:
		spawn_text(e.global_position + Vector2(40, -30), "새 개체: %s" % _tpl_name(template), Color("5bc0be"), 13, 2.0)


## Developer: finish the current stage at once (counts as a 3-star clear).
func _dev_clear() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.alive = false
		e.queue_free()
	wave_manager.queue.clear()
	wave_manager.spawning = false
	Game.wave = waves.size()
	Game.leaked = 0
	spawn_text(Vector2(Data.PLAY_W / 2.0, 330), "개발자: 즉시 클리어", Color("ffd166"), 24, 1.5)
	_on_won()


func spawn_child(f: Expr, progress: float, at: Vector2) -> void:
	var e = EnemyScript.new()
	e.setup("child", self, f, progress)
	enemies_node.add_child(e)
	spawn_zap(at, e.global_position, Color("ffb74d"))
	spawn_text(e.global_position + Vector2(0, -28), "f′", Color("ffb74d"), 12)


func spawn_projectile(from: Vector2, target, op: String, params: Dictionary, color: Color) -> void:
	var p = ProjectileScript.new()
	p.target = target
	p.op = op
	p.params = params
	p.color = color
	p.position = from
	projectiles_node.add_child(p)


func _effect(kind: String, pos: Vector2, color: Color, life: float):
	var fx = EffectScript.new()
	fx.kind = kind
	fx.position = pos
	fx.color = color
	fx.life = life
	fx.max_life = life
	effects_node.add_child(fx)
	return fx


func spawn_text(pos: Vector2, text: String, color: Color = Color.WHITE, size: int = 14, life: float = 0.9) -> void:
	var fx = _effect("text", pos, color, life)
	fx.text = text
	fx.size = size


func spawn_ring(pos: Vector2, radius: float, color: Color) -> void:
	var fx = _effect("ring", pos, color, 0.45)
	fx.radius = radius


func spawn_burst(pos: Vector2, color: Color) -> void:
	_effect("burst", pos, color, 0.4)


func spawn_zap(a: Vector2, b: Vector2, color: Color) -> void:
	var fx = _effect("zap", Vector2.ZERO, color, 0.25)
	var pts := PackedVector2Array([a])
	var n := 7
	var perp := (b - a).normalized().orthogonal()
	for i in range(1, n):
		pts.append(a.lerp(b, float(i) / n) + perp * randf_range(-7.0, 7.0))
	pts.append(b)
	fx.pts = pts


# ---------- headless self-test ----------
# godot --headless --path . res://scenes/main.tscn -- --autotest --stage=1-3 [--research=all|none|id,id] [--budget]

func _parse_autotest_args() -> void:
	var args := OS.get_cmdline_user_args()
	if not "--autotest" in args:
		return
	autotest = true
	Progress.persist = false
	Progress.auto_axioms = true
	Progress.research = {}
	Progress.flags = {}
	for a in args:
		if a.begins_with("--stage="):
			Progress.current_stage = a.substr(8)
		elif a == "--budget":
			autotest_budget = true
		elif a == "--hard":
			Game.hard = true
		elif a == "--no-algo":
			autotest_no_algo = true
		elif a.begins_with("--shot="):
			autotest_shot = a.substr(7)
		elif a == "--ult":
			autotest_ult = true
		elif a.begins_with("--ts="):
			autotest_ts = float(a.substr(5))
		elif a.begins_with("--algo="):   # --algo=damp:res://tests/algos/damp.py  (towers of that type run the file)
			var kv := a.substr(7).split(":", true, 1)
			Progress.algo_default[kv[0]] = kv[1]
		elif a.begins_with("--research="):
			var which := a.substr(11)
			if which == "all":
				for node in Data.RESEARCH:
					Progress.research[node["id"]] = true
			elif which != "none":
				for id in which.split(","):
					Progress.research[id] = true


func _autotest_start() -> void:
	# under the chapter-6 curse the bot writes algorithms like a player would (unless --algo= was given)
	if Data.cursed() and Progress.algo_default.is_empty() and not autotest_no_algo:
		Progress.research["code"] = true
		for type in available_towers:
			if type == "int":
				continue
			var fn := "smart.py"
			if type == "diff":
				fn = "coop_d.py"
			elif type == "merge":
				fn = "coop_sum.py"
			elif type == "div":
				fn = "coop_div.py"
			elif type == "damp":
				fn = "damp.py"
			elif type in ["newton", "bisect"]:
				fn = "root.py"
			Progress.algo_default[type] = "res://tests/algos/" + fn
	print("[autotest] stage %s, towers %s" % [Game.stage_id, str(available_towers)])
	begin_game()
	autotest_t0 = Time.get_ticks_msec()
	Engine.time_scale = autotest_ts
	autotest_plan = _autotest_plan()
	for pc in map.path_cells.keys():
		for off in [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			var c0: Vector2i = pc + off
			if map.is_buildable(c0) and not autotest_slots.has(c0):
				autotest_slots.append(c0)
	for m in Data.STAGES[Game.stage_id]["mix"] + Data.stage_bosses(Data.STAGES[Game.stage_id]):
		var kd: String = Data.TEMPLATES[m[0]]["kind"]
		if (kd == "exp2" and available_towers.has("damp")) or (kd == "signal" and available_towers.has("lpf")):
			autotest_order = true
			autotest_pre = "lpf" if kd == "signal" else "damp"
	if autotest_order:
		autotest_slots.sort_custom(func(a, b): return _slot_progress(a) < _slot_progress(b))
	if not autotest_budget:
		Game.rho = 100000
		for i in 26:
			build_type = available_towers[i % available_towers.size()]
			try_build(autotest_slots[(i * 7) % autotest_slots.size()])
			if i % 2 == 0:
				upgrade_selected()
				upgrade_selected()


var autotest_probe: float = 0.0
var autotest_ult: bool = false
var autotest_shot: String = ""
var autotest_no_algo: bool = false   # --no-algo: suffer the curse with the default (cursed) targeting
var autotest_shot_frames: int = 0
var autotest_pred: int = 0


func _autotest_tick() -> void:
	if autotest_shot != "":   # --shot=path.png: open the algorithm editor mid-stage and save a screenshot
		if code_editor != null and code_editor.visible:
			autotest_shot_frames += 1
			if autotest_shot_frames == 20:
				get_viewport().get_texture().get_image().save_png(autotest_shot)
				print("[autotest] screenshot " + autotest_shot)
				code_editor.close()
				autotest_shot = ""
			return
		if Game.wave >= 3 and state == "wave" and not occupied.is_empty():
			selected_tower = occupied.values()[0]
			open_code_editor()
			return
	# exercise the hover prediction (and optionally the ultimate) so runtime errors surface in sweeps
	autotest_probe -= get_process_delta_time()
	if autotest_probe <= 0.0 and state == "wave":
		autotest_probe = 2.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.alive:
				var pr: Dictionary = predict(e)
				autotest_pred += 1
				if autotest_pred == 1:
					print("[autotest] predict sample: %s -> dead=%s steps=%d" % [e.label, str(pr["dead"]), pr["steps"].size()])
				break
		if autotest_ult and Game.wave >= 8 and Game.ult_left > 0:
			use_ultimate()
	if state == "build":
		if autotest_budget:
			_autotest_spend()
		start_wave()
	elif state == "result":
		_autotest_finish()
	elif state == "credits" and Data.STAGES[Game.stage_id].get("final", false):
		_autotest_finish()      # the true ending
	elif state == "credits" and not x_spawned:
		credits_timer = 100.0   # skip ahead to the counterexample


func _autotest_spend() -> void:
	var guard := 0
	while guard < 40:
		guard += 1
		if Game.c2_unlocked() and Game.c2_cost() < Game.rho * 0.4:
			Game.buy_c2()
			continue
		if Game.c1_cost() < Game.rho * 0.15:
			Game.buy_c1()
			continue
		var want: String = autotest_plan[autotest_n % autotest_plan.size()] if Data.is_numeric_stage(Game.stage_id) else _autotest_best_tower()
		if autotest_order and autotest_n < 6:
			want = [autotest_pre, "dm1" if autotest_pre == "damp" else "harm", autotest_pre, "harm", "dm1", "diff"][autotest_n]
			if not available_towers.has(want):
				want = _autotest_best_tower()
		if autotest_n < 40 and Game.rho >= int(Data.TOWERS[want]["cost"]):
			var slot: Vector2i = autotest_slots[(autotest_n * 7) % autotest_slots.size()]
			if autotest_order:
				slot = _autotest_slot_for(want)
			var tries := 0
			while occupied.has(slot) and tries < 200:
				slot = autotest_slots[randi() % autotest_slots.size()]
				tries += 1
			build_type = want
			try_build(slot)
			autotest_n += 1
			if want == "harm" and Progress.has("omega2") and occupied.has(slot):
				occupied[slot].omega = _autotest_best_omega()
			if want == "dtl" and Progress.has("dtl2") and occupied.has(slot):
				occupied[slot].lam = _autotest_best_lambda()
			continue
		var cheapest = null
		for tw in occupied.values():
			if tw.level < 3 and (cheapest == null or tw.upgrade_cost() < cheapest.upgrade_cost()):
				cheapest = tw
		if cheapest != null and Game.rho >= cheapest.upgrade_cost() and autotest_n >= 6:
			selected_tower = cheapest
			upgrade_selected()
			continue
		break


func _slot_progress(c: Vector2i) -> float:
	var p := Data.cell_center(c)
	var best := INF
	var best_d := 0.0
	var d := 0.0
	while d <= map.total_length:
		var dist: float = p.distance_to(map.point_at(d))
		if dist < best:
			best = dist
			best_d = d
		d += 20.0
	return best_d


## Damping fields go early on the path (they must act first); everything else is spread over the rest.
func _autotest_slot_for(type: String) -> Vector2i:
	var n := autotest_slots.size()
	var lo := 0
	var hi := n
	if autotest_order:
		if type == autotest_pre:
			hi = int(n * 0.35)
		else:
			lo = int(n * 0.3)
	var free: Array = []
	for i in range(lo, hi):
		if not occupied.has(autotest_slots[i]):
			free.append(autotest_slots[i])
	if free.is_empty():
		for c in autotest_slots:
			if not occupied.has(c):
				free.append(c)
	if free.is_empty():
		return autotest_slots[0]
	return free[(autotest_n * 7) % free.size()]


func _autotest_best_lambda() -> int:
	var w := mini(Game.wave, waves.size() - 1)
	var c1 := 0
	var c2 := 0
	for g in waves[w]:
		if Data.TEMPLATES[g[0]].get("special", "") != "":
			continue
		var f: Expr = Data.make_expr(g[0], rng, w + 1)
		if f.has_t_mode(1):
			c1 += int(g[1])
		if f.has_t_mode(2):
			c2 += int(g[1])
	var n2 := 0
	for tw in occupied.values():
		if tw.type == "dtl" and tw.lam == 2:
			n2 += 1
	return 2 if c2 > c1 * (1 + n2) else 1


func _autotest_best_omega() -> int:
	var w := mini(Game.wave, waves.size() - 1)
	var c1 := 0
	var c2 := 0
	for g in waves[w]:
		var f: Expr = Data.make_expr(g[0], rng, w + 1)
		if f.has_mode(0, 1):
			c1 += int(g[1])
		if f.has_mode(0, 2):
			c2 += int(g[1])
	var n2 := 0
	for tw in occupied.values():
		if tw.type == "harm" and tw.omega == 2:
			n2 += 1
	return 2 if c2 > c1 * (1 + n2) else 1


## Reads the next wave like a player reading the preview: which operator helps the most enemies?
func _autotest_best_tower() -> String:
	var w := mini(Game.wave, waves.size() - 1)
	var counts := {}
	var owned := {}
	for tw in occupied.values():
		owned[tw.type] = int(owned.get(tw.type, 0)) + 1
	for g in waves[w]:
		var sp: String = Data.TEMPLATES[g[0]].get("special", "")
		if sp == "root":
			for tw in ["newton", "bisect"]:
				if available_towers.has(tw):
					counts[tw] = int(counts.get(tw, 0)) + int(g[1]) * (2 if (tw == "bisect" and g[0] == "root_cyc") or (tw == "newton" and g[0] != "root_cyc") else 1)
			continue
		if sp == "godel":
			continue
		for i in 4:
			var f0: Expr = Data.make_expr(g[0], rng, w + 1)
			# look a few operations ahead: x + eˣ needs D now and log later, so both count
			var forms: Array = [f0]
			var frontier: Array = [f0]
			for depth in (3 if Data.chapter_of(Game.stage_id) >= 3 else 0):
				var nxt: Array = []
				for h: Expr in frontier:
					for tt in ["sub", "div", "divx", "diff", "log2", "sqrt"]:
						if not available_towers.has(tt) or not TowerScript.op_useful(tt, h, 2 if tt == "div" else 1):
							continue
						var h2: Expr = h.clone()
						if TowerScript.transform(tt, h2, {"k": 2 if tt == "div" else 1, "n": 1, "mult": 1.0, "w": 1, "lam": 1}) and not h2.is_zero():
							nxt.append(h2)
				frontier = nxt.slice(0, 6)
				forms += frontier
			var counted := {}
			for f: Expr in forms:
				var direct := false
				for dt in ["diff", "dm1", "harm"]:
					if available_towers.has(dt) and TowerScript.op_useful(dt, f, 1):
						direct = true
				for type in available_towers:
					if type == "int" or type == "merge":
						continue
					if type == "damp" and direct:
						continue
					var ok: bool = TowerScript.op_useful(type, f, 2 if type == "div" else 1)
					if type == "harm" and Progress.has("omega2"):
						ok = f.has_mode(0, 1) or f.has_mode(0, 2)
					if type == "dtl":
						ok = f.has_t_mode(1) or (Progress.has("dtl2") and f.has_t_mode(2))
					if type == "newton" or type == "bisect":
						ok = false
					if not ok and available_towers.has("damp") and type != "damp" and f.has_growing():
						var damped: Expr = f.clone()
						damped.shift(-1)   # what it becomes after the damping field
						ok = TowerScript.op_useful(type, damped, 1)
					if ok and not counted.has(type):
						counted[type] = true
						counts[type] = int(counts.get(type, 0)) + int(g[1])
	var best := ""
	var best_score := -1.0
	for type in counts:
		# value per ρ, with diminishing returns for duplicates
		var sc: float = float(counts[type]) / float(Data.TOWERS[type]["cost"]) / (1.0 + (0.8 if Data.chapter_of(Game.stage_id) >= 3 else 0.35) * int(owned.get(type, 0)))
		if sc > best_score:
			best_score = sc
			best = type
	var total := 0
	for g in waves[w]:
		total += int(g[1])
	if available_towers.has("merge") and total >= 18 and occupied.size() >= 4 and int(owned.get("merge", 0)) < 3:
		var msc: float = float(total) * 0.6 / float(Data.TOWERS["merge"]["cost"]) / (1.0 + 0.6 * int(owned.get("merge", 0)))
		if msc > best_score:
			best_score = msc
			best = "merge"
	if best == "":
		best = available_towers[0]
	# under the curse, trig enemies die only through D + Σ teamwork: keep both around
	if Data.cursed() and available_towers.has("merge") and available_towers.has("diff"):
		var trig := false
		var freq2 := false
		for g in waves[w]:
			if Data.TEMPLATES[g[0]].get("kind", "") == "trig":
				trig = true
			if String(Data.TEMPLATES[g[0]].get("name", "")).contains("2x"):
				freq2 = true
		if trig:
			var nd := int(owned.get("diff", 0))
			var nm := int(owned.get("merge", 0))
			var nv := int(owned.get("div", 0))
			if freq2 and available_towers.has("div") and nv < 2 and nd >= 2 and nm >= 1:
				best = "div"
			elif nd < 5 or nm < 3:
				best = "diff" if nd <= nm * 2 else "merge"
	# support towers once the operators stand: about one 제논 per 10, one 가속도 and one 복원력 per 12
	if available_towers.has("zeno") and occupied.size() >= 8 and int(owned.get("zeno", 0)) * 10 < occupied.size():
		best = "zeno"
	elif available_towers.has("accel") and occupied.size() >= 12 and int(owned.get("accel", 0)) * 12 < occupied.size():
		best = "accel"
	elif available_towers.has("spring") and occupied.size() >= 10 and int(owned.get("spring", 0)) * 12 < occupied.size() - 4:
		best = "spring"
	if available_towers.has("int") and not Data.cursed() and int(owned.get("int", 0)) < 2 and occupied.size() >= 6 and occupied.size() % 5 == 0:
		best = "int"
	return best


## A sensible player builds what the stage needs: mostly −k/÷2, plus specialists only if their targets appear.
func _autotest_plan() -> Array:
	var kinds := {}
	for m in Data.STAGES[Game.stage_id]["mix"]:
		kinds[Data.TEMPLATES[m[0]]["kind"]] = true
	for b in Data.stage_bosses(Data.STAGES[Game.stage_id]):
		kinds[Data.TEMPLATES[b[0]]["kind"]] = true
	var plan: Array = []
	if kinds.has("poly") or kinds.has("exp") or kinds.has("trig"):
		plan = ["diff", "sub", "diff"]
		if kinds.has("exp"):
			plan += ["dm1", "dm1"]
		if kinds.has("trig"):
			plan += ["harm", "harm"]
		plan += ["diff", "int", "sub"]
	if kinds.has("num") or kinds.has("sq") or kinds.has("p2"):
		plan += ["sub", "div", "sub", "div", "sub"]
		if kinds.has("sq"):
			plan.append("sqrt")
		if kinds.has("p2"):
			plan.append("log2")
	var out: Array = []
	for tw in plan:
		if available_towers.has(tw):
			out.append(tw)
	return out


func _autotest_finish() -> void:
	var algo_errs := 0
	for row in Algo.console:
		if row[1]:
			algo_errs += 1
			print("[autotest] algo error: " + str(row[0]))
	if not Progress.algo_default.is_empty():
		print("[autotest] algorithms %s, errors %d" % [str(Progress.algo_default), algo_errs])
	var comp := {}
	for tw in occupied.values():
		var key: String = tw.glyph()
		comp[key] = int(comp.get(key, 0)) + 1
	print("[autotest] towers: ", comp)
	print("[prof] algo_ms=%d runs=%d steps=%d frames=%d frame_ms=%d enemies_max=%d" % [Algo.prof_us / 1000, Algo.prof_runs, Algo.prof_steps, Algo.prof_frames, Algo.prof_frame_us / 1000, prof_enemy_max])
	print("[autotest] done: flags=%s stage=%s won=%s wave=%d integrity=%d kills=%d leaked=%d combo=%d towers=%d met_x=%s wall=%.1fs" % [",".join(PackedStringArray(Progress.flags.keys())), Game.stage_id, str(Game.wave >= 15 and Game.integrity > 0), Game.wave, Game.integrity, Game.kills, Game.leaked, Game.max_combo, occupied.size(), str(Progress.flag("met_x")), (Time.get_ticks_msec() - autotest_t0) / 1000.0])
	autotest = false
	get_tree().quit()
