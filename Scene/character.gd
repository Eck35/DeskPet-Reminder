extends Node2D 

# 记录鼠标上一帧的位置
var drag_offset = Vector2.ZERO
var is_dragging = false

#鼠标悬停
var is_hovering_pet = false
var is_hovering_icon = false
var hide_timer = 0.0

@onready var icon_area = $"设置气泡"

func _on_area_2d_input_event(viewport, event, shape_idx):
	# 监听左键按下
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			drag_offset = get_window().position - DisplayServer.mouse_get_position()
			
			#添加点击显示计时器 (同时判断工作和休息)
			var main = get_parent()
			if main.get_node("WorkTimer").time_left > 0 or main.get_node("RestTimer").time_left > 0:
				$TimerBubble.show()
				
		else:
			is_dragging = false
			if $TimerBubble.visible:
				await get_tree().create_timer(1).timeout
				$TimerBubble.hide()
		
func _process(delta):
	if is_dragging:
		var current_mouse_pos = DisplayServer.mouse_get_position()
		get_window().position = current_mouse_pos + drag_offset

	if not is_hovering_pet and not is_hovering_icon and icon_area.visible:
		hide_timer -= delta
		if hide_timer <= 0:
			icon_area.hide()

func _on_area_2d_mouse_entered() -> void:
	is_hovering_pet = true
	icon_area.show()

func _on_area_2d_mouse_exited() -> void:
	is_hovering_pet = false
	hide_timer = 0.1

func _on_area_2d_2_mouse_entered() -> void:
	is_hovering_icon = true
	icon_area.show()

func _on_area_2d_2_mouse_exited() -> void:
	is_hovering_icon = false
	hide_timer = 0.1

func _on_area_2d_2_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_parent().get_node("SettingPanel").show()
		icon_area.hide()

# ================= 提醒休息时间到 =================

var is_waiting_for_choice = false
func start_tried_reminder():
	$"人物本体".play('jump')
	$"休息提醒".show()
	is_waiting_for_choice = true # 💡 每次必须重置状态
	get_parent().start_reminder_timer()

func _on_yes_btn_pressed() -> void:
	is_waiting_for_choice = false
	get_parent().stop_reminder_timer() 
	$"休息提醒".hide()
	
	# 进入休息环节
	print("休息！")
	get_parent().write_log("休息时间到！")
	$"人物本体".play("default")
	$"休息框".show()
	get_parent().start_rest_timer()

func _on_no_btn_pressed() -> void:
	get_parent().write_log("选择了不休息")
	print("不休息啊。")
	is_waiting_for_choice = false
	get_parent().stop_reminder_timer()
	cancel_reminder()
	#重置工作计时
	get_parent().get_node("UITimer").start()
	
func cancel_reminder():
	is_waiting_for_choice = false
	$"休息提醒".hide()
	$"人物本体".play("default")


# ================= 休息框内的动作 =================

var is_light_off = false	

func _on_关灯_pressed() -> void:
	get_parent().write_log("选择关灯")
	var main = get_parent()
	var overlay = main.get_node("DarkOverlay")
	
	# 💡 修复：用屏幕实际是否可见来判断状态，不再用 ! 取反，防止状态错乱
	is_light_off = not overlay.visible 
	
	if is_light_off:
		$休息框/Sprite2D/关灯.text = "开灯"
		overlay.show()
		$人物本体.play("light_off") 
	else:
		$休息框/Sprite2D/关灯.text = "关灯"
		overlay.hide()
		$人物本体.play("light_on")

func _on_人物本体_animation_finished() -> void:
	var current_anim = $"人物本体".animation
	# 排除掉 default 和一些可能常驻的动画
	if current_anim != "default":
		$"人物本体".play("default")
		$"休息框/Sprite2D/Label".text="休息时间，该做些什么呢？"	
		

func _on_走_pressed() -> void:
	get_parent().write_log("选择走一走")
	print("走一走！")
	$"休息框/Sprite2D/Label".text="工作了这么久，起身走走吧！"	
	$"人物本体".play("run")

func _on_看_pressed() -> void:
	get_parent().write_log("选择看一看")
	print("看一看！")
	$"休息框/Sprite2D/Label".text="眺望远方，放松一下眼睛吧！"	
	$"人物本体".play("look")

func _on_揉_pressed() -> void:
	get_parent().write_log("选择眼保健操")
	$"休息框/Sprite2D/Label".text="做个眼保健操，缓解眼睛疲劳！"	
	print("揉揉眼！")
	$"人物本体".play("eye")


# ================= 休息时间结束的工作提醒 =================

var is_waiting_for_work_choice = false

func show_rest_finished_bubble():
	$"人物本体".play("jump")
	$"休息框".hide()
	$"工作提醒".show()
	is_waiting_for_work_choice = true
	get_parent().start_reminder_timer()

func _on_yes_btn_2_pressed() -> void:
	get_parent().write_log("用户开启工作！")
	print("开始工作！")
	is_waiting_for_work_choice = false
	get_parent().stop_reminder_timer()
	$"工作提醒".hide()
	get_parent().start_work_timer_again()

func _on_no_btn_2_pressed() -> void:
	get_parent().write_log("用户继续休息！")
	print("继续休息！")
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
	print("没有做出选择呢！超时回到待机")
	
#重置开关灯状态
func reset_light_state():
	is_light_off = false
	$休息框/Sprite2D/关灯.text = "关灯"
