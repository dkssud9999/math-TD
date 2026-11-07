extends Control
## The full-size guide inside the algorithm editor (F1): searchable page list on the left,
## one page on the right. Pages open gradually with progress (Guide.is_open); unread ones say NEW,
## and only the next locked page is hinted, so it never shows everything at once.

signal open_example(page: Dictionary)
signal closed
signal page_changed(page: Dictionary)

var editor                       # the code editor (for its syntax highlighter)
var search: LineEdit
var tree: Tree
var sec_label: Label
var title_label: Label
var body: RichTextLabel
var try_box: PanelContainer
var try_label: Label
var code_view: CodeEdit
var task_label: Label
var task_view: CodeEdit
var hints_box: VBoxContainer
var hints_shown: Dictionary = {}   # page id -> how many hints the player has opened
var btn_prev: Button
var btn_next: Button
var btn_example: Button
var current_id: String = ""

const C_BG := Color(0.035, 0.055, 0.095, 0.995)
const C_SIDE := Color(0.06, 0.085, 0.13)
const C_GOLD := Color("ffd166")
const C_CYAN := Color("80deea")
const C_TEXT := Color("dfe7ec")
const C_DIM := Color("78909c")


func _ready() -> void:
	position = Vector2(0, 42)
	size = Vector2(1280, 678)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", _box(C_BG, 0))
	bg.size = size
	add_child(bg)

	# ---- left: search + pages ----
	var side := Panel.new()
	side.add_theme_stylebox_override("panel", _box(C_SIDE, 10))
	side.position = Vector2(14, 8)
	side.size = Vector2(300, 656)
	add_child(side)
	var head := _label("가이드", 20, C_GOLD)
	head.position = Vector2(30, 18)
	add_child(head)
	search = LineEdit.new()
	search.placeholder_text = "🔍  찾기 (예: 미분, 짝, after)"
	search.position = Vector2(26, 56)
	search.size = Vector2(276, 32)
	search.add_theme_font_size_override("font_size", 14)
	search.clear_button_enabled = true
	search.text_changed.connect(func(_t): rebuild())
	add_child(search)
	tree = Tree.new()
	tree.position = Vector2(22, 96)
	tree.size = Vector2(284, 560)
	tree.hide_root = true
	tree.add_theme_font_size_override("font_size", 15)
	tree.add_theme_constant_override("v_separation", 6)
	tree.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), 0))
	tree.add_theme_color_override("font_color", C_TEXT)
	tree.item_selected.connect(_on_pick)
	add_child(tree)

	# ---- right: the page ----
	var x0 := 340.0
	sec_label = _label("", 13, C_CYAN)
	sec_label.position = Vector2(x0, 14)
	add_child(sec_label)
	title_label = _label("", 26, C_GOLD)
	title_label.position = Vector2(x0, 34)
	add_child(title_label)
	var close_btn := _button("코드로 돌아가기  [F1]", func(): closed.emit())
	close_btn.position = Vector2(1090, 14)
	add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(x0, 82)
	scroll.size = Vector2(920, 530)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 14)
	scroll.add_child(col)
	body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.custom_minimum_size = Vector2(880, 0)
	body.add_theme_font_size_override("normal_font_size", 17)
	body.add_theme_font_size_override("bold_font_size", 17)
	body.add_theme_font_size_override("mono_font_size", 16)
	body.add_theme_color_override("default_color", C_TEXT)
	body.add_theme_constant_override("line_separation", 7)
	col.add_child(body)
	code_view = CodeEdit.new()
	# read-only, but in full colour (a non-editable CodeEdit greys its text out): edits are undone at once
	code_view.text_changed.connect(func():
		var p := Guide.page(current_id)
		if p.has("code") and code_view.text != p["code"]:
			code_view.text = p["code"])
	code_view.context_menu_enabled = false
	code_view.gutters_draw_line_numbers = true
	code_view.custom_minimum_size = Vector2(880, 120)
	code_view.add_theme_font_size_override("font_size", 16)
	if Data.font != null:
		code_view.add_theme_font_override("font", Data.font)
	col.add_child(code_view)
	task_label = _label("과제  ·  ____ 를 채우세요", 15, C_GOLD)
	col.add_child(task_label)
	task_view = CodeEdit.new()
	task_view.text_changed.connect(func():
		var p := Guide.page(current_id)
		if p.has("task") and task_view.text != p["task"]:
			task_view.text = p["task"])
	task_view.context_menu_enabled = false
	task_view.gutters_draw_line_numbers = true
	task_view.custom_minimum_size = Vector2(880, 120)
	task_view.add_theme_font_size_override("font_size", 16)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.09, 0.08, 0.04)
	tsb.border_color = Color(1.0, 0.82, 0.4, 0.45)
	tsb.set_border_width_all(1)
	tsb.set_corner_radius_all(6)
	task_view.add_theme_stylebox_override("normal", tsb)
	if Data.font != null:
		task_view.add_theme_font_override("font", Data.font)
	col.add_child(task_view)
	hints_box = VBoxContainer.new()
	hints_box.add_theme_constant_override("separation", 8)
	col.add_child(hints_box)
	try_box = PanelContainer.new()
	try_box.add_theme_stylebox_override("panel", _box(Color(0.10, 0.20, 0.16, 0.9), 12, Color("66bb6a")))
	try_label = _label("", 16, Color("c8e6c9"))
	try_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	try_label.custom_minimum_size = Vector2(850, 0)
	try_box.add_child(try_label)
	col.add_child(try_box)

	var row := HBoxContainer.new()
	row.position = Vector2(x0, 622)
	row.size = Vector2(920, 36)
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	btn_prev = _button("◀  이전", func(): _step(-1))
	row.add_child(btn_prev)
	btn_next = _button("다음  ▶", func(): _step(1))
	row.add_child(btn_next)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	btn_example = _button("이 코드를 새 파일로 열기", func():
		var p := Guide.page(current_id)
		if not p.is_empty():
			open_example.emit(p))
	row.add_child(btn_example)


func _box(c: Color, margin: int, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(margin)
	if border.a > 0:
		sb.border_color = border
		sb.border_width_left = 4
	return sb


func _label(t: String, sz: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", c)
	return l


func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 15)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


## Hints open one at a time, only when asked (the guide never hands over a finished answer).
func _render_hints(p: Dictionary) -> void:
	for c in hints_box.get_children():
		c.queue_free()
	var hints: Array = p.get("hints", [])
	if hints.is_empty():
		return
	var shown: int = hints_shown.get(p["id"], 0)
	for k in shown:
		var hl := RichTextLabel.new()
		hl.bbcode_enabled = true
		hl.fit_content = true
		hl.scroll_active = false
		hl.custom_minimum_size = Vector2(880, 0)
		hl.add_theme_font_size_override("normal_font_size", 16)
		hl.add_theme_font_size_override("bold_font_size", 16)
		hl.add_theme_color_override("default_color", Color("ffe0a3"))
		hl.text = "힌트 %d  ▸  %s" % [k + 1, hints[k]]
		hints_box.add_child(hl)
	if shown < hints.size():
		var b := _button("힌트 %d 보기  (%d / %d)" % [shown + 1, shown + 1, hints.size()], func():
			hints_shown[p["id"]] = shown + 1
			_render_hints(p))
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		hints_box.add_child(b)


## Opens at a page (or the first unread one, or the first page).
func show_page(id: String = "") -> void:
	if id == "":
		for p in Guide.open_pages():
			if Guide.is_new(p):
				id = p["id"]
				break
	if id == "" and current_id == "":
		var all := Guide.open_pages()
		id = all[0]["id"] if not all.is_empty() else ""
	if id != "":
		current_id = id
	_render()
	rebuild()


func rebuild() -> void:
	tree.clear()
	var root := tree.create_item()
	var q := search.text.strip_edges()
	var pages := Guide.open_pages()
	for sec in Guide.SECTIONS:
		var items: Array = pages.filter(func(p): return p["sec"] == sec and Guide.matches(p, q))
		if items.is_empty():
			continue
		var s := tree.create_item(root)
		s.set_text(0, sec)
		s.set_selectable(0, false)
		s.set_custom_color(0, C_CYAN)
		s.set_custom_font_size(0, 13)
		s.collapsed = sec == "사전" and q == "" and not items.any(func(p): return p["id"] == current_id)
		for p in items:
			var it := tree.create_item(s)
			var unread := Guide.is_new(p)
			it.set_text(0, ("●  " if unread else "    ") + p["title"])
			it.set_metadata(0, p["id"])
			if unread:
				it.set_custom_color(0, C_GOLD)
			if p["id"] == current_id:
				it.select(0)
	var nxt := Guide.next_locked()
	if q == "" and not nxt.is_empty():
		var lk := tree.create_item(root)
		lk.set_text(0, "🔒  다음: %s  (%s)" % [nxt["title"], nxt["from"]])
		lk.set_selectable(0, false)
		lk.set_custom_color(0, C_DIM)
		lk.set_custom_font_size(0, 13)
	if q != "" and root.get_child_count() == 0:
		var none := tree.create_item(root)
		none.set_text(0, "찾는 내용이 없습니다")
		none.set_selectable(0, false)
		none.set_custom_color(0, C_DIM)


func _on_pick() -> void:
	var it := tree.get_selected()
	if it == null or it.get_metadata(0) == null:
		return
	if String(it.get_metadata(0)) == current_id:
		return
	current_id = String(it.get_metadata(0))
	_render()
	rebuild.call_deferred()


func _step(d: int) -> void:
	var pages := Guide.open_pages()
	var i := -1
	for k in pages.size():
		if pages[k]["id"] == current_id:
			i = k
	var j := clampi(i + d, 0, pages.size() - 1)
	if j != i and j >= 0:
		current_id = pages[j]["id"]
		_render()
		rebuild()


func _render() -> void:
	var p := Guide.page(current_id)
	if p.is_empty():
		return
	if not Progress.guide_read.has(p["id"]):
		Progress.guide_read[p["id"]] = true
		Progress.save_game()
	sec_label.text = p["sec"]
	title_label.text = p["title"]
	body.text = String(p["body"]).replace("[code]", "[color=#c3e88d][code]").replace("[/code]", "[/code][/color]")
	var has_code: bool = p.has("code")
	code_view.visible = has_code
	btn_example.visible = has_code or p.has("task")
	btn_example.text = "과제를 새 파일로 열기" if p.has("task") else "이 코드를 새 파일로 열기"
	if has_code:
		if code_view.syntax_highlighter == null and editor != null:
			code_view.syntax_highlighter = editor._highlighter()
		code_view.text = p["code"]
		code_view.custom_minimum_size.y = 34 + 24 * code_view.get_line_count()
	task_label.visible = p.has("task")
	task_view.visible = p.has("task")
	if p.has("task"):
		if task_view.syntax_highlighter == null and editor != null:
			task_view.syntax_highlighter = editor._highlighter()
		task_view.text = p["task"]
		task_view.custom_minimum_size.y = 34 + 24 * task_view.get_line_count()
	_render_hints(p)
	try_box.visible = p.has("try")
	if p.has("try"):
		try_label.text = "해 보기  ▸  " + p["try"]
	var pages := Guide.open_pages()
	btn_prev.disabled = pages.is_empty() or pages[0]["id"] == current_id
	btn_next.disabled = pages.is_empty() or pages[-1]["id"] == current_id
	page_changed.emit(p)
