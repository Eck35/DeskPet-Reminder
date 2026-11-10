extends Control

signal work_confirmed(work_minutes: float, rest_minutes: float)

var _follow_target: Node2D
var _follow_offset := Vector2.ZERO

#记录颜色状态
var _is_pink_unlocked_ui = false
var _current_skin_ui = "default"

func _ready() -> void:
	$Panel/SettingContent/work_btn.pressed.connect(_on_work_btn_pressed)
	$Panel/SettingContent/rest_btn.pressed.connect(_on_rest_btn_pressed)
	$Panel/ShopContent/back_btn.pressed.connect(_on_back_btn_pressed)
	$Panel/ShopContent.hide()
	_follow_target = get_parent().get_node_or_null("Character") as Node2D
	_capture_follow_offset.call_deferred()

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
	#数据刷新
	var main = get_parent()
	refresh_shop_ui(main.star_count, main.is_pink_unlocked, main.current_skin)

func _on_back_btn_pressed() -> void:
	$Panel/ShopContent.hide()
	$Panel/SettingContent.show()

func set_star_count(stars: int) -> void:
	var text := "⭐ ： " + str(stars)
	$Panel/SettingContent/StarLabel.text = text
	$Panel/ShopContent/StarLabel.text = text

#刷新
func refresh_shop_ui(stars: int, is_pink_unlocked: bool, current_skin: String) -> void:
	_is_pink_unlocked_ui = is_pink_unlocked
	_current_skin_ui = current_skin
	set_star_count(stars)

	$Panel/ShopContent/HBoxContainer/white/check.visible = (current_skin == "default")
	$Panel/ShopContent/HBoxContainer/pink/check.visible = (current_skin == "pink")
	$Panel/ShopContent/HBoxContainer/pink/lock.visible = not is_pink_unlocked

func _on_pink_pressed() -> void:
	var main = get_parent()
	main.buy_or_equip_skin("pink")
	refresh_shop_ui(main.star_count, main.is_pink_unlocked, main.current_skin)


func _on_white_pressed() -> void:
	var main = get_parent()
	main.buy_or_equip_skin("default")
	refresh_shop_ui(main.star_count, main.is_pink_unlocked, main.current_skin)
