extends Node3D
## Original, geometry-only course. Platform tops are the world-space Y values below.
signal checkpoint_reached(index: int)
signal hazard_touched
signal finish_reached

const INK := Color("253a50")
const CREAM := Color("cfc8ac")
const MINT := Color("38ccb5")
const BLUE := Color("627ee8")
const CORAL := Color("ff796d")
const GOLD := Color("ffca65")

var route: Array[Dictionary] = []
var checkpoints: Array[Vector3] = [Vector3(0, 0.48, 3), Vector3(0, 1.48, -28), Vector3(0, 1.48, -59)]
var movers: Array[Dictionary] = []
var sweepers: Array[Node3D] = []
var gate: Area3D
var gate_mesh: MeshInstance3D
var gate_light: MeshInstance3D
var gate_active := false
var clock := 0.0
var checkpoint_rings: Array[MeshInstance3D] = []
var confetti: Array[Node3D] = []
var celebrating := false
var materials: Dictionary = {}

func _ready() -> void:
	_build_course()
	_build_scenery()

func mat(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var key := str(color) + str(glow)
	if materials.has(key): return materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.88
	m.metallic_specular = 0.15
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	materials[key] = m
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = mat(color)
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, top_radius: float = -1.0, segments: int = 24) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top_radius < 0 else top_radius
	shape.height = height
	shape.radial_segments = segments
	mesh.mesh = shape
	mesh.material_override = mat(color)
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

func _platform(center: Vector3, size: Vector2, color: Color, moving: bool = false) -> Node3D:
	var body: PhysicsBody3D = AnimatableBody3D.new() if moving else StaticBody3D.new()
	body.name = "Platform_%02d" % route.size()
	body.position = center
	if moving:
		(body as AnimatableBody3D).sync_to_physics = false
	add_child(body)
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = Vector3(size.x, 1.0, size.y)
	shape.shape = cube
	shape.position.y = -0.5
	body.add_child(shape)
	box(body, Vector3(0, -0.54, 0), Vector3(size.x, 0.9, size.y), color)
	box(body, Vector3(0, -0.06, 0), Vector3(size.x, 0.12, size.y), CREAM)
	# Dark inset undercarriage makes a strong floating-island silhouette.
	box(body, Vector3(0, -1.02, 0), Vector3(size.x * 0.8, 0.24, size.y * 0.78), INK.lightened(0.1))
	for x in [-1, 1]:
		box(body, Vector3(x * (size.x / 2 - 0.15), 0.015, 0), Vector3(0.12, 0.025, size.y - 0.3), color)
	# Take-off stripe and the runway arrow are visible from the chase camera.
	box(body, Vector3(0, 0.018, -size.y / 2 + 0.4), Vector3(minf(2.3, size.x - 1), 0.03, 0.16), color)
	_arrow(body, Vector3(0, 0.025, -0.2), color)
	route.append({"body": body, "size": size, "top": center.y, "moving": moving})
	return body

func _arrow(parent: Node3D, pos: Vector3, color: Color) -> void:
	var a := box(parent, pos + Vector3(-0.2,0,0), Vector3(0.12, 0.03, 0.64), color)
	a.rotation.y = -0.7
	var b := box(parent, pos + Vector3(0.2,0,0), Vector3(0.12, 0.03, 0.64), color)
	b.rotation.y = 0.7

func _build_course() -> void:
	var start := _platform(Vector3(0, 0, 2), Vector2(10,8), MINT)
	_arch(start, Vector3(0,0,2), "SKYLINE  /  SPRINT", MINT, 7.8)
	_label(start, Vector3(0, 0.07, 0.8), "01   HOP", 0.0065, INK, true)
	_platform(Vector3(0,0,-7), Vector2(5.5,4), MINT)
	_platform(Vector3(2,0.5,-14), Vector2(5.5,4), MINT)
	_platform(Vector3(-1,1,-21), Vector2(6,5), MINT)
	var cp1 := _platform(Vector3(0,1,-29), Vector2(9,7), BLUE)
	_checkpoint(cp1, 1)
	_arch(cp1, Vector3(0,0,-0.7), "02   /   DRIFT", BLUE, 7.5)
	var p1 := _platform(Vector3(0,1,-38), Vector2(5.5,4), BLUE, true)
	movers.append({"body":p1, "origin":p1.position, "amplitude":2.2, "speed":0.85, "phase":0.0})
	_rail(Vector3(0,-0.6,-38), 10.7, BLUE)
	_platform(Vector3(0,1,-45), Vector2(7,4), BLUE)
	var p2 := _platform(Vector3(0,1,-52), Vector2(5.5,4), BLUE, true)
	movers.append({"body":p2, "origin":p2.position, "amplitude":2.2, "speed":1.0, "phase":1.4})
	_rail(Vector3(0,-0.6,-52), 10.7, BLUE)
	var cp2 := _platform(Vector3(0,1,-60), Vector2(10,7), CORAL)
	_checkpoint(cp2, 2)
	_arch(cp2, Vector3(0,0,-0.7), "03   /   RHYTHM", CORAL, 8)
	var spin := _platform(Vector3(0,1,-70), Vector2(10,7), CORAL)
	_sweeper(spin)
	_platform(Vector3(0,1.5,-79), Vector2(6,4), CORAL)
	var timed := _platform(Vector3(0,1.5,-87), Vector2(8,7), CORAL)
	_gate(timed)
	var end := _platform(Vector3(0,1.5,-99), Vector2(12,11), GOLD)
	_arch(end, Vector3(0,0,0), "FINISH", GOLD, 9.5)
	for x in range(-4,5):
		for z in range(2):
			box(end, Vector3(x*0.8,0.02,2.4+z*0.65), Vector3(0.79,0.03,0.64), INK if (x+z)%2==0 else Color.WHITE)
	var finish := _zone(end, Vector3(0,1.5,1.8), Vector3(11,3,2))
	finish.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player"): finish_reached.emit())
	for i in range(40):
		var piece := box(self, Vector3(randf_range(-5,5), randf_range(4,11), randf_range(-104,-94)), Vector3(0.12,0.26,0.08), [MINT, BLUE, CORAL, GOLD][i%4])
		piece.visible = false
		confetti.append(piece)

func _checkpoint(parent: Node3D, index: int) -> void:
	var ring := cylinder(parent, Vector3(0,0.025,1), 1.15, 0.045, Color("b3c6d3"), -1, 48)
	checkpoint_rings.append(ring)
	cylinder(parent, Vector3(0,0.052,1), 0.88, 0.03, CREAM, -1, 48)
	_label(parent, Vector3(0,0.09,1), "SAVE", 0.0045, INK, true)
	var area := _zone(parent, Vector3(0,1.5,1), Vector3(8,3,3.8))
	area.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player"): checkpoint_reached.emit(index))
	for x in [-1,1]:
		cylinder(parent, Vector3(x*3.6,0.8,1), 0.1, 1.6, INK)
		box(parent, Vector3(x*3.6+0.35,1.35,1), Vector3(0.7,0.45,0.05), MINT)

func set_checkpoint(index: int) -> void:
	for i in checkpoint_rings.size():
		checkpoint_rings[i].material_override = mat(MINT if i < index else Color("b3c6d3"))

func _zone(parent: Node3D, pos: Vector3, size: Vector3) -> Area3D:
	var area := Area3D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 2
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	area.add_child(col)
	parent.add_child(area)
	return area

func _sweeper(parent: Node3D) -> void:
	var pivot := Node3D.new()
	parent.add_child(pivot)
	pivot.position.y = 0.57
	sweepers.append(pivot)
	cylinder(parent, Vector3(0,0.2,0), 0.48, 0.4, INK)
	cylinder(parent, Vector3(0,0.45,0), 0.32, 0.2, GOLD)
	box(pivot, Vector3.ZERO, Vector3(9.3,0.28,0.3), CORAL)
	for x in [-4.3, -3.3, -2.3, -1.3, 1.3, 2.3, 3.3, 4.3]:
		box(pivot, Vector3(x,0,0), Vector3(0.32,0.29,0.31), CREAM)
	var area := _zone(pivot, Vector3.ZERO, Vector3(9.3,0.28,0.3))
	area.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player"): hazard_touched.emit())
	_label(parent, Vector3(3.8,0.04,1.9), "JUMP", 0.004, INK, true)

func _gate(parent: Node3D) -> void:
	gate = _zone(parent, Vector3(0,0.8,0), Vector3(7.6,0.23,0.23))
	for x in [-1,1]:
		box(parent, Vector3(x*3.8,1.3,0), Vector3(0.28,2.6,0.5), INK)
		box(parent, Vector3(x*3.8,2.7,0), Vector3(0.6,0.25,0.8), GOLD)
	gate_mesh = box(parent, Vector3(0,0.8,0), Vector3(7.6,0.23,0.23), CORAL)
	gate_light = cylinder(parent, Vector3(3.8,2.95,0), 0.22, 0.22, MINT)
	box(parent, Vector3(0,0.024,0), Vector3(7.4,0.04,0.45), GOLD)
	_label(parent, Vector3(0,0.045,2), "GREEN = GO", 0.0055, INK, true)

func _arch(parent: Node3D, pos: Vector3, text: String, color: Color, width: float) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	for side in [-1,1]:
		box(root, Vector3(side*width/2,1.8,0), Vector3(0.28,3.6,0.3), color)
		box(root, Vector3(side*width/2,0.12,0), Vector3(0.7,0.24,0.7), INK)
	box(root, Vector3(0,3.6,0), Vector3(width+0.3,0.7,0.35), color)
	_label(root, Vector3(0,3.6,0.19), text, 0.007, Color.WHITE)

func _label(parent: Node3D, pos: Vector3, text: String, scale_px: float, color: Color, flat: bool = false) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = scale_px
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	label.position = pos
	if flat: label.rotation_degrees.x = -90
	parent.add_child(label)

func _rail(pos: Vector3, width: float, color: Color) -> void:
	box(self, pos, Vector3(width,0.16,0.2), INK.lightened(0.25))
	for side in [-1,1]:
		cylinder(self, pos+Vector3(side*width/2,0,0), 0.25, 0.4, color)

func _build_scenery() -> void:
	# Low-poly islands and cloud shelves frame the course, never fake walkable surfaces.
	for i in range(14):
		var side := -1 if i % 2 == 0 else 1
		var z := 7.0 - i*9.0
		var x := side * (15.0 + (i%3)*5.0)
		var root := Node3D.new()
		root.position = Vector3(x,-5.0-(i%3),z)
		add_child(root)
		cylinder(root, Vector3(0,-2,0), 1.1, 5.0, Color("6b899e"), 4.0, 6)
		cylinder(root, Vector3.ZERO, 4.05, 0.8, Color("78b7b2"), 4.05, 6)
		for j in range(3):
			var t := Vector3((j-1)*1.7,1.1, sin(i+j)*1.4)
			cylinder(root, t+Vector3(0,-0.4,0), 0.13, 1.0, INK, -1, 6)
			cylinder(root, t+Vector3(0,0.5,0), 1.0, 2.8, Color("3b8e8a"), 0, 5)
	for i in range(25):
		var cloud := Node3D.new()
		cloud.position = Vector3(-38+(i%6)*15, -8-(i%4)*1.5, 16-(i/6)*31)
		add_child(cloud)
		for j in range(3):
			var sphere := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 3.0+j*0.7
			s.height = s.radius*2
			s.radial_segments = 12
			s.rings = 6
			sphere.mesh = s
			sphere.material_override = mat(Color("c5dae2"))
			sphere.position = Vector3(j*3,0,0)
			sphere.scale.y = 0.32
			cloud.add_child(sphere)
	_balloon(Vector3(-20,9,-42), CORAL)
	_balloon(Vector3(25,12,-91), GOLD)
	# Distant horizon mountains, not reachable geometry.
	for i in range(13):
		cylinder(self, Vector3(-90+i*15,-24,-145), 14, 20+(i%4)*7, Color("8faabd"), 0, 5)

func _balloon(pos: Vector3, color: Color) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var sphere := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 2.7
	mesh.height = 6.5
	mesh.radial_segments = 12
	mesh.rings = 6
	sphere.mesh = mesh
	sphere.material_override = mat(color)
	root.add_child(sphere)
	cylinder(root, Vector3(0,-3.2,0), 0.8, 1.0, CREAM, 1.4, 12)
	box(root, Vector3(0,-4.6,0), Vector3(1.3,0.75,1.1), INK)
	for x in [-0.5,0.5]:
		box(root, Vector3(x,-3.95,0), Vector3(0.05,1.4,0.05), CREAM)

func _physics_process(delta: float) -> void:
	clock += delta
	for move in movers:
		move.body.position = move.origin + Vector3(sin(clock*move.speed+move.phase)*move.amplitude,0,0)
	for pivot in sweepers:
		pivot.rotation.y = clock * 1.45
	gate_active = fmod(clock,4.4) < 2.3
	gate_mesh.visible = gate_active
	gate_light.material_override = mat(CORAL if gate_active else MINT)
	if gate_active:
		for body in gate.get_overlapping_bodies():
			if body.is_in_group("player"): hazard_touched.emit()
	if celebrating:
		for i in confetti.size():
			var piece := confetti[i]
			piece.visible = true
			piece.position.y -= delta * (1.2+(i%4)*0.3)
			piece.rotation += Vector3(delta,delta*1.7,delta*0.6)
			if piece.position.y < 1.7: piece.position.y = 9.0

func reset() -> void:
	clock = 0.0
	celebrating = false
	set_checkpoint(0)
	for piece in confetti: piece.visible = false
