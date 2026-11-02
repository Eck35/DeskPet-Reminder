extends Control

func _on_exit_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		hide() 

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
