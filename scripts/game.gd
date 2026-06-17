extends Node3D

func _input(e):
    var h = $Camera3D / hud / hint
    if h.visible and e is InputEventMouseButton: get_viewport().set_input_as_handled()
    if h.visible and e.is_action_pressed("ui_cancel"):
        var t = create_tween()
        t.tween_property(h, "modulate:a", 0, 0.5)
        t.finished.connect( func(): h.hide();$Camera3D.update_ui())

func _ready():
    while 1:
        await get_tree().create_timer(randf_range(5, 15)).timeout
        $lightbolt_sound.play()
        $lightbolt.light_energy = 16
        await get_tree().create_timer(0.2).timeout
        $lightbolt.light_energy = 0
        await get_tree().create_timer(0.05).timeout
        $lightbolt.light_energy = 8
        await get_tree().create_timer(0.2).timeout
        $lightbolt.light_energy = 0
