extends SceneTree
var player
var errors := 0
class MovingPad extends AnimatableBody3D:
	func _physics_process(delta: float):
		position.x += delta * 1.5
func _initialize():
	for a in ["move_left", "move_right", "move_forward", "move_back", "jump"]:
		InputMap.add_action(a)
	call_deferred("run")
func check(ok: bool, message: String):
	if not ok:
		errors += 1
		push_error(message)
	else:
		print("PASS ", message)
func frames(n: int):
	for i in n:
		await physics_frame
func run():
	var floor_node := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(50, 1, 50)
	floor_node.add_child(floor_shape)
	floor_node.position.y = -0.5
	root.add_child(floor_node)
	player = load("res://scripts/player.gd").new()
	root.add_child(player)
	player.reset_at(Vector3(0, 0.44, 0))
	await frames(15)
	check(player.is_on_floor(), "lands on flat floor")
	Input.action_press("move_forward")
	await frames(45)
	check(player.position.z < -4.0, "forward input moves in negative Z")
	Input.action_release("move_forward")
	await frames(12)
	check(absf(player.velocity.z) < 0.1, "stops responsively")
	Input.action_press("jump")
	await frames(16)
	check(player.position.y > 1.6, "held jump reaches clear elevation")
	Input.action_release("jump")
	await frames(60)
	check(player.is_on_floor(), "returns to floor")
	player.set_controls_enabled(false)
	var previous: Vector3 = player.position
	Input.action_press("move_right")
	await frames(20)
	check(player.position.distance_to(previous) < 0.01, "disabled controls do not move")
	Input.action_release("move_right")
	player.reset_at(Vector3(2, 0.44, 1))
	check(player.velocity.length() == 0.0 and player.position == Vector3(2, 0.44, 1), "reset clears velocity and sets position")
	player.set_controls_enabled(true)
	player.reset_at(Vector3(24.8, 0.44, 0))
	await frames(5)
	Input.action_press("move_right")
	while player.is_on_floor():
		await frames(1)
	var edge_y: float = player.position.y
	Input.action_press("jump")
	await frames(8)
	check(player.position.y > edge_y + 0.5, "coyote jump works just after walking off edge")
	Input.action_release("move_right")
	Input.action_release("jump")
	await frames(2)
	player.reset_at(Vector3(0, 2, 0))
	player.velocity.y = -4
	while player.position.y > 0.95:
		await frames(1)
	check(not player.is_on_floor(), "buffer press starts before landing")
	Input.action_press("jump")
	await frames(12)
	check(player.position.y > 1.2 and player.velocity.y > 0, "buffered jump launches after landing")
	Input.action_release("jump")
	await frames(60)
	var pad := MovingPad.new()
	pad.sync_to_physics = true
	pad.position = Vector3(0, 2, 0)
	var pad_shape := CollisionShape3D.new()
	pad_shape.shape = BoxShape3D.new()
	pad_shape.shape.size = Vector3(6, 1, 6)
	pad.add_child(pad_shape)
	root.add_child(pad)
	player.reset_at(Vector3(0, 2.94, 0))
	await frames(20)
	var relative_x: float = player.position.x - pad.position.x
	await frames(90)
	check(absf((player.position.x - pad.position.x) - relative_x) < 0.12, "grounded cube rides moving AnimatableBody3D")
	Input.action_press("jump")
	await frames(3)
	check(absf(player.velocity.x) < 0.01, "platform leave does not add lateral launch velocity")
	Input.action_release("jump")
	quit(errors)
