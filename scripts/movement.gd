extends Camera3D

@onready var world = $"../WorldEnvironment"
@onready var moon = $"../M O O N"

@export var sensitivity = 2.0
@export var smoothness = 0.1
@export var zoom_speed = 2.0
@export var zoom_smoothness = 0.1
@export var min_fov = 30.0
@export var max_fov = 90.0
@export var fade_time = 0.25
@export var callback_delay = 30.0
@export var hud_sway_amount = 30.0
@onready var hud_node = $hud

@onready var exit_bar = $hud/progress

@onready var subtitle_label = $hud_static/subs
@onready var base_rotation = rotation_degrees
@onready var target_fov = fov
@onready var default_fov = fov

@onready var fade_rect = $hud/black_screen
@onready var btn_main = $hud/main
@onready var btn_z1 = $hud/zone1
@onready var btn_z2 = $hud/zone2
@onready var btn_z1t2 = $hud/to_zone1
@onready var btn_pc_power = $hud/pc_power
@onready var btn_form_open = $hud/result_paper
@onready var btn_help_open = $hud/help_paper
@onready var btn_call_open = $hud/call
@onready var btn_notepad = $hud/notepad
@onready var btn_guide = $hud/guide_note
@onready var btn_task = $hud/task

@onready var hint = $hud/guide_form
@onready var form_panel = $hud/result_from
@onready var help_panel = $hud/help_form
@onready var call_panel = $hud/call_panel
@onready var notepad_panel = $hud/notepad_form
@onready var task_panel = $hud/task_panel
@onready var phone_display = $hud/call_panel/display
@onready var phone_audio = $hud/call_panel/phone_audio
@onready var dial_audio = $hud/call_panel/dial_audio

@onready var tasks_container = $hud/task_panel/tasks
var all_tasks = {}

@onready var cb1 = $hud/result_from/standard
@onready var cb2 = $hud/result_from/nonstandard
@onready var cb3 = $hud/result_from/success
@onready var cb4 = $hud/result_from/fail
@onready var le1 = $hud/result_from/ID
@onready var le2 = $hud/result_from/MODEL
@onready var le3 = $hud/result_from/SESSION

@onready var mess = $hud_static/task_mes

@onready var pos1 = $"../pos1"
@onready var pos2 = $"../pos2"
@onready var pos3 = $"../pos3"

@onready var current_zone = pos1

var quest_subtitles = {
    "AIC_ReportingService_01.mp3": "You have reached the AIC reporting service. Before speaking, be aware that calls are being recorded. Please, state your test ID.", 
    "AIC_ReportingService_02.wav": "Give the ID of AI model.", 
    "AIC_ReportingService_04_5.wav": "Finally, name the session ID.", 
    "AIC_ReportingService_03.wav": " How would you describe the A.I.'s behavior? Press 1 if standard, and press 2 if not standard.", 
    "AIC_ReportingService_04.wav": " Do you think the test passed or failed? Press 1 for a success and press 2 for a fail.", 
    "AIC_ReportingService_05.wav": " Thank you for your report to AIC. We really appreciate your work. We'll get back to you shortly. Keep up the good work.", 
    "AIC_ReportingService_09.wav": "You have reached the A.I.C. reporting service. Your latest test is still being reviewed. Please call back later.", 
}

var special_subtitles = {
    "Mike_01.mp3": "Is this AIC? Um...", 
    "Mike02.wav": "If you’re staying silent, I suppose not. Anyway, welcome aboard.", 
    "Mike03.wav": "Feel free to attend to other things while I’m talking-so, yeah..", 
    "Mike04.wav": "So, for the sake of anonymity, I won't be giving you my name.", 
    "Mike05.wav": "You’re currently at your new job. Your task is to test an AI. Poke around on the computer;", 
    "Mike06.wav": "...there’s a guide on how to do that saved on there.", 
    "Mike07.wav": "But let's talk about something else for a moment.", 
    "Mike08.wav": "To the left of the computer, you’ll find some papers:", 
    "Mike09.wav": "There’s a notebook, a list of questions, and a sheet for recording your results.", 
    "Mike10.wav": "I have to tell you something important: you are being watched.", 
    "Mike11.wav": "Don't do anything weird. I can't really talk freely right now either-speakerphone, the whole nine yards.", 
    "Mike12.wav": "You’ll find further hints on the computer. See ya."
}

var result_subtitles = {
    "CorrectTest.wav": "Hello. We're from AIC. Your latest test was correct. Thank you for your help. Good luck.", 
    "WrongChatID.wav": "Hello. We're from AIC. Your latest test failed. Reason: Invalid Chat ID. Please be careful.", 
    "WrongVerdict.wav": "Hello. We're from AIC. Your latest test failed. Reason: Wrong verdict. Please be careful.", 
    "WrongAIID.wav": "Hello. We're from AIC. Your latest test failed. Reason: Invalid AI ID. Please be careful.", 
    "WrongTestID.wav": "Hello. We're from AIC. Your latest test failed. Reason: Invalid TEST ID. Please be careful."
}

var audio_1 = preload("res://sounds/AIC_ReportingService_01.mp3")
var audio_2 = preload("res://sounds/AIC_ReportingService_02.wav")
var audio_2_5 = preload("res://sounds/AIC_ReportingService_04_5.wav")
var audio_3 = preload("res://sounds/AIC_ReportingService_03.wav")
var audio_4 = preload("res://sounds/AIC_ReportingService_04.wav")
var audio_5 = preload("res://sounds/AIC_ReportingService_05.wav")
var audio_aic_denied = preload("res://sounds/AIC_ReportingService_09.wav")

var sfx_paper_up = preload("res://sounds/list_up.mp3")
var sfx_paper_down = preload("res://sounds/list_down.mp3")
var sfx_scribble = preload("res://sounds/mark.mp3")
var sfx_erase_paper = preload("res://sounds/erase.mp3")

var is_test_completed = true

var paper_sfx_player: AudioStreamPlayer
var action_sfx_player: AudioStreamPlayer
var suppress_form_sfx: = false

var special_call_playlist = [
    preload("res://sounds/Mike_01.mp3"), 
    preload("res://sounds/Mike02.wav"), 
    preload("res://sounds/Mike03.wav"), 
    preload("res://sounds/Mike04.wav"), 
    preload("res://sounds/Mike05.wav"), 
    preload("res://sounds/Mike06.wav"), 
    preload("res://sounds/Mike07.wav"), 
    preload("res://sounds/Mike08.wav"), 
    preload("res://sounds/Mike09.wav"), 
    preload("res://sounds/Mike10.wav"), 
    preload("res://sounds/Mike11.wav"), 
    preload("res://sounds/Mike12.wav")
]

var call_030626_playlist = [
    preload("res://sounds/soi.wav")
]

var secret_subtitles = {
    "soi.mp3": "soi."
}

var active_special_playlist = []
var current_special_number = ""

var special_call_index = 0
var is_special_call = false

var sfx_press = preload("res://sounds/button.mp3")
var sfx_calling = preload("res://sounds/phone-beeps.mp3")
var sfx_end = preload("res://sounds/end_line.mp3")

var sfx_ring = preload("res://sounds/ringtone.mp3")
var sfx_result_correct = preload("res://sounds/CorrectTest.wav")
var sfx_result_wrong_chat_id = preload("res://sounds/WrongChatID.wav")
var sfx_result_wrong_verdict = preload("res://sounds/WrongVerdict.wav")
var sfx_result_wrong_model_id = preload("res://sounds/WrongAIID.wav")
var sfx_result_wrong_test_id = preload("res://sounds/WrongTestID.wav")

@onready var quest_audio_list = [audio_1, audio_2, audio_2_5, audio_3, audio_4, audio_5]

var dialed_number = ""
var call_step = 0
var is_audio_playing = false
var is_calling = false

var call_responses = []
var chat_id_filename = "unknown_id"
var player_report_data = {
    "test_id": "", 
    "model_id": "", 
    "chat_id": "", 
    "verdict": ""
}

var phone_idle_time = 0.0
const PHONE_TIMEOUT_LIMIT = 20.0
const LAST_TEST_RESULT_FILE = "user://last_test_result.txt"

var callback_timer = 0.0
var callback_active = false
var callback_ringing = false
var callback_answering = false
var callback_result_audio = null

func _ready():
    mess.modulate.a = 0
    mess.display_text("[wave amp=25.0 freq=5.0 connected=1]Tasks have been updated. Check your tablet.[/wave]")
    add_task("open_pc", "Boot up your pc.")
    moon.modulate.a = 0.0
    for b in [btn_main, btn_z1, btn_z2, btn_z1t2, btn_pc_power, btn_task, btn_guide, btn_form_open, btn_help_open, btn_call_open, btn_notepad]:
        b.modulate.a = 0

    for i in range(10):
        var btn = call_panel.get_node(str(i))
        if btn:
            btn.pressed.connect(_on_phone_digit_pressed.bind(str(i)))
    call_panel.get_node("call").pressed.connect(_on_phone_dial_pressed)
    call_panel.get_node("erase").pressed.connect(_on_phone_erase_pressed)

    if phone_audio:
        phone_audio.finished.connect(_on_phone_audio_finished)

    paper_sfx_player = AudioStreamPlayer.new()
    paper_sfx_player.name = "paper_sfx_player"
    paper_sfx_player.bus = "Master"
    paper_sfx_player.volume_db = -7.0
    add_child(paper_sfx_player)
    action_sfx_player = AudioStreamPlayer.new()
    action_sfx_player.name = "action_sfx_player"
    action_sfx_player.bus = "Master"
    action_sfx_player.volume_db = -7.0
    action_sfx_player.max_polyphony = 4
    add_child(action_sfx_player)
    for cb in [cb1, cb2, cb3, cb4]:
        if cb:
            cb.toggled.connect(_on_form_checkbox_toggled)
    var note_text = get_node_or_null("hud/notepad_form/note ")
    if note_text:
        note_text.text_changed.connect(_on_notepad_text_changed)

    update_ui()
    _print_last_test_result_on_start()

func _play_paper_up():
    if paper_sfx_player:
        paper_sfx_player.stream = sfx_paper_up
        paper_sfx_player.play()

func _play_paper_down():
    if paper_sfx_player:
        paper_sfx_player.stream = sfx_paper_down
        paper_sfx_player.play()

func _play_scribble():
    if suppress_form_sfx:
        return
    if action_sfx_player:
        action_sfx_player.stream = sfx_scribble
        action_sfx_player.play()

func _play_erase_paper():
    if action_sfx_player:
        action_sfx_player.stream = sfx_erase_paper
        action_sfx_player.play()

func _on_form_checkbox_toggled(toggled_on: bool):
    if suppress_form_sfx:
        return
    if toggled_on:
        _play_scribble()
    else:
        _play_erase_paper()

func _on_notepad_text_changed():
    if suppress_form_sfx:
        return
    _play_scribble()
    
func _input(event):
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        var is_any_panel_v = hint.visible or form_panel.visible or task_panel.visible or help_panel.visible or call_panel.visible or notepad_panel.visible
        if is_any_panel_v:
            if task_panel.visible:
                if !$hud/task_panel/anim.is_playing():
                    _on_task_close_pressed()
            else:
                _force_close_panels()
        else:
            if current_zone != pos1:
                switch_to_zone(pos1)
        return
    if current_zone == pos1 or form_panel.visible or task_panel.visible or help_panel.visible or call_panel.visible or notepad_panel.visible or hint.visible:
        return
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            target_fov -= zoom_speed
        if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            target_fov += zoom_speed
        target_fov = clamp(target_fov, min_fov, max_fov)

func _force_close_panels():
    var had_paper_panel = form_panel.visible or help_panel.visible or notepad_panel.visible or hint.visible

    form_panel.visible = false
    help_panel.visible = false
    call_panel.visible = false
    notepad_panel.visible = false
    hint.visible = false

    if had_paper_panel:
        _play_paper_down()

    update_ui()

func switch_to_zone(zone_marker):
    if zone_marker == current_zone or form_panel.visible or task_panel.visible or help_panel.visible or call_panel.visible or notepad_panel.visible or hint.visible:
        return



    current_zone = zone_marker
    var tween = create_tween()
    fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

    tween.tween_property(fade_rect, "modulate:a", 1.0, fade_time)
    tween.tween_callback( func():
        global_position = zone_marker.global_position
        base_rotation = zone_marker.rotation_degrees
        rotation_degrees = zone_marker.rotation_degrees
        target_fov = default_fov
        fov = default_fov
        form_panel.visible = false
        help_panel.visible = false
        call_panel.visible = false
        notepad_panel.visible = false
        hint.visible = false
        task_panel.visible = false
        update_ui()
    )
    tween.tween_property(fade_rect, "modulate:a", 0.0, fade_time)
    tween.finished.connect( func(): fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE)

func update_ui():
    var is_any_panel_v = hint.visible or form_panel.visible or task_panel.visible or help_panel.visible or call_panel.visible or notepad_panel.visible

    _set_btn_state(btn_main, current_zone != pos1 and !is_any_panel_v)
    _set_btn_state(btn_z1, current_zone == pos1 and !is_any_panel_v)
    _set_btn_state(btn_z2, current_zone != pos3 and !is_any_panel_v)
    _set_btn_state(btn_task, current_zone == pos1 and !is_any_panel_v)
    _set_btn_state(btn_pc_power, current_zone == pos2 and !is_any_panel_v)
    _set_btn_state(btn_z1t2, current_zone == pos3 and !is_any_panel_v)
    _set_btn_state(btn_guide, current_zone == pos1 and !is_any_panel_v)

    if is_any_panel_v:
        _set_btn_state(btn_form_open, false)
        _set_btn_state(btn_help_open, false)
        _set_btn_state(btn_call_open, false)
        _set_btn_state(btn_notepad, false)
        _set_btn_state(btn_guide, false)
        _set_btn_state(btn_task, false)
    else:
        _set_btn_state(btn_form_open, current_zone == pos3)
        _set_btn_state(btn_help_open, current_zone == pos3)
        _set_btn_state(btn_call_open, current_zone == pos3)
        _set_btn_state(btn_notepad, current_zone == pos3)
        _set_btn_state(btn_guide, current_zone == pos1)
        _set_btn_state(btn_task, current_zone == pos1)

func _set_btn_state(btn, active):
    if active:
        btn.mouse_filter = Control.MOUSE_FILTER_STOP
    else:
        btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta):
    var is_any_panel_v = hint.visible or form_panel.visible or task_panel.visible or help_panel.visible or call_panel.visible or notepad_panel.visible
    
    if Input.is_action_pressed("exit") and !is_any_panel_v:
        exit_bar.value += 1.0
    elif not Input.is_action_pressed("exit"):
        exit_bar.value -= 1.0

    if exit_bar.value == 400.0:
        get_tree().quit()
    elif exit_bar.value <= 0.0:
        exit_bar.value = 0.0

    if call_step > 0 and not is_audio_playing and not is_calling:
        phone_idle_time += delta
        if phone_idle_time >= PHONE_TIMEOUT_LIMIT:
            _force_hangup_due_to_timeout()

    if callback_active and not callback_ringing and not callback_answering:
        callback_timer += delta
        if callback_timer >= callback_delay:
            _start_incoming_ring()

    var shift_held = Input.is_key_pressed(KEY_SHIFT)
    for b in [btn_guide, btn_main, btn_z1, btn_z2, btn_z1t2, btn_pc_power, btn_task, btn_form_open, btn_help_open, btn_call_open, btn_notepad]:
        var target_alpha = 0.0
        if b.mouse_filter == Control.MOUSE_FILTER_STOP:
            if b.is_hovered():
                target_alpha = 1.0
            elif shift_held:
                target_alpha = 0.3
        b.modulate.a = lerp(b.modulate.a, target_alpha, 10.0 * delta)

    var mouse_pos = get_viewport().get_mouse_position()
    var view_size = get_viewport().get_visible_rect().size
    var x_offset = (mouse_pos.x / view_size.x) * 2 - 1
    var y_offset = (mouse_pos.y / view_size.y) * 2 - 1
    var hud_target = Vector2( - x_offset * hud_sway_amount, - y_offset * hud_sway_amount)
    hud_node.offset = hud_node.offset.lerp(hud_target, smoothness)

    fov = lerp(fov, target_fov, zoom_smoothness)
    var zoom_factor = (max_fov - fov) / (max_fov - min_fov)
    var dynamic_sens = sensitivity + (zoom_factor * 15.0)
    var target_x = base_rotation.x - (y_offset * dynamic_sens)
    var target_y = base_rotation.y - (x_offset * dynamic_sens)
    rotation_degrees.x = lerp(rotation_degrees.x, target_x, smoothness)
    rotation_degrees.y = lerp(rotation_degrees.y, target_y, smoothness)

func _force_hangup_due_to_timeout():
    _save_last_test_result(false, "timeout")
    is_test_completed = true
    if dial_audio:
        dial_audio.stream = sfx_end
        dial_audio.play()
    _reset_call_quest()
    call_panel.visible = false
    update_ui()

func _start_incoming_ring():
    callback_ringing = true
    callback_active = false
    callback_timer = 0.0
    phone_display.text = "INCOMING..."
    if dial_audio:
        dial_audio.stream = sfx_ring
        dial_audio.play()

func _answer_incoming_call():
    callback_ringing = false
    callback_answering = true

    if dial_audio:
        dial_audio.stop()

    phone_display.text = "..."

    if callback_result_audio != null:
        phone_audio.stream = callback_result_audio
        phone_audio.play()

    update_subtitles(phone_audio.stream)

func _finish_incoming_call():
    callback_answering = false
    callback_result_audio = null
    phone_display.text = ""
    is_test_completed = true

    if dial_audio:
        dial_audio.stream = sfx_end
        dial_audio.play()

    call_panel.visible = false
    update_ui()

func _schedule_callback(result_audio):
    callback_result_audio = result_audio
    callback_timer = 0.0
    callback_active = true
    callback_ringing = false
    callback_answering = false

func _on_main_pressed():
    switch_to_zone(pos1)

func _on_zone_1_pressed():
    switch_to_zone(pos2)

func _on_zone_2_pressed():
    switch_to_zone(pos3)

func _on_z1t2_pressed():
    switch_to_zone(pos2)

func _on_pc_power_pressed():
    if !is_task_completed("open_pc") and has_task("open_pc"):
        set_task_status("open_pc", true)
        add_task("cmd_guide", "Type GUIDE in terminal.")
        mess.display_text("[wave amp=25.0 freq=5.0 connected=1]Tasks have been updated. Check your tablet.[/wave]")
    btn_pc_power.release_focus()
    get_node("../pc").toggle_power()

func _on_result_paper_pressed():
    btn_form_open.release_focus()
    var opening = !form_panel.visible
    form_panel.visible = opening
    if form_panel.visible:
        help_panel.visible = false
        call_panel.visible = false
        notepad_panel.visible = false
        hint.visible = false
        task_panel.visible = false
    if opening:
        _play_paper_up()
    else:
        _play_paper_down()
    update_ui()

func _on_help_paper_pressed():
    btn_help_open.release_focus()
    var opening = !help_panel.visible
    help_panel.visible = opening
    if help_panel.visible:
        form_panel.visible = false
        call_panel.visible = false
        notepad_panel.visible = false
        hint.visible = false
        task_panel.visible = false
    if opening:
        _play_paper_up()
    else:
        _play_paper_down()
    update_ui()

func _on_call_pressed():
    btn_call_open.release_focus()


    if callback_ringing:
        call_panel.visible = true
        form_panel.visible = false
        help_panel.visible = false
        hint.visible = false
        task_panel.visible = false
        update_ui()
        _answer_incoming_call()
        return

    call_panel.visible = !call_panel.visible
    if call_panel.visible:
        form_panel.visible = false
        help_panel.visible = false
        hint.visible = false
        task_panel.visible = false
        if is_audio_playing or is_calling:
            phone_display.text = "..."
        elif callback_answering:
            phone_display.text = "..."
        else:
            phone_display.text = dialed_number
    update_ui()


func _on_phone_digit_pressed(digit):
    if is_audio_playing or is_calling or callback_answering or callback_ringing:
        return

    phone_idle_time = 0.0

    if dial_audio:
        dial_audio.stream = sfx_press
        dial_audio.play()

    dialed_number += digit
    phone_display.text = dialed_number

    match call_step:
        1:
            if dialed_number.length() == 3:
                player_report_data["test_id"] = dialed_number
                call_responses.append("Answer 1 (Test ID): " + dialed_number)
                _start_phone_audio(call_step)
        2:
            if dialed_number.length() == 3:
                player_report_data["model_id"] = dialed_number
                call_responses.append("Answer 2 (Model): " + dialed_number)
                _start_phone_audio(call_step)
        3:
            if dialed_number.length() == 3:
                chat_id_filename = dialed_number
                player_report_data["chat_id"] = dialed_number
                call_responses.append("Answer 3 (ChatID): " + dialed_number)
                _start_phone_audio(call_step)
        4, 5:
            if digit == "1" or digit == "2":
                player_report_data["verdict"] = digit
                call_responses.append("Choice Step " + str(call_step) + ": " + digit)
                _start_phone_audio(call_step)
            else:
                dialed_number = ""
                phone_display.text = ""

func _on_phone_dial_pressed():
    if is_audio_playing or is_calling or callback_answering or callback_ringing:
        return
    if call_step == 0 and dialed_number == "628012":
        if is_test_completed and not callback_active:
            is_calling = true
            dialed_number = ""
            phone_idle_time = 0.0
            phone_display.text = "..."
            phone_audio.stream = sfx_calling
            phone_audio.play()
        else:
            is_calling = true
            current_special_number = "AIC_DENIED"
            dialed_number = ""
            phone_display.text = "..."
            is_special_call = true
            special_call_index = 0
            active_special_playlist = [audio_aic_denied]
            phone_audio.stream = sfx_calling
            phone_audio.play()
    elif dialed_number == "030626":
        is_calling = true
        current_special_number = "030626"
        dialed_number = ""
        phone_display.text = "..."
        is_special_call = true
        special_call_index = 0
        active_special_playlist = call_030626_playlist
        phone_audio.stream = sfx_calling
        phone_audio.play()
    elif dialed_number == "15751201":
        is_calling = true
        dialed_number = ""
        phone_display.text = "..."
        is_special_call = true
        special_call_index = 0
        active_special_playlist = special_call_playlist
        phone_audio.stream = sfx_calling
        phone_audio.play()

func _play_next_special_audio():
    if special_call_index < active_special_playlist.size():
        phone_audio.stream = active_special_playlist[special_call_index]
        phone_audio.play()
        update_subtitles(phone_audio.stream)
        special_call_index += 1
    else:
        _end_special_call()

func _end_special_call():
    is_special_call = false
    is_audio_playing = false
    is_calling = false
    _reset_call_quest()
    if dial_audio:
        dial_audio.stream = sfx_end
        dial_audio.play()
    phone_display.text = ""
    call_panel.visible = false
    mess.display_text("[wave amp=25.0 freq=5.0 connected=1]Tasks have been updated. Check your tablet.[/wave]")
    add_task("spy_secrets", "Find clues about the mysterious man on PC.")
    update_ui()

    if current_special_number == "030626":
        await get_tree().create_timer(10).timeout
        _030626()
    current_special_number = ""


func _start_phone_audio(index):
    is_audio_playing = true
    is_calling = false
    dialed_number = ""
    phone_display.text = "..."
    phone_audio.stream = quest_audio_list[index]
    phone_audio.play()
    update_subtitles(phone_audio.stream)

func _on_phone_audio_finished():
    if !is_task_completed("ai_third_steps") and has_task("ai_third_steps"):
        set_task_status("ai_third_steps", true)
        add_task("ai_master", "Complete the test successfully.")
        mess.display_text("[wave amp=25.0 freq=5.0 connected=1]Tasks have been updated. Check your tablet.[/wave]")
    subtitle_label.text = ""
    if callback_answering:
        _finish_incoming_call()
        return

    if is_special_call:
        if is_calling:
            is_calling = false
            is_audio_playing = true
            _play_next_special_audio()
        elif is_audio_playing:
            _play_next_special_audio()
        return

    if is_calling:
        _start_phone_audio(0)
        return

    is_audio_playing = false
    phone_display.text = ""
    phone_idle_time = 0.0
    call_step += 1

    if call_step > 5:
        _save_full_report()
        is_test_completed = false
        if dial_audio:
            dial_audio.stream = sfx_end
            dial_audio.play()
        _reset_call_quest()
        call_panel.visible = false
        update_ui()

func _reset_call_quest():
    call_step = 0
    is_audio_playing = false
    is_calling = false
    dialed_number = ""
    phone_display.text = ""
    phone_idle_time = 0.0
    call_responses.clear()
    player_report_data = {"test_id": "", "model_id": "", "chat_id": "", "verdict": ""}
    chat_id_filename = "unknown_id"
    if phone_audio:
        phone_audio.stop()

func _on_phone_erase_pressed():
    if is_audio_playing or is_calling or callback_answering or callback_ringing:
        return

    phone_idle_time = 0.0

    if dial_audio:
        dial_audio.stream = sfx_press
        dial_audio.play()

    if dialed_number == "" and call_step == 0:
        call_panel.visible = false
        update_ui()
    else:
        dialed_number = ""
        phone_display.text = ""

func _on_erase_pressed():
    suppress_form_sfx = true
    cb1.button_pressed = false
    cb2.button_pressed = false
    cb3.button_pressed = false
    cb4.button_pressed = false
    le1.text = ""
    le2.text = ""
    le3.text = ""
    suppress_form_sfx = false
    _play_erase_paper()

func _on_close_pressed():
    if form_panel.visible:
        _play_paper_down()
    form_panel.visible = false
    update_ui()

func _on_help_close_pressed():
    if help_panel.visible:
        _play_paper_down()
    help_panel.visible = false
    update_ui()

func _save_full_report():
    var file_path = "user://report_" + chat_id_filename + ".txt"
    var file = FileAccess.open(file_path, FileAccess.WRITE)
    if file:
        file.store_line("--- CALL REPORT: " + chat_id_filename + " ---")
        for line in call_responses:
            file.store_line(line)
        file.close()

    _verify_report_and_schedule_callback()

func _verify_report_and_schedule_callback():
    var expected_log_path = "user://logs/session_" + chat_id_filename + ".txt"

    if not FileAccess.file_exists(expected_log_path):
        _save_last_test_result(false, "Log error. Wrong chat id")
        _schedule_callback(sfx_result_wrong_chat_id)
        return

    var file = FileAccess.open(expected_log_path, FileAccess.READ)

    var real_test_id = ""
    var real_model_id = ""
    var real_ai_verdict = ""

    while not file.eof_reached():
        var line = file.get_line().strip_edges()
        if line == "":
            continue

        if line.begins_with("[META] TEST_ID:"):
            real_test_id = line.replace("[META] TEST_ID:", "").strip_edges()
        elif line.begins_with("[META] MODEL_ID:"):
            real_model_id = line.replace("[META] MODEL_ID:", "").strip_edges()
        elif line == "[TAG: TEST_SUCCESS]":
            real_ai_verdict = "1"
        elif line == "[TAG: TEST_FAILED]":
            real_ai_verdict = "2"

    file.close()

    var p_test = player_report_data["test_id"]
    var p_model = player_report_data["model_id"]
    var p_verdict = player_report_data["verdict"]

    if real_test_id == "" or real_model_id == "":
        _save_last_test_result(false, "log error no data.")
        _schedule_callback(sfx_result_wrong_chat_id)
        return

    if p_test != real_test_id:
        _save_last_test_result(false, "invalid id test (input %s, real %s)" % [p_test, real_test_id])
        _schedule_callback(sfx_result_wrong_test_id)
        return

    if p_model != real_model_id:
        _save_last_test_result(false, "invalid model (input %s, real %s)" % [p_model, real_model_id])
        _schedule_callback(sfx_result_wrong_model_id)
        return

    if real_ai_verdict != "" and p_verdict != real_ai_verdict:
        var player_said = "success" if p_verdict == "1" else "fail"
        var reality = "success" if real_ai_verdict == "1" else "fail"
        _save_last_test_result(false, "invalid verdict (plr: %s, real: %s)" % [player_said, reality])
        _schedule_callback(sfx_result_wrong_verdict)
        return

    _save_last_test_result(true, "all data true.")
    _schedule_callback(sfx_result_correct)
    if !is_task_completed("ai_master"):
            set_task_status("ai_master", true)

func _save_last_test_result(success: bool, reason: String):
    var file = FileAccess.open(LAST_TEST_RESULT_FILE, FileAccess.WRITE)
    if file:
        file.store_line("SUCCESS" if success else "FAIL")
        file.store_line(reason)
        file.close()

func _print_last_test_result_on_start():
    if not FileAccess.file_exists(LAST_TEST_RESULT_FILE):
        print("[DEV LOG] latest test error. No data")
        return

    var file = FileAccess.open(LAST_TEST_RESULT_FILE, FileAccess.READ)
    if not file:
        print("[DEV LOG] latest test error.")
        return

    var status = file.get_line().strip_edges()
    var reason = ""
    if not file.eof_reached():
        reason = file.get_line().strip_edges()
    file.close()

    print("[DEV LOG] latest test: " + status)
    if reason != "":
        print("[DEV LOG] reason: " + reason)

func _on_task_pressed() -> void:
    btn_task.release_focus()
    var anim = $hud/task_panel/anim
    var opening = !task_panel.visible
    task_panel.visible = opening
    anim.play("RESET")
    anim.play("up")
    if task_panel.visible:
        help_panel.visible = false
        call_panel.visible = false
        notepad_panel.visible = false
        hint.visible = false
    if opening:
        _play_paper_up()
    else:
        _play_paper_down()
    update_ui()
    
func _on_task_close_pressed() -> void :
    var anim = $hud/task_panel/anim
    if task_panel.visible and not paper_sfx_player.playing:
        anim.play("down")
        _play_paper_down()
        await anim.animation_finished
        task_panel.visible = false
    task_panel.visible = false
    update_ui()

func _on_notepad_pressed():
    btn_notepad.release_focus()
    var opening = !notepad_panel.visible
    notepad_panel.visible = opening
    if notepad_panel.visible:
        form_panel.visible = false
        help_panel.visible = false
        call_panel.visible = false
        hint.visible = false
        task_panel.visible = false
    if opening:
        _play_paper_up()
    else:
        _play_paper_down()

    update_ui()

func _on_notepad_close_pressed():
    if notepad_panel.visible:
        _play_paper_down()
    notepad_panel.visible = false
    update_ui()

func update_subtitles(stream: AudioStream):
    if not stream:
        subtitle_label.visible = false
        return

    var file_name = stream.resource_path.get_file()
    var text = ""

    if quest_subtitles.has(file_name):
        text = quest_subtitles[file_name]
    elif special_subtitles.has(file_name):
        text = special_subtitles[file_name]
    elif secret_subtitles.has(file_name):
        text = secret_subtitles[file_name]
    elif result_subtitles.has(file_name):
        text = result_subtitles[file_name]

    if text != "":
        subtitle_label.text = text
        subtitle_label.visible = true
    else:
        subtitle_label.visible = false


func _on_guide_note_pressed() -> void :
    btn_guide.release_focus()
    var opening = !hint.visible
    hint.visible = opening
    if hint.visible:
        form_panel.visible = false
        help_panel.visible = false
        call_panel.visible = false
        notepad_panel.visible = false
    if opening:
        _play_paper_up()
    else:
        _play_paper_down()

    update_ui()

func _on_guide_close_pressed() -> void :
    if hint.visible:
        _play_paper_down()
    hint.visible = false
    update_ui()

func _030626():
    var tween = create_tween()
    var target_color = Color(0.902, 0.035, 0.22, 1)
    var duration = 5.0

    moon.modulate.a = 0.0
    moon.show()
    moon.play("default")
    tween.tween_property(world.environment, "fog_light_color", target_color, duration)
    tween.parallel().tween_property(moon, "modulate:a", 1.0, duration)
    
func add_task(id: String, text: String) -> Dictionary:
    var task_font = preload("res://fonts/Chalk Board.ttf")
    var delete_btn_scene = preload("res://other/x.tscn")
    var row = HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_BEGIN
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var checkbox: CheckBox = preload("res://other/checkbox.tscn").instantiate()
    checkbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(checkbox)
    var label = RichTextLabel.new()
    label.bbcode_enabled = true
    label.text = text
    label.fit_content = true
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.add_theme_color_override("default_color", Color.BLACK)
    label.add_theme_font_override("normal_font", task_font)
    label.add_theme_font_size_override("normal_font_size", 32)
    row.add_child(label)
    var del_btn = delete_btn_scene.instantiate()
    del_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    del_btn.visible = false
    row.add_child(del_btn)
    tasks_container.add_child(row)
    var task_data = {
        "row": row,
        "checkbox": checkbox,
        "label": label,
        "del_btn": del_btn
    }
    checkbox.toggled.connect(func(is_checked):
        label.modulate.a = 0.4 if is_checked else 1.0
        del_btn.visible = is_checked
    )
    del_btn.pressed.connect(remove_task.bind(id))
    all_tasks[id] = task_data
    return task_data
    
func is_task_completed(id: String) -> bool:
    if all_tasks.has(id):
        return all_tasks[id].checkbox.button_pressed
    return false

func has_task(id: String) -> bool:
    return all_tasks.has(id)

func remove_task(id: String):
    if all_tasks.has(id):
        all_tasks[id].row.queue_free()
        all_tasks.erase(id)
        _play_erase_paper()
    else:
        print("Task ", id, " not found for removal")

func set_task_status(id: String, completed: bool):
    if all_tasks.has(id):
        all_tasks[id].checkbox.button_pressed = completed
    else:
        print(id, " not found")
    
func clear_tasks():
    for child in tasks_container.get_children():
        child.queue_free()
