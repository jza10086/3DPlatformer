extends SceneTree
## Focused state / integration checks. Setup placements here are deliberate;
## tests/traverse.gd independently proves the full course using input alone.
var game: Node3D
var errors := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok: print("PASS ",message)
	else:
		errors += 1
		push_error(message)

func frames(count: int) -> void:
	for i in count: await physics_frame

func action(name: String) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = name
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(10)
	check(game.course.gate.get_child(0).shape.size == game.course.gate_mesh.mesh.size,"gate collision exactly matches visible beam")
	check(game.elapsed==0 and not game.running,"timer waits for first movement")
	Input.action_press("move_forward")
	await frames(15)
	Input.action_release("move_forward")
	await frames(12)
	check(game.running and game.elapsed>0.2,"normal movement starts timer")
	await action("pause")
	check(paused,"Escape action pauses")
	var stopped_time: float = game.elapsed
	var stopped_clock: float = game.course.clock
	var stopped_pos: Vector3 = game.player.position
	var stopped_mover: Vector3 = game.course.movers[0].body.position
	await frames(35)
	check(game.elapsed==stopped_time and game.course.clock==stopped_clock,"pause freezes timer and hazard clock")
	check(game.player.position==stopped_pos and game.course.movers[0].body.position==stopped_mover,"pause freezes player and moving platforms")
	await action("pause")
	check(not paused,"Escape action resumes")
	await frames(4)
	check(game.elapsed>stopped_time,"timer resumes")
	# Real area entry, rather than directly assigning checkpoint state.
	game.player.reset_at(game.course.checkpoints[1])
	await frames(10)
	check(game.checkpoint==1,"checkpoint area activates save point")
	var pre_falls: int = game.falls
	game.player.reset_at(Vector3(20,-8,-30))
	await frames(10)
	check(game.falls==pre_falls+1,"fall emits a single respawn")
	check(game.player.position.distance_to(game.course.checkpoints[1])<0.1,"fall returns to saved checkpoint")
	await frames(50)
	# Moving-pad carry tested against the actual course's oscillating body.
	var mover: AnimatableBody3D = game.course.movers[0].body
	game.player.reset_at(mover.position+Vector3(0,0.48,0))
	await frames(15)
	check(game.player.is_on_floor(),"cube lands on actual moving platform")
	var offset: float = game.player.position.x-mover.position.x
	await frames(90)
	check(absf((game.player.position.x-mover.position.x)-offset)<0.13,"actual oscillating platform carries idle cube")
	# Rotating beam must remain dangerous on the live course.
	pre_falls = game.falls
	game.player.reset_at(Vector3(0.8,1.43,-70))
	await frames(110)
	check(game.falls>pre_falls,"live sweeper contact causes checkpoint respawn")
	# Enter while green and remain until it turns red: overlap-on-activation must hit.
	await frames(50)
	while fmod(game.course.clock,4.4)<2.6 or fmod(game.course.clock,4.4)>2.9:
		await frames(1)
	pre_falls = game.falls
	game.player.reset_at(Vector3(0,1.98,-87))
	await frames(10)
	check(game.falls==pre_falls,"green gate permits entry")
	await frames(120)
	check(game.falls==pre_falls+1,"gate turning red detects an existing occupant")
	await frames(50)
	pre_falls = game.falls
	await action("retry_checkpoint")
	await frames(5)
	check(game.falls==pre_falls+1 and game.player.position.distance_to(game.course.checkpoints[1])<0.1,"Backspace retries saved checkpoint")
	# Finish through its Area3D, then verify stopped timer and restart state.
	game.player.reset_at(Vector3(0,1.98,-97.2))
	await frames(10)
	check(game.finished and not game.player.controls_enabled,"finish area ends run and locks movement")
	var end_time: float = game.elapsed
	await frames(30)
	check(game.elapsed==end_time and game.best>0,"finish time freezes and best record is kept")
	await action("accept")
	await frames(5)
	check(not game.finished and not game.running and game.elapsed==0,"Enter restarts finished run with fresh timer")
	check(game.checkpoint==0 and game.falls==0 and game.player.controls_enabled,"restart clears progress and restores controls")
	check(game.player.position.distance_to(game.course.checkpoints[0])<0.1,"restart restores starting position")
	await action("pause")
	await action("restart")
	await frames(3)
	check(not paused and not game.running,"restart from pause returns to ready state")
	game.invulnerability = 0.0
	game._hazard_touched()
	game.restart()
	await frames(3)
	check(game.falls==0 and not game.respawn_pending,"restart cancels a queued old-run respawn")
	print("FOCUSED RESULT errors=",errors)
	game.queue_free()
	await process_frame
	quit(errors)
