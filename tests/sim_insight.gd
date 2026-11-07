extends SceneTree
## Insight economy walk-through: a player who clears every stage once, in order, and spends Insight as
## soon as research opens (essential research first, then the cheapest). Two players:
##   default  : clears every stage on normal only            → "RS  <stage> <research…>" (owned when it starts)
##   --hard   : clears each stage on normal, then on hard    → "RSH <stage> <research…>" (owned when its hard run starts)
## tests/modes.sh uses these lines, so the balance test plays with the research a real player would have.
## Run: godot --headless --path . -s res://tests/sim_insight.gd -- [--hard] [--quiet]


func _initialize() -> void:
	call_deferred("run")


var D
var P


func _buy() -> Array:
	var bought: Array = []
	var again := true
	while again:
		again = false
		var best = null
		for n in D.RESEARCH:
			if P.research_state(n) != "available" or P.insight < int(n["cost"]) or int(n["chapter"]) > 6 \
					or not P.chapter_visible(int(n["chapter"])):
				continue
			if best == null or (n.get("essential", false) and not best.get("essential", false)) \
					or (n.get("essential", false) == best.get("essential", false) and int(n["cost"]) < int(best["cost"])):
				best = n
		if best != null and P.buy_research(best):
			bought.append(best["id"])
			again = true
	return bought


func _owned() -> String:
	var out: Array = []
	for n in D.RESEARCH:
		if P.has(n["id"]):
			out.append(n["id"])
	return ",".join(PackedStringArray(out)) if not out.is_empty() else "none"


func run() -> void:
	D = root.get_node("Data")
	P = root.get_node("Progress")
	P.persist = false
	P.reset_save()
	P.persist = false
	var args := OS.get_cmdline_user_args()
	var with_hard := args.has("--hard")
	var quiet := args.has("--quiet")
	for sid in D.STAGE_ORDER:
		if int(D.STAGES[sid]["chapter"]) > 6:
			break
		var bought := _buy()
		if not quiet:
			print("%s start  insight_left=%d  bought=%s" % [sid, P.insight, ",".join(PackedStringArray(bought))])
		if not with_hard:
			print("RS %s %s" % [sid, _owned()])
		var st: Dictionary = D.STAGES[sid]
		var g: int = P.record_stage(sid, 3, 15, false)
		var c := 0
		if st.has("counter"):
			var ci: Dictionary = D.COUNTERS[st["counter"]]
			P.set_flag(ci["flag"])
			if ci.has("extra_flag"):
				P.set_flag(ci["extra_flag"])
			c = int(ci["insight"])
		if sid == "1-6":   # the fake ending: x walks in after the credits
			P.set_flag("met_x")
			P.set_flag("fake_ending")
			c = int(D.COUNTERS["x_counter"]["insight"])
		P.insight += c
		if with_hard:
			var hb := _buy()
			print("RSH %s %s" % [sid, _owned()])
			g += P.record_stage(sid, 3, 15, true)
			if not quiet and not hb.is_empty():
				print("      before hard: bought=%s" % ",".join(PackedStringArray(hb)))
		if not quiet:
			print("      +%d clear, +%d counter" % [g, c])
	quit()
