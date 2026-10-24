class_name BillboardAdCatalog
extends Resource

@export var entries: Array[BillboardAdEntry] = []


func approved_entries() -> Array[BillboardAdEntry]:
	var result: Array[BillboardAdEntry] = []
	var seen := {}
	for entry in entries:
		if entry == null or not entry.is_ready_for_rotation() or seen.has(entry.id):
			continue
		seen[entry.id] = true
		result.append(entry)
	return result
