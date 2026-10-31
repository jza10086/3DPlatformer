extends SceneTree
## Full-map input-only regression. No player placement, velocity edits, checkpoint
## edits, collision edits, hazard changes or timer changes are permitted here.
## --route=upper exercises the optional high route, otherwise the wide main path.
## --capture-dir=/absolute/path captures native rendered frames for a preview.
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

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir=arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(capture_dir)
		elif arg.begins_with("--route="): route_name=arg.trim_prefix("--route=")
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
	return absf(p.x-entry.body.position.x)<entry.size.x/2+margin and absf(p.z-entry.body.position.z)<entry.size.y/2+margin and absf(p.y-entry.body.position.y-.425)<.16

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
		var split: int=game.course.checkpoint_route_indices[2]
		var join: int=game.course.checkpoint_route_indices[3]
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
		distance_travelled+=_flat(p.position-previous_position).length()
		previous_position=p.position
		if frame%8==0: _capture()
		if game.finished:
			_drive_world(Vector3.ZERO)
			Input.action_release("jump")
			print("TRAVERSAL PASS route=%s elapsed=%.3f falls=%d jumps=%d checkpoints=%d distance=%.1fm frames=%d gate_waited=%s"%[route_name,game.elapsed,game.falls,jumps,game.checkpoint,distance_travelled,frame,gate_waited])
			for hold in range(60): await physics_frame
			await _capture("finish")
			if not capture_dir.is_empty():
				var manifest:=FileAccess.open(capture_dir.path_join("captures.json"),FileAccess.WRITE)
				manifest.store_string(JSON.stringify(capture_manifest,"\t"))
			game.queue_free()
			await process_frame
			# Dummy audio runs on wall time, unlike accelerated physics.
			OS.delay_msec(100)
			await process_frame
			quit(0)
			return
		if game.falls>0:
			push_error("TRAVERSAL FAILED route=%s pad=%d stage=%s frame=%d pos=%s; input-only, no bypass"%[route_name,current_pad,stage,frame,p.position])
			quit(1)
			return
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
