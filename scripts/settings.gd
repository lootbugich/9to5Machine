extends Control

func _on_volume_value_changed(value: float) -> void :
    AudioServer.set_bus_volume_db(0, value)

func _on_check_box_toggled(toggled_on: bool) -> void :
    AudioServer.set_bus_mute(0, toggled_on)

func _on_resolutions_item_selected(index: int) -> void :
    match index:
        0:
            DisplayServer.window_set_size(Vector2i(1152, 648))
        1:
            DisplayServer.window_set_size(Vector2i(1024, 576))
        2:
            DisplayServer.window_set_size(Vector2i(960, 540))
        3:
            DisplayServer.window_set_size(Vector2i(854, 480))
        4:
            DisplayServer.window_set_size(Vector2i(640, 480))

func _on_fullscreen_toggled(toggled_on: bool) -> void :
    if toggled_on == true:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
    else:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

func _on_fps_value_changed(value: float) -> void :
    var label_value = $Settings / Settings / FPS_title / FPS_value
    label_value.text = str(int(value))
    Engine.max_fps = value
