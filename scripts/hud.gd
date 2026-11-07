extends Control
## Top bar, operator panel, tower info, income formula, wave preview, overlays, credits.

var main
var lbl_stage: Label
var lbl_rho: Label
var lbl_rate: Label
var lbl_life: Label
var lbl_wave: Label
var btn_sound: Button
var btn_start: Button
var btn_speed: Button
var btn_auto: Button
var btn_pause: Button
var tower_buttons: Dictionary = {}
var info_title: Label
var info_body: Label
var btn_upgrade: Button
var btn_sell: Button
var btn_target: Button
var btn_algo: Button
var lbl_formula: Label
var btn_c1: Button
var btn_c2: Button
var lbl_preview: Label
var lbl_combo: Label
var overlay: Control = null
var group_button: Button = null
var btn_ult: Button
var tip: Label = null
var tip_poll: float = 0.0
const GROUP_ARITH := ["sub", "div", "sqrt", "log2"]
var credits: Label = null
var poll: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Data.make_theme()
	_build_top_bar()
	_build_side_panel()
	lbl_preview = _label("", 13, Color("b0bec5"))
	lbl_preview.position = Vector2(12, 692)
	lbl_preview.size = Vector2(Data.PLAY_W - 24, 24)
	lbl_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl_preview)
	lbl_combo = _label("", 28, Color("ffd166"))
	lbl_combo.position = Vector2(Data.PLAY_W - 260, 52)
	lbl_combo.size = Vector2(240, 40)
	lbl_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_combo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl_combo)
	Game.changed.connect(refresh)
	refresh()


func _process(delta: float) -> void:
	_update_tip(delta)
	poll -= delta
	if poll <= 0.0:
		poll = 0.12
		refresh()
	if credits != null and is_instance_valid(credits) and not main.credits_paused:
		credits.position.y -= 42.0 * delta / maxf(Engine.time_scale, 0.01)


func _label(text: String, size: int, color: Color = Color("e0e1dd")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _button(text: String, cb: Callable, size: int = 15) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(cb)
	return b


func _build_top_bar() -> void:
	var bar := Panel.new()
	bar.size = Vector2(1280, 40)
	add_child(bar)
	var hb := HBoxContainer.new()
	hb.position = Vector2(12, 4)
	hb.size = Vector2(1256, 32)
	hb.add_theme_constant_override("separation", 20)
	bar.add_child(hb)
	lbl_stage = _label("", 15, Color("5bc0be"))
	lbl_rho = _label("", 18, Color("ffd166"))
	lbl_rate = _label("", 13, Color("c5e1a5"))
	lbl_life = _label("", 17, Color("80deea"))
	lbl_wave = _label("", 16)
	for l in [lbl_stage, lbl_rho, lbl_rate, lbl_life, lbl_wave]:
		l.size_flags_vertical = Control.SIZE_FILL
		hb.add_child(l)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)
	btn_sound = _button("", func(): main.toggle_sound(), 13)
	btn_sound.custom_minimum_size = Vector2(100, 0)
	btn_speed = _button("1×", func(): main.toggle_speed())
	btn_speed.custom_minimum_size = Vector2(46, 0)
	btn_pause = _button("일시정지", func(): main.toggle_pause())
	btn_pause.custom_minimum_size = Vector2(76, 0)
	btn_start = _button("▶ 웨이브 시작", func(): main.start_wave(), 16)
	btn_start.custom_minimum_size = Vector2(160, 0)
	btn_ult = _button("", func(): main.use_ultimate(), 13)
	btn_ult.custom_minimum_size = Vector2(118, 0)
	btn_ult.tooltip_text = "[X] 화면의 모든 함수에 x = 0을 대입합니다. 스테이지당 2회."
	hb.add_child(btn_ult)
	btn_auto = _button("", func(): main.toggle_auto(), 13)
	btn_auto.custom_minimum_size = Vector2(96, 0)
	for b in [btn_sound, btn_auto, btn_speed, btn_pause, btn_start]:
		hb.add_child(b)


func _build_side_panel() -> void:
	var side := Panel.new()
	side.position = Vector2(Data.PLAY_W, Data.TOP)
	side.size = Vector2(1280 - Data.PLAY_W, 720 - Data.TOP)
	add_child(side)
	var vb := VBoxContainer.new()
	vb.position = Vector2(8, 8)
	vb.size = Vector2(side.size.x - 16, side.size.y - 16)
	vb.add_theme_constant_override("separation", 5)
	side.add_child(vb)
	vb.add_child(_label("연산", 13, Color("5bc0be")))
	# the operator list scrolls, so a long list never pushes the income buttons off-screen
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 110)
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5)
	scroll.add_child(list)
	var idx := 1
	var grouped := Data.chapter_of(Game.stage_id) >= 2
	var arith_count := 0
	for type in main.available_towers:
		if GROUP_ARITH.has(type):
			arith_count += 1
	if grouped and arith_count > 0:
		group_button = _button("", func():
			Progress.palette_open = not Progress.palette_open
			Progress.save_game()
			Sfx.play("ui")
			refresh(), 13)
		group_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		group_button.custom_minimum_size = Vector2(0, 24)
		group_button.add_theme_color_override("font_color", Color("b0bec5"))
		list.add_child(group_button)
	for type in main.available_towers:
		var b := _button("", main.select_build.bind(type), 14)
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 24 if main.available_towers.size() > 8 else (28 if main.available_towers.size() > 6 else 32))
		b.add_theme_color_override("font_color", Data.TOWERS[type]["color"])
		b.tooltip_text = "[%d] %s" % [idx, Data.TOWERS[type]["desc"]]
		tower_buttons[type] = b
		list.add_child(b)
		idx += 1
	vb.add_child(HSeparator.new())
	info_title = _label("", 16, Color("ffd166"))
	vb.add_child(info_title)
	info_body = _label("", 12)
	info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_body.custom_minimum_size = Vector2(vb.size.x, 0)
	info_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	vb.add_child(info_body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	btn_upgrade = _button("강화", func(): main.upgrade_selected(), 13)
	btn_upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_sell = _button("판매", func(): main.sell_selected(), 13)
	btn_sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(btn_upgrade)
	row.add_child(btn_sell)
	vb.add_child(row)
	btn_target = _button("조준", func():
		if is_instance_valid(main.selected_tower) and main.selected_tower.param_label() != "":
			main.cycle_omega()
		else:
			main.cycle_target(), 13)
	vb.add_child(btn_target)
	btn_algo = _button("", func(): main.open_code_editor(), 13)
	vb.add_child(btn_algo)
	vb.add_child(HSeparator.new())
	vb.add_child(_label("수입 (웨이브 중에만)", 12, Color("5bc0be")))
	lbl_formula = _label("", 15, Color("c5e1a5"))
	vb.add_child(lbl_formula)
	btn_c1 = _button("", func(): main.buy_c1(), 13)
	btn_c2 = _button("", func(): main.buy_c2(), 13)
	vb.add_child(btn_c1)
	vb.add_child(btn_c2)


func refresh() -> void:
	if lbl_rho == null or main == null:
		return
	var st: Dictionary = Data.STAGES[Game.stage_id]
	lbl_stage.text = "%s %s%s" % [Game.stage_id, st["name"], "  · 하드" if Game.hard else ""]
	lbl_rho.text = "ρ %d" % int(Game.rho)
	lbl_rate.text = "+%d/s" % Game.rho_rate()
	lbl_life.text = "무결성 %d" % Game.integrity
	_chg(lbl_wave, "text", "웨이브 %d / %d%s" % [Game.wave, main.waves.size(), "  (짧게)" if Progress.dev_short else ""])
	var early: bool = main.can_call_early()
	_chg(btn_start, "disabled", main.state != "build" and not early)
	if early:
		_chg(btn_start, "text", "▶ 조기 호출 +%dρ" % main.early_bonus())
	else:
		_chg(btn_start, "text", ("▶ 웨이브 %d" % (Game.wave + 1)) if main.state == "build" else "진행 중")
	_chg(btn_ult, "visible", Data.chapter_of(Game.stage_id) >= 2)
	_chg(btn_ult, "text", "x=0 대입 ×%d" % Game.ult_left)
	_chg(btn_ult, "disabled", Game.ult_left <= 0)
	_chg(btn_speed, "text", "%d×" % int(Engine.time_scale))
	var auto_txt := "자동 ▶▶ 켬" if Progress.auto_wave else "자동 ▶▶ 끔"
	if Progress.auto_wave and main.state == "build" and main.auto_timer > 0.0 and Game.wave > 0:
		auto_txt = "자동 %.1fs" % main.auto_timer
	_chg(btn_auto, "text", auto_txt)
	_chg(btn_auto, "modulate", Color("ffd166") if Progress.auto_wave else Color.WHITE)
	_chg(btn_pause, "text", "계속" if get_tree().paused else "일시정지")
	btn_sound.text = Sfx.MODE_LABELS[Sfx.mode]
	for type in tower_buttons:
		var b: Button = tower_buttons[type]
		var d: Dictionary = Data.TOWERS[type]
		_chg(b, "text", "%s    %s    %dρ" % [d["glyph"][0], d["name"], int(d["cost"])])
		_chg(b, "disabled", Game.rho < int(d["cost"]))
		if b.button_pressed != (main.build_type == type):
			b.set_pressed_no_signal(main.build_type == type)
	if group_button != null:
		var open: bool = Progress.palette_open
		_chg(group_button, "text", ("▾ " if open else "▸ ") + "산술  −k ÷2 √ log₂")
		for type in GROUP_ARITH:
			if tower_buttons.has(type):
				_chg(tower_buttons[type], "visible", open)
	if Game.c2_unlocked():
		lbl_formula.text = "dρ/dt = c₁ · c₂ = %d · %d = %d" % [Game.c1(), Game.c2(), Game.rho_rate()]
	else:
		lbl_formula.text = "dρ/dt = c₁ = %d" % Game.c1()
	_chg(btn_c1, "text", "c₁ : %d → %d      %dρ" % [Game.c1(), Game.c1() + 1, Game.c1_cost()])
	_chg(btn_c1, "disabled", Game.rho < Game.c1_cost())
	_chg(btn_c2, "visible", Game.c2_unlocked())
	_chg(btn_c2, "text", "c₂ : %d → %d      %dρ" % [Game.c2(), Game.c2() * 2, Game.c2_cost()])
	_chg(btn_c2, "disabled", Game.rho < Game.c2_cost())
	lbl_preview.text = main.preview_text()
	lbl_combo.text = ("×%d 연쇄" % main.combo) if main.combo >= 3 else ""
	_refresh_info()


## Hover an enemy: its body, annihilator, core damage, and the predicted path through the current towers.
func _update_tip(delta: float) -> void:
	if tip == null:
		tip = _label("", 12, Color("e0e1dd"))
		tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sbx := Data.box(Color(0.03, 0.05, 0.11, 0.94), Color("3a506b"), 8.0)
		tip.add_theme_stylebox_override("normal", sbx)
		tip.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		add_child(tip)
	var e = main.hovered_enemy()
	if e == null or overlay != null:
		tip.visible = false
		return
	tip_poll -= delta
	if tip_poll <= 0.0 or not tip.visible:
		tip_poll = 0.2
		var lines := PackedStringArray()
		lines.append(e.label if e.special != "root" else e.label)
		if e.special == "":
			if not e.numeric:
				lines.append(e.ann_text if Progress.has("ann") else "Ann ???  (연구 「소멸자 이론」)")
			lines.append("코어(x = %s)에 닿으면  −%d" % [Data.x_label(Game.x_end), e.threat])
			var pr: Dictionary = main.predict(e)
			lines.append("")
			lines.append("예측 — 지금 배치를 그대로 지나가면:")
			if pr["steps"].is_empty():
				lines.append("   (닿는 타워가 바꿀 수 있는 것이 없음)")
			var shown := 0
			for st in pr["steps"]:
				if shown >= 7:
					lines.append("   …")
					break
				lines.append("   %s  →  %s" % [st[0], st[1]])
				shown += 1
			lines.append("   ⇒ 소멸 ✓" if pr["dead"] else "   ⇒ 코어 도달:  %s   (−%d)" % [pr["f"].to_text(), int(pr["dmg"])])
		else:
			lines.append(e.sublabel)
		tip.text = "\n".join(lines)
		tip.reset_size()
	var m := get_viewport().get_mouse_position()
	var pos := m + Vector2(18, 14)
	pos.x = minf(pos.x, 1270.0 - tip.size.x)
	pos.y = minf(pos.y, 710.0 - tip.size.y)
	tip.position = pos
	tip.visible = true


## Sets a property only when it actually changes. Re-assigning every refresh (above all visible false→true)
## resets a button's hover/press state, which made the info buttons flicker and swallow clicks.
static func _chg(node: Object, prop: String, value) -> void:
	if node.get(prop) != value:
		node.set(prop, value)


func _refresh_info() -> void:
	var tw = main.selected_tower
	var show_up := false
	var show_target := false
	if tw != null and is_instance_valid(tw):
		show_up = true
		_chg(info_title, "text", "%s   %s  ·  Lv %d" % [tw.glyph(), tw.data["name"], tw.level])
		_chg(info_body, "text", tw.describe())
		if tw.level < 3:
			_chg(btn_upgrade, "text", "강화 %dρ  [U]" % tw.upgrade_cost())
			_chg(btn_upgrade, "disabled", Game.rho < tw.upgrade_cost())
		else:
			_chg(btn_upgrade, "text", "최대 레벨")
			_chg(btn_upgrade, "disabled", true)
		_chg(btn_sell, "text", "판매 +%dρ  [Del]" % tw.sell_value())
		if tw.param_label() != "":
			show_target = true
			_chg(btn_target, "text", tw.param_label())
		elif tw.uses_targeting():
			show_target = true
			_chg(btn_target, "text", "조준: %s  [T]" % tw.TARGET_MODES[tw.target_mode])
	elif main.build_type != "":
		var bd: Dictionary = Data.TOWERS[main.build_type]
		_chg(info_title, "text", "%s   %s" % [bd["glyph"][0], bd["name"]])
		_chg(info_body, "text", "%s\n\n비용 %dρ  ·  사거리 %d\n빈 칸을 클릭해 건설 (Shift: 연속 건설). 우클릭 취소." % [bd["desc"], int(bd["cost"]), int(bd["range"][0])])
	else:
		var st: Dictionary = Data.STAGES[Game.stage_id]
		_chg(info_title, "text", st["name"])
		_chg(info_body, "text", st["desc"] + "\n\n1–9·0 건설 · Space 시작 · U 강화 · T 조준 · Del 판매")
	_chg(btn_upgrade, "visible", show_up)
	_chg(btn_sell, "visible", show_up)
	_chg(btn_target, "visible", show_target)
	var show_algo: bool = show_up and Progress.has("code") and tw.type not in ["zeno", "accel"]
	_chg(btn_algo, "visible", show_algo)
	if show_algo:
		var a: String = tw.algo if tw.algo != "" else "기본 (맨 앞 적)"
		var cost := ""
		if tw.algo != "" and tw.algo_host != null:
			cost = "  ·  %d단계 +%.2fs" % [tw.algo_host.last_steps, tw.algo_delay]
		_chg(btn_algo, "text", ("</> %s  ⚠ 오류" if tw.algo_error != "" else "</> %s%s  [E]") % ([a] if tw.algo_error != "" else [a, cost]))
		_chg(btn_algo, "tooltip_text", tw.algo_error if tw.algo_error != "" else "공격 알고리즘 편집기 열기")


# ---------- overlays ----------

func close_overlay() -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null


func _overlay(title: String, subtitle: String, body: String, buttons: Array, title_color: Color = Color("ffd166"), dim: float = 0.94) -> void:
	close_overlay()
	var o := ColorRect.new()
	o.color = Color(0.02, 0.04, 0.09, dim)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(o)
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cc := CenterContainer.new()
	o.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	cc.add_child(vb)
	var lt := _label(title, 60, title_color)
	lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lt)
	var ls := _label(subtitle, 21, Color("5bc0be"))
	ls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(ls)
	var lb := _label(body, 16, Color("cfd8dc"))
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.custom_minimum_size = Vector2(800, 0)
	vb.add_child(lb)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	vb.add_child(row)
	for spec in buttons:
		var b := _button(spec[0], spec[1], 19)
		b.custom_minimum_size = Vector2(220, 50)
		row.add_child(b)
	overlay = o


func show_intro() -> void:
	var st: Dictionary = Data.STAGES[Game.stage_id]
	var ch: Dictionary = Data.CHAPTERS[int(st["chapter"])]
	var body: String = st["desc"]
	if Data.cursed():
		body += "

" + Data.CURSE_TEXT
	_overlay(st["name"], "%s   ·   스테이지 %s" % [ch["name"], Game.stage_id], body,
		[["시작  ▶", func(): main.begin_game()], ["돌아가기", func(): main.to_menu()]], Color("ffd166"), 0.86)


func show_result(won: bool, earned_stars: int, insight_gain: int) -> void:
	var star_txt := "★".repeat(earned_stars) + "☆".repeat(3 - earned_stars)
	var body := "%s\n\n처치 %d   ·   누출 %d   ·   최대 연쇄 ×%d\n통찰 +%d   (보유 %d)" % [star_txt, Game.kills, Game.leaked, Game.max_combo, insight_gain, Progress.insight]
	body += "\n\n★ 클리어   ★ 무결성 절반 이상   ★ 누출 0"
	var buttons: Array = []
	if won and main.next_stage() != "":
		buttons.append(["다음 스테이지  ▶", func(): main.go_stage(main.next_stage())])
	buttons.append(["다시 도전", func(): main.restart()])
	buttons.append(["연구 · 스테이지 선택", func(): main.to_menu()])
	if won:
		_overlay("클리어", "%s %s" % [Game.stage_id, Data.STAGES[Game.stage_id]["name"]], body, buttons)
	else:
		_overlay("붕괴", "웨이브 %d에서 코어가 무너졌습니다." % Game.wave, body + "\n\n패배해도 통찰은 쌓입니다. 연구로 새 연산을 여세요.", buttons, Color("ef5350"))


func show_credits() -> void:
	close_overlay()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay = dim
	credits = _label("", 22, Color("e0e1dd"))
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	credits.size = Vector2(1280, 1400)
	credits.position = Vector2(0, 720)
	credits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	credits.text = "LIMIT BREAK\n수 방어전\n\n\n— THE END —\n\n\n6개의 스테이지\n90개의 웨이브\n모든 수를 0으로 되돌렸습니다\n\n\n설계\n빼기 · 나누기 · 제곱근 · 이진 로그\n\n사운드\n사인파 합성기\n\n\n\n플레이해 주셔서 감사합니다"
	dim.add_child(credits)


func credits_glitch(text: String) -> void:
	if credits != null and is_instance_valid(credits):
		credits.text = text
		credits.add_theme_color_override("font_color", Color("ef5350"))
		var tw := create_tween()
		tw.tween_property(credits, "modulate:a", 0.35, 1.2)
	if overlay != null and is_instance_valid(overlay) and overlay is ColorRect:
		var tw2 := create_tween()
		tw2.tween_property(overlay, "color:a", 0.0, 1.2)   # the battlefield comes back into view


func show_true_end(earned_stars: int, insight_gain: int) -> void:
	close_overlay()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay = dim
	credits = _label("", 22, Color("ffd166"))
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	credits.size = Vector2(1280, 1800)
	credits.position = Vector2(0, 720)
	credits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	credits.text = "LIMIT BREAK\n\n\n— Q.E.D. —\n\n\n수는 함수가 되었고\n함수는 연산자의 핵이 되었고\n연산자는 주파수 위의 곱셈이 되었고\n정확함은 근사가 되었고\n마지막에 규칙은 당신의 선택이 되었습니다.\n\n\n산술 · 변화율 · 소멸자 · 복소평면 · 선형대수\n연산자 대수 · 시공간 · 주파수 영역 · 근사 · 공리\n\n\n%s\n\n\n플레이해 주셔서 감사합니다.\n(이번에는 정말로)" % ("★".repeat(earned_stars) + "☆".repeat(3 - earned_stars))
	dim.add_child(credits)
	var b := _button("연구실로", func(): main.to_menu(), 18)
	b.position = Vector2(1080, 660)
	b.size = Vector2(170, 44)
	dim.add_child(b)
	var note := _label("통찰 +%d" % insight_gain, 14, Color("c5e1a5"))
	note.position = Vector2(1080, 630)
	dim.add_child(note)


func show_counterexample(info: Dictionary) -> void:
	credits = null
	_overlay("반례", info["sub"], info["body"], [["연구실로", func(): main.to_menu()]], Color("ef5350"))
