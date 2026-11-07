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
var guide_read: Dictionary = {}   # guide page id -> true once opened (NEW badges)
var dev_mode: bool = false      # developer tools visible in the menu, F9 = instant clear
var dev_short: bool = false     # developer: stages play 5 of their 15 waves
var auto_wave: bool = false     # start the next wave by itself after a short breather
var normal_clear: Dictionary = {}   # stage id -> true once cleared on normal (its Insight is paid once)
var hard_stars: Dictionary = {}     # stage id -> best stars on hard
var algo_default: Dictionary = {}   # tower type -> .py file new towers of that type run
const SCRIPT_DIR := "user://scripts"
var _script_cache: Dictionary = {}
var _script_mtime: Dictionary = {}   # name -> modified time when last read/written by the game
var scripts_serial: int = 0          # bumps when a file changed outside the game (VS Code …)
var _watch_t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # the file watcher also runs while the editor pauses the game
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
	if not missing_essentials(node).is_empty():
		return "locked"
	return "available"


## Optional upgrades open only after every essential research of their chapter.
func missing_essentials(node: Dictionary) -> Array:
	var out: Array = []
	# only the extra upgrades wait for the chapter's essentials; research that opens a tower never does
	# (completing it can be what a stage needs, e.g. 완전제곱식 for 2-4)
	if not node.get("upgrade", false):
		return out
	for id in Data.essentials_of(int(node["chapter"])):
		if not has(id):
			out.append(id)
	return out


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
## Insight is paid once per stage per mode: normal ¾, hard 3/2 of the chapter budget ÷ stages.
## Insight is paid for the first clear of a stage in each mode (Data.stage_insight: normal ¾, hard 3/2 of
## the chapter's research budget, spread over its stages). A loss pays nothing, so a stage cannot be farmed;
## meeting a chapter's counterexample pays its own Insight (main.counter_reach).
func record_stage(sid: String, earned_stars: int, _waves_cleared: int, hard: bool = false) -> int:
	var gain := 0
	if earned_stars > 0:
		if hard:
			if not hard_stars.has(sid):
				gain += Data.stage_insight(sid, true)
			hard_stars[sid] = maxi(int(hard_stars.get(sid, 0)), earned_stars)
		elif not normal_clear.has(sid):
			gain += Data.stage_insight(sid, false)
			normal_clear[sid] = true
		stars[sid] = maxi(int(stars.get(sid, 0)), earned_stars)
	insight += gain
	save_game()
	return gain


## First encounter with a new kind of enemy pays a little Insight.
func see(template: String) -> bool:
	if seen.has(template):
		return false
	seen[template] = true
	return true


func add_insight(n: int) -> void:
	insight += n
	save_game()


var save_error: String = ""   # "" = the last save is on disk and verified; otherwise what went wrong


## Writes the save safely and returns whether it really landed on disk (read back and compared).
## Steps: temp file → verify → previous good save copied to .bak → temp replaces the save →
## if that replace fails, write the save directly → verify the result. load_game falls back to .bak.
func save_game() -> bool:
	if not persist:
		return true
	var text := JSON.stringify({
		"insight": insight, "research": research, "stars": stars, "flags": flags, "seen": seen, "axioms": axioms_on,
		"palette_open": palette_open, "guide_read": guide_read, "dev_mode": dev_mode, "dev_short": dev_short, "auto_wave": auto_wave,
		"algo_default": algo_default, "normal_clear": normal_clear, "hard_stars": hard_stars,
	})
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return _save_failed("임시 파일을 만들 수 없습니다 (%s)" % error_string(FileAccess.get_open_error()))
	f.store_string(text)
	f.close()
	if not _save_matches(tmp):
		return _save_failed("임시 파일이 제대로 써지지 않았습니다")   # the old save stays untouched
	var dir := DirAccess.open("user://")
	if dir == null:
		return _save_failed("저장 폴더를 열 수 없습니다")
	if FileAccess.file_exists(SAVE_PATH) and typeof(_parse_save(SAVE_PATH)) == TYPE_DICTIONARY:
		var ce := dir.copy(SAVE_PATH, SAVE_PATH + ".bak")
		if ce != OK:
			push_warning("save: .bak 복사 실패 (%s)" % error_string(ce))
	var re := dir.rename(tmp, SAVE_PATH)
	if re != OK:
		# replacing failed (e.g. the file is locked a moment): write it directly; the previous good
		# save is in .bak if this goes wrong too
		push_warning("save: 교체 실패 (%s), 직접 씁니다" % error_string(re))
		var g := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if g != null:
			g.store_string(text)
			g.close()
		dir.remove(tmp)
	if not _save_matches(SAVE_PATH):
		return _save_failed("저장 파일을 확인하지 못했습니다. 이전 저장은 %s.bak에 있습니다" % SAVE_PATH)
	save_error = ""
	return true


func _save_matches(path: String) -> bool:
	var d = _parse_save(path)
	return typeof(d) == TYPE_DICTIONARY and int(d.get("insight", -1)) == insight \
		and (d.get("research", {}) as Dictionary).size() == research.size() \
		and (d.get("stars", {}) as Dictionary).size() == stars.size()


func _save_failed(why: String) -> bool:
	save_error = why
	push_error("save failed: " + why)
	return false


func _parse_save(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH) and not FileAccess.file_exists(SAVE_PATH + ".bak"):
		return
	var d = _parse_save(SAVE_PATH)
	if typeof(d) != TYPE_DICTIONARY:
		# damaged save: keep it aside (it is not overwritten later) and use the previous one
		if FileAccess.file_exists(SAVE_PATH):
			var dir := DirAccess.open("user://")
			if dir != null:
				dir.copy(SAVE_PATH, SAVE_PATH + ".broken")
		d = _parse_save(SAVE_PATH + ".bak")
		if typeof(d) != TYPE_DICTIONARY:
			return
		push_warning("save was damaged; loaded the backup (%s.bak)" % SAVE_PATH)
	insight = int(d.get("insight", 0))
	research = d.get("research", {})
	flags = d.get("flags", {})
	seen = d.get("seen", {})
	axioms_on = d.get("axioms", {})
	palette_open = d.get("palette_open", false)
	dev_mode = d.get("dev_mode", false)
	guide_read = d.get("guide_read", {})
	dev_short = d.get("dev_short", false)
	auto_wave = d.get("auto_wave", false)
	algo_default = d.get("algo_default", {})
	normal_clear = d.get("normal_clear", {})
	hard_stars = {}
	var hs: Dictionary = d.get("hard_stars", {})
	for k in hs:
		hard_stars[k] = int(hs[k])
	stars = {}
	var raw: Dictionary = d.get("stars", {})
	for k in raw:
		stars[k] = int(raw[k])
		if stars[k] > 0 and not d.has("normal_clear"):
			normal_clear[k] = true   # clears from before the modes existed count as normal


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
		_script_mtime[name] = FileAccess.get_modified_time(path)
	_script_cache[name] = txt
	return txt


## Every half second: a file edited in another program is read again (towers use it on their next
## shot; the in-game editor reloads it). Like an IDE's file watcher.
func _process(delta: float) -> void:
	_watch_t += delta
	if _watch_t < 0.5:
		return
	_watch_t = 0.0
	var changed := false
	for name in _script_cache.keys():
		if String(name).begins_with("res://"):
			continue
		var path: String = SCRIPT_DIR + "/" + name
		var mt := FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else -1
		if mt != int(_script_mtime.get(name, mt)):
			_script_cache.erase(name)
			_script_mtime.erase(name)
			changed = true
	var listing := ",".join(PackedStringArray(list_scripts()))
	if listing != _last_listing:
		_last_listing = listing
		changed = true
	if changed:
		scripts_serial += 1


var _last_listing: String = ""


func write_script(name: String, src: String) -> void:
	DirAccess.make_dir_recursive_absolute(SCRIPT_DIR)
	var f := FileAccess.open(SCRIPT_DIR + "/" + name, FileAccess.WRITE)
	if f != null:
		f.store_string(src)
		f.close()
	_script_cache[name] = src
	_script_mtime[name] = FileAccess.get_modified_time(SCRIPT_DIR + "/" + name)
	_last_listing = ",".join(PackedStringArray(list_scripts()))


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


## Examples are created only when the file does not exist. A player's file is never overwritten,
## even if it uses an older API (the editor shows the error; the guide has current examples).
func ensure_example_scripts() -> void:
	for pair in [["attack.py", Data.EXAMPLE_ATTACK]]:
		if not FileAccess.file_exists(SCRIPT_DIR + "/" + pair[0]):
			write_script(pair[0], pair[1])
	# autocompletion for external editors (VS Code / Pylance read __builtins__.pyi). Ours, always current.
	DirAccess.make_dir_recursive_absolute(SCRIPT_DIR)
	var stub := FileAccess.open(SCRIPT_DIR + "/__builtins__.pyi", FileAccess.WRITE)
	if stub != null:
		stub.store_string(Data.BUILTINS_STUB)
		stub.close()


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
	normal_clear = {}
	hard_stars = {}
	flags = {}
	seen = {}
	axioms_on = {}
	guide_read = {}
	save_game()
