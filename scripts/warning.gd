extends Node2D

@onready var bs = $bs
@onready var start = $press

func _ready() -> void:
    start.text = "[pulse freq=1.0]Press ENTER to continue.[/pulse]"
    start.modulate.a = 0.0
    var tween = create_tween()
    tween.tween_property(bs, "modulate:a", 0.0, 1.0)
    tween.tween_interval(1.0)
    tween.tween_property(start, "modulate:a", 1.0, 1.0)

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_accept"):
        var tween = create_tween()
        tween.tween_property(bs, "modulate:a", 1.0, 1.0)
        await tween.finished
        await get_tree().process_frame
        get_tree().change_scene_to_file("res://scenes/menu.tscn")
