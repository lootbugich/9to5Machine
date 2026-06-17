extends Node2D

@onready var labeli = $start_label
@onready var buttlabeli = $button_desc_label

@onready var start = $start_button
@onready var example_butt = $example_button

func _ready() -> void:
    buttlabeli.visible = false
    example_butt.visible = false
    start.visible = false
    start.modulate.a = 0
    vis_lines(labeli)
    labeli.text = "Hello."
    await get_tree().create_timer(3).timeout
    vis_lines(labeli)
    labeli.text = "This is a [wave amp=70 freq=2.5]tutorial[/wave]. Here you will learn the basic controls."
    await get_tree().create_timer(8).timeout
    vis_lines(labeli)
    labeli.text = "Don't worry, you can [wave amp=70 freq=2.5]look up[/wave] the controls in the main game."
    await get_tree().create_timer(8).timeout
    vis_lines(labeli)
    labeli.text = "Well. Let's begin."
    await get_tree().create_timer(2).timeout
    start.visible = true
    create_tween().tween_property(start, "modulate:a", 1.0, 0.5)

func _on_start_button_pressed():
    if start.visible == true:
        start.disabled = true
        var tween = create_tween()
        tween.tween_property(start, "modulate:a", 0.0, 0.5)
        await tween.finished
        labeli.visible = false
        await get_tree().create_timer(1).timeout
        ex_button()

func _on_example_button_pressed():
    example_butt.disabled = true
    var tween = create_tween()
    tween.tween_property(example_butt, "modulate:a", 0.0, 0.5)
    tween.tween_property(buttlabeli, "modulate:a", 0.0, 0.5)
    await tween.finished
    example_butt.visible = false
    buttlabeli.visible = false
    await get_tree().create_timer(1).timeout
    continue_tutorial()

func vis_lines(lab: RichTextLabel):
    lab.visible_characters = 0
    await get_tree().process_frame
    while lab.visible_characters < lab.get_total_character_count():
        lab.visible_characters += 1
        await get_tree().create_timer(0.03).timeout

func ex_button():
    var tween = create_tween()
    example_butt.visible = true
    example_butt.modulate.a = 0
    tween.tween_property(example_butt, "modulate:a", 1.0, 0.5)
    await tween.finished
    await get_tree().create_timer(1).timeout
    buttlabeli.visible = true
    vis_lines(buttlabeli)
    buttlabeli.text = "This is an example of a [wave amp=70 freq=2.5]button[/wave].\nIt tells you what you can do with it and where it leads."
    await get_tree().create_timer(8).timeout
    vis_lines(buttlabeli)
    buttlabeli.text = "Click the button to continue."

func continue_tutorial():
    labeli.visible = true
    labeli.modulate.a = 0
    var tween = create_tween()
    tween.tween_property(labeli, "modulate:a", 1.0, 0.5)
    await tween.finished
    vis_lines(labeli)
    labeli.text = "Now, let’s move on to [wave amp=70 freq=2.5]interactive[/wave] objects."
    await get_tree().create_timer(8).timeout
    vis_lines(labeli)
    labeli.text = "Interactive objects will be everywhere. Keep a close eye on your surroundings."
