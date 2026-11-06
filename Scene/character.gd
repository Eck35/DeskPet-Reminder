extends Node2D 

var drag_offset = Vector2.ZERO
var is_dragging = false
var press_time = 0.0
var hide_timer = 0.0
@onready var icon_area = $"设置气泡"

func _on_area_2d_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_time = Time.get_ticks_msec()
			is_dragging = true
			drag_offset = get_window().position - DisplayServer.mouse_get_position()
			
		else:
			is_dragging = false
			var duration = Time.get_ticks_msec() - press_time
			#互动动画
			if duration < 200:
				if is_waiting_for_choice or is_waiting_for_work_choice:
					return 
				var current_anim = $"人物本体".animation
				if current_anim in ["eye", "run", "look", "light_off", "light_on", "jump","row"]:
					return 
				$"人物本体".play("hello")
				#显示倒计时
				var main = get_parent()
				if main.get_node("WorkTimer").time_left > 0 or main.get_node("RestTimer").time_left > 0:
					$TimerBubble.show()
					if $TimerBubble.visible:
						await get_tree().create_timer(1).timeout
						$TimerBubble.hide()
		
func _process(delta):
	var main = get_parent()
	if not main.has_method("mouse_pos_in_viewport"): return # 防报错保护
	
	var mouse = main.mouse_pos_in_viewport()
	
	# 获取本体的碰撞框检测悬停
	var body_shape = get_node_or_null("人物本体/Area2D/CollisionShape2D") as CollisionShape2D
	var icon_shape = get_node_or_null("设置气泡/Area2D_2/CollisionShape2D") as CollisionShape2D
	
	var on_body = main.shape_rect(body_shape).has_point(mouse) if body_shape else false
	var on_icon = main.shape_rect(icon_shape).has_point(mouse) if icon_shape else false

	# 悬停气泡显隐
	if on_body or on_icon:
		icon_area.show()
		hide_timer = 0.1
	elif hide_timer > 0:
		hide_timer -= delta
		if hide_timer <= 0 and icon_area.visible:
			icon_area.hide()
			
	#气泡随状态动态变化
	var is_working = main.get_node("WorkTimer").time_left > 0
	var is_resting = main.get_node("RestTimer").time_left > 0
	var current_text = "❓"
	
	if is_working:
		current_text = "💻"
	elif is_resting:
		current_text = "💤"
	if $设置气泡/Label.text != current_text:
		$设置气泡/Label.text = current_text
		
	# 拖拽整个窗口
	if is_dragging:
		get_window().position = DisplayServer.mouse_get_position() + drag_offset

# 点击图标打开设置面板（不需要再写穿透）
func _on_area_2d_2_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_parent().get_node("SettingPanel").show()
		icon_area.hide()

# ================= 提醒休息时间到 =================
var is_waiting_for_choice = false
func start_tried_reminder():
	$"人物本体".play('jump')
	$"休息提醒".show()
	is_waiting_for_choice = true 
	get_parent().start_reminder_timer()

func _on_yes_btn_pressed() -> void:
	print("选择了休息")
	get_parent().write_log("选择了休息")
	is_waiting_for_choice = false
	get_parent().stop_reminder_timer() 
	$"休息提醒".hide()
	$"人物本体".play("default")
	$"休息框".show()
	get_parent().start_rest_timer()
	is_light_off = true
	$"休息框/Sprite2D/buttons/关灯".text="开灯"

func _on_no_btn_pressed() -> void:
	get_parent().write_log("选择了继续工作")
	is_waiting_for_choice = false
	get_parent().stop_reminder_timer()
	cancel_reminder()
	get_parent().start_work_timer_again() 

func cancel_reminder():
	is_waiting_for_choice = false
	$"休息提醒".hide()
	$"人物本体".play("default")
	get_parent().set_dim(false)

# ================= 休息框内的动作 =================
var is_light_off = false	
func _on_关灯_pressed() -> void:
	get_parent().write_log("选择关灯")
	var main = get_parent()
	is_light_off = not main.is_dim_visible()
	if is_light_off:
		$"休息框/Sprite2D/buttons/关灯".text = "开灯"
		main.set_dim(true)
		$"人物本体".play("light_off")
	else:
		$"休息框/Sprite2D/buttons/关灯".text = "关灯"
		main.set_dim(false)
		$"人物本体".play("light_on")

func _on_人物本体_animation_finished() -> void:
	var current_anim = $"人物本体".animation
	if current_anim != "default":
		$"人物本体".play("default")
		$"休息框/Sprite2D/Label".text="小小的放松时间，你来选择:"	
		var panel = get_parent().get_node_or_null("SettingPanel")
		if panel != null:
			var want_anim = panel.is_idle_animation_enabled()
			if not want_anim and not $"休息框".visible:
				$"人物本体".stop()

func _on_走_pressed() -> void:
	get_parent().write_log("选择走一走")
	$"休息框/Sprite2D/Label".text="起来慢慢走一走，舒展紧绷的身体"	
	$"人物本体".play("run")

func _on_看_pressed() -> void:
	get_parent().write_log("选择看一看")
	$"休息框/Sprite2D/Label".text="望向窗外，让眼睛好好歇一歇"	
	$"人物本体".play("look")

func _on_揉_pressed() -> void:
	get_parent().write_log("选择按摩眼睛")
	$"休息框/Sprite2D/Label".text="轻轻揉揉眼周，赶走酸胀疲惫"	
	$"人物本体".play("eye")

func _on_活动_pressed() -> void:
	get_parent().write_log("选择按摩眼睛")
	$"休息框/Sprite2D/Label".text="转动双肩，把积攒的疲惫松一松"	
	$"人物本体".play("row")
	
# ================= 休息时间结束的工作提醒 =================
var is_waiting_for_work_choice = false
func show_rest_finished_bubble():
	$"人物本体".play("jump")
	$"休息框".hide()
	$"工作提醒".show()
	is_waiting_for_work_choice = true
	get_parent().start_reminder_timer()

func _on_yes_btn_2_pressed() -> void:
	get_parent().write_log("选择了开启工作！")
	is_waiting_for_work_choice = false
	get_parent().stop_reminder_timer()
	$"工作提醒".hide()
	#休息结束，发星
	var main = get_parent()
	if not main.cycle_rewarded:
		main.add_star()
		main.cycle_rewarded = true
		
	get_parent().start_work_timer_again()

func _on_no_btn_2_pressed() -> void:
	get_parent().write_log("选择了继续休息！")
	is_waiting_for_work_choice = false
	get_parent().stop_reminder_timer()
	$"工作提醒".hide()
	get_parent().start_rest_timer()
	$"休息框".show()
	$"人物本体".play("default")

func cancel_rest_finished():
	is_waiting_for_work_choice = false
	$"工作提醒".hide()
	$"人物本体".play("default")
	get_parent().write_log("超时未选择")

func reset_light_state():
	is_light_off = false
	$"休息框/Sprite2D/buttons/关灯".text = "关灯"
