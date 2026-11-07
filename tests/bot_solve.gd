extends SceneTree
## Can every enemy be killed? Runs the test bot's solver (scripts/bot.gd: cheapest sequence of real
## operators that brings f to exactly 0) on the enemies of each stage, with all research up to that chapter.
## Run: godot --headless --path . -s res://tests/bot_solve.gd -- [--stage=5-5] [--bosses] [--hard]
##   --bosses : bosses only (normal and hard versions)    no --stage: every stage 1-1 … 6-6


class FakeMap:
	var total_length := 100.0
	var path_cells := {}
	func point_at(d: float) -> Vector2:
		return Vector2(d, 0)


class FakeMain:
	var available_towers: Array = []
	var map := FakeMap.new()
	var autotest_slots: Array = []
	var autotest_perfect := false


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var D = root.get_node("Data")
	var G = root.get_node("Game")
	var P = root.get_node("Progress")
	P.persist = false
	var only := ""
	var bosses := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			only = a.substr(8)
		elif a == "--bosses":
			bosses = true
	var stuck := 0
	for sid in D.STAGE_ORDER:
		if only != "" and sid != only:
			continue
		var ch := int(D.STAGES[sid]["chapter"])
		if ch > 6:
			break
		P.research = {}
		for n in D.RESEARCH:
			if int(n["chapter"]) <= ch and not n.get("axiom", false):
				P.research[n["id"]] = true
		var fm := FakeMain.new()
		for t in D.chapter_towers(ch):
			if D.TOWERS[t]["research"] == "" or P.has(D.TOWERS[t]["research"]):
				fm.available_towers.append(t)
		G.stage_id = sid
		G.x_end = float(D.STAGES[sid]["x_end"])
		var st: Dictionary = D.STAGES[sid]
		for hard in [false, true]:
			G.hard = hard
			var list: Array = []
			if not bosses:
				for m in st["mix"]:
					list.append(m[0])
			for b in D.stage_bosses(st):
				list.append(b[0])
			var bot = load("res://scripts/bot.gd").new(fm)
			var rng := RandomNumberGenerator.new()
			for tpl in list:
				if D.TEMPLATES[tpl].get("special", "") != "" or D.COUNTERS.has(tpl):
					continue
				var f: Expr = D.make_expr(tpl, rng, 15)
				var sol: Dictionary = bot.solve(f)
				var seq: Array = []
				var hits := 0
				for s in sol["seq"]:
					seq.append("%s×%d" % [s[0], s[1]])
					hits += int(s[1])
				var trig: bool = f.has_trig() and not f.has_growing()
				var tag := "ok" if sol["dead"] else ("Σ+D?" if trig and fm.available_towers.has("merge") else "STUCK")
				if tag == "STUCK":
					stuck += 1
				print("%-4s %-4s %-9s %-5s %3d hits  %-48s %s" % [sid, "hard" if hard else "norm", tpl, tag, hits, f.to_text().substr(0, 48), " ".join(PackedStringArray(seq)).substr(0, 90)])
	print("stuck: %d" % stuck)
	quit()
