extends Node3D

signal completed(metrics: Dictionary)
var personal_best: int = 0
## A full island journey. One plain cube; no external assets or autoloads.
const Course := preload("res://games/minigame/godot_party_default_lighthouse_isles/scripts/course.gd")
const Player := preload("res://games/minigame/godot_party_default_lighthouse_isles/scripts/player.gd")
const Hud := preload("res://games/minigame/godot_party_default_lighthouse_isles/scripts/hud.gd")
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
var save_pulse_left := 0.0
var respawn_pending := false
var camera_anchor := Vector3.ZERO
var camera_heading := PI
var local_pause: bool = false:
	set(value):
		local_pause = value
		player.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
		course.process_mode = player.process_mode
var map_view := false
var _paused_before_overview := false
const FOLLOW_FOV := 58.0
const CAMERA_FAR := 520.0
var sounds: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	_setup_inputs()
	_build_environment()
	course = Course.new()
	course.process_mode = Node.PROCESS_MODE_INHERIT
	add_child(course)
	course.checkpoint_reached.connect(_checkpoint_reached)
	course.hazard_touched.connect(_hazard_touched)
	course.finish_reached.connect(_finish)
	player = Player.new()
	player.name = "Cube"
	player.collision_layer = 2
	player.collision_mask = 1
	player.add_to_group("player")
	player.process_mode = Node.PROCESS_MODE_INHERIT
	add_child(player)
	player.camera = camera
	player.fall_height = -14.0
	player.fell.connect(_hazard_touched)
	player.jumped.connect(func(): _play_sound("lighthouse_isles_jump"))
	player.landed.connect(func(): _play_sound("land"))
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)
	hud = Hud.new()
	canvas.add_child(hud)
	hud.checkpoint_total = course.checkpoints.size()-1
	hud.restart_requested.connect(restart)
	hud.resume_requested.connect(_toggle_pause)
	best = float(personal_best) / 1000.0
	_build_sounds()
	restart()

func _setup_inputs() -> void:
	var actions := {
		"lighthouse_isles_move_left": [KEY_A,KEY_LEFT], "lighthouse_isles_move_right": [KEY_D,KEY_RIGHT],
		"lighthouse_isles_move_forward": [KEY_W,KEY_UP], "lighthouse_isles_move_back": [KEY_S,KEY_DOWN],
		"lighthouse_isles_jump": [KEY_SPACE], "lighthouse_isles_restart": [KEY_R], "lighthouse_isles_pause": [KEY_ESCAPE],
		"lighthouse_isles_retry_checkpoint": [KEY_BACKSPACE], "lighthouse_isles_accept": [KEY_ENTER], "lighthouse_isles_mute": [KEY_M],
		"lighthouse_isles_overview": [KEY_TAB]
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
	env.fog_density = 0.0014
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-30,0)
	sun.light_color = Color("fff0d1")
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 125
	add_child(sun)
	camera = Camera3D.new()
	camera.name = "ChaseCamera"
	camera.fov = FOLLOW_FOV
	camera.far = CAMERA_FAR
	camera.current = true
	add_child(camera)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("lighthouse_isles_restart"): restart()
	elif event.is_action_pressed("lighthouse_isles_overview") and not event.is_echo(): _toggle_overview()
	elif event.is_action_pressed("lighthouse_isles_pause") and (not finished or map_view): _toggle_pause()
	elif event.is_action_pressed("lighthouse_isles_accept") and finished: restart()
	elif event.is_action_pressed("lighthouse_isles_retry_checkpoint") and not finished:
		if map_view: _toggle_overview()
		local_pause = false
		_hazard_touched()
	elif event.is_action_pressed("lighthouse_isles_mute"):
		muted = not muted
		hud.muted = muted

func _physics_process(delta: float) -> void:
	if local_pause: return
	invulnerability = maxf(0,invulnerability-delta)
	if not finished:
		if not running and (Input.get_vector("lighthouse_isles_move_left","lighthouse_isles_move_right","lighthouse_isles_move_forward","lighthouse_isles_move_back").length()>0 or Input.is_action_just_pressed("lighthouse_isles_jump")):
			running = true
		if running: elapsed += delta
	notice_left = maxf(0,notice_left-delta)
	save_pulse_left = maxf(0,save_pulse_left-delta)

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	if not local_pause:
		var target := player.global_position
		target.y = maxf(course.checkpoints[checkpoint].y-0.5,target.y-0.43)
		camera_anchor.x = lerpf(camera_anchor.x,target.x,1-exp(-8*delta))
		camera_anchor.z = lerpf(camera_anchor.z,target.z,1-exp(-10*delta))
		camera_anchor.y = lerpf(camera_anchor.y,target.y,1-exp(-3*delta))
		# Keep the control frame stable while airborne or standing still. The
		# route tangent anticipates bends; it never chases the cube's velocity.
		if player.is_on_floor() and Vector2(player.velocity.x,player.velocity.z).length() > 0.25:
			var forward := _course_forward(player.position)
			var desired_heading := atan2(forward.x,forward.z)
			var difference := wrapf(desired_heading-camera_heading,-PI,PI)
			if absf(difference) > 0.025:
				camera_heading += clampf(difference*1.8*delta,-0.65*delta,0.65*delta)
		_update_camera()
	hud.elapsed = elapsed
	hud.best = best
	hud.checkpoint = checkpoint
	hud.checkpoint_total = course.checkpoints.size()-1
	hud.chapter = course.current_chapter
	hud.save_pulse = clampf(save_pulse_left/1.8,0.0,1.0)
	hud.falls = falls
	hud.running = running
	hud.finished = finished
	hud.paused = local_pause and not map_view
	hud.map_view = map_view
	if map_view:
		hud.map_markers.clear()
		hud.map_saves.clear()
		var viewport_size := get_viewport().get_visible_rect().size
		var chapter_points: Array = course.get("chapter_starts") if course.get("chapter_starts") != null else course.checkpoints
		for point in chapter_points:
			hud.map_markers.append(camera.unproject_position(point+Vector3.UP*1.2)*Vector2(1280,800)/viewport_size)
		for index in range(1,course.checkpoints.size()):
			var point: Vector3 = course.checkpoints[index]
			hud.map_saves.append(camera.unproject_position(point+Vector3.UP*1.2)*Vector2(1280,800)/viewport_size)
		hud.finish_marker = Vector2(-1,-1)
		if course.get("finish_position") != null:
			hud.finish_marker = camera.unproject_position(course.get("finish_position")+Vector3.UP*3.0)*Vector2(1280,800)/viewport_size
	hud.notice_alpha = minf(notice_left,1.0)
	hud.queue_redraw()

func _course_forward(at: Vector3) -> Vector3:
	if course.has_method("camera_forward_at"):
		var direction: Vector3 = course.camera_forward_at(at)
		direction.y = 0.0
		if direction.length_squared() > 0.01: return direction.normalized()
	return Vector3.FORWARD

func _snap_camera_heading() -> void:
	var direction := _course_forward(player.position)
	camera_heading = atan2(direction.x,direction.z)

func _update_camera() -> void:
	if map_view:
		var center: Vector3 = course.get("overview_center") if course.get("overview_center") != null else Vector3(0,6,-12)
		var extent: float = float(course.get("overview_size")) if course.get("overview_size") != null else 165.0
		camera.set_orthogonal(extent,0.1,CAMERA_FAR)
		camera.position = center + Vector3(-95,155,100)
		camera.look_at(center)
		return
	camera.set_perspective(FOLLOW_FOV,0.1,CAMERA_FAR)
	var forward := Vector3(sin(camera_heading),0,cos(camera_heading))
	camera.position = camera_anchor - forward*15.8 + Vector3(0,12.2,0)
	camera.look_at(camera_anchor+forward*6.8)

func _toggle_overview() -> void:
	if map_view:
		map_view = false
		local_pause = _paused_before_overview
	else:
		_paused_before_overview = local_pause
		map_view = true
		local_pause = true
	_update_camera()

func _checkpoint_reached(index: int) -> void:
	if finished or index <= checkpoint or index >= course.checkpoints.size(): return
	if index != checkpoint+1:
		_show_notice("FIND CHECKPOINT %d BEFORE CONTINUING" % (checkpoint+1),3.0)
		return
	checkpoint = index
	course.set_checkpoint(index)
	save_pulse_left = 1.8
	_show_notice("SAVED CHECKPOINT  %d / %d" % [index,course.checkpoints.size()-1],3.2,"Falls return here  ·  Backspace retries from this beacon",true)
	_play_sound("save")

func _show_notice(message: String,seconds: float,detail: String="",saved: bool=false) -> void:
	hud.notice = message
	hud.notice_detail = detail
	hud.notice_is_save = saved
	notice_left = seconds

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
	_snap_camera_heading()
	_update_camera()
	var message := "BACK AT CHECKPOINT  %d / %d" % [checkpoint,course.checkpoints.size()-1] if checkpoint>0 else "BACK AT THE START"
	_show_notice(message,2.0,"Saved progress is kept" if checkpoint>0 else "Find the first glowing beacon")
	_play_sound("fall")

func restart() -> void:
	map_view = false
	_paused_before_overview = false
	local_pause = false
	checkpoint = 0
	elapsed = 0.0
	falls = 0
	running = false
	finished = false
	invulnerability = 0.8
	respawn_pending = false
	notice_left = 0
	save_pulse_left = 0
	hud.notice_is_save = false
	hud.notice_detail = ""
	course.reset()
	player.reset_at(course.checkpoints[0])
	player.set_controls_enabled(true)
	camera_anchor = player.position
	_snap_camera_heading()
	_update_camera()

func _toggle_pause() -> void:
	if map_view:
		_toggle_overview()
		return
	if finished: return
	local_pause = not local_pause

func _finish() -> void:
	if finished or not running: return
	if checkpoint != course.checkpoints.size()-1:
		_show_notice("FOLLOW THE ROUTE  /  SAVE EVERY CHECKPOINT",3.0)
		return
	finished = true
	player.set_controls_enabled(false)
	course.celebrating = true
	if best <= 0 or elapsed < best:
		best = elapsed
	_play_sound("finish")
	completed.emit({"time": roundi(elapsed * 1000.0), "falls": falls})

func _build_sounds() -> void:
	for entry in [["lighthouse_isles_jump",540.0,0.08],["land",230.0,0.05],["save",880.0,0.24],["fall",140.0,0.16],["finish",1046.5,0.45]]:
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
	sound.process_mode = Node.PROCESS_MODE_INHERIT
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()

func _exit_tree() -> void:
	for action: String in ["lighthouse_isles_move_left", "lighthouse_isles_move_right", "lighthouse_isles_move_forward", "lighthouse_isles_move_back", "lighthouse_isles_jump", "lighthouse_isles_restart", "lighthouse_isles_pause", "lighthouse_isles_retry_checkpoint", "lighthouse_isles_accept", "lighthouse_isles_mute", "lighthouse_isles_overview"]:
		InputMap.erase_action(action)
