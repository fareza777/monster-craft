class_name ChunkWorker
extends RefCounted
## Runs one background chunk job. All state is copied in, results are written
## under the shared mutex, so the scene tree is never touched off-thread.

var seed_value := 0
var cx := 0
var cz := 0
var key := Vector2i.ZERO
var diff_dict: Dictionary = {}
var blocks: PackedByteArray
var nx: PackedByteArray
var px: PackedByteArray
var nz: PackedByteArray
var pz: PackedByteArray
var version := 0
var mutex: Mutex
var results: Dictionary

func run_generate() -> void:
	var t0 := Time.get_ticks_msec()
	var gen := TerrainGen.new(seed_value)
	var buf := gen.generate_chunk(cx, cz)
	pass
	for idx in diff_dict:
		var i := int(idx)
		if i >= 0 and i < buf.size():
			buf[i] = int(diff_dict[idx])
	if mutex != null:
		mutex.lock()
	results[key] = {"type": "gen", "data": buf}
	if mutex != null:
		mutex.unlock()

func run_mesh() -> void:
	var t0 := Time.get_ticks_msec()
	var groups := GreedyMesher.build(blocks, nx, px, nz, pz, cx, cz)
	pass
	if mutex != null:
		mutex.lock()
	results[key] = {"type": "mesh", "data": groups, "version": version}
	if mutex != null:
		mutex.unlock()
