class_name WaveData
extends Resource

@export var entries: Array[WaveEntry] = []


func size() -> int:
	var n := 0
	for e in entries:
		n += e.count
	return n
