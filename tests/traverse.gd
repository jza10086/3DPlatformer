extends SceneTree
## Input-only whole-course regression. Never moves the player or changes hazards.
## Native capture: godot --path . --script res://tests/traverse.gd -- --capture-dir=/absolute/path
var game: Node3D
var frame := 0
var current_pad := 0
var launch_frame := -100
var jumps := 0
var capture_dir := ""
var capture_index := 0
var capture_busy := false
var sweep_jumped := false
var gate_waited := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(capture_dir)
	call_deferred("run")

func _drive(x: float, forward: bool) -> void:
	for action in ["move_left","move_right","move_forward","move_back"]:
		Input.action_release(action)
	if forward: Input.action_press("move_forward")
	if x > 0.28: Input.action_press("move_right")
	if x < -0.28: Input.action_press("move_left")

func _jump() -> void:
	Input.action_press("jump")
	launch_frame = frame
	jumps += 1
	print("JUMP ", jumps, " pad=",current_pad," pos=",game.player.position)

func _capture(name: String = "") -> void:
	if capture_dir.is_empty() or capture_busy: return
	capture_busy = true
	await RenderingServer.frame_post_draw
	var path := "%s/%05d.png" % [capture_dir,capture_index]
	if not name.is_empty(): path = "%s/%s.png" % [capture_dir,name]
	root.get_texture().get_image().save_png(path)
	capture_index += 1
	capture_busy = false

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame
	_capture("start")
	for i in range(7200):
		frame = i
		var p: CharacterBody3D = game.player
		if frame % 8 == 0: _capture()
		if game.finished:
			_drive(0,false)
			Input.action_release("jump")
			print("TRAVERSAL PASS elapsed=%.3f falls=%d jumps=%d checkpoint=%d frames=%d" % [game.elapsed,game.falls,jumps,game.checkpoint,frame])
			for hold in range(60): await physics_frame
			await _capture("finish")
			quit(0)
			return
		if game.falls > 0:
			push_error("TRAVERSAL FAILED: fell at pad %d frame %d; no teleport or hazard bypass used" % [current_pad,frame])
			quit(1)
			return
		if frame - launch_frame > 38 and Input.is_action_pressed("jump"): Input.action_release("jump")
		# Recognize real landings, using geometry only as observational metadata.
		if current_pad+1 < game.course.route.size() and p.is_on_floor():
			var next: Dictionary = game.course.route[current_pad+1]
			var center: Vector3 = next.body.position
			if absf(p.position.z-center.z) < next.size.y/2+0.2 and absf(p.position.x-center.x)<next.size.x/2+0.2:
				current_pad += 1
				print("LAND pad=",current_pad," pos=",p.position," t=",game.elapsed)
				_capture("pad_%02d" % current_pad)
		var here: Dictionary = game.course.route[current_pad]
		var here_center: Vector3 = here.body.position
		var front_edge: float = here_center.z-here.size.y/2
		var target_x := 0.0
		var go := true
		# Brake while airborne to land before the rotating bar, leaving jump clearance.
		if current_pad == 8 and not p.is_on_floor() and p.position.z < -67.1: go = false
		if current_pad == 10 and not p.is_on_floor() and p.position.z < -84.6: go = false
		if current_pad+1 < game.course.route.size():
			var next: Dictionary = game.course.route[current_pad+1]
			# Wide platforms allow safe central landings; moving pads require steering.
			target_x = next.body.position.x * 0.55
		if current_pad == 9 and not sweep_jumped and p.is_on_floor():
			_jump()
			sweep_jumped = true
		if current_pad == 11 and p.position.z > -87.0 and p.position.z < -84.6:
			var phase: float = fmod(game.course.clock,4.4)
			if phase < 2.4 or phase > 3.8:
				go = false
				gate_waited = true
		if current_pad == 12:
			target_x = 0.0
		elif p.is_on_floor() and p.position.z <= front_edge + 0.5 and frame-launch_frame>15:
			_jump()
		_drive(target_x-p.position.x,go)
		await physics_frame
	push_error("TRAVERSAL TIMEOUT pad=%d pos=%s" % [current_pad,game.player.position])
	quit(1)
