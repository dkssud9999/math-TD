extends SceneTree
## Screenshots of the editor guide (dev aid). Run without --headless, with an isolated APPDATA.

func _initialize() -> void:
	call_deferred("run")


func _shot(name: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/" + name + ".png")


func _page(editor, id: String) -> void:
	editor._toggle_guide(true)
	editor.guide.current_id = id
	editor.guide._render()
	editor.guide.rebuild()


func run() -> void:
	var p = root.get_node("Progress")
	p.persist = false
	p.current_stage = "4-1"
	root.get_node("Game").stage_id = "4-1"
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var editor = load("res://scripts/code_editor.gd").new()
	editor.main = scene
	scene.add_child(editor)
	for i in 5:
		await process_frame
	editor.open(null)
	_page(editor, "task_sum")
	editor.guide.hints_shown["task_sum"] = 1
	editor.guide._render()
	await _shot("g1_task_sum")
	_page(editor, "calc")
	await _shot("g2_calc")
	p.dev_mode = true          # later pages, as if the player had reached 4-5
	_page(editor, "task_d")
	await _shot("g3_task_d")
	_page(editor, "errors")
	await _shot("g4_errors")
	_page(editor, "task_sum")
	editor._toggle_guide(false)
	editor._open_example(load("res://scripts/guide.gd").page("task_sum"))
	await _shot("g5_editor")
	quit()
