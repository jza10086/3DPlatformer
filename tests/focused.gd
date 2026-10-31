extends SceneTree
## Isolated integration checks deliberately place the cube to test boundaries.
## These are NOT completion evidence: traverse.gd proves both full routes using
## ordinary digital movement/jump inputs from spawn, without any state edits.
var game: Node3D
var errors := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if ok: print("PASS ",message)
	else:
		errors+=1
		push_error(message)
func frames(count: int) -> void:
	for i in count: await physics_frame
func action(name: String) -> void:
	var event:=InputEventAction.new()
	event.action=name
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event=InputEventAction.new()
	event.action=name
	event.pressed=false
	Input.parse_input_event(event)
	await process_frame
func release_movement() -> void:
	for name in ["move_forward","move_back","move_left","move_right","jump"]: Input.action_release(name)
func drive(direction: Vector3) -> void:
	for name in ["move_forward","move_back","move_left","move_right"]: Input.action_release(name)
	var right: Vector3=game.camera.global_basis.x
	var back: Vector3=game.camera.global_basis.z
	right.y=0
	back.y=0
	var axis:=Vector2(direction.dot(right.normalized()),direction.dot(back.normalized())).normalized()
	if axis.x>.38: Input.action_press("move_right")
	elif axis.x<-.38: Input.action_press("move_left")
	if axis.y>.38: Input.action_press("move_back")
	elif axis.y<-.38: Input.action_press("move_forward")

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(10)
	check(game.course.route.size()>=35 and game.course.upper_route.size()>=5,"complete authored route and optional high branch are present")
	var narrow_count:=0
	for entry in game.course.route:
		if minf(entry.size.x,entry.size.y)<2.9: narrow_count+=1
	check(narrow_count>=3 and game.course.upper_route[0].size.y<=2.8,"main course and alternate route include genuine narrow collision widths")
	check(game.course.checkpoints.size()==10 and game.course.checkpoint_route_indices.size()==10,"nine sequential saves plus start are present")
	check(game.course.gate.get_child(0).shape.size==game.course.gate_mesh.mesh.size,"gate collider exactly matches visible beam")
	check(game.elapsed==0 and not game.running,"timer waits for normal movement")
	var initial_camera: Transform3D=game.camera.transform
	await action("overview")
	check(game.map_view and paused,"Tab opens paused overview")
	check(game.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"overview shows full map orthographically")
	await process_frame
	check(game.hud.map_markers.size()==6 and game.hud.map_saves.size()==9,"overview separates six chapters from all nine save beacons")
	var stopped_pos: Vector3=game.player.position
	var stopped_clock: float=game.course.clock
	var stopped_mover: Vector3=game.course.movers[0].body.position
	Input.action_press("move_forward")
	await frames(35)
	Input.action_release("move_forward")
	check(game.player.position==stopped_pos and game.course.clock==stopped_clock and game.course.movers[0].body.position==stopped_mover,"overview freezes player, hazards and ferry")
	check(game.elapsed==0 and not game.running,"overview input does not start run")
	await action("pause")
	check(not game.map_view and not paused,"Escape closes overview to previous live mode")
	check(game.camera.projection==Camera3D.PROJECTION_PERSPECTIVE and game.camera.position.distance_to(initial_camera.origin)<.1,"overview restores chase projection and framing")
	await action("pause")
	await action("overview")
	check(game.map_view and paused,"overview is accessible from pause")
	await action("overview")
	check(not game.map_view and paused,"closing overview restores previous pause")
	await action("overview")
	await action("restart")
	check(not game.map_view and not paused and not game.running and game.elapsed==0,"R from overview resets all view and run state")
	Input.action_press("move_forward")
	await frames(20)
	Input.action_release("move_forward")
	await frames(15)
	check(game.running and game.elapsed>.3,"ordinary movement begins timer")
	await action("pause")
	var stopped_time: float=game.elapsed
	stopped_clock=game.course.clock
	stopped_pos=game.player.position
	await frames(35)
	check(game.elapsed==stopped_time and game.course.clock==stopped_clock and game.player.position==stopped_pos,"Escape pause freezes timer and simulation")
	await action("pause")
	await frames(8)
	check(not paused and game.elapsed>stopped_time,"Escape resumes simulation")
	# Entering a late district does not skip progression, even by unusual paths.
	game.player.reset_at(game.course.checkpoints[2])
	await frames(10)
	check(game.checkpoint==0,"out-of-order checkpoint area cannot skip saved progress")
	game.player.reset_at(game.course.finish_position)
	await frames(10)
	check(not game.finished,"finish area rejects incomplete checkpoint sequence")
	# Each checkpoint and its fall recovery are verified against actual Area3D.
	for index in range(1,game.course.checkpoints.size()):
		game.player.reset_at(game.course.checkpoints[index])
		await frames(10)
		check(game.checkpoint==index,"checkpoint %d saves through its live area"%index)
		check(game.course.current_chapter==game.course.checkpoint_chapters[index] and game.hud.chapter==game.course.checkpoint_chapters[index],"save %d keeps correct district and camera chapter"%index)
		check(game.hud.notice_is_save and game.hud.checkpoint_total==9 and game.save_pulse_left>0,"save %d gives explicit saved feedback"%index)
		await frames(45)
		var before: int=game.falls
		game.player.reset_at(Vector3(200,-15,200))
		await frames(10)
		check(game.falls==before+1,"fall at checkpoint %d produces exactly one respawn"%index)
		check(game.player.position.distance_to(game.course.checkpoints[index])<.1,"fall returns to checkpoint %d"%index)
		check(game.hud.notice.begins_with("BACK AT CHECKPOINT") and str(index) in game.hud.notice,"respawn feedback identifies checkpoint %d"%index)
	await frames(50)
	var before: int=game.falls
	await action("overview")
	await action("retry_checkpoint")
	await frames(5)
	check(not paused and not game.map_view,"Backspace safely exits overview")
	check(game.falls==before+1 and game.player.position.distance_to(game.course.checkpoints[-1])<.1,"Backspace retries latest save")
	await frames(50)
	# Garden hurdles are real solid objects: ordinary walking stops, but the
	# unmodified jump clears each. Setup placement is isolated to this test.
	for index in game.course.hurdles.size():
		var h: Dictionary=game.course.hurdles[index]
		game.player.reset_at(h.at+Vector3(0,.48,1.3))
		for step in range(20):
			drive(Vector3.FORWARD)
			await frames(1)
		check(game.player.position.z>h.at.z+.5 and game.player.is_on_floor(),"garden hurdle %d physically blocks walking"%index)
		Input.action_press("jump")
		for step in range(44):
			if game.player.position.z>h.at.z-1: drive(Vector3.FORWARD)
			else:
				for key in ["move_forward","move_back","move_left","move_right"]: Input.action_release(key)
			await frames(1)
		release_movement()
		await frames(20)
		check(game.player.position.z<h.at.z-.5 and game.player.is_on_floor() and absf(game.player.position.y-h.at.y-.425)<.1,"normal jump clears garden hurdle %d"%index)
	# Both moving ferries carry an idle cube, including opposite phase/direction.
	for index in range(game.course.movers.size()):
		var mover: AnimatableBody3D=game.course.movers[index].body
		game.player.reset_at(mover.position+Vector3(0,.48,0))
		await frames(15)
		check(game.player.is_on_floor(),"cube lands on ferry %d"%index)
		var offset: Vector3=game.player.position-mover.position
		await frames(90)
		check(((game.player.position-mover.position)-offset).length()<.18,"ferry %d carries idle cube without drift"%index)
	# Rollers are not cosmetic spinning cylinders: the engine reports their
	# angular platform velocity and carries an idle cube sideways by contact.
	var roller_count:=0
	var roller_signs: Array[int]=[]
	for entry in game.course.route:
		if not entry.has("roller"): continue
		roller_count+=1
		await frames(50)
		var roller: StaticBody3D=entry.roller
		var cylinder_collider: CollisionShape3D=roller.get_child(0)
		check(cylinder_collider.shape is CylinderShape3D and absf(cylinder_collider.shape.radius-entry.radius)<.001,"roller %d uses a genuine curved cylinder collider"%roller_count)
		game.player.reset_at(entry.body.position+Vector3(0,.48,0))
		await frames(8)
		check(game.player.is_on_floor(),"roller %d supports the cube on its real cylinder"%roller_count)
		var omega: Vector3=game.player.get_platform_angular_velocity()
		check(omega.length()>.05 and omega.distance_to(roller.constant_angular_velocity)<.05,"roller %d exposes actual angular contact velocity"%roller_count)
		var z_before: float=game.player.position.z
		var roller_falls: int=game.falls
		await frames(24)
		var drift: float=game.player.position.z-z_before
		check(absf(drift)>.12 and signf(drift)==signf(omega.x) and game.falls==roller_falls,"roller %d physically carries idle cube sideways in the rotation direction"%roller_count)
		roller_signs.append(int(signf(omega.x)))
		var visual: Node3D=game.course.rollers[roller_count-1].visual
		check(absf(wrapf(visual.rotation.x-entry.speed*game.course.clock,-PI,PI))<.01,"roller %d visible stripes match its physical angular speed"%roller_count)
		print("ROLLER PHYSICS index=%d omega=%s drift=%.3fm"%[roller_count,omega,drift])
	check(roller_count>=2 and roller_signs.has(-1) and roller_signs.has(1),"rolling roads include both rotation directions")
	# Every sweep is live; its visible, rotating bar must cause a respawn.
	for index in range(game.course.sweepers.size()):
		await frames(50)
		var pivot: Node3D=game.course.sweepers[index]
		before=game.falls
		var hit: Vector3=pivot.global_position+pivot.global_basis.x*2
		hit.y=pivot.get_parent().global_position.y+.48
		game.player.reset_at(hit)
		await frames(15)
		check(game.falls==before+1,"live sweeper %d contact returns cube to save"%index)
	await frames(50)
	while fmod(game.course.clock,4.8)<2.65 or fmod(game.course.clock,4.8)>2.85: await frames(1)
	before=game.falls
	var beam: Vector3=game.course.gate.global_position
	game.player.reset_at(Vector3(beam.x,beam.y-.32,beam.z))
	await frames(10)
	check(game.falls==before,"green timing gate allows occupancy")
	await frames(140)
	check(game.falls==before+1,"red activation detects an existing gate occupant")
	# High-route misses are caught by a real recovery shelf, then a normal jump
	# reconnects to the low route rather than requiring a forced checkpoint retry.
	await frames(50)
	before=game.falls
	game.player.reset_at(Vector3(1,8,-54))
	await frames(60)
	check(game.player.is_on_floor() and absf(game.player.position.y-2.725)<.05 and game.falls==before,"high route recovery shelf catches a missed landing")
	for i in range(60):
		if game.player.position.z>=-49.7: break
		drive(Vector3.BACK)
		await frames(1)
	Input.action_press("jump")
	for i in range(42):
		drive(Vector3.BACK)
		await frames(1)
	Input.action_release("jump")
	release_movement()
	await frames(15)
	check(game.player.is_on_floor() and game.player.position.y>3.4 and game.falls==before,"normal movement and jump return recovery shelf to main route")
	game.player.reset_at(game.course.finish_position)
	await frames(10)
	check(game.finished and not game.player.controls_enabled,"finish area ends complete run and locks controls")
	var end_time: float=game.elapsed
	await frames(30)
	check(game.elapsed==end_time and game.best>0,"completed time freezes and versioned best is saved")
	await action("overview")
	check(game.map_view and paused,"finished run can inspect overview")
	await action("pause")
	check(not game.map_view and game.finished,"Escape closes completed-run overview")
	await action("accept")
	await frames(5)
	check(not game.finished and not game.running and game.elapsed==0 and game.checkpoint==0 and game.falls==0,"Enter clears completed progress for a new run")
	check(game.player.controls_enabled and game.player.position.distance_to(game.course.checkpoints[0])<.1,"restart restores controls and starting position")
	await action("pause")
	await action("restart")
	await frames(3)
	check(not paused and not game.running,"restart from pause returns to ready mode")
	game.invulnerability=0
	game._hazard_touched()
	game.restart()
	await frames(3)
	check(game.falls==0 and not game.respawn_pending,"restart cancels queued old-run respawn")
	print("FOCUSED RESULT checks=%d errors=%d"%[checks,errors])
	game.queue_free()
	await process_frame
	# Dummy audio runs on wall time, unlike accelerated physics.
	OS.delay_msec(100)
	await process_frame
	quit(errors)
