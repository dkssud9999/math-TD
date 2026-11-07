extends Control
## Stage select + research lab. Only chapters (and research) the player has reached are shown,
## so chapter 1 looks like the whole game.

var root: Control
var reset_armed: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Data.make_theme()
	_build()
	for a in OS.get_cmdline_user_args():   # --shot-menu=path.png: screenshot of the menu, then quit (tests)
		if a.begins_with("--shot-menu="):
			for i in 20:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(a.substr(12))
			get_tree().quit()


func _label(text: String, size: int, color: Color = Color("e0e1dd")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, cb: Callable, size: int = 15) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(cb)
	return b


func _latest_chapter() -> int:
	var latest := 1
	for ch in Data.CHAPTERS:
		if Progress.chapter_visible(int(ch)):
			latest = maxi(latest, int(ch))
	return latest


func _build() -> void:
	if root != null:
		root.queue_free()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color("0a1424")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var title := _label("LIMIT BREAK", 54, Color("ffd166"))
	title.position = Vector2(40, 24)
	root.add_child(title)
	var latest := _latest_chapter()
	var sub := _label(Data.CHAPTERS[latest]["sub"], 20, Color("5bc0be"))
	sub.position = Vector2(44, 98)
	root.add_child(sub)
	var ins := _label("통찰  %d" % Progress.insight, 24, Color("c5e1a5"))
	ins.position = Vector2(1000, 40)
	root.add_child(ins)

	# ---- stages (newest chapter on top, scrollable) ----
	var lscroll := ScrollContainer.new()
	lscroll.position = Vector2(40, 140)
	lscroll.size = Vector2(620, 520)
	lscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(lscroll)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(600, 0)
	left.add_theme_constant_override("separation", 10)
	lscroll.add_child(left)
	var chapters: Array = Data.CHAPTERS.keys()
	chapters.sort()
	chapters.reverse()
	for ch in chapters:
		if not Progress.chapter_visible(int(ch)):
			continue
		if latest > 1:   # while only chapter 1 exists, it must not look like "chapter 1 of many"
			left.add_child(_label(Data.CHAPTERS[ch]["name"], 22, Color("ffd166")))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		left.add_child(grid)
		for sid in Data.STAGE_ORDER:
			if int(Data.STAGES[sid]["chapter"]) != int(ch):
				continue
			var stars: int = Progress.stars.get(sid, 0)
			var unlocked := Progress.stage_unlocked(sid)
			var hs: int = int(Progress.hard_stars.get(sid, 0))
			var txt := "%s  %s
%s%s" % [sid, Data.STAGES[sid]["name"], "★".repeat(stars) + "☆".repeat(3 - stars), ("   하드 " + "★".repeat(hs)) if hs > 0 else ""]
			if not unlocked:
				txt = "%s
잠김" % sid
			var b := _button(txt, _play.bind(sid), 15)
			b.custom_minimum_size = Vector2(190, 60)
			b.disabled = not unlocked
			grid.add_child(b)
	if Progress.stars.is_empty():
		var hint := _label("숫자를 0으로 만들어 코어를 지키세요.
스테이지를 깨거나, 져도, 통찰이 쌓입니다. 통찰로 새 연산을 연구하세요.", 15, Color("b0bec5"))
		left.add_child(hint)

	# ---- research (newest chapter on top, scrollable; owned items shrink to one line) ----
	var rscroll := ScrollContainer.new()
	rscroll.position = Vector2(680, 140)
	rscroll.size = Vector2(570, 520)
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(rscroll)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(530, 0)
	right.add_theme_constant_override("separation", 6)
	rscroll.add_child(right)
	right.add_child(_label("연구", 22, Color("ffd166")))
	var nodes: Array = Data.RESEARCH.duplicate()
	nodes.reverse()
	var shown_axiom_header := false
	for node in nodes:
		if not Progress.chapter_visible(int(node["chapter"])):
			continue
		if node.has("flag") and not Progress.flag(node["flag"]):
			continue   # don't spoil what hasn't been discovered
		var st := Progress.research_state(node)
		if node.get("axiom", false) and not shown_axiom_header:
			shown_axiom_header = true
			right.add_child(_label("공리  (켜진 공리 %d / %d — 클릭해서 켜고 끄기)" % [Progress.axioms_on.size(), Progress.AXIOM_SLOTS], 15, Color("ef9a9a")))
		if node.get("axiom", false) and st == "owned":
			var on: bool = Progress.axioms_on.get(node["id"], false)
			var ab := _button("%s  %s
%s" % ["● 켜짐" if on else "○ 꺼짐", node["name"], node["desc"]], _toggle_axiom.bind(node["id"]), 13)
			ab.alignment = HORIZONTAL_ALIGNMENT_LEFT
			ab.custom_minimum_size = Vector2(530, 50)
			ab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # long descriptions wrap instead of running off-screen
			ab.add_theme_color_override("font_color", Color("ffd166") if on else Color("b0bec5"))
			right.add_child(ab)
			continue
		var head := ""
		var body: String = node["desc"]
		match st:
			"owned":
				head = "✔  %s" % node["name"]
				body = ""
			"available":
				head = "%s    — 통찰 %d" % [node["name"], int(node["cost"])]
			_:
				var reqs := PackedStringArray()
				for r in node.get("req", []):
					if not Progress.has(r):
						reqs.append(_research_name(r))
				if node.has("stage") and int(Progress.stars.get(node["stage"], 0)) == 0:
					reqs.append("%s 클리어" % node["stage"])
				if not Progress.missing_essentials(node).is_empty():
					reqs.append("이 장의 필수 연구 전부")
				head = "%s    — 통찰 %d    (필요: %s)" % [node["name"], int(node["cost"]), ", ".join(reqs)]
		var b := _button(head if body == "" else "%s
%s" % [head, body], _buy.bind(node), 13)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(530, 26 if body == "" else 50)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # long descriptions wrap instead of running off-screen
		b.disabled = st != "available" or Progress.insight < int(node["cost"])
		if st == "owned":
			b.add_theme_color_override("font_disabled_color", Color("81c784"))
		right.add_child(b)

	# ---- bottom bar ----
	var row := HBoxContainer.new()
	row.position = Vector2(40, 670)
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)
	row.add_child(_button(Sfx.MODE_LABELS[Sfx.mode], func():
		Sfx.cycle_mode()
		_build(), 14))
	row.add_child(_button("기록 초기화 (두 번 클릭)" if not reset_armed else "정말 초기화합니다", _reset, 14))
	row.add_child(_button("개발자 모드: " + ("켬" if Progress.dev_mode else "끔"), func():
		Progress.dev_mode = not Progress.dev_mode
		Progress.save_game()
		_build(), 14))
	if Progress.dev_mode:
		row.add_child(_button("모든 장 열기", func():
			Progress.dev_unlock_all()
			_build(), 14))
		row.add_child(_button("통찰 +100", func():
			Progress.add_insight(100)
			_build(), 14))
		row.add_child(_button("짧은 스테이지(5웨이브): " + ("켬" if Progress.dev_short else "끔"), func():
			Progress.dev_short = not Progress.dev_short
			Progress.save_game()
			_build(), 14))
		row.add_child(_label("게임 중 F9 = 즉시 클리어", 13, Color("b0bec5")))
	row.add_child(_button("종료", func(): get_tree().quit(), 14))


func _research_name(id: String) -> String:
	for n in Data.RESEARCH:
		if n["id"] == id:
			return n["name"]
	return id


## A stage button asks: normal or hard? (Insight is paid once per mode.)
func _play(sid: String) -> void:
	Sfx.play("ui")
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.size = Vector2(1280, 720)
	add_child(shade)
	var box := VBoxContainer.new()
	box.position = Vector2(440, 220)
	box.custom_minimum_size = Vector2(400, 0)
	box.add_theme_constant_override("separation", 10)
	shade.add_child(box)
	box.add_child(_label("%s  %s" % [sid, Data.STAGES[sid]["name"]], 24, Color("ffd166")))
	var n_paid: bool = Progress.normal_clear.has(sid)
	var h_paid: bool = Progress.hard_stars.has(sid)
	var nb := _button("일반   —   통찰 %s" % ("받음 ✓" if n_paid else "+%d" % Data.stage_insight(sid, false)), _start.bind(sid, false), 18)
	nb.custom_minimum_size = Vector2(400, 52)
	box.add_child(nb)
	var hb := _button("하드   —   통찰 %s\n물량 1.4배 · 더 빠름 · 보스 하나 더" % ("받음 ✓" if h_paid else "+%d" % Data.stage_insight(sid, true)), _start.bind(sid, true), 18)
	hb.custom_minimum_size = Vector2(400, 66)
	hb.add_theme_color_override("font_color", Color("ef9a9a"))
	box.add_child(hb)
	box.add_child(_button("취소", func(): shade.queue_free(), 15))


func _start(sid: String, hard: bool) -> void:
	Sfx.play("ui")
	Progress.current_stage = sid
	Game.hard = hard
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _buy(node: Dictionary) -> void:
	if Progress.buy_research(node):
		Sfx.play("clear")
	_build()


func _toggle_axiom(id: String) -> void:
	if Progress.toggle_axiom(id):
		Sfx.play("pulse")
	else:
		Sfx.play("leak", 1.5)
	_build()


func _reset() -> void:
	if not reset_armed:
		reset_armed = true
		_build()
		return
	reset_armed = false
	Progress.reset_save()
	Sfx.play("lose")
	_build()
