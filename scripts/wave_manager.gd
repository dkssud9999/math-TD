extends Node
## Turns wave definitions into a timed spawn queue.

var main
var queue: Array = []
var timer: float = 0.0
var spawning: bool = false


func start_wave(n: int) -> void:
	queue.clear()
	var groups: Array = main.waves[n - 1]
	for g in groups:
		var count := int(g[1])
		for i in count:
			var delay: float = float(g[2])
			if i == count - 1:
				delay = 2.0  # breather between groups
			queue.append({"type": g[0], "delay": delay})
	timer = 0.5
	spawning = true


func _process(delta: float) -> void:
	if not spawning:
		return
	timer -= delta
	while timer <= 0.0 and not queue.is_empty():
		var item: Dictionary = queue.pop_front()
		main.spawn_enemy(item["type"], 0.0)
		timer += float(item["delay"])
	if queue.is_empty():
		spawning = false


func finished() -> bool:
	return not spawning and queue.is_empty()
