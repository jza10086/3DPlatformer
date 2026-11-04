extends Node3D
## Lighthouse Isles: one complete authored world, not a random obstacle generator.
## All route geometry is original. Tops, widths and branch metadata are also used
## observationally by the input-only regression runner; they never drive the cube.
signal checkpoint_reached(index: int)
signal hazard_touched
signal finish_reached

const INK := Color("274651")
const CREAM := Color("d9caab")
const MINT := Color("56ba93")
const BLUE := Color("5c9fca")
const CORAL := Color("ed7958")
const GOLD := Color("efbf56")
const ROCK := Color("597680")
const GRASS := Color("62a789")
const WOOD := Color("b98b62")
var route: Array[Dictionary] = []
var upper_route: Array[Dictionary] = []
var chapter_starts: Array[Vector3] = []
var checkpoints: Array[Vector3] = []
var checkpoint_chapters: Array[int] = [0,1,1,2,3,3,4,4,5,5]
var branch_split_index:=0
var branch_join_index:=0
var rollers: Array[Dictionary] = []
var hurdles: Array[Dictionary] = []
var checkpoint_beacons: Array[MeshInstance3D] = []
var checkpoint_route_indices: Array[int] = []
var finish_position := Vector3(-8,16.48,-28)
var overview_center := Vector3(0,6,-12)
var overview_size := 165.0
var movers: Array[Dictionary] = []
var sweepers: Array[Node3D] = []
var gates: Array[Dictionary] = []
var gate: Area3D
var gate_mesh: MeshInstance3D
var gate_light: MeshInstance3D
var gate_active := false
var clock := 0.0
var checkpoint_rings: Array[MeshInstance3D] = []
var confetti: Array[Node3D] = []
var celebrating := false
var materials: Dictionary = {}
var windmill_rotors: Array[Node3D] = []
var current_chapter := 0

func _ready() -> void:
	gate = %TimedGate
	gate_mesh = %GateMesh
	gate_light = %GateLight
	finish_position = %FinishPoint.global_position
	branch_split_index = get_meta("branch_split")
	branch_join_index = get_meta("branch_join")
	checkpoint_chapters.clear()
	# Order belongs to each saved landing pad. Nested meshes and art may be freely reordered.
	for group: StringName in [&"main_route", &"upper_route"]:
		var entries: Array[Dictionary] = route if group == &"main_route" else upper_route
		var ordered: Array[Node] = _members(group)
		ordered.sort_custom(func(a: Node, b: Node) -> bool: return a.get_meta("route_order") < b.get_meta("route_order"))
		for body: Node3D in ordered:
			var info: Dictionary = body.get_meta("route_data").duplicate()
			info["body"] = body
			info["top"] = body.position.y
			entries.append(info)
			if info.kind == "roller":
				var roller_body: Node3D = body.get_node(body.get_meta("roller_body"))
				info["roller"] = roller_body
				rollers.append({"root": body, "body": roller_body, "visual": body.get_node(body.get_meta("roller_visual")), "radius": info.radius, "speed": info.speed, "length": body.get_meta("length")})
	for body: Node3D in _members(&"island_mover"):
		movers.append({"body":body, "origin":body.position, "axis":body.get_meta("axis"), "speed":body.get_meta("speed"), "phase":body.get_meta("phase"), "amplitude":body.get_meta("amplitude")})
	sweepers.assign(_members(&"island_sweeper"))
	windmill_rotors.assign(_members(&"island_rotor"))
	confetti.assign(_members(&"island_confetti"))
	checkpoint_rings.assign(_members(&"save_ring"))
	checkpoint_beacons.assign(_members(&"save_beacon"))
	var spawns: Array[Node] = _members(&"island_spawn")
	spawns.sort_custom(func(a: Node, b: Node) -> bool: return a.get_meta("index") < b.get_meta("index"))
	for spawn: Marker3D in spawns:
		checkpoints.append(spawn.global_position)
		checkpoint_chapters.append(spawn.get_meta("chapter"))
		checkpoint_route_indices.append(spawn.get_parent().get_meta("route_order"))
	for chapter: Marker3D in find_children("Chapter*", "Marker3D", false, false):
		chapter_starts.append(chapter.global_position)
	for zone: Area3D in _members(&"island_checkpoint"):
		zone.body_entered.connect(_on_checkpoint.bind(zone.get_meta("checkpoint")))
	for zone: Area3D in _members(&"island_hazard"):
		zone.body_entered.connect(_on_hazard)
	%FinishZone.body_entered.connect(_on_finish)
	gates.append({"area":gate, "mesh":gate_mesh, "light":gate_light, "parent":gate.get_parent()})
	for marker: Marker3D in _members(&"island_hurdle"):
		hurdles.append({"parent":marker.get_parent(), "at":marker.global_position, "width":marker.get_meta("width"), "height":marker.get_meta("height")})

func _members(group: StringName) -> Array[Node]:
	return get_tree().get_nodes_in_group(group).filter(is_ancestor_of)

func _on_checkpoint(body: Node3D, index: int) -> void:
	if body.is_in_group("player"):
		checkpoint_reached.emit(index)

func _on_hazard(body: Node3D) -> void:
	if body.is_in_group("player"):
		hazard_touched.emit()

func _on_finish(body: Node3D) -> void:
	if body.is_in_group("player"):
		finish_reached.emit()

func mat(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var key := str(color)+str(glow)
	if materials.has(key): return materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color.srgb_to_linear()
	m.roughness = .86
	m.metallic_specular = .12
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	materials[key] = m
	return m

func set_checkpoint(index: int) -> void:
	current_chapter=checkpoint_chapters[index]
	for ring: MeshInstance3D in checkpoint_rings:
		ring.material_override = mat(MINT if int(ring.get_meta("checkpoint")) <= index else GOLD)
	for beacon: MeshInstance3D in checkpoint_beacons:
		beacon.material_override = mat(MINT if int(beacon.get_meta("checkpoint")) <= index else GOLD,0.5)

func camera_forward_at(pos: Vector3) -> Vector3:
	# Region-aware nearest segment: vertically stacked shortcut cannot spin the camera.
	var best_distance:=INF
	var best_forward:=Vector3.FORWARD
	for i in route.size()-1:
		if abs(route[i].chapter-current_chapter)>0: continue
		var a: Vector3=route[i].body.position
		var b: Vector3=route[i+1].body.position
		var flat:=Vector3(b.x-a.x,0,b.z-a.z)
		var t:=clampf(Vector3(pos.x-a.x,0,pos.z-a.z).dot(flat)/maxf(flat.length_squared(),.01),0,1)
		var nearest:=a+flat*t
		var d:=Vector2(pos.x-nearest.x,pos.z-nearest.z).length_squared()
		if d<best_distance:
			best_distance=d
			best_forward=flat.normalized()
	if current_chapter==2: return Vector3.RIGHT
	return best_forward

func _physics_process(delta: float) -> void:
	clock+=delta
	for move in movers: move.body.position=move.origin+move.get("axis",Vector3.RIGHT)*sin(clock*move.speed+move.phase)*move.amplitude
	for pivot in sweepers: pivot.rotation.y=clock*float(pivot.get_meta("speed"))+float(pivot.get_meta("phase"))
	for rotor in windmill_rotors: rotor.rotation.z+=delta*.45
	for roller in rollers: roller.visual.rotation.x=clock*roller.speed
	gate_active=fmod(clock,4.8)<2.4
	gate_mesh.visible=gate_active
	gate_light.material_override=mat(CORAL if gate_active else MINT,.15)
	if gate_active:
		for body in gate.get_overlapping_bodies():
			if body.is_in_group("player"): hazard_touched.emit()
	if celebrating:
		for i in confetti.size():
			var piece:=confetti[i]
			piece.visible=true
			piece.position.y-=delta*(1.3+(i%4)*.3)
			piece.rotation+=Vector3(delta,delta*1.7,delta*.6)
			if piece.position.y<16.2: piece.position.y=25

func reset() -> void:
	clock=0
	celebrating=false
	set_checkpoint(0)
	for move in movers: move.body.position=move.origin+move.get("axis",Vector3.RIGHT)*sin(move.phase)*move.amplitude
	for pivot in sweepers: pivot.rotation.y=float(pivot.get_meta("phase"))
	for roller in rollers: roller.visual.rotation.x=0
	for piece in confetti: piece.visible=false
