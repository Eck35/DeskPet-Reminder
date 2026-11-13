extends Control

signal work_confirmed(work_minutes: float, rest_minutes: float)

var _follow_target: Node2D
var _follow_offset := Vector2.ZERO

#记录颜色状态
var _current_skin_ui = "white"

func _ready() -> void:
	$Panel/SettingContent/work_btn.pressed.connect(_on_work_btn_pressed)
	$Panel/rest_btn.pressed.connect(_on_rest_btn_pressed)
	$Panel/ShopContent/back_btn.pressed.connect(_on_back_btn_pressed)
	$Panel/ShopContent.hide()
	_follow_target = get_parent().get_node_or_null("Character") as Node2D
	_capture_follow_offset.call_deferred()
	call_deferred("_init_reward_ui")

func _init_reward_ui() -> void:
	var main = get_parent()
	$Panel/SettingContent/AnimToggle2.button_pressed = main.reward_enabled
	$Panel/SettingContent/Shop.visible = main.reward_enabled
	$Panel/SettingContent/StarLabel.visible = main.reward_enabled
	
func _process(_delta: float) -> void:
	if visible and _follow_target != null:
		global_position = _follow_target.global_position + _follow_offset

func _capture_follow_offset() -> void:
	if _follow_target != null:
		_follow_offset = global_position - _follow_target.global_position

# ================= 面板输入 =================
func get_work_minutes() -> float:
	return _get_valid_time($Panel/SettingContent/Label1/SpinBox1, 45.0)

func get_rest_minutes() -> float:
	return _get_valid_time($Panel/SettingContent/Label2/SpinBox2, 15.0)

func is_idle_animation_enabled() -> bool:
	return not $Panel/SettingContent/AnimToggle.button_pressed

func _get_valid_time(line_edit: LineEdit, default_val: float) -> float:
	var text := line_edit.text.strip_edges()
	if text == "":
		return default_val
	if not text.is_valid_float():
		return -1.0
	var val := float(text)
	if val <= 0:
		return -1.0
	return val

# ================= 按钮 =================
func _on_work_btn_pressed() -> void:
	get_parent().prepare_work_start()

	var work_minutes := get_work_minutes()
	var rest_minutes := get_rest_minutes()
	if work_minutes == -1.0 or rest_minutes == -1.0:
		print("检测到无效输入")
		$Panel/SettingContent/ErrorLabel.show()
		return

	$Panel/SettingContent/ErrorLabel.hide()
	hide()
	work_confirmed.emit(work_minutes, rest_minutes)

func _on_rest_btn_pressed() -> void:
	$Panel/ShopContent.hide()
	$Panel/SettingContent.show()
	hide()
				
# ================= 导出日志 =================
func _on_log_btn_pressed() -> void:
	var main = get_parent()
	var current_log_file = main.current_log_file
	var path = "user://" + current_log_file
	if not FileAccess.file_exists(path):
		return

	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.current_file = current_log_file

	dialog.file_selected.connect(func(target_path):
		var data = FileAccess.get_file_as_string(path)
		var dest = FileAccess.open(target_path, FileAccess.WRITE)
		if dest:
			dest.store_string(data)
			dest.close()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))


func _on_shop_pressed() -> void:
	$Panel/SettingContent.hide()
	$Panel/ShopContent.show()
	refresh_shop_ui()

func _on_back_btn_pressed() -> void:
	$Panel/ShopContent.hide()
	$Panel/SettingContent.show()

func set_star_count(stars: int) -> void:
	var text := "⭐ ： " + str(stars)
	$Panel/SettingContent/StarLabel.text = text
	$Panel/ShopContent/StarLabel.text = text


# 遍历主窗口里的皮肤字典，自动更新对应的锁和勾
func refresh_shop_ui() -> void:
	var main = get_parent()
	set_star_count(main.star_count)
	
	var container = $Panel/ShopContent/HBoxContainer
	
	# 直接遍历容器里的所有子节点
	for skin_node in container.get_children():
		var node_name = skin_node.name 
		
		# 如果这个名字在你的皮肤字典里存在
		if main.skin_data.has(node_name):
			# 更新勾号
			var check = skin_node.get_node_or_null("check")
			if check:
				check.visible = (main.current_skin == node_name)
				
			# 更新锁
			var lock = skin_node.get_node_or_null("lock")
			if lock:
				lock.visible = not main.skin_data[node_name]["unlocked"]


func _on_pink_pressed() -> void:
	var main = get_parent()
	main.buy_or_equip_skin("pink")
	refresh_shop_ui()

func _on_white_pressed() -> void:
	var main = get_parent()
	main.buy_or_equip_skin("white")
	refresh_shop_ui()


func _on_blue_pressed() -> void:
	var main = get_parent()
	main.buy_or_equip_skin("blue")
	refresh_shop_ui()

func _on_green_pressed() -> void:
	var main = get_parent()
	main.buy_or_equip_skin("green")
	refresh_shop_ui()

func _on_yellow_pressed() -> void:
	var main = get_parent()
	main.buy_or_equip_skin("yellow")
	refresh_shop_ui()

func _on_red_pressed() -> void:
	var main = get_parent()
	main.buy_or_equip_skin("red")
	refresh_shop_ui()

func _on_purple_pressed() -> void:
	var main = get_parent()
	main.buy_or_equip_skin("purple")
	refresh_shop_ui()
	
func _on_orange_pressed() -> void:
	var main = get_parent()
	main.buy_or_equip_skin("orange")
	refresh_shop_ui()

func _on_seablue_pressed() -> void:
	var main = get_parent()
	main.buy_or_equip_skin("seablue")
	refresh_shop_ui()
	
func _on_anim_toggle_2_toggled(toggled_on: bool) -> void:
	var main = get_parent()
	main.reward_enabled = toggled_on
	$Panel/SettingContent/Shop.visible = toggled_on
	$Panel/SettingContent/StarLabel.visible = toggled_on
	if not toggled_on:
		main.current_skin = "white"
		main.apply_skin()
		main.save_game()
	else:
		pass
