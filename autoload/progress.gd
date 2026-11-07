extends Node
## Persistent meta-progression: Insight, research, stage records, story flags.

const SAVE_PATH := "user://limit_break_save.json"

var insight: int = 0
var research: Dictionary = {}   # id -> true
var stars: Dictionary = {}      # stage id -> best stars (0..3)
var flags: Dictionary = {}      # "met_x", "fake_ending"
var seen: Dictionary = {}       # enemy template -> true
var current_stage: String = "1-1"
var axioms_on: Dictionary = {}  # axiom id -> true (at most AXIOM_SLOTS)
var auto_axioms: bool = false   # autotest: every owned axiom counts as active
const AXIOM_SLOTS := 3
var persist: bool = true        # autotest turns this off so it never touches the real save
var palette_open: bool = false  # chapter 2+: arithmetic towers folded into one group
var dev_mode: bool = false      # developer tools visible in the menu, F9 = instant clear
var dev_short: bool = false     # developer: stages play 5 of their 15 waves
var auto_wave: bool = false     # start the next wave by itself after a short breather
var algo_default: Dictionary = {}   # tower type -> .py file new towers of that type run
const SCRIPT_DIR := "user://scripts"
var _script_cache: Dictionary = {}


func _ready() -> void:
	load_game()
	# Playtest shortcut: `-- --dev-unlock` opens 1-1..1-6 without touching the real save.
	var args := OS.get_cmdline_user_args()
	if "--dev-unlock" in args:
		persist = false
		insight = maxi(insight, 60)
		for sid in ["1-1", "1-2", "1-3", "1-4", "1-5"]:
			stars[sid] = maxi(int(stars.get(sid, 0)), 1)
	# `-- --dev-unlock=all`: every chapter met and every stage open, research still to buy (insight 300).
	if "--dev-unlock=all" in args:
		persist = false
		insight = maxi(insight, 600)
		for fl in ["met_x", "fake_ending", "met_exp", "met_sin", "met_swarm", "met_exp2", "met_time", "met_signal", "met_quintic", "met_godel"]:
			flags[fl] = true
		for sid in Data.STAGE_ORDER:
			stars[sid] = maxi(int(stars.get(sid, 0)), 1)


func has(id: String) -> bool:
	if id == "code":   # algorithms come with the chapter-4 curse, free
		return research.has("code") or flag("met_sin")
	return id == "" or research.has(id)


## An axiom is in force when it was bought and switched on (max AXIOM_SLOTS at once).
func axiom(id: String) -> bool:
	return research.has(id) and (auto_axioms or axioms_on.get(id, false))


func toggle_axiom(id: String) -> bool:
	if not research.has(id):
		return false
	if axioms_on.get(id, false):
		axioms_on.erase(id)
	elif axioms_on.size() < AXIOM_SLOTS:
		axioms_on[id] = true
	else:
		return false
	save_game()
	return true


func flag(id: String) -> bool:
	return flags.get(id, false)


func set_flag(id: String) -> void:
	flags[id] = true
	save_game()


func research_state(node: Dictionary) -> String:
	if has(node["id"]):
		return "owned"
	for r in node.get("req", []):
		if not has(r):
			return "locked"
	if node.has("flag") and not flag(node["flag"]):
		return "locked"
	if node.has("stage") and int(stars.get(node["stage"], 0)) == 0:
		return "locked"
	return "available"


func buy_research(node: Dictionary) -> bool:
	if research_state(node) != "available" or insight < int(node["cost"]):
		return false
	insight -= int(node["cost"])
	research[node["id"]] = true
	if node.get("axiom", false) and axioms_on.size() < AXIOM_SLOTS:
		axioms_on[node["id"]] = true
	save_game()
	return true


func stage_unlocked(sid: String) -> bool:
	var order: Array = Data.STAGE_ORDER
	var idx := order.find(sid)
	if idx <= 0:
		return true
	var st: Dictionary = Data.STAGES[sid]
	if st.has("flag"):
		return flag(st["flag"])   # a chapter opens when its counterexample has been met
	return stars.get(order[idx - 1], 0) > 0


func chapter_visible(ch: int) -> bool:
	for sid in Data.STAGE_ORDER:
		if int(Data.STAGES[sid]["chapter"]) == ch and stage_unlocked(sid):
			return true
	return false


## Records a result; returns the Insight earned.
## Insight is scarce on purpose: a first clear pays 8, each new star 3 (once), a loss a small consolation
## (1 per 5 waves survived, at most 3). Replaying a cleared stage pays nothing new.
func record_stage(sid: String, earned_stars: int, waves_cleared: int) -> int:
	var gain := 0
	var prev: int = stars.get(sid, 0)
	if earned_stars > 0 and prev == 0:
		gain += 8
	if earned_stars > prev:
		gain += (earned_stars - prev) * 3
		stars[sid] = earned_stars
	if earned_stars == 0:
		gain += mini(3, int(waves_cleared / 5.0))
	insight += gain
	save_game()
	return gain


## First encounter with a new kind of enemy pays a little Insight.
func see(template: String) -> bool:
	if seen.has(template):
		return false
	seen[template] = true
	insight += 1
	return true


func add_insight(n: int) -> void:
	insight += n
	save_game()


func save_game() -> void:
	if not persist:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"insight": insight, "research": research, "stars": stars, "flags": flags, "seen": seen, "axioms": axioms_on,
		"palette_open": palette_open, "dev_mode": dev_mode, "dev_short": dev_short, "auto_wave": auto_wave,
		"algo_default": algo_default,
	}))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	insight = int(d.get("insight", 0))
	research = d.get("research", {})
	flags = d.get("flags", {})
	seen = d.get("seen", {})
	axioms_on = d.get("axioms", {})
	palette_open = d.get("palette_open", false)
	dev_mode = d.get("dev_mode", false)
	dev_short = d.get("dev_short", false)
	auto_wave = d.get("auto_wave", false)
	algo_default = d.get("algo_default", {})
	stars = {}
	var raw: Dictionary = d.get("stars", {})
	for k in raw:
		stars[k] = int(raw[k])


# ---------- attack algorithms: real .py files in user://scripts ----------

func list_scripts() -> Array:
	var out: Array = []
	var dir := DirAccess.open(SCRIPT_DIR)
	if dir == null:
		return out
	for fn in dir.get_files():
		if fn.ends_with(".py"):
			out.append(fn)
	out.sort()
	return out


func read_script(name: String) -> String:
	if name == "":
		return ""
	if _script_cache.has(name):
		return _script_cache[name]
	var path := name if name.begins_with("res://") else SCRIPT_DIR + "/" + name
	var txt := ""
	if FileAccess.file_exists(path):
		txt = FileAccess.get_file_as_string(path)
	_script_cache[name] = txt
	return txt


func write_script(name: String, src: String) -> void:
	DirAccess.make_dir_recursive_absolute(SCRIPT_DIR)
	var f := FileAccess.open(SCRIPT_DIR + "/" + name, FileAccess.WRITE)
	if f != null:
		f.store_string(src)
		f.close()
	_script_cache[name] = src


func delete_script(name: String) -> void:
	DirAccess.remove_absolute(SCRIPT_DIR + "/" + name)
	_script_cache.erase(name)
	for k in algo_default.keys():
		if algo_default[k] == name:
			algo_default.erase(k)
	save_game()


func rename_script(old: String, new_name: String) -> bool:
	if new_name == old or FileAccess.file_exists(SCRIPT_DIR + "/" + new_name):
		return false
	var src := read_script(old)
	write_script(new_name, src)
	delete_script(old)
	return true


## Drop external edits (files changed outside the game) so the next read sees them.
func reload_scripts() -> void:
	_script_cache.clear()


func ensure_example_scripts() -> void:
	# (re)write the examples when missing or still in the first version's API (e.growing, e.ann_degree …)
	for pair in [["attack.py", Data.EXAMPLE_ATTACK], ["pair.py", Data.EXAMPLE_DAMP]]:
		var old := read_script(pair[0])
		if old == "" or old.contains("e.growing") or old.contains("ann_degree") or old.contains("def attack(enemies):\n    return enemies[0]") or old.contains("e.f.has(\"exp\")"):
			write_script(pair[0], pair[1])


## Developer: every chapter met and every stage open (skips the reveals).
func dev_unlock_all() -> void:
	for fl in ["met_x", "fake_ending", "met_exp", "met_sin", "met_swarm", "met_exp2", "met_time", "met_signal", "met_quintic", "met_godel"]:
		flags[fl] = true
	for sid in Data.STAGE_ORDER:
		stars[sid] = maxi(int(stars.get(sid, 0)), 1)
	save_game()


func reset_save() -> void:
	insight = 0
	research = {}
	stars = {}
	flags = {}
	seen = {}
	axioms_on = {}
	save_game()
