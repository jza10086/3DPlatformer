extends SceneTree
## Full-map input-only regression. No player placement, velocity edits, checkpoint
## edits, collision edits, hazard changes or timer changes are permitted here.
## --route=upper exercises the optional high route, otherwise the wide main path.
## --capture-dir=/absolute/path captures native rendered frames for a preview.
## --demo-respawn deliberately walks off after the middle harbor save, then
## observes the actual checkpoint respawn and finishes through normal inputs.
var game: Node3D
var frame := 0
var current_pad := 0
var launch_frame := -100
var jumps := 0
var capture_dir := ""
var capture_index := 0
var capture_busy := false
var capture_manifest: Array[Dictionary] = []
var route_name := "main"
var path: Array[Dictionary] = []
var targets: Array[Vector3] = []
var target_index := 0
var stage := "center"
var launch := Vector3.ZERO
var jumped_for_segment := false
var last_progress := 0
var gate_waited := false
var distance_travelled := 0.0
var previous_position := Vector3.ZERO
var demo_respawn := false
var demo_state := 0
var demo_hold_until := 0
var observed_falls := 0
var roller_contacts: Dictionary = {}
var hurdle_jumps: Dictionary = {}
var mover_contacts: Dictionary = {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir=arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(capture_dir)
		elif arg.begins_with("--route="): route_name=arg.trim_prefix("--route=")
		elif arg=="--demo-respawn": demo_respawn=true
	call_deferred("run")

func _drive_world(direction: Vector3) -> void:
	for action in ["move_left","move_right","move_forward","move_back"]: Input.action_release(action)
	if direction.length_squared()<.002: return
	var right: Vector3=game.camera.global_basis.x
	var back: Vector3=game.camera.global_basis.z
	right.y=0
	back.y=0
	right=right.normalized()
	back=back.normalized()
	var axis:=Vector2(direction.dot(right),direction.dot(back)).normalized()
	# Ordinary held keyboard directions (eight-way), recalculated as camera turns.
	if axis.x>.38: Input.action_press("move_right")
	elif axis.x<-.38: Input.action_press("move_left")
	if axis.y>.38: Input.action_press("move_back")
	elif axis.y<-.38: Input.action_press("move_forward")

func _jump() -> void:
	Input.action_press("jump")
	launch_frame=frame
	jumps+=1
	jumped_for_segment=true
	print("JUMP ",jumps," pad=",current_pad," pos=",game.player.position)

func _capture(name: String="") -> void:
	if capture_dir.is_empty() or capture_busy: return
	capture_busy=true
	await RenderingServer.frame_post_draw
	var dest: String="%s/%05d.png"%[capture_dir,capture_index]
	if not name.is_empty(): dest="%s/%s.png"%[capture_dir,name]
	root.get_texture().get_image().save_png(dest)
	capture_manifest.append({"file":dest.get_file(),"physics_frame":frame,"simulation_seconds":game.elapsed,"route":route_name})
	capture_index+=1
	capture_busy=false

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x,0,v.z)

func _contains(entry: Dictionary,p: Vector3,margin: float=.1) -> bool:
	var in_bounds: bool=absf(p.x-entry.body.position.x)<entry.size.x/2+margin and absf(p.z-entry.body.position.z)<entry.size.y/2+margin
	if entry.has("roller"):
		# A cylinder is curved, unlike the flat rectangle metadata used elsewhere.
		# Real grounded contact and actual platform angular velocity are also
		# observed independently; no test-owned support surface is introduced.
		return in_bounds and p.y>entry.body.position.y-.5 and p.y<entry.body.position.y+.7
	return in_bounds and absf(p.y-entry.body.position.y-.425)<.16

func _observe_rollers() -> void:
	if not game.player.is_on_floor(): return
	for entry in path:
		if entry.moving and _contains(entry,game.player.position):
			var key: String=entry.body.name
			mover_contacts[key]=int(mover_contacts.get(key,0))+1
	var omega: Vector3=game.player.get_platform_angular_velocity()
	if omega.length()<.05: return
	for entry in path:
		if entry.has("roller") and _contains(entry,game.player.position):
			var key: String=entry.body.name
			roller_contacts[key]=int(roller_contacts.get(key,0))+1

func _resume_from_observed_save() -> void:
	var original_index: int=game.course.checkpoint_route_indices[game.checkpoint]
	var saved_body: Node3D=game.course.route[original_index].body
	for i in path.size():
		if path[i].body==saved_body:
			current_pad=i
			break
	stage="center"
	targets=_surface_targets(path[current_pad])
	target_index=0
	last_progress=frame
	previous_position=game.player.position
	Input.action_release("jump")
	_drive_world(Vector3.ZERO)
	print("DEMO CHECKPOINT RETURN save=%d pad=%d time=%.2f pos=%s"%[game.checkpoint,current_pad,game.elapsed,game.player.position])
	_capture("checkpoint_return")

func _surface_targets(entry: Dictionary) -> Array[Vector3]:
	var center: Vector3=entry.body.position
	var result: Array[Vector3]=[]
	# Real, broad bypass shoulders are part of the map (not a disabled hazard).
	# Traverse those deliberately; focused.gd separately proves live sweepers hit.
	for pivot in game.course.sweepers:
		if pivot.get_parent()==entry.body:
			var beam: MeshInstance3D=pivot.get_child(0)
			var radius: float=beam.mesh.size.x/2
			var x: float=center.x+radius+1.0
			result.append(Vector3(x,center.y,center.z+entry.size.y/2-2.8))
			result.append(Vector3(x,center.y,center.z-entry.size.y/2+2.8))
			return result
	result.append(center)
	return result

func _plan_segment() -> void:
	var here: Dictionary=path[current_pad]
	var next: Dictionary=path[current_pad+1]
	var a: Vector3=game.player.position
	a.y=here.body.position.y
	var b: Vector3=next.body.position
	var direction:=_flat(b-a).normalized()
	var exit_distance:=INF
	var entry_distance: float=0
	if absf(direction.x)>.001:
		exit_distance=minf(exit_distance,(here.body.position.x+signf(direction.x)*here.size.x/2-a.x)/direction.x)
		entry_distance=maxf(entry_distance,(b.x-signf(direction.x)*next.size.x/2-a.x)/direction.x)
	if absf(direction.z)>.001:
		exit_distance=minf(exit_distance,(here.body.position.z+signf(direction.z)*here.size.y/2-a.z)/direction.z)
		entry_distance=maxf(entry_distance,(b.z-signf(direction.z)*next.size.y/2-a.z)/direction.z)
	var gap: float=entry_distance-exit_distance
	var rise: float=b.y-a.y
	jumped_for_segment=false
	if gap<.15 and rise<.2:
		stage="travel"
	else:
		# Elevated overlapping land needs take-off before its leading wall.
		var runup: float=minf(exit_distance-.3,entry_distance-.85)
		launch=a+direction*maxf(runup,.1)
		stage="launch"

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	if not capture_dir.is_empty():
		root.mode=Window.MODE_WINDOWED
		root.size=Vector2i(960,600)
	await physics_frame
	await physics_frame
	path.assign(game.course.route)
	if route_name=="upper":
		var split: int=game.course.branch_split_index
		var join: int=game.course.branch_join_index
		var alternate: Array[Dictionary]=[]
		for i in range(split+1): alternate.append(path[i])
		for entry in game.course.upper_route: alternate.append(entry)
		for i in range(join,path.size()): alternate.append(path[i])
		path=alternate
	targets=_surface_targets(path[0])
	previous_position=game.player.position
	_capture("start")
	for i in range(18000):
		frame=i
		var p: CharacterBody3D=game.player
		if game.falls==observed_falls: distance_travelled+=_flat(p.position-previous_position).length()
		_observe_rollers()
		previous_position=p.position
		if frame%8==0: _capture()
		if game.finished:
			_drive_world(Vector3.ZERO)
			Input.action_release("jump")
			var expected_rollers:=0
			var expected_movers:=0
			for entry in path:
				if entry.has("roller"): expected_rollers+=1
				if entry.moving: expected_movers+=1
			if roller_contacts.size()!=expected_rollers or mover_contacts.size()!=expected_movers or hurdle_jumps.size()!=game.course.hurdles.size() or (demo_respawn and demo_state!=3):
				push_error("TRAVERSAL invalid coverage: rollers=%s expected=%d demo=%d"%[roller_contacts,expected_rollers,demo_state])
				quit(1)
				return
			print("ROLLER CONTACTS ",roller_contacts," MOVING CONTACTS ",mover_contacts," HURDLE JUMPS ",hurdle_jumps.size())
			print("TRAVERSAL PASS route=%s elapsed=%.3f falls=%d jumps=%d checkpoints=%d distance=%.1fm frames=%d gate_waited=%s"%[route_name,game.elapsed,game.falls,jumps,game.checkpoint,distance_travelled,frame,gate_waited])
			for hold in range(60): await physics_frame
			await _capture("finish")
			if not capture_dir.is_empty():
				var manifest:=FileAccess.open(capture_dir.path_join("captures.json"),FileAccess.WRITE)
				manifest.store_string(JSON.stringify(capture_manifest,"\t"))
				manifest.close()
			game.queue_free()
			await process_frame
			# Dummy audio runs on wall time, unlike accelerated physics.
			OS.delay_msec(100)
			await process_frame
			quit(0)
			return
		if game.falls>observed_falls:
			if demo_respawn and demo_state==1 and game.falls==1:
				observed_falls=game.falls
				_resume_from_observed_save()
				demo_state=2
				demo_hold_until=frame+75
			else:
				push_error("TRAVERSAL FAILED route=%s pad=%d stage=%s frame=%d pos=%s; input-only, no bypass"%[route_name,current_pad,stage,frame,p.position])
				quit(1)
				return
		if demo_respawn and demo_state==0 and game.checkpoint==5 and stage=="center" and _flat(path[current_pad].body.position-p.position).length()<.9:
			demo_state=1
			print("DEMO WALK OFF save=",game.checkpoint," pos=",p.position)
			_capture("checkpoint_before_fall")
		if demo_state==1:
			_drive_world(Vector3.LEFT)
			await physics_frame
			continue
		if demo_state==2:
			_drive_world(Vector3.ZERO)
			if frame<demo_hold_until:
				await physics_frame
				continue
			demo_state=3
		if frame-launch_frame>40 and Input.is_action_pressed("jump"): Input.action_release("jump")
		if frame-last_progress>1000:
			push_error("TRAVERSAL STUCK pad=%d stage=%s pos=%s launch=%s target=%s"%[current_pad,stage,p.position,launch,targets])
			quit(1)
			return
		var desired:=Vector3.ZERO
		if stage=="center":
			var target: Vector3=targets[target_index]
			desired=_flat(target-p.position)
			if desired.length()<.65 and p.is_on_floor():
				target_index+=1
				last_progress=frame
				if target_index>=targets.size():
					if current_pad+1<path.size(): _plan_segment()
					else: desired=_flat(game.course.finish_position-p.position)
		elif stage=="launch":
			desired=_flat(launch-p.position)
			if desired.length()<.65 and p.is_on_floor():
				_jump()
				stage="travel"
				desired=_flat(path[current_pad+1].body.position-p.position)
		elif stage=="travel":
			var next: Dictionary=path[current_pad+1]
			var next_targets: Array[Vector3]=_surface_targets(next)
			desired=_flat(next_targets[0]-p.position)
			if p.is_on_floor() and _contains(next,p.position):
				current_pad+=1
				stage="center"
				targets=next_targets
				target_index=0
				last_progress=frame
				print("LAND pad=%d chapter=%d t=%.2f pos=%s"%[current_pad,next.chapter,game.elapsed,p.position])
				_capture("pad_%02d"%current_pad)
		# Read the visible garden hurdles and press Space before their near face.
		# These are solid jumpable obstacles, not hazard-volume bypasses.
		for h in game.course.hurdles:
			if h.parent==path[current_pad].body and p.is_on_floor() and desired.z<-.2 and frame-launch_frame>42:
				var approach: float=p.position.z-h.at.z
				if approach>.55 and approach<1.7 and absf(p.position.x-h.at.x)<h.width/2+.4:
					_jump()
					hurdle_jumps[str(h.at)]=true
		# The final timing gate is crossed only during its visible green window.
		if path[current_pad].body==game.course.gate.get_parent() and p.position.z>game.course.gate.global_position.z+.8 and p.position.z<game.course.gate.global_position.z+2.7:
			var phase: float=fmod(game.course.clock,4.8)
			if phase<2.55 or phase>3.7:
				desired=Vector3.ZERO
				gate_waited=true
		_drive_world(desired if desired.length()>.25 else Vector3.ZERO)
		await physics_frame
	push_error("TRAVERSAL TIMEOUT")
	quit(1)
