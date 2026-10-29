extends Control

@onready var work_timer = $WorkTimer
@onready var reminder_timer = $ReminderTimer
@onready var rest_timer = $RestTimer
var planned_rest_minutes = 5
var current_log_file = ""

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
	#日志文件生成
	var t = Time.get_datetime_dict_from_system()
	current_log_file = "Log_%04d%02d%02d_%02d%02d%02d.txt" % [t.year, t.month, t.day, t.hour, t.minute, t.second]
	
	#工作按钮
	var start_btn = $SettingPanel/Panel/work_btn
	var rest_btn =  $SettingPanel/Panel/rest_btn
	start_btn.pressed.connect(_on_start_button_pressed)	
	rest_btn.pressed.connect(_on_exit_button_pressed)
	rest_timer.timeout.connect(_on_rest_timer_timeout)
	reminder_timer.timeout.connect(_on_reminder_timer_timeout)
	
	# 让窗口背景透明
	get_tree().root.transparent_bg = true
	get_window().transparent = true
	
	# 绑定退出快捷键 
	if not InputMap.has_action("quit"):
		InputMap.add_action("quit")
		var key_event = InputEventKey.new()
		key_event.keycode = KEY_ESCAPE 
		InputMap.action_add_event("quit", key_event)
		
	# 自动播放待机动画
	$Character/人物本体.play("default")
	$Character/设置气泡.play("default")
	
	#连接计时器
	$WorkTimer.timeout.connect(_on_work_timer_timeout)
	$UITimer.timeout.connect(_on_ui_timer_timeout)


# ============提醒相关==============
func start_reminder_timer():
	reminder_timer.start(30.0)

func stop_reminder_timer():
	reminder_timer.stop()

func _on_reminder_timer_timeout():
	reminder_timer.stop() 
	if $Character.is_waiting_for_choice:
		write_log("超时未选择")
		print("超时未选择")
		$Character.cancel_reminder()
		$UITimer.stop() 
	elif $Character.is_waiting_for_work_choice:
		$Character.cancel_rest_finished()
	
# 开始工作
func _on_start_button_pressed():
	$SettingPanel.hide()
	var work_minutes = $SettingPanel/Panel/Label1/SpinBox1.value
	var rest_minutes = $SettingPanel/Panel/Label2/SpinBox2.value
	
	# 重置计时器
	rest_timer.stop()
	reminder_timer.stop()
	
	$WorkTimer.wait_time = work_minutes * 60
	$WorkTimer.start()
	$UITimer.start()
	write_log("开始工作！已设置工作时间：%s分钟，休息时间：%s分钟" % [work_minutes, rest_minutes])
	print("开始工作！,已设置工作时间：",work_minutes,"休息时间：",rest_minutes)

func _on_exit_button_pressed():
	$SettingPanel.hide()
	print("关闭面板")
	
func _on_work_timer_timeout():
	$Character.start_tried_reminder()
	write_log("休息时间到")
	print("叮！时间到！该休息了！")
	$UITimer.stop()

# 进入休息
func start_rest_timer():
	#重置计时器
	work_timer.stop()
	reminder_timer.stop()
	
	# 获取时长
	planned_rest_minutes = $SettingPanel/Panel/Label2/SpinBox2.value
	rest_timer.start(planned_rest_minutes * 60)
	$UITimer.start()

func _on_rest_timer_timeout():
	#关闭计时器
	rest_timer.stop()
	$UITimer.stop()
	
	# 休息结束！
	$DarkOverlay.hide()
	$Character/休息框.hide()
	$Character.reset_light_state()
	
	$Character.show_rest_finished_bubble()

# --- 重新开始工作 ---
func start_work_timer_again():
	rest_timer.stop()
	reminder_timer.stop()
	
	var work_minutes = $SettingPanel/Panel/Label1/SpinBox1.value
	work_timer.wait_time = work_minutes * 60
	work_timer.start()
	$UITimer.start()
	$Character/人物本体.play("default")
	write_log("选择继续工作！")
	print("再次开始工作！")
	
	
# 全局按键监听（用于快捷键退出）
func _unhandled_input(event):
	# 如果是键盘按键，并且是按下状态，并且按的是 ESC
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()

func _on_ui_timer_timeout() -> void:
	var left_time = 0
	
	# 如果工作计时器在跑，显示工作时间
	if not work_timer.is_stopped():
		left_time = work_timer.time_left
	# 如果休息计时器在跑，显示休息时间
	elif not rest_timer.is_stopped():
		left_time = rest_timer.time_left
		
	if left_time > 0:
		var m = int(left_time) / 60
		var s = int(left_time) % 60
		var time_str = "%02d:%02d" % [m, s]
		$Character/TimerBubble/TimeLabel.text = time_str
