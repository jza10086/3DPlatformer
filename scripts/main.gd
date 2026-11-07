extends Node3D
const CONTROLS: GDScript = preload("res://games/protocols/godot_party_default_protocol/solo_controls.gd")
const SETTINGS: GDScript = preload("res://games/minigame/godot_party_default_lighthouse_isles/settings.gd")
var controls: CONTROLS = CONTROLS.new(SETTINGS.schema())
var _active: bool = false
var _stopped: bool = false
var _text_source: RefCounted

signal completed(metrics: Dictionary)
var personal_best: int = 0
## A full island journey. One plain cube; no external assets or autoloads.
const COURSE_SCRIPT: GDScript = preload("res://games/minigame/godot_party_default_lighthouse_isles/scripts/course.gd")
const PLAYER_SCRIPT: GDScript = preload("res://games/minigame/godot_party_default_lighthouse_isles/scripts/player.gd")
const HUD_SCRIPT: GDScript = preload("res://games/minigame/godot_party_default_lighthouse_isles/scripts/hud.gd")
@export var course: COURSE_SCRIPT
@onready var player: PLAYER_SCRIPT = $Cube
@onready var camera: Camera3D = $ChaseCamera
@onready var hud: HUD_SCRIPT = $GameHUD/HUD
@export_category("Follow camera")
@export var follow_distance: float = 15.8
@export var follow_height: float = 12.2
@export var look_ahead: float = 6.8
@export var camera_smoothing: Vector3 = Vector3(8.0, 3.0, 10.0)
@export var heading_response: float = 1.8
@export var heading_speed: float = 0.65
@export var overview_offset: Vector3 = Vector3(-95.0, 155.0, 100.0)
@export_category("Audio")
@export var jump_sound: PartyAudioCue
@export var land_sound: PartyAudioCue
@export var save_sound: PartyAudioCue
@export var fall_sound: PartyAudioCue
@export var finish_sound: PartyAudioCue
var checkpoint: int = 0
var elapsed: float = 0.0
var best: float = 0.0
var falls: int = 0
var running: bool = false
var finished: bool = false
var muted: bool = false
var invulnerability: float = 0.0
var notice_left: float = 0.0
var save_pulse_left: float = 0.0
var respawn_pending: bool = false
var camera_anchor: Vector3 = Vector3.ZERO
var camera_heading: float = PI
var local_pause: bool = false:
	set(value):
		local_pause = value
		player.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
		course.process_mode = player.process_mode
var map_view: bool = false
var _paused_before_overview: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	assert(course != null, "Assign the authored course in the scene.")
	course.checkpoint_reached.connect(_checkpoint_reached)
	course.hazard_touched.connect(_hazard_touched)
	course.finish_reached.connect(_finish)
	player.add_to_group("player")
	player.controls = controls
	player.fell.connect(_hazard_touched)
	player.jumped.connect(func() -> void: _play_sound(jump_sound))
	player.landed.connect(func() -> void: _play_sound(land_sound))
	hud.i18n = _text_source
	hud.formal = controls.context != null
	hud.checkpoint_total = course.checkpoints.size()-1
	hud.restart_requested.connect(_restart_requested)
	hud.resume_requested.connect(_resume_requested)
	best = float(personal_best) / 1000.0
	for cue: PartyAudioCue in [jump_sound, land_sound, save_sound, fall_sound, finish_sound]:
		assert(cue != null and cue.validate() == OK, "Assign a valid cue for every game sound.")
	restart()
	player.set_physics_process(false)
	course.set_physics_process(false)
	$GameHUD.hide()
	if controls.context == null:
		solo_start()

func _unhandled_input(event: InputEvent) -> void:
	if not controls.allowed():
		return
	if controls.matches(event, &"lighthouse_isles_restart"):
		restart()
	elif controls.matches(event, &"lighthouse_isles_overview") and not event.is_echo():
		_toggle_overview()
	elif controls.context == null and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and (not finished or map_view):
		_toggle_pause()
	elif controls.matches(event, &"lighthouse_isles_accept") and finished:
		restart()
	elif controls.matches(event, &"lighthouse_isles_retry_checkpoint") and not finished:
		if map_view:
			_toggle_overview()
		local_pause = false
		_hazard_touched()
	elif controls.matches(event, &"lighthouse_isles_mute"):
		muted = not muted
		hud.muted = muted

func _physics_process(delta: float) -> void:
	if not _active or local_pause:
		return
	invulnerability = maxf(0,invulnerability-delta)
	if not finished:
		if not running and (controls.get_vector("lighthouse_isles_move_left","lighthouse_isles_move_right","lighthouse_isles_move_forward","lighthouse_isles_move_back").length()>0 or controls.is_pressed(&"lighthouse_isles_jump")):
			running = true
		if running:
			elapsed += delta
	notice_left = maxf(0,notice_left-delta)
	save_pulse_left = maxf(0,save_pulse_left-delta)

func _process(delta: float) -> void:
	if not _active:
		return
	if not local_pause:
		var target: Vector3 = player.global_position
		target.y = maxf(course.checkpoints[checkpoint].y-0.5,target.y-0.43)
		camera_anchor.x = lerpf(camera_anchor.x,target.x,1-exp(-camera_smoothing.x*delta))
		camera_anchor.z = lerpf(camera_anchor.z,target.z,1-exp(-camera_smoothing.z*delta))
		camera_anchor.y = lerpf(camera_anchor.y,target.y,1-exp(-camera_smoothing.y*delta))
		# Keep the control frame stable while airborne or standing still. The
		# route tangent anticipates bends; it never chases the cube's velocity.
		if player.is_on_floor() and Vector2(player.velocity.x,player.velocity.z).length() > 0.25:
			var forward: Vector3 = course.camera_forward_at(player.position)
			var desired_heading: float = atan2(forward.x,forward.z)
			var difference: float = wrapf(desired_heading-camera_heading,-PI,PI)
			if absf(difference) > 0.025:
				camera_heading += clampf(difference*heading_response*delta,-heading_speed*delta,heading_speed*delta)
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
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		var chapter_points: Array[Vector3] = course.chapter_starts
		for point: Vector3 in chapter_points:
			hud.map_markers.append(camera.unproject_position(point+Vector3.UP*1.2)*Vector2(1280,800)/viewport_size)
		for index: int in range(1,course.checkpoints.size()):
			var point: Vector3 = course.checkpoints[index]
			hud.map_saves.append(camera.unproject_position(point+Vector3.UP*1.2)*Vector2(1280,800)/viewport_size)
		hud.finish_marker = camera.unproject_position(course.finish_position+Vector3.UP*3.0)*Vector2(1280,800)/viewport_size
	hud.notice_alpha = minf(notice_left,1.0)
	hud.refresh()

func _snap_camera_heading() -> void:
	var direction: Vector3 = course.camera_forward_at(player.position)
	camera_heading = atan2(direction.x,direction.z)

func _update_camera() -> void:
	if map_view:
		var center: Vector3 = course.overview_center
		var extent: float = course.overview_size
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = extent
		camera.position = center + overview_offset
		camera.look_at(center)
		return
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	var forward: Vector3 = Vector3(sin(camera_heading),0,cos(camera_heading))
	camera.position = camera_anchor - forward*follow_distance + Vector3.UP*follow_height
	camera.look_at(camera_anchor+forward*look_ahead)

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
	if finished or index <= checkpoint or index >= course.checkpoints.size():
		return
	if index != checkpoint+1:
		_show_notice(hud.hud_text(&"notice.missing_checkpoint", {"checkpoint": checkpoint + 1}), 3.0)
		return
	checkpoint = index
	course.set_checkpoint(index)
	save_pulse_left = 1.8
	_show_notice(hud.hud_text(&"notice.saved_checkpoint", {"current": index, "total": course.checkpoints.size() - 1}), 3.2, "Falls return here  ·  Backspace retries from this beacon", true)
	_play_sound(save_sound)

func _show_notice(message: String,seconds: float,detail: String="",saved: bool=false) -> void:
	hud.notice = message
	hud.notice_detail = detail
	hud.notice_is_save = saved
	notice_left = seconds

func _hazard_touched() -> void:
	if invulnerability > 0 or finished or respawn_pending:
		return
	respawn_pending = true
	_respawn.call_deferred()

func _respawn() -> void:
	if not respawn_pending:
		return
	respawn_pending = false
	falls += 1
	invulnerability = 0.7
	player.reset_at(course.checkpoints[checkpoint])
	camera_anchor = player.position
	_snap_camera_heading()
	_update_camera()
	var message: String = hud.hud_text(&"notice.return_checkpoint", {"current": checkpoint, "total": course.checkpoints.size() - 1}) if checkpoint > 0 else "BACK AT THE START"
	_show_notice(message,2.0,"Saved progress is kept" if checkpoint>0 else "Find the first glowing beacon")
	_play_sound(fall_sound)

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
	if finished:
		return
	local_pause = not local_pause

func _finish() -> void:
	if finished or not running:
		return
	if checkpoint != course.checkpoints.size()-1:
		_show_notice("FOLLOW THE ROUTE  /  SAVE EVERY CHECKPOINT",3.0)
		return
	finished = true
	player.set_controls_enabled(false)
	course.celebrating = true
	if best <= 0 or elapsed < best:
		best = elapsed
	_play_sound(finish_sound)
	completed.emit({"time": roundi(elapsed * 1000.0), "falls": falls})

func _play_sound(cue: PartyAudioCue) -> void:
	if muted or not _active:
		return
	var playback: PartyAudioHandle = $GameAudio.play_sfx(cue)
	assert(playback.error == OK, "Game audio playback failed: " + error_string(playback.error))

## Injected before entering the tree. F6 leaves the formal dependencies unset.
func solo_setup(input: PartyInput, text_source: RefCounted) -> void:
	controls.bind(input)
	_text_source = text_source
	$GameAudio.prepare_scope()

func solo_start() -> void:
	if _stopped:
		return
	_active = true
	controls.enabled = true
	player.set_physics_process(true)
	course.set_physics_process(true)
	$GameHUD.show()

func solo_stop() -> void:
	if _stopped:
		return
	_stopped = true
	_active = false
	controls.enabled = false
	set_process(false)
	set_physics_process(false)
	set_process_unhandled_input(false)
	set_process_unhandled_key_input(false)
	if not is_node_ready():
		return
	respawn_pending = false
	player.set_controls_enabled(false)
	player.set_physics_process(false)
	course.set_physics_process(false)
	$GameHUD.hide()
	$GameAudio.close_scope()

func solo_graphics_targets() -> Dictionary:
	return {"world": $WorldEnvironment1, "sun": $DirectionalLight3D2}

func solo_audio_target() -> PartyGameAudio:
	return $GameAudio

func _restart_requested() -> void:
	if controls.allowed():
		restart()

func _resume_requested() -> void:
	if controls.allowed():
		_toggle_pause()
