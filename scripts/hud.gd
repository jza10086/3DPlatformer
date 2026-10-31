extends Control
## Compact edge-mounted overlays: the island, not a dashboard, owns the frame.
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
var map_view := false
var map_markers: Array[Vector2] = []
var finish_marker := Vector2(-1,-1)
var notice := ""
var notice_alpha := 0.0
var _font: Font
var _bold: FontVariation
const WHITE := Color("f7f7ef")
const INK := Color("24394f")
const MINT := Color("51e1c2")
const GOLD := Color("ffd17a")
const SUBTLE := Color("bad1dc")
const CHAPTERS := ["HARBOR GARDENS", "WINDMILL COURT", "CANOPY PATHS", "FERRY HARBOR", "RIDGE ASCENT", "LIGHTHOUSE RUN"]

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

func _panel(rect: Rect2, color: Color, radius: int = 12) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	draw_style_box(style,rect)

func _text(at: Vector2, content: String, size_px: int, color: Color = WHITE, bold: bool = false) -> void:
	draw_string(_bold if bold else _font,at,content,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)

func _center(y: float, content: String, size_px: int, color: Color = WHITE, bold: bool = false) -> void:
	var font: Font = _bold if bold else _font
	_text(Vector2(640-font.get_string_size(content,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x/2,y),content,size_px,color,bold)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,size/Vector2(1280,800))
	_panel(Rect2(24,24,244,66),Color(0.12,0.21,0.28,0.94))
	# A plain square remains the whole character identity — never a face.
	draw_rect(Rect2(41,42,25,25),WHITE)
	_text(Vector2(79,52),"CUBE",23,WHITE,true)
	_text(Vector2(80,74),"LIGHTHOUSE ISLES",12,SUBTLE)
	if map_view:
		_draw_map()
		return
	_panel(Rect2(474,24,332,66),Color(0.12,0.21,0.28,0.9))
	_center(50,"0%d  /  %s" % [checkpoint+1,CHAPTERS[clampi(checkpoint,0,5)]],13,WHITE,true)
	for i in range(6):
		_panel(Rect2(495+i*49,67,43,4),MINT if i<=checkpoint else Color("476277"),2)
	_panel(Rect2(1066,24,190,66),Color(0.97,0.98,0.94,0.9))
	_text(Vector2(1081,42),"TIME",9,INK,true)
	_text(Vector2(1080,68),time_text(elapsed),25,INK,true)
	_text(Vector2(1082,82),"BEST  "+(time_text(best) if best>0 else "—"),9,INK)
	_panel(Rect2(24,102,174,30),Color(0.97,0.98,0.94,0.86),9)
	draw_circle(Vector2(40,117),4,MINT.darkened(0.3))
	_text(Vector2(52,122),"CHECKPOINT  %d / 5" % checkpoint,11,INK,true)
	_panel(Rect2(217,748,846,30),Color(0.12,0.21,0.28,0.87),10)
	_center(768,"WASD / ARROWS  Move    SPACE  Jump    TAB  Map    BACKSPACE  Retry    R  Restart    ESC  Pause    M  Sound",11)
	if not running and not finished and not paused:
		_panel(Rect2(416,627,448,76),Color(0.12,0.21,0.28,0.94))
		_center(657,"One little cube. A whole island journey.",19,WHITE,true)
		_center(682,"Move to begin  ·  Hold Space for height  ·  Tab to explore the map",12,SUBTLE)
	if notice_alpha>0.0 and not finished and not paused:
		_panel(Rect2(410,108,460,36),Color(0.12,0.21,0.28,notice_alpha*0.93),10)
		_center(132,notice,12,Color(1,1,0.95,notice_alpha),true)
	if paused or finished:
		draw_rect(Rect2(0,0,1280,800),Color(0.08,0.16,0.24,0.3))
		_panel(Rect2(410,240,460,320),INK,22)
		_center(282,"LIGHTHOUSE ISLES",12,MINT)
		_center(332,"ISLAND JOURNEY COMPLETE" if finished else "TAKE A BREATHER",25,WHITE,true)
		if finished:
			_center(387,time_text(elapsed),43,GOLD,true)
			_center(420,"%d falls   ·   5 checkpoints   ·   One excellent cube" % falls,13,SUBTLE)
		else:
			_center(382,"Your timer and the islands are paused.",15,SUBTLE)
			_center(414,"Tab views the full map. Backspace retries this section.",12,SUBTLE)
		_panel(Rect2(462,453,356,49),MINT,12)
		_center(485,"RUN AGAIN  /  ENTER" if finished else "KEEP GOING  /  ESC",16,INK,true)
		_center(534,"R  ·  Start a fresh run",12,SUBTLE)
	if muted: _text(Vector2(1155,768),"SOUND OFF",10,INK)

func _draw_map() -> void:
	_panel(Rect2(474,24,332,66),Color(0.12,0.21,0.28,0.9))
	_center(50,"THE COMPLETE JOURNEY",14,WHITE,true)
	_center(73,"6 chapters  /  5 saves  /  1 lighthouse",11,SUBTLE)
	_panel(Rect2(24,116,206,230),Color(0.12,0.21,0.28,0.9))
	_text(Vector2(42,142),"FOLLOW THE ISLANDS",11,MINT,true)
	for i in CHAPTERS.size():
		var y: float = 171+i*27
		draw_circle(Vector2(47,y-4),8,MINT if i<=checkpoint else Color("476277"))
		_text(Vector2(44,y),str(i+1),10,INK if i<=checkpoint else WHITE,true)
		_text(Vector2(64,y),CHAPTERS[i],10,WHITE if i<=checkpoint else SUBTLE,i==checkpoint)
	for i in map_markers.size():
		var p := map_markers[i]
		if p.x<12 or p.x>1268 or p.y<12 or p.y>788: continue
		draw_circle(p+Vector2(0,2),13,Color(0.06,0.12,0.17,0.4))
		draw_circle(p,12,MINT if i<=checkpoint else WHITE)
		_text(p+Vector2(-4,5),str(i+1),14,INK,true)
	if finish_marker.x>=0:
		_panel(Rect2(finish_marker.x-36,finish_marker.y-11,72,22),GOLD,7)
		_text(finish_marker+Vector2(-25,4),"FINISH",11,INK,true)
	_panel(Rect2(409,748,462,30),Color(0.12,0.21,0.28,0.91),10)
	_center(768,"TAB / ESC   Return to the journey     ·     Timer paused",12)

func _gui_input(event: InputEvent) -> void:
	if map_view: return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position*Vector2(1280,800)/size
		if Rect2(462,453,356,49).has_point(p):
			if finished: restart_requested.emit()
			elif paused: resume_requested.emit()
