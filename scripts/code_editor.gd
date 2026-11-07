extends CanvasLayer
## In-game Python editor for attack algorithms. Files live in user://scripts/*.py (real files).
## Opening it pauses the game; Esc closes.

var main
var tower = null                 # the tower it was opened for (assignment + test runs)
var current: String = ""
var files: ItemList
var code: CodeEdit
var name_edit: LineEdit
var status: Label
var console_box: RichTextLabel
var assign_label: Label
var assign_opt: OptionButton
var btn_all: Button
var save_timer: float = -1.0
var was_paused: bool = false
var seen_serial: int = -1
var _loading: bool = false
var guide                        # guide_panel.gd (F1)
var btn_guide: Button
var mini_title: Label
var mini_body: RichTextLabel
var seen_scripts: int = -1       # Progress.scripts_serial last handled (external edits)


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var bg := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.09, 0.995)
	bg.add_theme_stylebox_override("panel", sb)
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# ---- top bar ----
	var top := HBoxContainer.new()
	top.position = Vector2(10, 8)
	top.size = Vector2(1260, 30)
	top.add_theme_constant_override("separation", 8)
	bg.add_child(top)
	var title := _label("알고리즘 편집기", 18, Color("ffd166"))
	top.add_child(title)
	var path := _label("  user://scripts/", 12, Color("78909c"))
	top.add_child(path)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(_button("새 파일", _new_file))
	top.add_child(_button("삭제", _delete_file))
	var ext := _button("VS Code로 열기", _open_external)
	ext.tooltip_text = "스크립트 폴더를 외부 편집기로 엽니다. 저장하면 게임이 바로 다시 읽습니다."
	top.add_child(ext)
	top.add_child(_button("폴더 열기", func(): OS.shell_open(ProjectSettings.globalize_path(Progress.SCRIPT_DIR))))
	btn_guide = _button("가이드  [F1]", func(): _toggle_guide(not guide.visible))
	top.add_child(btn_guide)
	top.add_child(_button("다시 읽기", func():
		Progress.reload_scripts()
		_refresh_files()
		_open_file(current)))
	top.add_child(_button("닫기  [Esc]", close))

	# ---- file list ----
	files = ItemList.new()
	files.position = Vector2(10, 46)
	files.size = Vector2(170, 620)
	files.add_theme_font_size_override("font_size", 14)
	files.item_selected.connect(func(i):
		_flush()
		_open_file(files.get_item_text(i)))
	bg.add_child(files)

	# ---- code ----
	name_edit = LineEdit.new()
	name_edit.position = Vector2(190, 46)
	name_edit.size = Vector2(300, 28)
	name_edit.placeholder_text = "파일 이름.py"
	name_edit.tooltip_text = "이름을 고치고 Enter로 바꿉니다"
	name_edit.text_submitted.connect(_rename)
	bg.add_child(name_edit)
	status = _label("", 13, Color("a5d6a7"))
	status.position = Vector2(500, 50)
	status.size = Vector2(380, 24)
	status.clip_text = true
	bg.add_child(status)

	code = CodeEdit.new()
	code.position = Vector2(190, 80)
	code.size = Vector2(690, 586)
	code.gutters_draw_line_numbers = true
	code.indent_automatic = true
	code.indent_use_spaces = true
	code.indent_size = 4
	code.auto_brace_completion_enabled = true
	code.add_theme_font_size_override("font_size", 15)
	if Data.font != null:
		code.add_theme_font_override("font", Data.font)
	code.syntax_highlighter = _highlighter()
	code.text_changed.connect(func():
		if not _loading:
			save_timer = 0.6)
	bg.add_child(code)

	# ---- right side: assignment, API, console ----
	var right := VBoxContainer.new()
	right.position = Vector2(892, 46)
	right.size = Vector2(378, 620)
	right.add_theme_constant_override("separation", 6)
	bg.add_child(right)
	assign_label = _label("", 13, Color("80deea"))
	assign_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(assign_label)
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 6)
	assign_opt = OptionButton.new()
	assign_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	assign_opt.fit_to_longest_item = false
	assign_opt.clip_text = true
	assign_opt.custom_minimum_size = Vector2(120, 0)
	assign_opt.item_selected.connect(_on_assign)
	arow.add_child(assign_opt)
	btn_all = _button("같은 종류 전부", _assign_all)
	btn_all.tooltip_text = "이 종류의 모든 타워와 앞으로 지을 타워에 같은 알고리즘을 씁니다"
	arow.add_child(btn_all)
	right.add_child(arow)
	var test_row := HBoxContainer.new()
	test_row.add_theme_constant_override("separation", 6)
	test_row.add_child(_button("테스트 실행", _test_run))
	test_row.add_child(_button("콘솔 지우기", func():
		Algo.console.clear()
		Algo.console_serial += 1))
	right.add_child(test_row)
	# the page the player is reading, small, so it can stay open next to the code
	var ghead := HBoxContainer.new()
	ghead.add_theme_constant_override("separation", 6)
	mini_title = _label("가이드", 14, Color("ffd166"))
	mini_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mini_title.clip_text = true
	ghead.add_child(mini_title)
	ghead.add_child(_button("◀", func(): guide._step(-1)))
	ghead.add_child(_button("▶", func(): guide._step(1)))
	ghead.add_child(_button("크게", func(): _toggle_guide(true)))
	right.add_child(ghead)
	mini_body = RichTextLabel.new()
	mini_body.bbcode_enabled = true
	mini_body.custom_minimum_size = Vector2(0, 250)
	mini_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mini_body.add_theme_font_size_override("normal_font_size", 13)
	mini_body.add_theme_font_size_override("bold_font_size", 13)
	mini_body.add_theme_font_size_override("mono_font_size", 12)
	mini_body.add_theme_constant_override("line_separation", 3)
	var msb := StyleBoxFlat.new()
	msb.bg_color = Color(0.06, 0.085, 0.13)
	msb.set_corner_radius_all(6)
	msb.set_content_margin_all(8)
	mini_body.add_theme_stylebox_override("normal", msb)
	right.add_child(mini_body)
	right.add_child(_label("콘솔", 12, Color("5bc0be")))
	console_box = RichTextLabel.new()
	console_box.bbcode_enabled = true
	console_box.scroll_following = true
	console_box.custom_minimum_size = Vector2(0, 190)
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	csb.border_color = Color(0.25, 0.35, 0.45, 0.6)
	csb.set_border_width_all(1)
	csb.set_content_margin_all(6)
	console_box.add_theme_stylebox_override("normal", csb)
	console_box.add_theme_font_size_override("normal_font_size", 12)
	right.add_child(console_box)

	# ---- the full guide (F1), over everything below the top bar ----
	guide = preload("res://scripts/guide_panel.gd").new()
	guide.editor = self
	guide.visible = false
	bg.add_child(guide)
	guide.closed.connect(func(): _toggle_guide(false))
	guide.open_example.connect(_open_example)
	guide.page_changed.connect(_show_mini)


func _toggle_guide(on: bool) -> void:
	guide.visible = on
	if on:
		guide.show_page(guide.current_id)
	else:
		code.grab_focus()
	_refresh_guide_button()


func _refresh_guide_button() -> void:
	var n := Guide.unread_count()
	btn_guide.text = ("가이드  [F1]   ● 새 %d" % n) if n > 0 else "가이드  [F1]"
	btn_guide.add_theme_color_override("font_color", Color("ffd166") if n > 0 else Color("e0e0e0"))


## The small copy of the current page beside the code.
func _show_mini(p: Dictionary) -> void:
	mini_title.text = p["title"]
	var txt := String(p["body"]).replace("[code]", "[color=#c3e88d][code]").replace("[/code]", "[/code][/color]")
	if p.has("code"):
		txt += "\n\n[color=#c3e88d][code]%s[/code][/color]" % String(p["code"]).replace("[", "[lb]")
	if p.has("task"):
		txt += "\n\n[color=#ffd166]과제[/color]\n[color=#ffe0a3][code]%s[/code][/color]" % String(p["task"]).replace("[", "[lb]")
	if p.has("hints"):
		txt += "\n[color=#78909c]힌트는 「크게」에서 하나씩 열 수 있습니다.[/color]"
	if p.has("try"):
		txt += "\n\n[color=#a5d6a7]해 보기 ▸ %s[/color]" % p["try"]
	mini_body.text = txt
	mini_body.scroll_to_line(0)
	_refresh_guide_button()


func _open_example(p: Dictionary) -> void:
	_flush()
	var fn := "guide_%s.py" % p["id"]
	if not Progress.list_scripts().has(fn):   # never overwrite: the player may already be working on it
		var body: String = String(p["task"]) if p.has("task") else String(p["code"])
		var head := "# %s — ____ 를 채우세요\n" % p["title"] if p.has("task") else "# 가이드: %s\n" % p["title"]
		Progress.write_script(fn, head + body)
	_toggle_guide(false)
	_refresh_files()
	_open_file(fn)
	_refresh_assign()
	status.text = "%s 열림 — 오른쪽 위에서 타워에 붙이고 「테스트 실행」" % fn


## VS Code (or any editor) on the scripts folder; falls back to the file explorer.
func _open_external() -> void:
	_flush()
	var dir := ProjectSettings.globalize_path(Progress.SCRIPT_DIR)
	var pid := -1
	if OS.get_name() == "Windows":
		var code_cmd := OS.get_environment("LOCALAPPDATA") + "\\Programs\\Microsoft VS Code\\bin\\code.cmd"
		if FileAccess.file_exists(code_cmd):
			pid = OS.create_process("cmd.exe", ["/c", code_cmd, dir])
		else:
			var out: Array = []
			if OS.execute("where", ["code"], out) == 0:
				pid = OS.create_process("cmd.exe", ["/c", "code", dir])
	else:
		pid = OS.create_process("code", [dir])
	if pid <= 0:
		OS.shell_open(dir)
		status.text = "VS Code를 찾지 못해 폴더를 열었습니다. 원하는 편집기로 폴더째 여세요."
	else:
		status.text = "VS Code에서 엽니다. 저장하면 게임이 바로 다시 읽습니다."


func _label(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l


func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 13)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _highlighter() -> CodeHighlighter:
	var h := CodeHighlighter.new()
	h.number_color = Color("f78c6c")
	h.symbol_color = Color("89ddff")
	h.function_color = Color("82aaff")
	h.member_variable_color = Color("c3e88d")
	for kw in ["def", "return", "if", "elif", "else", "for", "while", "in", "not", "and", "or", "is",
			"break", "continue", "pass", "lambda", "global"]:
		h.add_keyword_color(kw, Color("c792ea"))
	for kw in ["True", "False", "None", "me", "set_param"]:
		h.add_keyword_color(kw, Color("ffcb6b"))
	for kw in PyVM.BUILTINS:
		h.add_keyword_color(kw, Color("82aaff"))
	h.add_color_region("#", "", Color("637777"), true)
	h.add_color_region("\"", "\"", Color("ecc48d"))
	h.add_color_region("'", "'", Color("ecc48d"))
	return h


# ---------- open / close ----------

func open(for_tower) -> void:
	tower = for_tower if (for_tower != null and is_instance_valid(for_tower)) else null
	Progress.ensure_example_scripts()
	Progress.reload_scripts()
	was_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	_refresh_files()
	var want: String = tower.algo if tower != null and tower.algo != "" else current
	if want == "" or not Progress.list_scripts().has(want):
		var all := Progress.list_scripts()
		want = all[0] if not all.is_empty() else ""
	_open_file(want)
	_refresh_assign()
	seen_scripts = Progress.scripts_serial
	code.grab_focus()
	# new pages since last time: open the guide on the first one (the very first visit starts there too)
	if Guide.unread_count() > 0:
		guide.current_id = ""
		_toggle_guide(true)
	else:
		guide.show_page(guide.current_id)
		_toggle_guide(false)


func close() -> void:
	_flush()
	visible = false
	get_tree().paused = was_paused
	if main != null:
		main.hud.refresh()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_toggle_guide(not guide.visible)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if guide.visible:
			_toggle_guide(false)
		else:
			close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	if save_timer > 0.0:
		save_timer -= delta
		if save_timer <= 0.0:
			_flush()
	if seen_scripts != Progress.scripts_serial:
		seen_scripts = Progress.scripts_serial
		_external_change()
	if seen_serial != Algo.console_serial:
		seen_serial = Algo.console_serial
		var parts := PackedStringArray()
		for row in Algo.console:
			var txt: String = String(row[0]).replace("[", "[lb]")
			parts.append(("[color=#ef9a9a]%s[/color]" % txt) if row[1] else txt)
		console_box.text = "\n".join(parts)


# ---------- files ----------

## A file was changed, added or removed in another program (VS Code …).
func _external_change() -> void:
	_refresh_files()
	if current == "" or save_timer > 0.0:
		return   # unsaved typing here wins; it is written in a moment
	if not Progress.list_scripts().has(current):
		var all := Progress.list_scripts()
		_open_file(all[0] if not all.is_empty() else "")
		return
	var disk := Progress.read_script(current)
	if disk != code.text:
		var line := code.get_caret_line()
		var col := code.get_caret_column()
		_loading = true
		code.text = disk
		_loading = false
		code.set_caret_line(mini(line, code.get_line_count() - 1))
		code.set_caret_column(col)
		_check()
		status.text = "외부 편집기에서 바뀐 내용을 다시 읽었습니다 ✓"

func _refresh_files() -> void:
	files.clear()
	for fn in Progress.list_scripts():
		files.add_item(fn)
		if fn == current:
			files.select(files.item_count - 1)


func _open_file(fn: String) -> void:
	current = fn
	_loading = true
	code.text = Progress.read_script(fn) if fn != "" else ""
	code.editable = fn != ""
	_loading = false
	name_edit.text = fn
	for i in files.item_count:
		if files.get_item_text(i) == fn:
			files.select(i)
	_check()


## Save now (if there are unsaved edits) and re-check the syntax.
func _flush() -> void:
	if current == "" or save_timer < 0.0:
		save_timer = -1.0
		return
	save_timer = -1.0
	Progress.write_script(current, code.text)
	_check()


func _check() -> void:
	for i in code.get_line_count():
		code.set_line_background_color(i, Color(0, 0, 0, 0))
	if current == "":
		status.text = "파일이 없습니다. 「새 파일」을 누르세요."
		return
	var vm := PyVM.new()
	var ok := vm.compile(code.text)
	var err_msg := vm.error_text()
	if ok and not code.text.contains("attack"):
		ok = false
		err_msg = "attack(…)을 부르는 곳이 없습니다 — 이 타워는 쏘지 않습니다"
	if ok and code.text.contains("____"):
		ok = false
		err_msg = "빈칸 ____ 이 남아 있습니다 — 채우기 전까지 이 타워는 기본 동작으로 싸웁니다"
	if ok:
		status.text = "저장됨 ✓  문법 이상 없음"
		status.add_theme_color_override("font_color", Color("a5d6a7"))
		return
	var msg := err_msg
	status.text = msg
	status.tooltip_text = msg
	status.add_theme_color_override("font_color", Color("ef9a9a"))
	var ln := _line_of(msg)
	if ln > 0 and ln <= code.get_line_count():
		code.set_line_background_color(ln - 1, Color(0.6, 0.15, 0.15, 0.35))


static func _line_of(msg: String) -> int:
	var re := RegEx.new()
	re.compile("줄 (\\d+)")
	var m := re.search(msg)
	return int(m.get_string(1)) if m != null else 0


func _new_file() -> void:
	_flush()
	var n := 1
	while Progress.list_scripts().has("algo%d.py" % n):
		n += 1
	var fn := "algo%d.py" % n
	Progress.write_script(fn, Data.EXAMPLE_ATTACK)
	_refresh_files()
	_open_file(fn)
	_refresh_assign()


func _delete_file() -> void:
	if current == "":
		return
	Progress.delete_script(current)
	for tw in main.occupied.values():
		if tw.algo == current:
			tw.algo = ""
	current = ""
	_refresh_files()
	var all := Progress.list_scripts()
	_open_file(all[0] if not all.is_empty() else "")
	_refresh_assign()


func _rename(new_name: String) -> void:
	new_name = new_name.strip_edges()
	if new_name == "" or current == "":
		return
	if not new_name.ends_with(".py"):
		new_name += ".py"
	if not new_name.is_valid_filename():
		status.text = "쓸 수 없는 파일 이름입니다"
		return
	_flush()
	var old := current
	var defaults := Progress.algo_default.duplicate()
	if not Progress.rename_script(old, new_name):
		status.text = "같은 이름의 파일이 이미 있습니다"
		return
	for k in defaults:
		if defaults[k] == old:
			Progress.algo_default[k] = new_name
	Progress.save_game()
	for tw in main.occupied.values():
		if tw.algo == old:
			tw.algo = new_name
	_refresh_files()
	_open_file(new_name)
	_refresh_assign()


# ---------- assignment ----------

func _refresh_assign() -> void:
	assign_opt.clear()
	if tower == null or not is_instance_valid(tower):
		assign_label.text = "타워를 선택한 뒤 E를 누르면 그 타워에 알고리즘을 붙이고 테스트할 수 있습니다."
		assign_opt.disabled = true
		btn_all.disabled = true
		return
	assign_opt.disabled = false
	btn_all.disabled = false
	assign_label.text = "선택한 타워:  %s %s  ·  Lv %d" % [tower.glyph(), tower.data["name"], tower.level]
	assign_opt.add_item("기본 (맨 앞 적)")
	var sel := 0
	var all := Progress.list_scripts()
	for i in all.size():
		assign_opt.add_item(all[i])
		if all[i] == tower.algo:
			sel = i + 1
	assign_opt.select(sel)


func _on_assign(idx: int) -> void:
	if tower == null or not is_instance_valid(tower):
		return
	tower.algo = "" if idx == 0 else assign_opt.get_item_text(idx)
	tower.algo_error = ""
	if tower.algo_host != null:
		tower.algo_host.dispose()
	tower.algo_host = null


func _assign_all() -> void:
	if tower == null or not is_instance_valid(tower):
		return
	var a: String = tower.algo
	for tw in main.occupied.values():
		if tw.type == tower.type:
			tw.algo = a
			tw.algo_error = ""
			if tw.algo_host != null:
				tw.algo_host.dispose()
			tw.algo_host = null
	if a == "":
		Progress.algo_default.erase(tower.type)
	else:
		Progress.algo_default[tower.type] = a
	Progress.save_game()
	Algo.log_line("%s 종류 전부: %s" % [tower.data["name"], a if a != "" else "기본 조준"])


func _test_run() -> void:
	_flush()
	if tower == null or not is_instance_valid(tower):
		Algo.log_line("테스트하려면 타워를 선택한 뒤 E로 여세요.", true)
		return
	var saved: String = tower.algo
	tower.algo = current
	var host := Algo.new(tower)
	var near: Array = tower.in_range(tower.range_px())
	Algo.log_line("— 테스트: %s, 사거리 안의 적 %d개 —" % [current, near.size()])
	var res := host.run(near, true)
	host.dispose()
	tower.algo = saved
	if not res["ok"]:
		return
	if res["targets"].is_empty():
		Algo.log_line("→ 쏘지 않음 (None)")
	else:
		var names := PackedStringArray()
		for e in res["targets"]:
			names.append(e.f.to_text())
		Algo.log_line("→ 쏠 대상: " + ", ".join(names))
