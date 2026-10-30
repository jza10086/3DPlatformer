class_name CubePlayer
extends CharacterBody3D
## A plain cube with camera-relative, forgiving platformer movement.

signal fell
signal jumped
signal landed

const RUN_SPEED := 7.0
const GROUND_ACCELERATION := 45.0
const AIR_ACCELERATION := 36.0
const JUMP_SPEED := 9.0
const GRAVITY := 24.0
const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.14
const CUBE_SIZE := 0.85

@export var fall_height := -15.0
var camera: Camera3D
var controls_enabled := true
var visual: MeshInstance3D

var _coyote_left := 0.0
var _jump_buffer_left := 0.0
var _fall_reported := false
var _visual_scale := Vector3.ONE


func _ready() -> void:
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(50.0)
	floor_stop_on_slope = true
	# Platforms carry the cube while grounded, without adding a surprising
	# sideways launch when it jumps off a moving landing pad.
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * CUBE_SIZE
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	visual = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * CUBE_SIZE
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.97, 0.97, 0.95)
	material.roughness = 0.66
	visual.material_override = material
	add_child(visual)


func _physics_process(delta: float) -> void:
	var grounded := is_on_floor()
	_coyote_left = COYOTE_TIME if grounded and velocity.y <= 0.0 else maxf(0.0, _coyote_left - delta)
	_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)
	var input_axis := Vector2.ZERO
	if controls_enabled:
		input_axis = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if Input.is_action_just_pressed("jump"):
			_jump_buffer_left = JUMP_BUFFER_TIME
	var direction := _camera_relative_direction(input_axis)
	var acceleration := GROUND_ACCELERATION if grounded else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, direction.x * RUN_SPEED, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * RUN_SPEED, acceleration * delta)
	if not grounded:
		velocity.y = maxf(velocity.y - GRAVITY * delta, -32.0)
	if controls_enabled and _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		_take_jump()
	if controls_enabled and Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= 0.48
	var descending := velocity.y < -1.0
	move_and_slide()
	if is_on_floor() and not grounded and descending:
		_visual_scale = Vector3(1.08, 0.88, 1.08)
		landed.emit()
		# Consume a buffered press on the landing frame, not a frame later.
		if controls_enabled and _jump_buffer_left > 0.0:
			_take_jump()
	_update_visual(delta, direction)
	if global_position.y < fall_height and not _fall_reported:
		_fall_reported = true
		fell.emit()


func _take_jump() -> void:
	velocity.y = JUMP_SPEED
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	_visual_scale = Vector3(0.97, 1.06, 0.97)
	jumped.emit()


func _camera_relative_direction(axis: Vector2) -> Vector3:
	var right := Vector3.RIGHT
	var back := Vector3.BACK
	if is_instance_valid(camera):
		right = camera.global_basis.x
		back = camera.global_basis.z
		right.y = 0.0
		back.y = 0.0
		right = right.normalized()
		back = back.normalized()
	return (right * axis.x + back * axis.y).limit_length(1.0)


func _update_visual(delta: float, direction: Vector3) -> void:
	_visual_scale = _visual_scale.lerp(Vector3.ONE, 1.0 - exp(-16.0 * delta))
	visual.scale = _visual_scale
	var lean := Vector3(direction.z * 0.055, 0.0, -direction.x * 0.055)
	visual.rotation = visual.rotation.lerp(lean, 1.0 - exp(-13.0 * delta))


func reset_at(spawn_position: Vector3) -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	_fall_reported = false
	_visual_scale = Vector3.ONE
	if is_instance_valid(visual):
		visual.rotation = Vector3.ZERO
		visual.scale = Vector3.ONE


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not enabled:
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
