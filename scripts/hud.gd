extends Control
signal restart_requested
signal resume_requested

var elapsed := 0.0
var best := 0.0
var checkpoint := 0
var falls := 0
var running := false
var finished := false
var paused := false
var muted := false
var notice := ""
var notice_alpha := 0.0
var _font: Font
var _bold: FontVariation
const WHITE := Color("f7f7ef")
const INK := Color("24394f")
const MINT := Color("51e1c2")
const GOLD := Color("ffd17a")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_font = ThemeDB.fallback_font
	_bold = FontVariation.new()
	_bold.base_font = _font
	_bold.variation_embolden = 0.7

func time_text(value: float) -> String:
	var centis := int(value*100.0)
	return "%02d:%02d.%02d" % [centis/6000, (centis/100)%60, centis%100]

func _panel(rect: Rect2, color: Color, radius: int = 14) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func _text(at: Vector2, content: String, size_px: int, color: Color = WHITE, bold: bool = false) -> void:
	draw_string(_bold if bold else _font, at, content, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func _center(y: float, content: String, size_px: int, color: Color = WHITE, bold: bool = false) -> void:
	var font: Font = _bold if bold else _font
	_text(Vector2(640-font.get_string_size(content,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x/2,y),content,size_px,color,bold)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,size/Vector2(1280,800))
	_panel(Rect2(28,26,235,79),INK)
	# Plain square brand mark mirrors the player — never a face.
	draw_rect(Rect2(46,45,24,24),WHITE)
	_text(Vector2(83,60),"CUBE",27,WHITE,true)
	_text(Vector2(83,83),"SKYLINE SPRINT",12,Color("a7c2d5"))
	_panel(Rect2(473,26,334,76),Color(0.14,0.23,0.31,0.94))
	var names := ["HOP ISLANDS", "DRIFT PLATFORMS", "FIND THE RHYTHM"]
	_center(53,"0%d  /  %s" % [checkpoint+1,names[checkpoint]],14,WHITE,true)
	for i in range(3):
		_panel(Rect2(514+i*87,68,78,5), MINT if i<=checkpoint else Color("476277"),2)
	_text(Vector2(1082,45),"TIME",11,INK,true)
	_text(Vector2(1050,78),time_text(elapsed),28,INK,true)
	_text(Vector2(1052,98),"BEST  "+(time_text(best) if best > 0 else "—"),11,INK)
	_panel(Rect2(28,125,181,34),Color(1,1,0.96,0.84),10)
	draw_circle(Vector2(46,142),4,MINT.darkened(0.25))
	_text(Vector2(58,147),"CHECKPOINT   %d / 2" % checkpoint,12,INK,true)
	_panel(Rect2(310,748,660,31),Color(0.14,0.23,0.31,0.88),10)
	_center(769,"WASD / ARROWS   Move       SPACE   Jump       R   Restart       ESC   Pause       M   Sound",12)
	if not running and not finished and not paused:
		_panel(Rect2(433,616,414,82),INK)
		_center(647,"A little cube. A big leap.",20,WHITE,true)
		_center(675,"Move to start  •  Hold Space for a longer jump",13,Color("b6cfdd"))
	if notice_alpha > 0.0 and not finished and not paused:
		var c := Color(0.14,0.23,0.31,notice_alpha*0.95)
		_panel(Rect2(470,133,340,40),c,12)
		_center(159,notice,15,Color(1,1,0.95,notice_alpha),true)
	if paused or finished:
		draw_rect(Rect2(0,0,1280,800),Color(0.08,0.16,0.24,0.32))
		_panel(Rect2(410,240,460,320),INK,22)
		_center(282,"SKYLINE SPRINT",12,MINT)
		_center(332,"COURSE CLEAR" if finished else "TAKE A BREATHER",30,WHITE,true)
		if finished:
			_center(387,time_text(elapsed),43,GOLD,true)
			_center(420,"%d falls   ·   2 checkpoints   ·   One excellent cube" % falls,13,Color("c3d6de"))
		else:
			_center(382,"Your timer and the course are paused.",15,Color("c3d6de"))
			_center(414,"Backspace returns to your checkpoint.",13,Color("c3d6de"))
		_panel(Rect2(462,453,356,49),MINT,12)
		_center(485,"RUN AGAIN  /  ENTER" if finished else "KEEP GOING  /  ESC",16,INK,true)
		_center(534,"R  ·  Start a fresh run",12,Color("a7c2d5"))
	if muted: _text(Vector2(1152,768),"SOUND OFF",10,INK)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position * Vector2(1280,800)/size
		if Rect2(462,453,356,49).has_point(p):
			if finished: restart_requested.emit()
			elif paused: resume_requested.emit()
