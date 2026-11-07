extends Node
## Run state. Economy follows a formula, Exponential-Idle style:  dρ/dt = c₁ · c₂  (only while a wave runs).

signal changed
signal integrity_depleted

var rho: float = 0.0
var integrity: int = 0
var wave: int = 0
var endless: bool = false
var kills: int = 0
var harvested: float = 0.0
var c1_level: int = 0
var c2_level: int = 0
var stage_id: String = "1-1"
var x_end: float = 3.0
var leaked: int = 0
var max_combo: int = 0
var start_integrity: int = 100
var ult_left: int = 0


func reset() -> void:
	rho = Data.START_RHO
	integrity = Data.START_INTEGRITY
	wave = 0
	endless = false
	kills = 0
	harvested = 0.0
	c1_level = 0
	c2_level = 0
	leaked = 0
	max_combo = 0
	stage_id = Progress.current_stage
	x_end = float(Data.STAGES[stage_id]["x_end"])
	rho = float(Data.CHAPTERS[int(Data.STAGES[stage_id]["chapter"])].get("rho", Data.START_RHO))
	integrity = int(Data.STAGES[stage_id].get("integrity", Data.CHAPTERS[int(Data.STAGES[stage_id]["chapter"])].get("integrity", Data.START_INTEGRITY)))
	start_integrity = integrity
	ult_left = 2 if int(Data.STAGES[stage_id]["chapter"]) >= 2 else 0
	changed.emit()


func c1() -> int:
	return 1 + c1_level


func c2() -> int:
	return 1 << c2_level


func rho_rate() -> int:
	return c1() * c2()


func c1_cost() -> int:
	return int(round(20.0 * pow(1.6, c1_level)))


func c2_cost() -> int:
	return int(round(250.0 * pow(6.0, c2_level)))


func buy_c1() -> bool:
	if not spend(c1_cost()):
		return false
	c1_level += 1
	changed.emit()
	return true


func c2_unlocked() -> bool:
	return Progress.has("mult")


func buy_c2() -> bool:
	if not c2_unlocked() or not spend(c2_cost()):
		return false
	c2_level += 1
	changed.emit()
	return true


func spend(cost: int) -> bool:
	if rho < cost:
		return false
	rho -= cost
	changed.emit()
	return true


func add_rho(n: float) -> void:
	rho += n


func damage(n: int) -> void:
	if integrity <= 0 or n <= 0:
		return
	leaked += 1
	integrity = maxi(0, integrity - n)
	changed.emit()
	if integrity <= 0:
		integrity_depleted.emit()
