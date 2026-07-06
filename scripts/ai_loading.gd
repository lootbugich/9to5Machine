extends Control

@onready var status_label = $VBoxContainer / StatusLabel
@onready var progress_label = $VBoxContainer / ProgressLabel

var wait_for_continue: = false
var load_success: = false
var skip_available: = false
var skipped: = false

func _ready():
    status_label.text = "System Check..."
    progress_label.text = ""

    ai_host.progress_changed.connect(_on_progress_changed)
    ai_host.all_models_ready.connect(_on_all_ready)

    call_deferred("_begin_loading")

func _begin_loading():
    var ok = await ai_host.ensure_started()
    load_success = ok

    if not ok:
        status_label.text = "CRITICAL ERROR"
        progress_label.text = "Failed to start AI Engine. Press any key to exit."
        wait_for_continue = true
        return

    _start_skip_timer()

func _start_skip_timer():
    await get_tree().create_timer(20.0).timeout
    if not ai_host.all_ready and not skipped and load_success:
        skip_available = true
        if progress_label.text != "":
            progress_label.text += "\n[ Press 'S' to skip wait ]"

func _on_all_ready():
    status_label.text = "ALL SYSTEMS ONLINE"
    progress_label.text = "Press any key to play..."
    wait_for_continue = true

func _on_progress_changed(text: String, current: int, total: int):
    if wait_for_continue or skipped:
        return

    status_label.text = text

    if total == 100:
        progress_label.text = "Progress: " + str(current) + "%"
    elif total > 0:
        progress_label.text = "Status: " + str(current) + " of " + str(total) + " modules active"
    elif total == -1:
        progress_label.text = "Establishing connection..."
    else:
        progress_label.text = ""

func _unhandled_input(event):
    if not (event is InputEventKey and event.pressed and not event.echo):
        return

    if wait_for_continue:
        if load_success:
            get_tree().change_scene_to_file("res://scenes/game.tscn")
        else:
            get_tree().quit()

    elif skip_available and event.keycode == KEY_S:
        skipped = true
        status_label.text = "Loading in background..."
        progress_label.text = "Transitioning..."
        await get_tree().create_timer(1.0).timeout
        get_tree().change_scene_to_file("res://scenes/game.tscn")
        
func _input(event):
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
         get_tree().change_scene_to_file("res://scenes/menu.tscn")
