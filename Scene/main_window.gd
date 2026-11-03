extends Control

@onready var work_timer = $WorkTimer
@onready var reminder_timer = $ReminderTimer
@onready var rest_timer = $RestTimer
var planned_rest_minutes = 5
var current_log_file = ""

# ================= 桌面穿透 系统 =================
const REGION_PADDING := 8.0  # 窗口区域在 UI 外的留边
var _passthrough_api = null
var _dim_window: Window
var _dim_rect: ColorRect
var _last_region_polygon := PackedVector2Array()
var _region_ready := false

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
	
	# 连接信号（面板内部按钮由 setting_panel.gd 处理）
	$SettingPanel.work_confirmed.connect(_on_work_confirmed)
	rest_timer.timeout.connect(_on_rest_timer_timeout)
	reminder_timer.timeout.connect(_on_reminder_timer_timeout)
	
	# 透明设置
	get_tree().root.transparent_bg = true
	get_window().transparent = true

	# 旧的黑幕节点不再使用，黑幕改由独立的全屏窗口显示
	var old_overlay := get_node_or_null("DarkOverlay") as CanvasItem
	if old_overlay != null:
		old_overlay.hide()
	
	# 快捷键
	if not InputMap.has_action("quit"):
		InputMap.add_action("quit")
		var key_event = InputEventKey.new()
		key_event.keycode = KEY_ESCAPE 
		InputMap.action_add_event("quit", key_event)
		
	$Character/人物本体.play("default")

	# ⚠️ 初始化穿透插件
	_passthrough_api = Engine.get_singleton("MousePassthrough") if Engine.has_singleton("MousePassthrough") else null
	if _passthrough_api == null:
		push_warning("MousePassthrough 插件未加载，独立黑幕窗口不会启用")
	_create_dim_window()  # 独立全屏黑幕窗口（常驻、点击穿透）
	_update_window_region.call_deferred()  # 主窗口按 UI 区域裁剪

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

#================ 设置面板回调 =============
func prepare_work_start() -> void:
	set_dim(false)
	$Character/休息框.hide()

func _on_work_confirmed(work_minutes: float, rest_minutes: float) -> void:
	rest_timer.stop()
	reminder_timer.stop()
	$WorkTimer.wait_time = work_minutes * 60
	$WorkTimer.start()
	$UITimer.start()
	write_log("开始工作！工作时间：%s分钟，休息时间：%s分钟" % [work_minutes, rest_minutes])
	if $SettingPanel.is_idle_animation_enabled():
		$Character/人物本体.play("default")
	else:
		$Character/人物本体.animation = "default"
		$Character/人物本体.frame = 0
		$Character/人物本体.stop()

func _on_work_timer_timeout():
	$Character.start_tried_reminder()
	write_log("休息时间到！")
	$UITimer.stop()
	set_dim(true) # 屏幕变暗提醒

func start_rest_timer():
	work_timer.stop()
	reminder_timer.stop()
	planned_rest_minutes = $SettingPanel.get_rest_minutes()
	if planned_rest_minutes == -1.0: planned_rest_minutes = 15.0
	rest_timer.start(planned_rest_minutes * 60)
	$UITimer.start()

func _on_rest_timer_timeout():
	rest_timer.stop()
	$UITimer.stop()
	set_dim(false)
	$Character/休息框.hide()
	$Character.reset_light_state()
	$Character.show_rest_finished_bubble()

func start_work_timer_again():
	rest_timer.stop()
	reminder_timer.stop()
	var work_minutes = $SettingPanel.get_work_minutes()
	if work_minutes == -1.0: work_minutes = 45.0
	work_timer.wait_time = work_minutes * 60
	work_timer.start()
	$UITimer.start()
	if $SettingPanel.is_idle_animation_enabled():
		$Character/人物本体.play("default")
	else:
		$Character/人物本体.animation = "default"
		$Character/人物本体.frame = 0
		$Character/人物本体.stop()
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

# ================= 关灯黑幕（独立全屏窗口） =================
func _create_dim_window() -> void:
	# 没有穿透插件时不创建独立黑幕，避免全屏窗口挡住所有点击
	if _passthrough_api == null:
		return

	var dim_color := Color(0.49, 0.46501, 0.4018, 0.352941)
	var old_overlay := get_node_or_null("DarkOverlay") as ColorRect
	if old_overlay != null:
		dim_color = old_overlay.color

	var screen := DisplayServer.window_get_current_screen()
	var screen_pos := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)

	_dim_window = Window.new()
	_dim_window.name = "DimWindow"
	_dim_window.visible = false
	# 确保是独立原生窗口，避免被嵌入主窗口
	if _dim_window.get("force_native") != null:
		_dim_window.set("force_native", true)
	_dim_window.set_flag(Window.FLAG_BORDERLESS, true)
	_dim_window.set_flag(Window.FLAG_ALWAYS_ON_TOP, true)
	_dim_window.set_flag(Window.FLAG_TRANSPARENT, true)
	_dim_window.set_flag(Window.FLAG_NO_FOCUS, true)
	_dim_window.transparent_bg = true
	_dim_window.position = screen_pos
	_dim_window.size = screen_size

	_dim_rect = ColorRect.new()
	_dim_rect.name = "DimRect"
	_dim_rect.color = dim_color
	_dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_rect.visible = false
	_dim_window.add_child(_dim_rect)
	_dim_rect.position = Vector2.ZERO
	_dim_rect.size = Vector2(screen_size)

	add_child(_dim_window)
	_dim_window.show()
	_setup_dim_passthrough()

func _setup_dim_passthrough() -> void:
	# 显示窗口后原生句柄才会出现，等它准备好再设置穿透
	for i in 10:
		if _dim_window == null:
			return
		var handle := DisplayServer.window_get_native_handle(
			DisplayServer.WINDOW_HANDLE, _dim_window.get_window_id()
		)
		if handle != 0:
			_passthrough_api.set_passthrough(_dim_window.get_window_id(), true)
			return
		await get_tree().process_frame
	# 设置失败就关掉黑幕窗口，避免它挡住整个桌面
	push_warning("黑幕窗口穿透设置失败，已禁用黑幕窗口")
	_dim_window.hide()
	_dim_window.queue_free()
	_dim_window = null
	_dim_rect = null

func set_dim(enabled: bool) -> void:
	if _dim_window != null and _dim_rect != null:
		_dim_rect.visible = enabled
		return
	# 插件不可用时退回窗口内的旧黑幕
	var old_overlay := get_node_or_null("DarkOverlay") as ColorRect
	if old_overlay != null:
		old_overlay.visible = enabled

func is_dim_visible() -> bool:
	if _dim_window != null and _dim_rect != null:
		return _dim_rect.visible
	var old_overlay := get_node_or_null("DarkOverlay") as ColorRect
	return old_overlay != null and old_overlay.visible

# ================= 静态窗口穿透区域 =================
func _process(_delta: float) -> void:
	_update_window_region()

func _update_window_region() -> void:
	# 插件不可用时保持旧黑幕兜底，不裁剪窗口
	if _passthrough_api == null:
		return

	# 内嵌弹窗（比如导出日志的 FileDialog）打开时，临时取消区域裁剪
	for node in find_children("*", "Window", true, false):
		var w := node as Window
		if w != null and w != _dim_window and w.visible and w.is_embedded():
			_set_region_polygon(PackedVector2Array())
			return

	var bounds := _get_ui_region_rect()
	if bounds.size == Vector2.ZERO:
		_set_region_polygon(PackedVector2Array())
		return
	_set_region_polygon(PackedVector2Array([
		bounds.position,
		Vector2(bounds.end.x, bounds.position.y),
		bounds.end,
		Vector2(bounds.position.x, bounds.end.y),
	]))

func _set_region_polygon(polygon: PackedVector2Array) -> void:
	if _region_ready and polygon == _last_region_polygon:
		return
	_last_region_polygon = polygon
	_region_ready = true
	get_window().set_mouse_passthrough_polygon(polygon)

func _get_ui_region_rect() -> Rect2:
	var bounds := Rect2()
	var has_bounds := false
	for rect in _get_interactive_rects():
		if rect.size == Vector2.ZERO:
			continue
		if not has_bounds:
			bounds = rect
			has_bounds = true
		else:
			bounds = bounds.merge(rect)
	if not has_bounds:
		return Rect2()
	bounds = bounds.grow(REGION_PADDING)
	var window_rect := Rect2(Vector2.ZERO, Vector2(get_window().size))
	return bounds.intersection(window_rect)

func _get_interactive_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var ch: Node = $Character

	# 人物本体：碰撞框 + 所有动画帧的可见范围
	var body_shape = ch.get_node_or_null("人物本体/Area2D/CollisionShape2D") as CollisionShape2D
	if body_shape:
		rects.append(shape_rect(body_shape))
	var body_sprite = ch.get_node_or_null("人物本体") as AnimatedSprite2D
	if body_sprite:
		rects.append(animated_sprite_rect(body_sprite))

	# 设置气泡：区域始终包含，避免悬停显隐导致窗口区域频繁变化
	var icon_shape = ch.get_node_or_null("设置气泡/Area2D_2/CollisionShape2D") as CollisionShape2D
	if icon_shape:
		rects.append(shape_rect(icon_shape))
	var icon_sprite = ch.get_node_or_null("设置气泡") as AnimatedSprite2D
	if icon_sprite:
		rects.append(animated_sprite_rect(icon_sprite))

	# 计时气泡：始终包含，避免拖动时窗口区域变化
	var tb_sprite = ch.get_node_or_null("TimerBubble/Sprite2D") as Sprite2D
	if tb_sprite:
		rects.append(sprite_rect(tb_sprite))
	var tb_label = ch.get_node_or_null("TimerBubble/TimeLabel") as Control
	if tb_label:
		rects.append(control_rect(tb_label))

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

func animated_sprite_rect(sprite: AnimatedSprite2D) -> Rect2:
	if sprite == null or sprite.sprite_frames == null:
		return Rect2()
	var bounds := Rect2()
	var has_bounds := false
	for anim in sprite.sprite_frames.get_animation_names():
		for i in sprite.sprite_frames.get_frame_count(anim):
			var tex := sprite.sprite_frames.get_frame_texture(anim, i)
			if tex == null:
				continue
			var tex_size := tex.get_size()
			var rect: Rect2
			if sprite.centered:
				rect = Rect2(-tex_size / 2.0 + sprite.offset, tex_size)
			else:
				rect = Rect2(sprite.offset, tex_size)
			if not has_bounds:
				bounds = rect
				has_bounds = true
			else:
				bounds = bounds.merge(rect)
	if not has_bounds:
		return Rect2()
	return local_rect_to_viewport(sprite, bounds)

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
