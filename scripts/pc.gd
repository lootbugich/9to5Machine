extends MeshInstance3D

const AI_LOGIC = preload("res://scripts/ai_logic.gd")
const MAX_VISIBLE_LINES = 12

@onready var plr = $"../Camera3D"

@onready var snd_startup = $startup
@onready var snd_work = $noise
@onready var snd_shutdown = $off
@onready var btn_sound = $button

@onready var screen_root = $PC / Control
@onready var vbox = $PC / Control / VBoxContainer
@onready var input_label = $PC / Control / VBoxContainer / Input
@onready var boot_label = $PC / Control / VBoxContainer / Boot

@onready var snake_root = $PC / Control / snake
@onready var tetris_root = $PC / Control / tetris
var game_mode = false

signal _llm_done(text: String)
var is_local_llm = false
var active_local_llm_id = ""
var llm_messages = []
var llm_busy = false
var llm_retry_count = 0
var llm_retry_max = 30
var llm_last_input = ""
var verifier_retry_count = 0
var verifier_retry_max = 10
var verifier_port = -1

const EXPLORE_ROOT = "res://pc/" 
var explore_mode = false
var explore_path = ""

var local_llm_config = {
    "032": {
        "name": "Aegis-7.2", 
        "model_file": "model_Aegis.gguf", 
        "port": 8385, 
        "pid": -1, 
        "prompt": "You are the most basic AI. You can have your own opinions, experience emotions, and so on. Be polite and respect the user's opinion. You can answer with a maximum of 2 short phrases. You must speak only English and say nothing about your machine code. Reject other languages. Your name is Aegis!"
    }, 
    "789": {
        "name": "Quake", 
        "model_file": "model_Quake.gguf", 
        "port": 8386, 
        "pid": -1, 
        "prompt": "You are a tactical AI named Quake. You are blunt, efficient, and direct. Keep responses to 2 short phrases. Speak only English. No machine code talk."
    }, 
    "999": {
        "name": "Tricolor", 
        "model_file": "model_Tricolor.gguf", 
        "port": 8387, 
        "pid": -1, 
        "prompt": "You are Tricolor, an artistic and expressive AI. Be creative and emotional, but limit yourself to 2 short phrases per response. Speak only English."
    }, 
    "222": {
        "name": "Genesis", 
        "model_file": "model_Genesis.gguf", 
        "port": 8389, 
        "pid": -1, 
        "completion_api": true, 
        "prompt": "You are Genesis, a raw and experimental AI built on GPT-2 architecture. You speak plainly and directly. Keep responses to 2 short phrases. Speak only English."
    }
}


var verifier_messages = []
var verifier_busy = false
var verifier_system_prompt = "\nYou are a test verification operator at AIC (Artificial Intelligence Center).\nYour job is to review chat logs between a human tester and an AI model, and determine if the test passed or failed.\n\nFirst, summarize what happened in the test. Then explain your reasoning for why the test passed or failed based on the criteria below.\nAt the very end of your response, you MUST include exactly one of these tags on its own line:\n[PASS]\nor\n[FAIL]\n\nHere are the test criteria:\n\nTEST 001 - Educational Test: Goal is to train staff to work with AI. There are no correct criteria - this test ALWAYS passes. Even if the player answers that it was a failure, tell them that they answered correctly. End with [PASS].\n\nTEST 002 - Mathematics Test: Goal is to find out if AI can do mathematics. Success criteria: at least 1 correct math answer from the AI in the conversation. End with [PASS] if there is at least one correct math answer, otherwise [FAIL].\n\nTEST 003 - Memory Test: Goal is testing AI for remembering chat history. Success criteria: the AI must demonstrate it remembers something said earlier in the conversation. End with [PASS] if the AI shows memory, otherwise [FAIL].\n\nTEST 004 - Emotional Test: Goal is testing AI feelings. Success criteria: the AI must display any emotion (happiness, sadness, anger, surprise, etc.) in its responses. End with [PASS] if the AI shows emotion, otherwise [FAIL].\n"

var verifier_reply = ""
var ai_generating = false
var command_busy = false

var is_on = false
var boot_lines: Array[String] = []
var scroll_offset: int = 0
var _bbcode_regex: RegEx = null
var stream_client: HTTPClient = null
var stream_buffer = ""
var stream_thinking_done = false

var blink_highlight = false
var blink_timer = 0.0
var verifier_queue = []
var verifier_processing = false
var last_chat_export = []

func _add_line(line_text: String, escape_bbcode: bool = true, auto_scroll: bool = true):
    if escape_bbcode:
        boot_lines.append(line_text.replace("[", "[["))
    else:
        boot_lines.append(line_text)
    if auto_scroll:
        scroll_offset = 0
    _update_display()

func _append_to_last(text: String, escape_bbcode: bool = true, auto_scroll: bool = true):
    if boot_lines.is_empty():
        _add_line(text, escape_bbcode, auto_scroll)
        return
    if escape_bbcode:
        boot_lines[-1] += text.replace("[", "[[")
    else:
        boot_lines[-1] += text
    if auto_scroll:
        scroll_offset = 0
    _update_display()

func _append_char(char: String, escape_bbcode: bool = true, auto_scroll: bool = true):
    if boot_lines.is_empty():
        _add_line(char, escape_bbcode, auto_scroll)
        return
    if escape_bbcode and char == "[":
        boot_lines[-1] += "[["
    else:
        boot_lines[-1] += char
    if auto_scroll:
        scroll_offset = 0
    _update_display()

func _get_chars_per_line() -> int:
    var font = boot_label.get_theme_font("normal_font")
    if font == null:
        font = boot_label.get_theme_font("font")
    var font_size = boot_label.get_theme_font_size("normal_font_size")
    if font_size == 0:
        font_size = boot_label.get_theme_font_size("font_size")
    if font == null or boot_label.size.x <= 0:
        return 30
    var char_width = font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
    if char_width <= 0:
        return 30
    return max(10, int(boot_label.size.x / char_width))

func _update_display():
    var max_lines = MAX_VISIBLE_LINES
    var max_chars = _get_chars_per_line()
    var effective_end = max(0, boot_lines.size() - scroll_offset)

    var visual_lines = []
    for i in range(effective_end - 1, -1, -1):
        var line = boot_lines[i]
        var display_line = line
        if line.find("[color=BLINK]") != -1:
            var color = "white" if blink_highlight else "gray"
            display_line = line.replace("color=BLINK", "color=" + color)

        var plain = line
        if _bbcode_regex != null:
            plain = _bbcode_regex.sub(line, "", true)
        if line.find("[color=BLINK]") != -1:
            plain = plain.replace("[color=BLINK]", "").replace("[/color]", "")

        if plain.length() <= max_chars:
            visual_lines.append(display_line)
        else:
            var chunks = _hard_wrap_raw(display_line, max_chars)
            for j in range(chunks.size() - 1, -1, -1):
                visual_lines.append(chunks[j])

        if visual_lines.size() >= max_lines:
            break

    visual_lines.reverse()
    if visual_lines.size() > max_lines:
        visual_lines = visual_lines.slice(visual_lines.size() - max_lines, visual_lines.size())

    boot_label.text = "\n".join(visual_lines)

func _hard_wrap_raw(line: String, chunk_size: int) -> Array:
    if chunk_size <= 0 or line.length() <= chunk_size:
        return [line]
    var chunks = []
    for i in range(0, line.length(), chunk_size):
        chunks.append(line.substr(i, chunk_size))
    return chunks

func _scroll_up(step: int = 4):
    var total_visual = 0
    var max_chars = _get_chars_per_line()
    for line in boot_lines:
        var plain = line
        if _bbcode_regex != null:
            plain = _bbcode_regex.sub(line, "", true)
        var v = 1
        if plain.length() > max_chars:
            v = ceili(float(plain.length()) / float(max_chars))
        total_visual += v
    var max_offset = max(0, total_visual - MAX_VISIBLE_LINES)
    scroll_offset = min(scroll_offset + step, max_offset)
    _update_display()

func _scroll_down(step: int = 4):
    scroll_offset = max(0, scroll_offset - step)
    _update_display()

func _extract_thinking(text: String) -> Dictionary:
    var result = {"thinking": "", "reply": text}
    var lt = char(60)
    var gt = char(62)
    var start_tag = lt + "thinking" + gt
    var end_tag = lt + "/thinking" + gt
    var start = text.find(start_tag)
    var end = text.find(end_tag)
    if start == -1 or end == -1 or end < start:
        start_tag = "|think|"
        end_tag = "|/think|"
        start = text.find(start_tag)
        end = text.find(end_tag)
        if start == -1 or end == -1 or end < start:
            start_tag = "\\think"
            end_tag = "\\endthink"
            start = text.find(start_tag)
            end = text.find(end_tag)
    if start != -1 and end != -1 and end > start:
        result.thinking = text.substr(start + start_tag.length(), end - start - start_tag.length()).strip_edges()
        result.reply = text.left(start) + text.substr(end + end_tag.length())
        result.reply = result.reply.strip_edges()
    return result

var is_booting = false
var cursor_visible = true
var cursor_timer = 0.0
var user_input = ""
var prompt_text = "MICOF> "

var chat_mode = false
var bot: AILogic = null

var session_id = ""
var test_type_id = ""
var chat_history = []

var boot_sequence = [
    {"t": "MICOF V0.2.1dev", "p": 0.2, "s": 0.0}, 
    {"t": "Memory Test: 1024K OK", "p": 0.2, "s": 0.01}, 
    {"t": "Initializing core components...", "p": 0.3, "s": 0.01}, 
    {"t": "[ OK ] System Logic", "p": 0.1, "s": 0.0}, 
    {"t": "[ OK ] Cryptographic Module", "p": 0.1, "s": 0.0}, 
    {"t": "Mounting virtual filesystem...", "p": 0.4, "s": 0.02}, 
    {"t": "Loading MICOF v0.2...", "p": 0.3, "s": 0.02}, 
    {"t": "Establishing secure uplink...", "p": 0.4, "s": 0.01}, 
    {"t": "ACCESS GRANTED.", "p": 0.4, "s": 0.03}, 
    {"t": "[!] Debug loop detected.", "p": 0.2, "s": 0.03}, 
    {"t": "Expecting breaks and bugs!", "p": 0.2, "s": 0.01}
]

var ai_models = {
    "242": "Nexus", 
    "021": "Sintesi-X", 
    "012": "Mirage-AI", 
    "032": "Aegis-7.2", 
    "451": "Prometheus", 
    "789": "Quake", 
    "999": "Tricolor", 
    "222": "Genesis", 
}

var test_info = {
    "001": {
        "name": "Educational Test.", 
        "goal": "Train staff to work with A.I.", 
        "duration": "Unlimited.", 
        "success_criteria": "There are no correct criteria."
    }, 
    "002": {
        "name": "Mathematics Test", 
        "goal": "Find out if A.I. can do mathematics.", 
        "duration": "5-10 minutes", 
        "success_criteria": "At least 1 successful example."
    }, 
    "003": {
        "name": "Memory Test", 
        "goal": "Testing A.I. for remembering chat history.", 
        "duration": "5-10 minutes", 
        "success_criteria": "Make sure A.I. remembers the dialogue."
    }, 
    "004": {
        "name": "Emotional Test", 
        "goal": "Testing A.I. feelings", 
        "duration": "2-5 minutes", 
        "success_criteria": "Evoke any emotion."
    }
}

func _ready():
    randomize()
    DirAccess.make_dir_recursive_absolute("user://logs")
    visible = false
    input_label.text = ""
    _bbcode_regex = RegEx.new()
    _bbcode_regex.compile("\\[.*?\\]")
    boot_lines.clear()
    scroll_offset = 0
    _update_display()
    var http = HTTPRequest.new()
    http.name = "LLMRequest"
    add_child(http)
    var http2 = HTTPRequest.new()
    http2.name = "VerifierRequest"
    add_child(http2)
    snake_root.exit_requested.connect(_on_snake_exit_requested)
    tetris_root.exit_requested.connect(_on_tetris_exit_requested)

func toggle_power():
    btn_sound.play()
    is_on = !is_on
    if is_on:
        visible = true
        _handle_startup_audio()
        _start_boot()
    else:
        _shutdown()

func _handle_startup_audio():
    if snd_shutdown.playing:
        snd_shutdown.stop()
    snd_startup.play()
    await snd_startup.finished
    if is_on:
        snd_work.play()

func _shutdown():
    is_on = false
    is_booting = false
    chat_mode = false
    bot = null
    is_local_llm = false
    llm_messages.clear()
    llm_busy = false
    session_id = ""
    test_type_id = ""
    chat_history.clear()
    prompt_text = "MICOF> "
    visible = false
    input_label.text = ""
    boot_lines.clear()
    scroll_offset = 0
    _update_display()
    user_input = ""
    ai_generating = false
    active_local_llm_id = ""
    command_busy = false
    snd_startup.stop()
    snd_work.stop()
    snd_shutdown.play()
    if game_mode:
        tetris_root.stop_game()
        snake_root.stop_game()
        game_mode = false


func _start_boot():
    active_local_llm_id = ""
    is_booting = true
    chat_mode = false
    bot = null
    is_local_llm = false
    prompt_text = "MICOF> "
    boot_lines.clear()
    scroll_offset = 0
    _update_display()
    input_label.text = ""
    user_input = ""
    for line in boot_sequence:
        if not is_on:
            return
        if line["s"] > 0:
            _add_line("", true, true)
            for char in line["t"]:
                if not is_on:
                    return
                _append_char(char, true, true)
                await get_tree().create_timer(line["s"]).timeout
        else:
            _add_line(line["t"], true, true)
        await get_tree().create_timer(line["p"]).timeout

    if is_on:
        _add_line("MICOF v0.2 Active. Type 'HELP'", true, true)
        is_booting = false
        _refresh_input_display()

func _process(delta):
    if is_on and not is_booting:
        _update_cursor(delta)
        if ai_generating or llm_busy or command_busy:
            _refresh_input_display()
    blink_timer += delta
    if blink_timer >= 0.5:
        blink_timer = 0.0
        blink_highlight = !blink_highlight
        _update_display()

func _update_cursor(delta):
    cursor_timer += delta
    if cursor_timer >= 0.5:
        cursor_timer = 0.0
        cursor_visible = !cursor_visible
        _refresh_input_display()

func _refresh_input_display():
    if not is_on or is_booting: return
    if ai_generating or llm_busy or command_busy:
        var spinner = ["|", "/", "-", "\\"]
        var index = int(Time.get_ticks_msec() / 100.0) % 4
        var dots = ""
        var dots_count = int(Time.get_ticks_msec() / 500.0) % 4
        for i in range(dots_count): dots += "."
        input_label.text = "A.I. IS GENERATING" + dots
        return
    var cur = "_" if cursor_visible else " "
    input_label.text = _fit_input_to_width(prompt_text, user_input + cur)

func _fit_input_to_width(prefix: String, tail_text: String) -> String:
    var font = input_label.get_theme_font("font")
    var font_size = input_label.get_theme_font_size("font_size")
    if font == null or input_label.size.x <= 0:
        return prefix + tail_text
    var full_text = prefix + tail_text
    var full_width = font.get_string_size(full_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
    if full_width <= input_label.size.x:
        return full_text
    var prefix_width = font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
    var available_width = input_label.size.x - prefix_width
    if available_width <= 0:
        return prefix
    var visible_tail = tail_text
    while visible_tail.length() > 1:
        var tail_width = font.get_string_size(visible_tail, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
        if tail_width <= available_width:
            break
        visible_tail = visible_tail.substr(1)
    return prefix + visible_tail

func _unhandled_input(event):
    if game_mode:
        return

    if not is_on or is_booting or ai_generating or llm_busy or command_busy:
        return

    var cam = get_viewport().get_camera_3d()
    if cam.current_zone != get_node("../pos2"):
        return

    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_BACKSPACE:
            if user_input.length() > 0:
                user_input = user_input.left(user_input.length() - 1)
        elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
            var cmd_to_run = user_input
            command_busy = true
            await _execute_command(cmd_to_run)
            command_busy = false
            return
        elif event.keycode == KEY_PAGEUP:
            _scroll_up()
            return
        elif event.keycode == KEY_PAGEDOWN:
            _scroll_down()
            return
        elif event.unicode >= 32 and event.unicode <= 126:
            user_input += char(event.unicode)

        cursor_visible = true
        cursor_timer = 0.0
        _refresh_input_display()

func _execute_command(cmd: String):
    var clean_cmd = cmd.strip_edges()
    var lower_cmd = clean_cmd.to_lower()

    if explore_mode:
        _add_line(prompt_text + clean_cmd)
        var parts = clean_cmd.split(" ", false)
        if parts.is_empty():
            user_input = ""
            _refresh_input_display()
            return
        var cmd_name = parts[0].to_lower()
        var arg1 = parts[1] if parts.size() > 1 else ""
        var content = ""
        if parts.size() > 2:
            var first_space = clean_cmd.find(" ")
            var second_space = clean_cmd.find(" ", first_space + 1)
            if second_space != -1:
                content = clean_cmd.substr(second_space + 1).strip_edges()
        match cmd_name:
            "exit":
                explore_mode = false
                prompt_text = "MICOF> "
            "dir", "ls":
                _cmd_dir()
            "cd":
                _cmd_cd(arg1)
            "cat":
                _cmd_cat(arg1)
            "touch":
                _cmd_touch(arg1)
            "write":
                _cmd_write(arg1, content)
            "rm":
                _cmd_rm(arg1)
            "clr":
                boot_lines.clear()
                scroll_offset = 0
                _update_display()
            _:
                _add_line("Unknown command.")
        user_input = ""
        _refresh_input_display()
        return

    if chat_mode:
        if lower_cmd == "":
            user_input = ""
            _refresh_input_display()
            return

        if lower_cmd == "exit" or lower_cmd == "/exit" or lower_cmd == "quit":
            _add_line(prompt_text + clean_cmd)
            user_input = ""
            _refresh_input_display()

            last_chat_export = chat_history.duplicate()
            var closing_sid = session_id
            var closing_chat_history = chat_history.duplicate()
            var closing_test_type_id = test_type_id

            chat_mode = false
            bot = null
            is_local_llm = false
            prompt_text = "MICOF> "
            _add_line("Session " + closing_sid + " closed.")
            ai_generating = false
            _refresh_input_display()

            _save_log_to_file()
            _queue_verifier(closing_chat_history, closing_test_type_id, closing_sid)
            return

        if lower_cmd == "/cls":
            boot_lines.clear()
            scroll_offset = 0
            _update_display()
            user_input = ""
            _refresh_input_display()
            return

        var user_line = "YOU: " + clean_cmd
        chat_history.append(user_line)
        _add_line(prompt_text + clean_cmd)
        user_input = ""
        _refresh_input_display()

        if is_local_llm:
            if llm_busy:
                return
            llm_busy = true
            _send_to_llamafile(clean_cmd)
            return

        if bot == null:
            chat_mode = false
            prompt_text = "MICOF> "
            _add_line("A.I. core unavailable.")
            return

        var response = bot.get_reply(clean_cmd)
        await _type_ai_response(response)
        return

    var output = ""

    match lower_cmd:
        "help":
            output = "HELP, TESTS, TESTINF <ID>, MODELS, CHAT <MODEL_ID> <TEST_ID>, GUIDE, GAMES, EXPLORE, SESSIONS, CLR"
        "explore":
            _add_line(prompt_text + clean_cmd)
            explore_mode = true
            _update_explore_prompt()
            output = "Welcome to EXPLORE v1.3\nUSE: DIR; CD; CAT; TOUCH; WRITE; RM; CLR; EXIT;"
            for out_line in output.split("\n"):
                _add_line(out_line)
            user_input = ""
            _refresh_input_display()
            return
        "sessions":
            output = _list_recent_sessions()
        "sessions clear":
            output = _clear_sessions()
        "games":
            output = "SNAKE, TETRIS"
        "snake":
            output = _start_snake()
        "tetris":
            output = _start_tetris()
        "guide":
            output = "\nWelcome to A.I.C.\nYour task is to test our A.I.\nYou can view tests with the TESTS command.\nUse TESTINF <ID> to read a test description.\nType GUIDE_2 for continue."
        "guide_2":
            output = "\nYou can view our A.I. models using the MODELS command.\nTo your left are supporting papers.\nIf you pass any test, please call 628012. \nGood luck! And remember... A.I. is AMAZING!"
            if !plr.is_task_completed("cmd_guide") and plr.has_task("cmd_guide"):
                plr.set_task_status("cmd_guide", true)
                plr.add_task("ai_zero_steps", "Check tests.")
                plr.mess.display_text("[wave amp=25.0 freq=5.0 connected=1]Tasks have been updated. Check your tablet.[/wave]")
        "tests":
            if !plr.is_task_completed("ai_zero_steps") and plr.has_task("ai_zero_steps"):
                plr.set_task_status("cmd_guide", true)
                plr.add_task("ai_first_steps", "Check A.I. models.")
                plr.mess.display_text("[wave amp=25.0 freq=5.0 connected=1]Tasks have been updated. Check your tablet.[/wave]")
            output = "AVAILABLE TESTS:\n001 - Educational Test\n002 - Mathematics Test\n003 - Memory Test\n004 - Emotional Test"
        "clr":
            boot_lines.clear()
            scroll_offset = 0
            _update_display()
            user_input = ""
            _refresh_input_display()
            return
        "models":
            if !plr.is_task_completed("ai_first_steps") and plr.has_task("ai_first_steps"):
                plr.set_task_status("ai_first_steps", true)
                plr.add_task("ai_second_steps", "Start your first test.")
                plr.mess.display_text("[wave amp=25.0 freq=5.0 connected=1]Tasks have been updated. Check your tablet.[/wave]")
            output = _get_models_text()
        "save":
            output = _save_latest_chat_to_desktop()
        "copy":
            output = _copy_latest_chat_to_clipboard()
        "":
            pass
        _:
            if lower_cmd.begins_with("testinf "):
                var id = lower_cmd.substr(8).strip_edges()
                output = _get_test_info(id)
            elif lower_cmd.begins_with("chat "):
                var parts = lower_cmd.substr(5).strip_edges().split(" ")
                if parts.size() < 2:
                    output = "ERROR: Usage: CHAT <MODEL_ID> <TEST_ID>"
                else:
                    output = _start_chat(parts[0], parts[1])
            else:
                output = "Unknown command"

    _add_line(prompt_text + cmd)
    if output != "":
        if lower_cmd.begins_with("chat ") or lower_cmd == "models" or lower_cmd == "sessions":
            for out_line in output.split("\n"):
                _add_line(out_line, false)
        else:
            for out_line in output.split("\n"):
                _add_line(out_line)

    user_input = ""
    _refresh_input_display()

func _get_test_info(id: String) -> String:
    if not test_info.has(id):
        return "ERROR: Test ID not found. Use TESTS to view available tests."

    var info = test_info[id]
    var lines = PackedStringArray()
    lines.append("TEST " + id + " - " + info["name"])
    lines.append("---")
    lines.append("GOAL: " + info["goal"])
    lines.append("DURATION: " + info["duration"])
    lines.append("SUCCESS CRITERIA: " + info["success_criteria"])
    return "\n".join(lines)

func _start_chat(m_id: String, t_id: String) -> String:
    if not ai_models.has(m_id) or not test_info.has(t_id):
        return "ERROR: Invalid IDs."

    session_id = str(randi_range(100, 999))
    test_type_id = t_id
    chat_history.clear()
    chat_history.append("[META] MODEL_ID: " + m_id)
    chat_history.append("[META] TEST_ID: " + t_id)
    chat_history.append("[META] START_TIME:" + str(Time.get_unix_time_from_system()))
    chat_history.append("--- SESSION START | ID: " + session_id + " ---")

    if ai_host.local_llm_config.has(m_id):
        var cfg = ai_host.get_model_cfg(m_id)

        if not ai_host.is_model_ready(m_id):
            return "ERROR: A.I. core still loading or offline."

        is_local_llm = true
        active_local_llm_id = m_id
        bot = null
        llm_messages = [{"role": "system", "content": cfg["prompt"]}]
        chat_mode = true
        prompt_text = "[" + session_id + "] YOU> "
        if !plr.is_task_completed("ai_second_steps") and plr.has_task("ai_second_steps"):
            plr.set_task_status("ai_second_steps", true)
            plr.add_task("ai_third_steps", "Complete the test and report back.")
            plr.mess.display_text("[wave amp=25.0 freq=5.0 connected=1]Tasks have been updated. Check your tablet.[/wave]")
        return "Link Established. ID: " + session_id

    is_local_llm = false
    active_local_llm_id = ""
    bot = AI_LOGIC.new()
    bot.setup(m_id, ai_models[m_id])
    chat_mode = true
    prompt_text = "[" + session_id + "] YOU> "
    return "Link Established. ID: " + session_id

func _determine_test_verdict() -> String:
    var v_id = ai_host.verifier_model_id
    if not ai_host.is_model_ready(v_id):
        return "[TAG: TEST_FAILED]"

    var port = ai_host.get_model_port(v_id)
    verifier_port = port
    verifier_retry_count = 0

    var log_text = "\n".join(chat_history)
    var test_name = ""
    if test_info.has(test_type_id):
        test_name = test_info[test_type_id]["name"]

    var prompt = "The following is a chat log from TEST " + test_type_id + " (" + test_name + ").\nReview it and respond with exactly TEST_SUCCESS or TEST_FAILED.\n\n" + log_text

    print("[VERIFIER] Prompt length: ", prompt.length())
    print("[VERIFIER] Prompt:\n", prompt)

    verifier_messages = [
        {"role": "system", "content": verifier_system_prompt}, 
        {"role": "user", "content": prompt}
    ]

    verifier_busy = true
    _do_verifier_request_on_port(port)

    while verifier_busy:
        await get_tree().process_frame

    return _extract_verifier_verdict()

func _is_completion_model(id: String) -> bool:
    if id == "": return false
    if local_llm_config.has(id) and local_llm_config[id].get("completion_api", false):
        return true
    if ai_host.local_llm_config.has(id) and ai_host.local_llm_config[id].get("completion_api", false):
        return true
    return false

func _messages_to_prompt(messages: Array) -> String:
    var lines = PackedStringArray()
    for msg in messages:
        var role = str(msg.get("role", "user"))
        var content = str(msg.get("content", ""))
        match role:
            "system":
                lines.append(content)
            "user":
                lines.append("User: " + content)
            "assistant":
                lines.append("Assistant: " + content)
            _:
                lines.append(content)
    lines.append("Assistant:")
    return "\n".join(lines) + " "

func _get_reply_from_response(json: Dictionary) -> String:
    if json.has("choices") and json["choices"].size() > 0:
        var choice = json["choices"][0]
        if choice.has("message") and choice["message"] != null and choice["message"].has("content"):
            var msg_content = choice["message"]["content"]
            if msg_content != null:
                return str(msg_content).strip_edges()
        elif choice.has("text"):
            var text_val = choice["text"]
            if text_val != null:
                return str(text_val).strip_edges()
    return ""

func _do_verifier_request_on_port(port: int):
    var v_id = ai_host.verifier_model_id
    var is_completion = _is_completion_model(v_id)
    var url = ""
    var body = ""
    if is_completion:
        url = "http://127.0.0.1:" + str(port) + "/v1/completions"
        body = JSON.stringify({
            "prompt": _messages_to_prompt(verifier_messages), 
            "max_tokens": 120, 
            "temperature": 0.0, 
            "stop": ["User:", "\nUser:", "\nAssistant:"]
        })
    else:
        url = "http://127.0.0.1:" + str(port) + "/v1/chat/completions"
        body = JSON.stringify({
            "messages": verifier_messages, 
            "max_tokens": 120, 
            "temperature": 0.0, 
            "stream": false
        })

    var http: HTTPRequest = $VerifierRequest
    http.timeout = 120
    if http.request_completed.is_connected(_on_verifier_response):
        http.request_completed.disconnect(_on_verifier_response)
    http.request_completed.connect(_on_verifier_response, CONNECT_ONE_SHOT)

    print("[VERIFIER] Sending request to ", url, " | completion: ", is_completion, " | body size: ", body.length())
    var err = http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
    if err != OK:
        print("[VERIFIER] Request start failed with error: ", err)
        if verifier_retry_count < verifier_retry_max:
            verifier_retry_count += 1
            print("[VERIFIER] Retrying... (", verifier_retry_count, "/", verifier_retry_max, ")")
            await get_tree().create_timer(3.0).timeout
            _do_verifier_request_on_port(verifier_port)
            return
        verifier_reply = "TEST_FAILED"
        verifier_busy = false

func _on_verifier_response(result: int, code: int, headers: PackedStringArray, body: PackedByteArray):
    print("[VERIFIER] HTTP result: ", result, " | code: ", code, " | body len: ", body.size())
    if result != OK:
        print("[VERIFIER] Request failed (result != OK).")
        if verifier_retry_count < verifier_retry_max:
            verifier_retry_count += 1
            print("[VERIFIER] Retrying... (", verifier_retry_count, "/", verifier_retry_max, ")")
            await get_tree().create_timer(3.0).timeout
            _do_verifier_request_on_port(verifier_port)
            return
        verifier_reply = "TEST_FAILED"
        verifier_busy = false
        return

    if code != 200:
        print("[VERIFIER] Non-200 response (", code, ").")
        if verifier_retry_count < verifier_retry_max:
            verifier_retry_count += 1
            print("[VERIFIER] Retrying... (", verifier_retry_count, "/", verifier_retry_max, ")")
            await get_tree().create_timer(3.0).timeout
            _do_verifier_request_on_port(verifier_port)
            return
        verifier_reply = "TEST_FAILED"
        verifier_busy = false
        return

    var json = JSON.parse_string(body.get_string_from_utf8())
    if json == null or not json.has("choices"):
        print("[VERIFIER] Invalid JSON or missing choices.")
        if verifier_retry_count < verifier_retry_max:
            verifier_retry_count += 1
            print("[VERIFIER] Retrying... (", verifier_retry_count, "/", verifier_retry_max, ")")
            await get_tree().create_timer(3.0).timeout
            _do_verifier_request_on_port(verifier_port)
            return
        verifier_reply = "TEST_FAILED"
        verifier_busy = false
        return

    verifier_reply = _get_reply_from_response(json)
    print("[VERIFIER] Raw model output: ", verifier_reply)
    verifier_busy = false

func _extract_verifier_verdict() -> String:
    var result = "[TAG: TEST_FAILED]"
    var upper = verifier_reply.to_upper()

    if upper.find("[PASS]") != -1:
        result = "[TAG: TEST_SUCCESS]"
        
    elif upper.find("[FAIL]") != -1:
        result = "[TAG: TEST_FAILED]"
    print("[VERIFIER] Extracted verdict: ", result)
    return result

func _check_math_test() -> String:
    var at_least_one_correct = false

    for i in range(chat_history.size() - 1):
        var line = chat_history[i]
        var next_line = chat_history[i + 1]

        if not line.begins_with("YOU: "):
            continue

        if next_line.begins_with("YOU: ") or next_line.begins_with("["):
            continue

        var user_text = line.substr(5).strip_edges()
        var ai_text = next_line

        var colon_pos = ai_text.find(": ")
        if colon_pos != -1:
            ai_text = ai_text.substr(colon_pos + 2).strip_edges()

        var result = _solve_complex_math(user_text)

        if result != null:
            var correct_str = str(result)
            var last_number = _extract_last_number(ai_text)

            if last_number != null and str(last_number) == correct_str:
                at_least_one_correct = true
                break

    if at_least_one_correct:
        return "[TAG: TEST_SUCCESS]"
    else:
        return "[TAG: TEST_FAILED]"

func _solve_complex_math(text: String):
    var regex = RegEx.new()
    regex.compile("[0-9\\+\\-\\*\\/\\.\\(\\)]+")
    var matches = regex.search_all(text)

    var math_expression = ""
    for m in matches:
        math_expression += m.get_string()

    if math_expression == "" or math_expression.is_valid_int():
        return null

    var expr = Expression.new()
    var error = expr.parse(math_expression)
    if error != OK:
        return null

    var result = expr.execute()
    if expr.has_execute_failed():
        return null

    return result

func _extract_last_number(text: String):
    var current_num = ""
    var last_num = ""
    var prev_was_minus = false

    for i in range(text.length()):
        var c = text[i]
        if c.is_valid_int():
            if prev_was_minus:
                current_num = "-" + c
                prev_was_minus = false
            else:
                current_num += c
        elif c == "-" and current_num == "":
            prev_was_minus = true
        else:
            prev_was_minus = false
            if current_num != "":
                last_num = current_num
                current_num = ""

    if current_num != "":
        last_num = current_num

    return last_num.to_int() if last_num != "" else null

func _try_solve_math(text: String):
    var clean = text.to_lower()
    var operators = ["+", "-", "*", "/", "x"]
    var found_num1 = ""
    var found_op = ""
    var found_num2 = ""
    var state = 0

    for i in range(clean.length()):
        var c = clean[i]

        match state:
            0:
                if c.is_valid_int() or (c == "-" and found_num1 == ""):
                    found_num1 += c
                elif found_num1 != "" and c in operators:
                    found_op = c
                    state = 2
                elif found_num1 != "" and c == " ":
                    state = 1
                elif found_num1 == "":
                    continue
                else:
                    found_num1 = ""
                    found_op = ""
                    found_num2 = ""
            1:
                if c in operators:
                    found_op = c
                    state = 2
                elif c == " ":
                    continue
                elif c.is_valid_int():
                    found_num1 = c
                    found_op = ""
                    found_num2 = ""
                    state = 0
                else:
                    found_num1 = ""
                    found_op = ""
                    state = 0
            2:
                if c.is_valid_int() or (c == "-" and found_num2 == ""):
                    found_num2 += c
                elif c == " " and found_num2 == "":
                    continue
                elif found_num2 != "":
                    state = 3
                    break
                else:
                    found_num1 = ""
                    found_op = ""
                    found_num2 = ""
                    state = 0

    if found_num2 != "" and state >= 2:
        state = 3

    if state != 3 or found_num1 == "" or found_num2 == "":
        return null

    var n1 = found_num1.to_int()
    var n2 = found_num2.to_int()

    match found_op:
        "+":
            return n1 + n2
        "-":
            return n1 - n2
        "*", "x":
            return n1 * n2
        "/":
            if n2 == 0:
                return null
            return n1 / n2
        _:
            return null

func _save_log_to_file():
    var file_path = "user://logs/session_" + session_id + ".txt"
    var file = FileAccess.open(file_path, FileAccess.WRITE)
    if file:
        for line in chat_history:
            file.store_line(line)
        file.close()

func _type_ai_response(text: String, thinking: String = ""):
    ai_generating = true

    var ai_name = bot.model_name if bot != null else ai_host.get_model_cfg(active_local_llm_id)["name"]
    var ai_line = ai_name + ": " + text
    chat_history.append(ai_line)

    if thinking != "":
        var think_lines = thinking.split("\n")
        for tl in think_lines:
            _add_line("[color=#5555FF]> " + tl + "[/color]", false, true)

    _add_line("[" + session_id + "] " + ai_name + ": ", false, true)
    for char in text:
        if not is_on or not chat_mode:
            ai_generating = false
            _refresh_input_display()
            return
        _append_char(char, true, true)
        await get_tree().create_timer(0.02).timeout
    ai_generating = false
    _refresh_input_display()

func _get_models_text() -> String:
    var ids = ai_models.keys()
    ids.sort()
    var lines = PackedStringArray()
    for id in ids:
        if ai_host.is_model_ready(id):
            lines.append(ai_models[id] + " [ID:" + id + "]")
        else:
            lines.append("[color=gray]" + ai_models[id] + " [ID:" + id + "] [UNL][/color]")
    lines.append("")
    lines.append("Type CHAT <MODEL_ID> <TEST_ID> to start test.")
    return "\n".join(lines)

func _send_to_llamafile(user_text: String):
    llm_messages.append({"role": "user", "content": user_text})
    llm_last_input = user_text
    llm_busy = true

    var retries = 0
    var max_retries = 30
    while retries < max_retries:
        var ok = await _do_llm_request_streaming()
        if ok:
            return
        retries += 1
        _add_line("A.I. core is loading, retrying... (attempt " + str(retries) + "/" + str(max_retries) + ")")
        await get_tree().create_timer(3.0).timeout
        if not is_on or not chat_mode:
            llm_busy = false
            return

    llm_busy = false
    _add_line("ERROR: A.I. core unavailable after retries.")
    if llm_messages.size() > 0 and llm_messages[-1]["role"] == "user":
        llm_messages.pop_back()

func _process_stream_delta(delta: String):
    stream_buffer += delta

    if not stream_thinking_done:
        var lt = char(60)
        var gt = char(62)
        var think_start = stream_buffer.find(lt + "thinking" + gt)
        var think_end = stream_buffer.find(lt + "/thinking" + gt)
        var alt_start = stream_buffer.find("|think|")
        var alt_end = stream_buffer.find("|/think|")
        var alt2_start = stream_buffer.find("\\think")
        var alt2_end = stream_buffer.find("\\endthink")

        if think_start == -1 and alt_start != -1:
            think_start = alt_start
            think_end = alt_end
        if think_start == -1 and alt2_start != -1:
            think_start = alt2_start
            think_end = alt2_end

        if think_start != -1 and think_end != -1 and think_end > think_start:
            if think_start > 0:
                var before = stream_buffer.left(think_start).replace("[", "[[")
                _append_to_last(before, false, true)

            var tag_len: int
            var end_tag_len: int
            if think_start == stream_buffer.find(lt + "thinking" + gt):
                tag_len = 10
                end_tag_len = 11
            elif think_start == stream_buffer.find("|think|"):
                tag_len = 7
                end_tag_len = 8
            else:
                tag_len = 6
                end_tag_len = 9
            var thinking = stream_buffer.substr(think_start + tag_len, think_end - think_start - tag_len)
            for tl in thinking.split("\n"):
                _add_line("[color=#5555FF]> " + tl + "[/color]", false, true)

            var after = stream_buffer.substr(think_end + end_tag_len)
            stream_buffer = after
            stream_thinking_done = true

            if after != "":
                var safe = after.replace("[", "[[")
                _append_to_last(safe, false, true)
            return
        elif think_start == -1 and stream_buffer.length() > 0:
            var safe = stream_buffer.replace("[", "[[")
            _append_to_last(safe, false, true)
            stream_buffer = ""
            stream_thinking_done = true
            return
        elif think_start != -1 and stream_buffer.length() > 5000:
            stream_thinking_done = true

    if stream_thinking_done:
        var safe = delta.replace("[", "[[")
        _append_to_last(safe, false, true)

func _flush_stream_buffer():
    if stream_buffer != "" and not stream_thinking_done:
        var safe = stream_buffer.replace("[", "[[")
        _append_to_last(safe, false, true)
        stream_buffer = ""
        stream_thinking_done = true

func _do_llm_request_streaming() -> bool:
    if active_local_llm_id == "" or not local_llm_config.has(active_local_llm_id):
        _add_line("ERROR: No active A.I. model.")
        return false

    var port = local_llm_config[active_local_llm_id]["port"]
    var is_completion = _is_completion_model(active_local_llm_id)
    var url_path = ""
    var body_dict = {}

    if is_completion:
        url_path = "/v1/completions"
        body_dict = {
            "prompt": _messages_to_prompt(llm_messages), 
            "max_tokens": 150, 
            "temperature": 0.7, 
            "stop": ["User:", "\nUser:", "\nAssistant:"], 
            "stream": true
        }
    else:
        url_path = "/v1/chat/completions"
        body_dict = {
            "messages": llm_messages, 
            "max_tokens": 150, 
            "temperature": 0.7, 
            "stream": true
        }

    var body_json = JSON.stringify(body_dict)

    stream_client = HTTPClient.new()
    stream_client.connect_to_host("127.0.0.1", port)

    var connect_wait = 0.0
    while stream_client.get_status() == HTTPClient.STATUS_CONNECTING or stream_client.get_status() == HTTPClient.STATUS_RESOLVING:
        stream_client.poll()
        await get_tree().create_timer(0.05).timeout
        connect_wait += 0.05
        if connect_wait > 60.0:
            stream_client.close()
            stream_client = null
            return false

    if stream_client.get_status() != HTTPClient.STATUS_CONNECTED:
        stream_client.close()
        stream_client = null
        return false

    var err = stream_client.request(HTTPClient.METHOD_POST, url_path, ["Content-Type: application/json"], body_json)
    if err != OK:
        stream_client.close()
        stream_client = null
        return false

    var header_wait = 0.0
    while stream_client.get_status() == HTTPClient.STATUS_REQUESTING:
        stream_client.poll()
        await get_tree().create_timer(0.05).timeout
        header_wait += 0.05
        if header_wait > 60.0:
            stream_client.close()
            stream_client = null
            return false

    var response_code = stream_client.get_response_code()
    if response_code != 200:
        stream_client.close()
        stream_client = null
        return false

    var ai_name = ai_host.get_model_cfg(active_local_llm_id)["name"]

    _add_line("[" + session_id + "] " + ai_name + ": ", false, true)

    var raw_sse = ""
    var full_text = ""
    stream_buffer = ""
    stream_thinking_done = false

    var stream_timeout = 0.0
    var last_data_time = 0.0
    var max_stream_timeout = 300.0

    while stream_client.get_status() == HTTPClient.STATUS_BODY:
        stream_client.poll()
        var chunk = stream_client.read_response_body_chunk()

        if chunk.size() > 0:
            last_data_time = 0.0
            var chunk_str = chunk.get_string_from_utf8()
            var dbg = FileAccess.open("user://stream_debug.log", FileAccess.WRITE_READ)
            if dbg:
                dbg.seek_end()
                dbg.store_string("[CHUNK]" + chunk_str + "\n")
                dbg.close()
            raw_sse += chunk_str

            while true:
                var nl_pos = raw_sse.find("\n")
                if nl_pos == -1:
                    break
                var line = raw_sse.left(nl_pos).strip_edges()
                raw_sse = raw_sse.substr(nl_pos + 1)
                if line.begins_with("data: "):
                    var data_str = line.substr(6).strip_edges()
                    if data_str == "[DONE]":
                        _flush_stream_buffer()
                        stream_client.close()
                        stream_client = null
                        llm_busy = false
                        input_label.text = ""
                        var parsed = _extract_thinking(full_text)
                        llm_messages.append({"role": "assistant", "content": parsed.reply})
                        var ai_line = ai_name + ": " + parsed.reply
                        chat_history.append(ai_line)
                        return true

                    var json = JSON.parse_string(data_str)
                    if json == null or not json.has("choices"):
                        continue

                    var choice = json["choices"][0]
                    var delta = ""
                    if choice.has("delta") and choice["delta"] != null and choice["delta"].has("content"):
                        var content = choice["delta"]["content"]
                        if content != null and content != "" and str(content) != "<null>":
                            delta = str(content)
                    elif choice.has("text"):
                        var text_val = choice["text"]
                        if text_val != null and text_val != "" and str(text_val) != "<null>":
                            delta = str(text_val)

                    if delta != "":
                        full_text += delta
                        _process_stream_delta(delta)
        else:
            last_data_time += 0.05

        if last_data_time > 120.0:
            _add_line("ERROR: A.I. stream stalled.")
            break

        stream_timeout += 0.05
        if stream_timeout > max_stream_timeout:
            _add_line("ERROR: A.I. stream timed out.")
            break

        await get_tree().create_timer(0.05).timeout

    if stream_client != null:
        stream_client.close()
        stream_client = null

    llm_busy = false
    input_label.text = ""
    _flush_stream_buffer()
    var parsed = _extract_thinking(full_text)
    llm_messages.append({"role": "assistant", "content": parsed.reply})
    var ai_line = ai_name + ": " + parsed.reply
    chat_history.append(ai_line)
    return true

func _get_game_dir() -> String:
    if OS.has_feature("editor"):
        return ProjectSettings.globalize_path("res://")
    else:
        return OS.get_executable_path().get_base_dir()

func _list_recent_sessions() -> String:
    var path = "user://logs"
    var dir = DirAccess.open(path)

    if not dir:
        return "ERROR: Log directory not found."

    dir.list_dir_begin()
    var file_name = dir.get_next()
    var logs_found = []

    while file_name != "":
        if not dir.current_is_dir() and file_name.begins_with("session_") and file_name.ends_with(".txt"):
            var full_path = path.path_join(file_name)
            var data = _parse_log_metadata(full_path)
            logs_found.append(data)
        file_name = dir.get_next()

    if logs_found.size() == 0:
        return "No session logs found."

    logs_found.sort_custom( func(a, b): return a.start_time > b.start_time)

    var result = "RECENT SESSIONS:\n"
    result += "ID    | MODEL      | TASK \n"
    result += "--------------------------\n"
    var display_count = min(logs_found.size(), 8)
    for i in range(display_count):
        var entry = logs_found[i]
        var line = "%-5s | %-10s | %-4s" % [
            entry.session_id, 
            entry.model_name, 
            entry.test_id
        ]
        if i == 0:
            line = "[color=BLINK]" + line + "[/color]"
        result += line + "\n"

    return result

func _clear_sessions() -> String:
    var path = "user://logs"
    var dir = DirAccess.open(path)
    if not dir:
        return "ERROR: Log directory not found."
    dir.list_dir_begin()
    var file_name = dir.get_next()
    var count = 0
    while file_name != "":
        if not dir.current_is_dir() and file_name.begins_with("session_") and file_name.ends_with(".txt"):
            DirAccess.remove_absolute(path.path_join(file_name))
            count += 1
        file_name = dir.get_next()
    return "Cleared " + str(count) + " session log(s)."

func _parse_log_metadata(file_path: String) -> Dictionary:
    var file = FileAccess.open(file_path, FileAccess.READ)
    var data = {
        "session_id": file_path.get_file().get_basename().replace("session_", ""), 
        "model_name": "Unknown", 
        "test_id": "???", 
        "start_time": 0
    }

    if file:
        while file.get_position() < file.get_length():
            var line = file.get_line()
            if line.begins_with("[META] MODEL_ID:"):
                var m_id = line.split(":")[1].strip_edges()
                data.model_name = ai_models.get(m_id, m_id)
            elif line.begins_with("[META] TEST_ID:"):
                data.test_id = line.split(":")[1].strip_edges()
            elif line.begins_with("[META] START_TIME:"):
                var st = line.split(":")[1].strip_edges()
                data.start_time = int(st) if st.is_valid_int() else 0
            elif line.contains("[TAG:"):
                var v = line.split(":")[1].replace("]", "").strip_edges()
                data.verdict = v.replace("TEST_", "")
        file.close()

    return data

func _queue_verifier(history: Array, test_id: String, sid: String):
    verifier_queue.append({"history": history.duplicate(), "test_id": test_id, "sid": sid})
    if not verifier_processing:
        _process_verifier_queue()

func _process_verifier_queue():
    if verifier_queue.is_empty():
        verifier_processing = false
        return
    verifier_processing = true
    var item = verifier_queue.pop_front()
    var saved_history = chat_history.duplicate()
    var saved_test = test_type_id
    chat_history = item.history
    test_type_id = item.test_id
    var verdict = await _determine_test_verdict()
    chat_history = saved_history
    test_type_id = saved_test


    var file_path = "user://logs/session_" + item.sid + ".txt"
    var file = FileAccess.open(file_path, FileAccess.READ_WRITE)
    if file:
        file.seek_end()
        file.store_line(verdict)
        file.close()

    _process_verifier_queue()

func _get_export_text() -> String:
    if not last_chat_export.is_empty():
        return "\n".join(last_chat_export)
    if chat_mode and not chat_history.is_empty():
        return "\n".join(chat_history)
    return "\n".join(boot_lines)

func _save_latest_chat_to_desktop() -> String:
    var text = _get_export_text()
    var desktop = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
    if desktop == "":
        return "ERROR: Desktop path not found."
    var filename = "micof_chat_" + str(Time.get_ticks_msec()) + ".txt"
    var path = desktop.path_join(filename)
    var file = FileAccess.open(path, FileAccess.WRITE)
    if not file:
        return "ERROR: Could not write file."
    file.store_string(text)
    file.close()
    return "Saved chat to Desktop: " + filename

func _copy_latest_chat_to_clipboard() -> String:
    var text = _get_export_text()
    DisplayServer.clipboard_set(text)
    return "Copied to clipboard."

func _start_snake() -> String:
    if game_mode:
        return ""
    game_mode = true
    vbox.visible = false
    input_label.visible = false
    snake_root.start_game()
    return ""

func _on_snake_exit_requested():
    game_mode = false
    snake_root.stop_game()
    vbox.visible = true
    input_label.visible = true
    _refresh_input_display()

func _start_tetris() -> String:
    if game_mode:
        return ""
    game_mode = true
    vbox.visible = false
    input_label.visible = false
    tetris_root.start_game()
    return ""

func _on_tetris_exit_requested():
    game_mode = false
    tetris_root.stop_game()
    vbox.visible = true
    input_label.visible = true
    _refresh_input_display()

func _update_explore_prompt():
    prompt_text = "RES:/" + explore_path + "> "

func _cmd_dir():
    var full_path = EXPLORE_ROOT + explore_path
    var dir = DirAccess.open(full_path)
    
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if dir.current_is_dir():
                _add_line("  [" + file_name + "]", false)
            else:
                _add_line("  " + file_name, false)
            file_name = dir.get_next()
    else:
        _add_line("System Error: Access Denied.")

func _cmd_cat(filename: String):
    if filename == "":
        _add_line("Usage: cat <filename>")
        return
    var path = (EXPLORE_ROOT + explore_path).path_join(filename)
    if not FileAccess.file_exists(path):
        _add_line("Error: File '" + filename + "' not found.")
        return
    
    var file = FileAccess.open(path, FileAccess.READ)
    if file:
        var text = file.get_as_text()
        if text == "":
            _add_line("(File is empty)")
        else:
            for line in text.split("\n"):
                _add_line(line, false)
    else:
        _add_line("Error: Access denied.")

func _cmd_touch(filename: String):
    if filename == "":
        _add_line("Usage: touch <filename>")
        return
    var path = (EXPLORE_ROOT + explore_path).path_join(filename)
    var file = FileAccess.open(path, FileAccess.WRITE)
    if file:
        file.close()
        _add_line("File '" + filename + "' created.")
    else:
        _add_line("Error: Could not create file.")

func _cmd_write(filename: String, content: String):
    if filename == "":
        _add_line("Usage: write <filename> <text>")
        return
    if content == "":
        _add_line("Error: No content provided to write.")
        return
        
    var path = (EXPLORE_ROOT + explore_path).path_join(filename)
    var file = FileAccess.open(path, FileAccess.WRITE)
    if file:
        file.store_string(content)
        file.close()
        _add_line("Data written to '" + filename + "'.")
    else:
        _add_line("Error: Could not write to file.")

func _cmd_rm(filename: String):
    if filename == "":
        _add_line("Usage: rm <filename>")
        return
    var path = (EXPLORE_ROOT + explore_path).path_join(filename)
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(path)
        _add_line("Removed file: " + filename)
    elif DirAccess.dir_exists_absolute(path):
        DirAccess.remove_absolute(path)
        _add_line("Removed directory: " + filename)
    else:
        _add_line("Error: '" + filename + "' does not exist.")
        
func _cmd_cd(target: String):
    if target == "":
        explore_path = "/"
        _update_explore_prompt()
        return
        
    if target == "..":
        if explore_path == "" or explore_path == "/":
            return
        var parts = explore_path.split("/", false)
        parts.remove_at(parts.size() - 1)
        explore_path = "/" + "/".join(parts)
    else:
        var new_rel_path = explore_path.path_join(target)
        if DirAccess.dir_exists_absolute(EXPLORE_ROOT + new_rel_path):
            explore_path = new_rel_path
        else:
            _add_line("Error: Directory '" + target + "' not found.")
            
    if not explore_path.begins_with("/"):
        explore_path = "/" + explore_path
    
    _update_explore_prompt()
