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
var chapter_starts: Array[Vector3] = [Vector3(-52,.48,38),Vector3(-52,1.68,-14),Vector3(-20,3.48,-58),Vector3(40,4.48,-58),Vector3(60,5.48,2),Vector3(0,12.48,22)]
var checkpoints: Array[Vector3] = [Vector3(-52,.48,38),Vector3(-52,1.68,-14),Vector3(-44,2.28,-50),Vector3(-20,3.48,-58),Vector3(40,4.48,-58),Vector3(60,4.48,-22),Vector3(60,5.48,2),Vector3(30,9.08,22),Vector3(0,12.48,22),Vector3(-8,14.08,-5)]
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
var water_material: ShaderMaterial
var current_chapter := 0

func _ready() -> void:
	_build_course()
	_build_world()
	_add_wayfinding()

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

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = mat(color)
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, top_radius: float = -1.0, segments: int = 16) -> MeshInstance3D:
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

func _collider(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = size
	shape.shape = cube
	shape.position = at
	parent.add_child(shape)

func _pad(center: Vector3, size: Vector2, color: Color, kind: String = "land", chapter: int = 0, branch: bool = false) -> Node3D:
	var moving := kind == "ferry"
	var body: PhysicsBody3D = AnimatableBody3D.new() if moving else StaticBody3D.new()
	body.name = ("Upper_" if branch else "Route_")+str(upper_route.size() if branch else route.size())
	body.position = center
	if moving: (body as AnimatableBody3D).sync_to_physics = false
	add_child(body)
	_collider(body,Vector3(size.x,1,size.y),Vector3(0,-.5,0))
	if kind == "land":
		var ground_tone: Color=[GRASS,Color("9ca58b"),GRASS,Color("729e99"),Color("829581"),Color("91aa8d")][chapter]
		box(body,Vector3(0,-.15,0),Vector3(size.x,.3,size.y),ground_tone)
		# Broad traversable grass shoulders, stone path, and layered sea cliffs.
		var path_width := minf(size.x-1.0,6.0) if size.y >= size.x else size.x-.7
		var path_length := size.y-.7 if size.y >= size.x else minf(size.y-1.0,6.0)
		var surface_tone: Color=[CREAM,Color("c5ad90"),Color("b5bf87"),Color("b59570"),Color("a7ad9e"),Color("d8c7a7")][chapter]
		box(body,Vector3(0,.006,0),Vector3(path_width,.022,path_length),surface_tone)
		for side in [-1,1]:
			if size.y>=size.x: box(body,Vector3(side*(path_width/2-.13),.028,0),Vector3(.12,.028,path_length),color)
			else: box(body,Vector3(0,.028,side*(path_length/2-.13)),Vector3(path_width,.028,.12),color)
		if chapter==3:
			# Timber quay furniture makes the harbor distinct from garden stone.
			for side in [-1,1]:
				for end in [-1,1]:
					cylinder(body,Vector3(side*(size.x/2-.45),.38,end*(size.y/2-.6)),.16,.75,INK,-1,8)
			box(body,Vector3(0,.028,0),Vector3(path_width,.03,.045),INK.lightened(.25))
		if chapter==4:
			for side in [-1,1]:
				var outcrop:=cylinder(body,Vector3(side*(size.x/2-.8),.3,size.y/2-.9),.65,.6,ROCK,.35,5)
				outcrop.rotation.y=side*.4
		_cliff(body,size,center.y)
	elif kind == "bridge":
		box(body,Vector3(0,-.22,0),Vector3(size.x,.44,size.y),WOOD)
		for i in range(int(maxf(size.x,size.y)/.7)):
			var z := -size.y/2+.35+i*.7
			if size.y>=size.x: box(body,Vector3(0,.01,z),Vector3(size.x,.025,.035),INK.lightened(.25))
			else: box(body,Vector3(-size.x/2+.35+i*.7,.01,0),Vector3(.035,.025,size.y),INK.lightened(.25))
		box(body,Vector3(0,-.5,0),Vector3(size.x*.82,.2,size.y*.82),INK)
	else:
		box(body,Vector3(0,-.4,0),Vector3(size.x,.7,size.y),BLUE)
		box(body,Vector3(0,-.04,0),Vector3(size.x-.3,.08,size.y-.3),BLUE.lightened(.12))
		for side in [-1,1]:
			cylinder(body,Vector3(side*(size.x/2-.4),-.5,0),.45,size.y-.6,INK).rotation_degrees.x=90
			box(body,Vector3(side*(size.x/2-.18),.02,0),Vector3(.14,.05,size.y-.4),GOLD)
	var data := {"body":body,"size":size,"top":center.y,"moving":moving,"kind":kind,"chapter":chapter}
	if branch: upper_route.append(data)
	else: route.append(data)
	return body

func _cliff(parent: Node3D, size: Vector2, top: float) -> void:
	# Elliptical faceted buttresses beneath the actual, flat walkable land.
	var depth := 8.5+top
	var points:=PackedVector3Array()
	for i in range(7):
		var a:=i*TAU/7
		points.append(Vector3(cos(a)*size.x*.48*1.16,-.35,sin(a)*size.y*.48*1.16))
		points.append(Vector3(cos(a)*size.x*.48,-depth-.35,sin(a)*size.y*.48))
	var rock_shape:=ConvexPolygonShape3D.new()
	rock_shape.points=points
	var cliff_collision:=CollisionShape3D.new()
	cliff_collision.shape=rock_shape
	parent.add_child(cliff_collision)
	var rock := cylinder(parent,Vector3(0,-depth*.5-.35,0),1,depth,ROCK,1.16,7)
	rock.scale = Vector3(size.x*.48,1,size.y*.48)
	var ledge := cylinder(parent,Vector3(0,-1.1,0),1,1.1,Color("b4b9aa"),1.05,8)
	ledge.scale = Vector3(size.x*.53,1,size.y*.53)
	for side in [-1,1]:
		box(parent,Vector3(side*(size.x/2-.2),-.28,0),Vector3(.4,.4,size.y),MINT.darkened(.16))
		if size.x>=12:
			var rib:=cylinder(parent,Vector3(side*size.x*.34,-depth*.62,size.y*.12),1,depth*.72,ROCK.darkened(.14),.8,5)
			rib.scale=Vector3(size.x*.13,1,size.y*.32)
	var strata:=cylinder(parent,Vector3(0,-depth*.46,0),1,.38,ROCK.lightened(.12),1.0,7)
	strata.scale=Vector3(size.x*.51,1,size.y*.51)

func _build_course() -> void:
	var start := _pad(Vector3(-52,0,38),Vector2(22,24),MINT)
	checkpoint_route_indices.append(0)
	_arch(start,Vector3(0,0,6),"LIGHTHOUSE ISLES",MINT,10)
	_label(start,Vector3(0,.06,2),"01   HARBOR GARDENS",.009,INK,true)
	_label(start,Vector3(0,.06,-2),"WASD  +  SPACE",.006,INK,true)
	_garden(start,Vector3(-7,0,-3),MINT)
	_garden(start,Vector3(7,0,-3),MINT)
	_bunting(start,Vector3(0,4,8),16,MINT)
	_dock(start,Vector3(-8,-.05,7),Vector2(3,7))
	var hurdles_start := _pad(Vector3(-52,0,22),Vector2(10,12),MINT)
	_hurdle(hurdles_start,Vector3(0,0,2),6.8,.58)
	_hurdle(hurdles_start,Vector3(0,0,-2),6.8,.58)
	_pad(Vector3(-52,.4,12),Vector2(8,5),MINT)
	_pad(Vector3(-49,.8,4),Vector2(8,5),MINT)
	var garden := _pad(Vector3(-52,1.2,-6),Vector2(18,10),MINT)
	_garden(garden,Vector3(-6,0,0),GOLD)
	_garden(garden,Vector3(6,0,0),MINT)
	var cp1 := _pad(Vector3(-52,1.2,-14),Vector2(20,8),CORAL,"land",1)
	_checkpoint(cp1,1)
	_arch(cp1,Vector3(0,0,0),"02   WINDMILL COURT",CORAL,10)
	var court := _pad(Vector3(-52,1.2,-26),Vector2(22,16),CORAL,"land",1)
	_sweeper(court,Vector3(0,0,0),1.0,0.2,10.0)
	_windmill(court,Vector3(-8,0,-4),CORAL)
	_bunting(court,Vector3(0,4.8,-6.5),18,CORAL)
	_garden(court,Vector3(8,0,3),GOLD)
	var court2 := _pad(Vector3(-52,1.2,-40),Vector2(22,12),CORAL,"land",1)
	_sweeper(court2,Vector3(0,0,0),-1.25,1.4,10.5)
	_garden(court2,Vector3(-8,0,0),MINT)
	var corner := _pad(Vector3(-44,1.8,-50),Vector2(14,12),CORAL,"land",1)
	_windmill(corner,Vector3(-4.5,0,-3),GOLD)
	_checkpoint(corner,2)
	var shuttle := _pad(Vector3(-32,2.4,-56),Vector2(10,8),BLUE,"ferry",1)
	movers.append({"body":shuttle,"origin":shuttle.position,"amplitude":1.25,"speed":.9,"phase":.5,"axis":Vector3.BACK})
	var shuttle_rail:=box(self,Vector3(-32,1,-56),Vector3(.2,.15,13),INK)
	shuttle_rail.name="ShuttleGuide"
	var cp2 := _pad(Vector3(-20,3,-58),Vector2(12,14),GOLD,"land",2)
	_checkpoint(cp2,3)
	branch_split_index=route.size()-1
	_sign(cp2,Vector3(0,1.1,-4),"03  CANOPY PATHS\nLIFT LOOP  /  NARROW SHORTCUT",GOLD,-PI/2)
	# The broad low path is forgiving; misses from the high route land here.
	_pad(Vector3(-20,3,-47),Vector2(10,10),MINT,"land",2)
	var low1 := _pad(Vector3(-8,3,-42),Vector2(14,10),MINT,"land",2)
	_garden(low1,Vector3(0,0,3),MINT)
	var lift := _pad(Vector3(6,3.2,-42),Vector2(10,8),BLUE,"ferry",2)
	movers.append({"body":lift,"origin":lift.position,"amplitude":.55,"speed":.85,"phase":.7,"axis":Vector3.UP})
	for x in [-1,1]: box(self,Vector3(6+x*4.8,.8,-42),Vector3(.16,5,.16),INK)
	_label(lift,Vector3(0,.08,1.5),"LIFT  /  RIDE THEN LEAP",.0048,INK,true)
	_pad(Vector3(18,3.5,-47),Vector2(12,10),MINT,"land",2)
	_pad(Vector3(28,4,-55),Vector2(10,10),MINT,"land",2)
	# High branch is original geometry, rejoining before the same save point.
	_pad(Vector3(-9,4,-58),Vector2(8,2.4),GOLD,"bridge",2,true)
	_pad(Vector3(1,5,-58),Vector2(8,2.2),GOLD,"bridge",2,true)
	_pad(Vector3(11,5.6,-58),Vector2(8,2.2),GOLD,"bridge",2,true)
	_pad(Vector3(21,5.2,-58),Vector2(8,2.4),GOLD,"bridge",2,true)
	_pad(Vector3(30,4.6,-58),Vector2(8,2.8),GOLD,"bridge",2,true)
	# Recovery shelf under high route, connected to the wide path: no hidden death pit.
	var shelf := StaticBody3D.new()
	shelf.position=Vector3(6,2.3,-55)
	add_child(shelf)
	_collider(shelf,Vector3(45,.5,12),Vector3(0,-.25,0))
	box(shelf,Vector3(0,-.18,0),Vector3(45,.36,12),GRASS.darkened(.07))
	box(shelf,Vector3(0,.01,3),Vector3(45,.025,2),CREAM)
	for x in [-13,0,13]: _tree(shelf,Vector3(x,0,3),MINT,1.5)
	var cp3 := _pad(Vector3(40,4,-58),Vector2(14,14),BLUE,"land",3)
	_checkpoint(cp3,4)
	branch_join_index=route.size()-1
	_sign(cp3,Vector3(0,1.1,-4),"04  FERRY HARBOR\nWATCH THE LANDING",BLUE,-PI/2)
	var quay := _pad(Vector3(52,4,-58),Vector2(12,14),BLUE,"land",3)
	_crane(quay,Vector3(4,0,-4))
	_dock(quay,Vector3(6.8,-.2,1),Vector2(3.5,8))
	for i in range(3): box(quay,Vector3(-4,.45,-4+i*1.4),Vector3(1,.9,1),WOOD.darkened(.1))
	_pad(Vector3(60,4,-46),Vector2(12,10),BLUE,"land",3)
	var ferry1 := _pad(Vector3(60,4,-34),Vector2(8,8),BLUE,"ferry",3)
	movers.append({"body":ferry1,"origin":ferry1.position,"amplitude":1.9,"speed":.8,"phase":0.0})
	_rail(Vector3(60,2.8,-34),15,BLUE)
	var rest := _pad(Vector3(60,4,-22),Vector2(14,10),BLUE,"land",3)
	_checkpoint(rest,5)
	_sign(rest,Vector3(-4,1.2,0),"WAIT\nTHEN JUMP",BLUE,PI)
	_crane(rest,Vector3(5,0,-1))
	_dock(rest,Vector3(7.5,-.2,0),Vector2(3,7))
	var ferry2 := _pad(Vector3(60,4.4,-10),Vector2(8,8),BLUE,"ferry",3)
	movers.append({"body":ferry2,"origin":ferry2.position,"amplitude":2.1,"speed":.9,"phase":1.7})
	_rail(Vector3(60,3.2,-10),15,BLUE)
	var cp4 := _pad(Vector3(60,5,2),Vector2(16,14),GOLD,"land",4)
	_checkpoint(cp4,6)
	_sign(cp4,Vector3(5,1.1,0),"05  RIDGE ASCENT",GOLD,PI)
	_pad(Vector3(60,5.5,12),Vector2(12,7),GOLD,"land",4)
	var ridge := _pad(Vector3(55,6.2,20),Vector2(12,10),GOLD,"land",4)
	_tree(ridge,Vector3(4,0,3),MINT,2)
	for i in range(6):
		var p := Vector3(46-i*8,7+i*.8,22)
		if i==1 or i==4:
			_roller(p,7.2,1.6,.72 if i==1 else -.85,4)
		elif i==3 or i==5:
			_pad(p,Vector2(7.2,2.4),GOLD,"bridge",4)
		else:
			var step := _pad(p,Vector2(7.2,12 if i<2 else 10),GOLD,"land",4)
			_tree(step,Vector3(0,0,3.8),MINT,1.6)
			if i==2: _checkpoint(step,7)
	var cp5 := _pad(Vector3(0,12,22),Vector2(9,14),CORAL,"land",5)
	_checkpoint(cp5,8)
	_sign(cp5,Vector3(0,1.1,4),"06  LIGHTHOUSE RUN",CORAL,PI/2)
	var last_corner := _pad(Vector3(-8,12,14),Vector2(12,12),CORAL,"land",5)
	_sweeper(last_corner,Vector3(0,0,-.7),1.1,1.0,8)
	_pad(Vector3(-8,12.8,4),Vector2(2.6,7),GOLD,"bridge",5)
	var final_save:=_pad(Vector3(-8,13.6,-5),Vector2(10,7),CORAL,"land",5)
	_checkpoint(final_save,9)
	var timed := _pad(Vector3(-8,14.4,-14),Vector2(12,8),CORAL,"land",5)
	_gate(timed)
	_pad(Vector3(-8,15.2,-22),Vector2(14,5),GOLD,"land",5)
	var end := _pad(Vector3(-8,16,-31),Vector2(26,10),GOLD,"land",5)
	_arch(end,Vector3(0,0,1.8),"LIGHTHOUSE  /  FINISH",GOLD,12)
	_lighthouse(end,Vector3(0,0,-2))
	for x in range(-6,7):
		for z in range(2): box(end,Vector3(x*.8,.035,3+z*.65),Vector3(.79,.045,.64),INK if (x+z)%2==0 else Color.WHITE)
	var finish := _zone(end,Vector3(0,1.5,3),Vector3(22,3,2.0))
	finish.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player"): finish_reached.emit())
	for i in range(48):
		var piece := box(self,Vector3(-8+sin(i*3.3)*10,19+(i%7),-29+cos(i*2.7)*4),Vector3(.15,.3,.08),[MINT,BLUE,CORAL,GOLD][i%4])
		piece.visible=false
		confetti.append(piece)

func _checkpoint(parent: Node3D, index: int) -> void:
	checkpoint_route_indices.append(route.size()-1)
	var ring := cylinder(parent,Vector3(0,.04,0),1.6,.06,GOLD,-1,40)
	checkpoint_rings.append(ring)
	cylinder(parent,Vector3(0,.078,0),1.25,.035,CREAM,-1,40)
	_label(parent,Vector3(0,.105,0),"SAVE  %02d"%index,.005,INK,true)
	var size: Vector2=route[-1].size
	var area:=_zone(parent,Vector3(0,1.7,0),Vector3(size.x,3.4,size.y))
	area.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player"): checkpoint_reached.emit(index))
	for side in [-1,1]:
		var along_x:=index in [2,3,4,7,8]
		var at:=Vector3(1.3 if index==3 else 0,0,side*(size.y/2-.65)) if along_x else Vector3(side*(size.x/2-.65),0,0)
		cylinder(parent,at+Vector3(0,1.4,0),.16,2.8,INK,-1,8)
		var beacon:=cylinder(parent,at+Vector3(0,3,0),.4,.55,GOLD,-1,12)
		beacon.material_override=mat(GOLD,.5)
		checkpoint_beacons.append(beacon)
		_label(parent,at+Vector3(0,3.8,0),"SAVE\n%02d"%index,.006,Color.WHITE).billboard=BaseMaterial3D.BILLBOARD_ENABLED
	var floating:=_label(parent,Vector3(0,2.3,0),"CHECKPOINT  %02d"%index,.007,GOLD)
	floating.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	floating.name="CheckpointBanner"

func set_checkpoint(index: int) -> void:
	current_chapter=checkpoint_chapters[index]
	for i in checkpoint_rings.size(): checkpoint_rings[i].material_override=mat(MINT if i<index else GOLD)
	for i in checkpoint_beacons.size(): checkpoint_beacons[i].material_override=mat(MINT if i/2<index else GOLD,.5)

func _zone(parent: Node3D,pos: Vector3,size: Vector3) -> Area3D:
	var area:=Area3D.new()
	area.position=pos
	area.collision_layer=0
	area.collision_mask=2
	_collider(area,size,Vector3.ZERO)
	parent.add_child(area)
	return area

func _sweeper(parent: Node3D,at: Vector3,speed: float,phase: float,width: float) -> void:
	var pivot:=Node3D.new()
	parent.add_child(pivot)
	pivot.position=at+Vector3(0,.58,0)
	pivot.set_meta("speed",speed)
	pivot.set_meta("phase",phase)
	sweepers.append(pivot)
	cylinder(parent,at+Vector3(0,.2,0),.6,.4,INK)
	cylinder(parent,at+Vector3(0,.44,0),.4,.14,GOLD)
	box(pivot,Vector3.ZERO,Vector3(width,.26,.3),CORAL)
	for i in range(int(width)):
		box(pivot,Vector3(-width/2+.5+i,0,0),Vector3(.25,.28,.32),CREAM)
	var area:=_zone(pivot,Vector3.ZERO,Vector3(width,.26,.3))
	area.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player"): hazard_touched.emit())
	# Dashed ring makes the swept volume legible before entering it.
	for i in range(28):
		var theta:=i*TAU/28
		var mark:=box(parent,at+Vector3(sin(theta)*width*.52,.04,cos(theta)*width*.52),Vector3(.35,.04,.15),CORAL)
		mark.rotation.y=theta

func _gate(parent: Node3D) -> void:
	gate=_zone(parent,Vector3(0,.8,0),Vector3(9,.24,.24))
	for side in [-1,1]:
		box(parent,Vector3(side*4.5,1.5,0),Vector3(.35,3,.6),INK)
		box(parent,Vector3(side*4.5,3.1,0),Vector3(.7,.3,.7),GOLD)
	gate_mesh=box(parent,Vector3(0,.8,0),Vector3(9,.24,.24),CORAL)
	gate_light=cylinder(parent,Vector3(4.5,3.4,0),.3,.3,MINT)
	box(parent,Vector3(0,.03,0),Vector3(9,.04,.5),GOLD)
	_label(parent,Vector3(0,.06,2.2),"GREEN  =  GO",.006,INK,true)
	gates.append({"area":gate,"mesh":gate_mesh,"light":gate_light,"parent":parent})

func _arrow(parent: Node3D,pos: Vector3,color: Color,yaw: float=0) -> void:
	var root:=Node3D.new()
	root.position=pos
	root.rotation.y=yaw
	parent.add_child(root)
	box(root,Vector3(0,0,.18),Vector3(.18,.035,1.0),color)
	var a:=box(root,Vector3(-.22,0,-.22),Vector3(.16,.035,.66),color)
	a.rotation.y=-.75
	var b:=box(root,Vector3(.22,0,-.22),Vector3(.16,.035,.66),color)
	b.rotation.y=.75

func _add_wayfinding() -> void:
	for i in route.size()-1:
		var here: Dictionary=route[i]
		var next: Dictionary=route[i+1]
		var dir: Vector3=(next.body.position-here.body.position).normalized()
		var yaw:=atan2(-dir.x,-dir.z)
		_arrow(here.body,Vector3(0,.04,0),GOLD if here.kind in ["ferry","roller"] else [MINT,CORAL,MINT,BLUE,GOLD,CORAL][here.chapter].darkened(.25),yaw)
		if i%3==1: _flag(here.body,Vector3(here.size.x/2-.7,0,-here.size.y/2+.7),[MINT,CORAL,MINT,BLUE,GOLD,CORAL][here.chapter])
	for entry in upper_route: _arrow(entry.body,Vector3(0,.04,0),GOLD, -PI/2)

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

func _arch(parent: Node3D,pos: Vector3,text: String,color: Color,width: float) -> void:
	var root:=Node3D.new()
	root.position=pos
	parent.add_child(root)
	for side in [-1,1]:
		box(root,Vector3(side*width/2,1.9,0),Vector3(.38,3.8,.45),INK)
		box(root,Vector3(side*width/2,.14,0),Vector3(.9,.28,.9),CREAM)
	box(root,Vector3(0,3.8,0),Vector3(width+.5,.85,.45),color)
	_label(root,Vector3(0,3.8,.24),text,.008,Color.WHITE)

func _label(parent: Node3D,pos: Vector3,text: String,scale_px: float,color: Color,flat: bool=false) -> Label3D:
	var label:=Label3D.new()
	label.text=text
	label.font_size=48
	label.pixel_size=scale_px
	label.modulate=color
	label.outline_size=0
	label.position=pos
	if flat: label.rotation_degrees.x=-90
	parent.add_child(label)
	return label

func _sign(parent: Node3D,pos: Vector3,text: String,color: Color,yaw: float=0) -> void:
	var root:=Node3D.new()
	root.position=pos
	root.rotation.y=yaw
	parent.add_child(root)
	box(root,Vector3(0,-.35,0),Vector3(.18,2.0,.18),INK)
	box(root,Vector3(0,.8,0),Vector3(7,1.5,.2),color)
	_label(root,Vector3(0,.8,.115),text,.0055,Color.WHITE)
	var back:=_label(root,Vector3(0,.8,-.115),text,.0055,Color.WHITE)
	back.rotation.y=PI

func _flag(parent: Node3D,pos: Vector3,color: Color) -> void:
	cylinder(parent,pos+Vector3(0,1.4,0),.065,2.8,INK,-1,8)
	box(parent,pos+Vector3(.45,2.35,0),Vector3(.95,.6,.045),color)
	cylinder(parent,pos+Vector3(0,.1,0),.22,.2,CREAM,-1,8)

func _tree(parent: Node3D,pos: Vector3,color: Color,size: float=2) -> void:
	_collider(parent,Vector3(.4,1.3,.4),pos+Vector3(0,.65,0))
	cylinder(parent,pos+Vector3(0,.65,0),.18,1.3,WOOD,-1,7)
	cylinder(parent,pos+Vector3(0,1.7,0),size*.6,size*1.3,color,0,7)
	cylinder(parent,pos+Vector3(0,2.3,0),size*.43,size,color.lightened(.08),0,7)

func _garden(parent: Node3D,pos: Vector3,color: Color) -> void:
	box(parent,pos+Vector3(0,.12,0),Vector3(2.8,.24,3.5),CREAM.darkened(.15))
	box(parent,pos+Vector3(0,.28,0),Vector3(2.5,.14,3.2),GRASS.darkened(.22))
	_tree(parent,pos+Vector3(0,.3,-.3),color,1.7)
	for i in range(5):
		cylinder(parent,pos+Vector3(sin(i*4)*.9,.7,cos(i*3)*1.2),.22,.4,[GOLD,CORAL][i%2],.08,6)

func _dock(parent: Node3D,pos: Vector3,size: Vector2) -> void:
	_collider(parent,Vector3(size.x,.25,size.y),pos)
	box(parent,pos,Vector3(size.x,.25,size.y),WOOD)
	for side in [-1,1]:
		for end in [-1,1]: cylinder(parent,pos+Vector3(side*(size.x/2-.2),-.6,end*(size.y/2-.2)),.18,2,INK,-1,8)

func _bunting(parent: Node3D,pos: Vector3,width: float,color: Color) -> void:
	box(parent,pos,Vector3(width,.035,.035),INK)
	for i in range(12):
		var flag:=cylinder(parent,pos+Vector3(-width/2+(i+.5)*width/12,-.25,0),.3,.6,color if i%2==0 else CREAM,0,3)
		flag.rotation_degrees.x=180

func _windmill(parent: Node3D,pos: Vector3,color: Color) -> void:
	_collider(parent,Vector3(2.6,5,2.6),pos+Vector3(0,2.5,0))
	cylinder(parent,pos+Vector3(0,2.5,0),1.6,5,CREAM,1.1,8)
	cylinder(parent,pos+Vector3(0,5.5,0),1.7,1.8,color,0,8)
	var rotor:=Node3D.new()
	rotor.position=pos+Vector3(0,4.1,1.25)
	parent.add_child(rotor)
	windmill_rotors.append(rotor)
	for i in range(4):
		var blade:=Node3D.new()
		blade.rotation.z=i*PI/2
		rotor.add_child(blade)
		box(blade,Vector3(0,1.9,0),Vector3(.17,3.8,.16),INK)
		box(blade,Vector3(.35,2.4,0),Vector3(.9,2.2,.09),WOOD.lightened(.12))
	cylinder(rotor,Vector3.ZERO,.35,.3,color).rotation_degrees.x=90

func _crane(parent: Node3D,pos: Vector3) -> void:
	_collider(parent,Vector3(1.6,.7,1.6),pos+Vector3(0,.35,0))
	box(parent,pos+Vector3(0,2.9,0),Vector3(.45,5.8,.45),GOLD)
	box(parent,pos+Vector3(-1.3,5.5,0),Vector3(3.2,.35,.35),GOLD)
	box(parent,pos+Vector3(-2.7,3.7,0),Vector3(.035,3.5,.035),INK)
	box(parent,pos+Vector3(-2.7,1.8,0),Vector3(.7,.45,.6),WOOD)
	box(parent,pos+Vector3(0,.35,0),Vector3(1.6,.7,1.6),INK)

func _lighthouse(parent: Node3D,pos: Vector3) -> void:
	cylinder(parent,pos+Vector3(0,.4,0),4.2,.8,CREAM,-1,12)
	for i in range(6): cylinder(parent,pos+Vector3(0,1.7+i*2.4,0),2.45-i*.12,2.4,CREAM if i%2==0 else CORAL,2.33-i*.12,12)
	cylinder(parent,pos+Vector3(0,15.6,0),2.5,.4,INK,-1,12)
	cylinder(parent,pos+Vector3(0,16.8,0),1.7,2.2,GOLD,-1,12)
	for i in range(8):
		var a:=i*TAU/8
		box(parent,pos+Vector3(sin(a)*1.72,16.8,cos(a)*1.72),Vector3(.13,2.2,.13),INK)
	cylinder(parent,pos+Vector3(0,18.4,0),2.7,1.3,INK,0,12)
	cylinder(parent,pos+Vector3(0,19.4,0),.12,1.2,GOLD,-1,8)
	# Distinctive bright beacon visible from every district, no borrowed assets.
	var lamp:=cylinder(parent,pos+Vector3(0,16.8,0),1.25,1.6,Color("ffeab0"),-1,12)
	lamp.material_override=mat(Color("ffdf88"),.8)
	for side in [-1,1]:
		_tree(parent,pos+Vector3(side*9,0,2),MINT,2.2)
		_bunting(parent,pos+Vector3(side*8,3.5,2),7,GOLD)

func _rail(pos: Vector3,width: float,color: Color) -> void:
	box(self,pos,Vector3(width,.15,.2),INK.lightened(.15))
	for side in [-1,1]: cylinder(self,pos+Vector3(side*width/2,0,0),.3,.6,color)

func _build_world() -> void:
	# Calm sea ties the islands into a spatially coherent coastal world.
	var water:=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=Vector2(1000,1000)
	water.mesh=plane
	water.position=Vector3(0,-8.3,0)
	var shader:=Shader.new()
	shader.code="shader_type spatial; render_mode unshaded; varying vec3 wp; void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;} void fragment(){ float v=sin(wp.x*.13+wp.z*.11+TIME*.3)*.5+.5; float r=smoothstep(.95,1.0,sin(wp.x*.31+wp.z*.24+sin(wp.z*.2)+TIME*.25)); ALBEDO=mix(vec3(.20,.48,.56),vec3(.25,.56,.61),v)+r*.035; }"
	water_material=ShaderMaterial.new()
	water_material.shader=shader
	water.material_override=water_material
	add_child(water)
	# Distant cliffs are deliberately beyond the course, without path paint or flags.
	for i in range(22):
		var theta:=i*TAU/22
		var dist:=125.0+(i%4)*18
		var p:=Vector3(sin(theta)*dist,-8,cos(theta)*dist-15)
		var island:=cylinder(self,p+Vector3(0,-1,0),8+(i%3)*3,9+(i%4)*5,Color("94a8aa"),5+(i%3)*2,7)
		island.scale.z=1.5
	# Small nonwalkable outcrops, boats and breakers below playable cliff tops.
	for p in [Vector3(-75,-7,18),Vector3(-25,-7,34),Vector3(28,-7,-21),Vector3(38,-7,42),Vector3(-34,-7,-76)]:
		cylinder(self,p,5,4,ROCK,3.6,6)
		for j in range(3):
			var surf:=cylinder(self,p+Vector3(j*1.3,-.7,j*.4),5.5,.035,Color("9ac9ca"),-1,24)
			surf.scale=Vector3(1,.2,.35)
	_boat(Vector3(-68,-7,43),CORAL)
	_boat(Vector3(78,-7,-53),GOLD)
	_boat(Vector3(76,-7,-23),BLUE)
	_boat(Vector3(33,-7,6),CREAM)
	# A stone aqueduct under the ridge gives the ascent a recognizable silhouette.
	for x in range(6,55,8):
		box(self,Vector3(x,-.5,22),Vector3(1.8,15,7),ROCK.darkened(.06))
		box(self,Vector3(x,5.3,22),Vector3(6.5,1.5,7),ROCK)

func _boat(pos: Vector3,color: Color) -> void:
	var hull:=cylinder(self,pos,1,1,WOOD,.75,5)
	hull.scale=Vector3(1.3,1,3.5)
	cylinder(self,pos+Vector3(0,2.8,0),.09,5.5,INK,-1,8)
	var sail:=box(self,pos+Vector3(1.1,3.8,0),Vector3(2.1,2.6,.045),color)
	sail.rotation.z=.1

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


func _hurdle(parent: Node3D,at: Vector3,width: float,height: float) -> void:
	_collider(parent,Vector3(width,height,.3),at+Vector3(0,height/2,0))
	box(parent,at+Vector3(0,height/2,0),Vector3(width,height,.3),CORAL)
	for i in range(int(width)):
		box(parent,at+Vector3(-width/2+.5+i,height+.015,0),Vector3(.4,.03,.32),CREAM)
	hurdles.append({"parent":parent,"at":parent.position+at,"width":width,"height":height})
	_label(parent,at+Vector3(0,.04,1.0),"HOP",.0045,INK,true)

func _roller(top: Vector3,length: float,radius: float,speed: float,chapter: int) -> Node3D:
	# A genuine curved collision surface with angular contact velocity. StaticBody's
	# angular surface velocity is the documented conveyor/revolving-platform API.
	# The striped drum spins at exactly the same angular speed: not cosmetic motion.
	var root:=Node3D.new()
	root.position=top
	root.name="RollerRoad_%d"%rollers.size()
	add_child(root)
	var body:=StaticBody3D.new()
	body.position.y=-radius
	body.constant_angular_velocity=Vector3.RIGHT*speed
	root.add_child(body)
	var shape:=CollisionShape3D.new()
	var cylinder_shape:=CylinderShape3D.new()
	cylinder_shape.radius=radius
	cylinder_shape.height=length
	shape.shape=cylinder_shape
	shape.rotation.z=PI/2
	body.add_child(shape)
	var visual:=Node3D.new()
	body.add_child(visual)
	cylinder(visual,Vector3.ZERO,radius,length,BLUE if speed<0 else CORAL,-1,32).rotation.z=PI/2
	for i in range(12):
		var a:=i*TAU/12
		var stripe:=box(visual,Vector3(0,cos(a)*(radius+.015),sin(a)*(radius+.015)),Vector3(length-.2,.04,.2),CREAM if i%3==0 else GOLD)
		stripe.rotation.x=a
	for side in [-1,1]:
		cylinder(root,Vector3(side*(length/2+.12),-radius,0),radius*.55,.24,INK,-1,16).rotation.z=PI/2
		box(root,Vector3(side*(length/2+.12),-radius-1.5,0),Vector3(.35,3,.35),INK)
		var flag_at:=Vector3(side*(length/2-.25),0,-radius-.3)
		_flag(root,flag_at,GOLD)
	var data: Dictionary={"body":root,"size":Vector2(length,radius*2),"top":top.y,"moving":false,"kind":"roller","chapter":chapter,"roller":body,"radius":radius,"speed":speed}
	route.append(data)
	rollers.append({"root":root,"body":body,"visual":visual,"radius":radius,"speed":speed,"length":length})
	return root
