extends Node3D
## One run, one course, one cube. No autoloads or external assets.
const Course := preload("res://scripts/course.gd")
const Player := preload("res://scripts/player.gd")
const Hud := preload("res://scripts/hud.gd")
var course: Node3D
var player: CharacterBody3D
var camera: Camera3D
var hud: Control
var checkpoint := 0
var elapsed := 0.0
var best := 0.0
var falls := 0
var running := false
var finished := false
var muted := false
var invulnerability := 0.0
var notice_left := 0.0
var respawn_pending := false
var camera_anchor := Vector3.ZERO
var sounds: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_inputs()
	_build_environment()
	course = Course.new()
	course.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(course)
	course.checkpoint_reached.connect(_checkpoint_reached)
	course.hazard_touched.connect(_hazard_touched)
	course.finish_reached.connect(_finish)
	player = Player.new()
	player.name = "Cube"
	player.collision_layer = 2
	player.collision_mask = 1
	player.add_to_group("player")
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.camera = camera
	player.fall_height = -7.5
	player.fell.connect(_hazard_touched)
	player.jumped.connect(func(): _play_sound("jump"))
	player.landed.connect(func(): _play_sound("land"))
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)
	hud = Hud.new()
	canvas.add_child(hud)
	hud.restart_requested.connect(restart)
	hud.resume_requested.connect(_toggle_pause)
	_load_best()
	_build_sounds()
	restart()

func _setup_inputs() -> void:
	var actions := {
		"move_left": [KEY_A,KEY_LEFT], "move_right": [KEY_D,KEY_RIGHT],
		"move_forward": [KEY_W,KEY_UP], "move_back": [KEY_S,KEY_DOWN],
		"jump": [KEY_SPACE], "restart": [KEY_R], "pause": [KEY_ESCAPE],
		"retry_checkpoint": [KEY_BACKSPACE], "accept": [KEY_ENTER], "mute": [KEY_M]
	}
	for action in actions:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in actions[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action,event): InputMap.action_add_event(action,event)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("8fb9d7")
	sky_material.sky_horizon_color = Color("e0dcd2")
	sky_material.ground_bottom_color = Color("6e9eb9")
	sky_material.ground_horizon_color = Color("e0dcd2")
	sky_material.sky_curve = 0.22
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9e0ed")
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("bed4df")
	env.fog_density = 0.0025
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-30,0)
	sun.light_color = Color("fff0d1")
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 85
	add_child(sun)
	camera = Camera3D.new()
	camera.name = "ChaseCamera"
	camera.fov = 55
	camera.far = 260
	camera.current = true
	add_child(camera)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"): restart()
	elif event.is_action_pressed("pause") and not finished: _toggle_pause()
	elif event.is_action_pressed("accept") and finished: restart()
	elif event.is_action_pressed("retry_checkpoint") and not finished:
		if get_tree().paused: _toggle_pause()
		_hazard_touched()
	elif event.is_action_pressed("mute"):
		muted = not muted
		hud.muted = muted

func _physics_process(delta: float) -> void:
	if get_tree().paused: return
	invulnerability = maxf(0,invulnerability-delta)
	if not finished:
		if not running and (Input.get_vector("move_left","move_right","move_forward","move_back").length()>0 or Input.is_action_just_pressed("jump")):
			running = true
		if running: elapsed += delta
	notice_left = maxf(0,notice_left-delta)

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	if not get_tree().paused:
		var target := player.global_position
		target.y = maxf(course.checkpoints[checkpoint].y-0.5,target.y-0.43)
		camera_anchor.x = lerpf(camera_anchor.x,target.x,1-exp(-8*delta))
		camera_anchor.z = lerpf(camera_anchor.z,target.z,1-exp(-10*delta))
		camera_anchor.y = lerpf(camera_anchor.y,target.y,1-exp(-3*delta))
		_update_camera()
	hud.elapsed = elapsed
	hud.best = best
	hud.checkpoint = checkpoint
	hud.falls = falls
	hud.running = running
	hud.finished = finished
	hud.paused = get_tree().paused
	hud.notice_alpha = minf(notice_left,1.0)
	hud.queue_redraw()

func _update_camera() -> void:
	camera.position = camera_anchor + Vector3(0,10.5,14.5)
	camera.look_at(camera_anchor+Vector3(0,0,-5.2))

func _checkpoint_reached(index: int) -> void:
	if index <= checkpoint or finished: return
	checkpoint = index
	course.set_checkpoint(index)
	hud.notice = "CHECKPOINT SAVED  /  %d OF 2" % index
	notice_left = 2.8
	_play_sound("save")

func _hazard_touched() -> void:
	if invulnerability > 0 or finished or respawn_pending: return
	respawn_pending = true
	_respawn.call_deferred()

func _respawn() -> void:
	if not respawn_pending: return
	respawn_pending = false
	falls += 1
	invulnerability = 0.7
	player.reset_at(course.checkpoints[checkpoint])
	camera_anchor = player.position
	_update_camera()
	hud.notice = "BACK ON TRACK"
	notice_left = 1.4
	_play_sound("fall")

func restart() -> void:
	get_tree().paused = false
	checkpoint = 0
	elapsed = 0.0
	falls = 0
	running = false
	finished = false
	invulnerability = 0.8
	respawn_pending = false
	notice_left = 0
	course.reset()
	player.reset_at(course.checkpoints[0])
	player.set_controls_enabled(true)
	camera_anchor = player.position
	_update_camera()

func _toggle_pause() -> void:
	if finished: return
	get_tree().paused = not get_tree().paused

func _finish() -> void:
	if finished or not running: return
	finished = true
	player.set_controls_enabled(false)
	course.celebrating = true
	if best <= 0 or elapsed < best:
		best = elapsed
		var config := ConfigFile.new()
		config.set_value("record","best_seconds",best)
		config.save("user://record.cfg")
	_play_sound("finish")

func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load("user://record.cfg") == OK:
		best = float(config.get_value("record","best_seconds",0.0))

func _build_sounds() -> void:
	for entry in [["jump",540.0,0.08],["land",230.0,0.05],["save",880.0,0.24],["fall",140.0,0.16],["finish",1046.5,0.45]]:
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		var count := int(entry[2]*22050)
		var data := PackedByteArray()
		data.resize(count*2)
		for i in count:
			var t := float(i)/22050.0
			var envelope := sin(PI*i/count)*exp(-3.0*i/count)
			var sample := int(sin(TAU*entry[1]*t)*envelope*4500)
			data.encode_s16(i*2,sample)
		stream.data = data
		sounds[entry[0]] = stream

func _play_sound(key: String) -> void:
	if muted or not sounds.has(key): return
	var sound := AudioStreamPlayer.new()
	sound.stream = sounds[key]
	sound.volume_db = -7
	sound.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()
