extends Node3D

@onready var CPanel = get_node("/root/menu/Camera3D/Control/Credits")
@onready var CPanelBG = get_node("/root/menu/Camera3D/Control/CreditsBG")
@onready var IPanel = get_node("/root/menu/Camera3D/Control/Issues")
@onready var IPanelBG = get_node("/root/menu/Camera3D/Control/IssuesBG")

var model_selector: Control = null
var model_checkboxes: Dictionary = {}
var verifier_selector: Control = null
var selected_verifier_id: String = ""

var all_models = [
    {"id": "451", "name": "Prometheus"}, 
    {"id": "032", "name": "Aegis-7.2"}, 
    {"id": "789", "name": "Quake"}, 
    {"id": "999", "name": "Tricolor"}, 
    {"id": "111", "name": "Ani"}, 
    {"id": "222", "name": "Genesis"}, 
    {"id": "333", "name": "TinyBit"}, 
    {"id": "404", "name": "Logic"}, 
    {"id": "808", "name": "Singularity"}, 
    {"id": "666", "name": "Terminal"}
]

func _ready():
    _build_model_selector()
    _build_verifier_selector()
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

func _build_model_selector():
    model_selector = Control.new()
    model_selector.name = "ModelSelector"
    model_selector.process_mode = Node.PROCESS_MODE_ALWAYS
    model_selector.set_anchors_preset(Control.PRESET_FULL_RECT)
    model_selector.visible = false
    get_node("/root/menu/Camera3D/Control").add_child(model_selector)

    var overlay = ColorRect.new()
    overlay.name = "Overlay"
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    overlay.color = Color(0, 0, 0, 0.6)
    model_selector.add_child(overlay)

    var center = CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    model_selector.add_child(center)

    var panel = PanelContainer.new()
    panel.custom_minimum_size = Vector2(420, 480)
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.08, 0.08, 0.08, 0.95)
    style.corner_radius_top_left = 8
    style.corner_radius_top_right = 8
    style.corner_radius_bottom_left = 8
    style.corner_radius_bottom_right = 8
    panel.add_theme_stylebox_override("panel", style)
    center.add_child(panel)

    var vbox = VBoxContainer.new()
    vbox.offset_left = 16
    vbox.offset_top = 16
    vbox.offset_right = -16
    vbox.offset_bottom = -16
    panel.add_child(vbox)

    var title = Label.new()
    title.text = "Select Models to Load"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)

    var sep = HSeparator.new()
    vbox.add_child(sep)

    var scroll = ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(0, 280)
    vbox.add_child(scroll)

    var checks_vbox = VBoxContainer.new()
    checks_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(checks_vbox)

    for m in all_models:
        var hbox = HBoxContainer.new()
        var chk = CheckBox.new()
        chk.text = m["name"] + " [" + m["id"] + "]"
        chk.button_pressed = true
        model_checkboxes[m["id"]] = chk
        hbox.add_child(chk)
        checks_vbox.add_child(hbox)

    var btn_continue = Button.new()
    btn_continue.text = "Continue"
    btn_continue.pressed.connect(_on_model_selector_continue)
    vbox.add_child(btn_continue)

    var btn_cancel = Button.new()
    btn_cancel.text = "Cancel"
    btn_cancel.pressed.connect(_on_model_selector_cancel)
    vbox.add_child(btn_cancel)

func _on_model_selector_continue():
    for m in all_models:
        var chk = model_checkboxes.get(m["id"])
        if chk:
            ai_host.enabled_models[m["id"]] = chk.button_pressed
    model_selector.visible = false
    _show_verifier_selector()

func _on_model_selector_cancel():
    model_selector.visible = false
    get_tree().paused = false

func _build_verifier_selector():
    verifier_selector = Control.new()
    verifier_selector.name = "VerifierSelector"
    verifier_selector.process_mode = Node.PROCESS_MODE_ALWAYS
    verifier_selector.set_anchors_preset(Control.PRESET_FULL_RECT)
    verifier_selector.visible = false
    get_node("/root/menu/Camera3D/Control").add_child(verifier_selector)

    var overlay = ColorRect.new()
    overlay.name = "Overlay"
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    overlay.color = Color(0, 0, 0, 0.6)
    verifier_selector.add_child(overlay)

    var center = CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    verifier_selector.add_child(center)

    var panel = PanelContainer.new()
    panel.custom_minimum_size = Vector2(420, 380)
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.08, 0.08, 0.08, 0.95)
    style.corner_radius_top_left = 8
    style.corner_radius_top_right = 8
    style.corner_radius_bottom_left = 8
    style.corner_radius_bottom_right = 8
    panel.add_theme_stylebox_override("panel", style)
    center.add_child(panel)

    var vbox = VBoxContainer.new()
    vbox.offset_left = 16
    vbox.offset_top = 16
    vbox.offset_right = -16
    vbox.offset_bottom = -16
    panel.add_child(vbox)

    var title = Label.new()
    title.text = "Select Verifier Model"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)

    var sep = HSeparator.new()
    vbox.add_child(sep)

    for m in all_models:
        var btn = Button.new()
        btn.text = m["name"] + " [" + m["id"] + "]"
        btn.pressed.connect(_on_verifier_selected.bind(m["id"]))
        verifier_buttons[m["id"]] = btn
        vbox.add_child(btn)

    var cancel = Button.new()
    cancel.text = "Cancel"
    cancel.pressed.connect(_on_verifier_cancel)
    vbox.add_child(cancel)

var verifier_buttons: Dictionary = {}

func _show_verifier_selector():
    for m in all_models:
        var btn = verifier_buttons.get(m["id"])
        if btn:
            btn.visible = ai_host.enabled_models.get(m["id"], true)
    verifier_selector.visible = true

func _on_verifier_selected(id: String):
    selected_verifier_id = id
    verifier_selector.visible = false
    get_tree().paused = false
    _do_load()

func _on_verifier_cancel():
    verifier_selector.visible = false
    get_tree().paused = false

func _on_play_pressed() -> void :
    if Input.is_key_pressed(KEY_ALT) or Input.is_key_pressed(KEY_CTRL):
        model_selector.visible = true
        get_tree().paused = true
        return
    selected_verifier_id = ""
    for m in all_models:
        ai_host.enabled_models[m["id"]] = true
    _do_load()

func _do_load():
    if not selected_verifier_id.is_empty():
        ai_host.set_verifier_model(selected_verifier_id)
    get_tree().change_scene_to_file("res://scenes/load.tscn")

func _process(delta: float) -> void :
    pass

func _on_exit_pressed() -> void :
    get_tree().quit()

func _on_issues_pressed() -> void :
    IPanel.visible = !IPanel.visible
    IPanelBG.visible = !IPanelBG.visible
