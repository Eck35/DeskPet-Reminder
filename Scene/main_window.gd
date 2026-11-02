extends Control

@onready var work_timer = $WorkTimer
@onready var reminder_timer = $ReminderTimer
@onready var rest_timer = $RestTimer
var planned_rest_minutes = 5
var current_log_file = ""

# ================= 桌面穿透 系统 =================
const HIT_MARGIN := 6.0  # 容错边界，防止边缘抖动
var _passthrough_api = null
var _passthrough_active := false

#=====导出日志======
func write_log(content: String):
	var t = Time.get_datetime_dict_from_system()
	var time_str = "[%02d:%02d:%02d] " % [t.hour, t.minute, t.second]
	var path = "user://" + current_log_file 
	var file = FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.seek_end() 
		file.store_line(time_str + content)
		file.close()

func _ready():
	# 根 Control 不接收鼠标，否则会抢掉人物 Area2D 的点击
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 确保 Area2D 的点击检测开启
	get_viewport().physics_object_picking = true

	# 初始化日志文件名
	var t = Time.get_datetime_dict_from_system()
	current_log_file = "Log_%04d%02d%02d_%02d%02d%02d.txt" % [t.year, t.month, t.day, t.hour, t.minute, t.second]
	
	# 连接信号
	var start_btn = $SettingPanel/Panel/work_btn
	var rest_btn =  $SettingPanel/Panel/rest_btn
	start_btn.pressed.connect(_on_start_button_pressed)	
	rest_btn.pressed.connect(_on_exit_button_pressed)
	rest_timer.timeout.connect(_on_rest_timer_timeout)
	reminder_timer.timeout.connect(_on_reminder_timer_timeout)
	
	# 透明设置
	get_tree().root.transparent_bg = true
	get_window().transparent = true

	# 黑幕铺满整个窗口，并画在人物背后（不压暗小人）
	$DarkOverlay.z_index = -1
	get_window().size_changed.connect(_fit_dark_overlay)
	_fit_dark_overlay.call_deferred()
	
	# 快捷键
	if not InputMap.has_action("quit"):
		InputMap.add_action("quit")
		var key_event = InputEventKey.new()
		key_event.keycode = KEY_ESCAPE 
		InputMap.action_add_event("quit", key_event)
		
	$Character/人物本体.play("default")

	# 记录面板相对人物的初始位置（以场景里的布局为准）
	_panel_offset = $SettingPanel.global_position - $Character.global_position

	# ⚠️ 初始化穿透插件
	_passthrough_api = Engine.get_singleton("MousePassthrough") if Engine.has_singleton("MousePassthrough") else null
	if _passthrough_api == null:
		push_warning("MousePassthrough 插件未加载，桌面穿透不会生效")
	_set_passthrough(true) # 开局默认穿透

# ================= 计时器调度 =================
func start_reminder_timer():
	reminder_timer.start(30.0)

func stop_reminder_timer():
	reminder_timer.stop()

func _on_reminder_timer_timeout():
	reminder_timer.stop() 
	if $Character.is_waiting_for_choice:
		write_log("超时未选择")
		$Character.cancel_reminder()
		$UITimer.stop() 
	elif $Character.is_waiting_for_work_choice:
		$Character.cancel_rest_finished()

#检测输入是否合法
func get_valid_time(line_edit: LineEdit, default_val: float) -> float:
	var text = line_edit.text.strip_edges()
	if text == "":
		return default_val
		
	if not text.is_valid_float():
		return -1.0
		
	var val = float(text)
	if val <= 0:
		return -1.0
	
	return val
	
func _on_start_button_pressed():
	var work_minutes = get_valid_time($SettingPanel/Panel/Label1/SpinBox1,45)
	var rest_minutes = get_valid_time($SettingPanel/Panel/Label2/SpinBox2,15)

	#报错显示
	if work_minutes == -1.0 or rest_minutes == -1.0:
		print("检测到无效输入")
		$SettingPanel/Panel/ErrorLabel.show()
		return 
		
	$SettingPanel/Panel/ErrorLabel.hide()
	$SettingPanel.hide()
	rest_timer.stop()
	reminder_timer.stop()
	$WorkTimer.wait_time = work_minutes * 60
	$WorkTimer.start()
	$UITimer.start()
	write_log("开始工作！工作时间：%s分钟，休息时间：%s分钟" % [work_minutes, rest_minutes])

func _on_exit_button_pressed():
	$SettingPanel.hide()

func _on_work_timer_timeout():
	$Character.start_tried_reminder()
	write_log("休息时间到")
	$UITimer.stop()
	$DarkOverlay.show()#屏幕变暗提醒

func start_rest_timer():
	work_timer.stop()
	reminder_timer.stop()
	planned_rest_minutes = get_valid_time($SettingPanel/Panel/Label2/SpinBox2, 15)
	if planned_rest_minutes == -1.0: planned_rest_minutes = 15 
	rest_timer.start(planned_rest_minutes * 60)
	$UITimer.start()

func _on_rest_timer_timeout():
	rest_timer.stop()
	$UITimer.stop()
	$DarkOverlay.hide()
	$Character/休息框.hide()
	$Character.reset_light_state()
	$Character.show_rest_finished_bubble()

func start_work_timer_again():
	rest_timer.stop()
	reminder_timer.stop()
	var work_minutes = get_valid_time($SettingPanel/Panel/Label1/SpinBox1,45)
	if work_minutes == -1.0: work_minutes = 45
	work_timer.wait_time = work_minutes * 60
	work_timer.start()
	$UITimer.start()
	$Character/人物本体.play("default")
	write_log("选择继续工作！")

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()

func _on_ui_timer_timeout() -> void:
	var left_time = 0
	if not work_timer.is_stopped():
		left_time = work_timer.time_left
	elif not rest_timer.is_stopped():
		left_time = rest_timer.time_left
	if left_time > 0:
		var m = int(left_time) / 60
		var s = int(left_time) % 60
		$Character/TimerBubble/TimeLabel.text = "%02d:%02d" % [m, s]

# ================= 关灯黑幕 =================
func _fit_dark_overlay() -> void:
	$DarkOverlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	$DarkOverlay.global_position = Vector2.ZERO
	$DarkOverlay.size = get_viewport().get_visible_rect().size

# ================= 设置面板跟随 =================
var _panel_offset := Vector2.ZERO

# ================= 桌面穿透 (每帧 AABB 检测) =================
func _process(_delta: float) -> void:
	# 设置面板保持在人物旁边的相对位置
	if $SettingPanel.visible:
		$SettingPanel.global_position = $Character.global_position + _panel_offset
	_update_passthrough()

func _update_passthrough() -> void:
	var want := not _mouse_on_interactive_ui()
	if want != _passthrough_active:
		_set_passthrough(want)

func _set_passthrough(enabled: bool) -> void:
	_passthrough_active = enabled
	if _passthrough_api != null:
		_passthrough_api.set_passthrough(get_window().get_window_id(), enabled)

func _mouse_on_interactive_ui() -> bool:
	# 1. 拖拽中必须始终能接收鼠标
	if $Character.is_dragging:
		return true

	# 2. 弹窗打开时先整窗接收鼠标
	for node in find_children("*", "Window", true, false):
		var w := node as Window
		if w != null and w.visible and w.is_embedded():
			return true

	# 3. 遍历所有活跃的 UI 框，看鼠标在不在里面
	var mouse := mouse_pos_in_viewport()
	for rect in _get_interactive_rects():
		if rect.size == Vector2.ZERO:
			continue
		if rect.grow(HIT_MARGIN).has_point(mouse):
			return true
	return false

func _get_interactive_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var ch: Node = $Character

	# 人物本体碰撞框
	var body_shape = ch.get_node_or_null("人物本体/Area2D/CollisionShape2D") as CollisionShape2D
	if body_shape: 
		rects.append(shape_rect(body_shape))

	# 设置气泡碰撞框
	var icon = ch.get_node_or_null("设置气泡") as CanvasItem
	if icon and icon.is_visible_in_tree():
		var icon_shape = ch.get_node_or_null("设置气泡/Area2D_2/CollisionShape2D") as CollisionShape2D
		if icon_shape: rects.append(shape_rect(icon_shape))

	# 计时气泡
	var timer_bubble := ch.get_node_or_null("TimerBubble") as CanvasItem
	if timer_bubble and timer_bubble.is_visible_in_tree():
		var tb_sprite = ch.get_node_or_null("TimerBubble/Sprite2D") as Sprite2D
		if tb_sprite: rects.append(sprite_rect(tb_sprite))

	# 各种提醒框（气泡底图 + 里面所有UI控件）
	for path in ["休息提醒", "工作提醒", "休息框"]:
		var bubble_node = ch.get_node_or_null(path) as CanvasItem
		if bubble_node and bubble_node.is_visible_in_tree():
			var bubble_sprite = ch.get_node_or_null(path + "/Sprite2D") as Sprite2D
			if bubble_sprite:
				rects.append(sprite_rect(bubble_sprite))
				for child in bubble_sprite.get_children():
					var c := child as Control
					if c and c.is_visible_in_tree():
						rects.append(control_rect(c))

	# 设置面板
	if $SettingPanel.visible:
		var panel = $SettingPanel.get_node_or_null("Panel") as Control
		if panel: rects.append(control_rect(panel))

	return rects

# 坐标计算辅助函数
func mouse_pos_in_viewport() -> Vector2:
	var win := get_window()
	var pos := Vector2(DisplayServer.mouse_get_position() - win.position)
	var win_size := Vector2(win.size)
	var view_size := get_viewport().get_visible_rect().size
	if win_size.x > 0.0 and win_size.y > 0.0:
		pos *= view_size / win_size
	return pos

func shape_rect(shape_node: CollisionShape2D) -> Rect2:
	if shape_node == null: return Rect2()
	var rect_shape := shape_node.shape as RectangleShape2D
	if rect_shape == null: return Rect2()
	return local_rect_to_viewport(shape_node, rect_shape.get_rect())

func sprite_rect(sprite: Sprite2D) -> Rect2:
	if sprite == null: return Rect2()
	return local_rect_to_viewport(sprite, sprite.get_rect())

func control_rect(control: Control) -> Rect2:
	if control == null: return Rect2()
	return local_rect_to_viewport(control, Rect2(Vector2.ZERO, control.size))

func local_rect_to_viewport(item: CanvasItem, local_rect: Rect2) -> Rect2:
	var xf := item.get_global_transform_with_canvas()
	var p0 := xf * local_rect.position
	var p1 := xf * Vector2(local_rect.end.x, local_rect.position.y)
	var p2 := xf * local_rect.end
	var p3 := xf * Vector2(local_rect.position.x, local_rect.end.y)
	var mn := p0.min(p1).min(p2).min(p3)
	var mx := p0.max(p1).max(p2).max(p3)
	return Rect2(mn, mx - mn)
