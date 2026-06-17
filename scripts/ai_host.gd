extends Node

signal progress_changed(text: String, current: int, total: int)
signal all_models_ready()

const LLAMAFILE_URL = "https://github.com/lootbugich/models/raw/main/llamafile.exe"

var local_llm_config = {
    "032": {"name": "Aegis-7.2", "model_file": "model_Aegis.gguf", "download_url": "https://github.com/lootbugich/models/raw/main/model_Aegis.gguf", "port": 8385, "pid": -1, "prompt": "..."}, 
    "789": {"name": "Quake", "model_file": "model_Quake.gguf", "download_url": "https://github.com/lootbugich/models/raw/main/model_Quake.gguf", "port": 8386, "pid": -1, "prompt": "..."}, 
    "999": {"name": "Tricolor", "model_file": "model_Tricolor.gguf", "download_url": "https://github.com/lootbugich/models/raw/main/model_Tricolor.gguf", "port": 8387, "pid": -1, "prompt": "..."}, 
    "222": {"name": "Genesis", "model_file": "model_Genesis.gguf", "download_url": "https://github.com/lootbugich/models/raw/main/model_Genesis.gguf", "port": 8389, "pid": -1, "prompt": "..."}
}

var started: = false
var starting: = false
var all_ready: = false
var enabled_models: Dictionary = {}
var ready_flags: Dictionary = {}

var verifier_model_id = "789"

func is_model_ready(id: String) -> bool:
    return ready_flags.get(id, false)

func get_model_cfg(id: String) -> Dictionary:
    return local_llm_config.get(id, {})

func get_model_port(id: String) -> int:
    if local_llm_config.has(id):
        return local_llm_config[id]["port"]
    return -1

func _get_ai_dir() -> String:
    var path = "user://ai"
    if not DirAccess.dir_exists_absolute(path):
        DirAccess.make_dir_recursive_absolute(path)
    return ProjectSettings.globalize_path(path)

func ensure_started() -> bool:
    if started: return true
    if starting: return false
    if not is_inside_tree():
        await self.tree_entered

    starting = true
    print("[AI Host] Starting initialization...")
    var ai_dir = _get_ai_dir()

    var server_exe = ai_dir.path_join("llamafile.exe")
    if not FileAccess.file_exists(server_exe):
        print("[AI Host] Engine missing. Downloading...")
        var ok = await _download_manager(LLAMAFILE_URL, server_exe, "AI Engine")
        if not ok:
            _abort_starting("Failed to download AI Engine")
            return false

    var ids = local_llm_config.keys()
    for id in ids:
        if enabled_models.has(id) and not enabled_models[id]: continue

        var cfg = local_llm_config[id]
        var model_path = ai_dir.path_join(cfg["model_file"])

        if not FileAccess.file_exists(model_path):
            print("[AI Host] Model ", cfg["name"], " missing. Downloading...")
            var ok = await _download_manager(cfg["download_url"], model_path, "Model: " + cfg["name"])
            if not ok:
                _abort_starting("Failed to download model: " + cfg["name"])
                return false
    print("[AI Host] All files present. Launching processes...")
    _start_llamafile()
    _poll_background()

    started = true
    starting = false
    print("[AI Host] Ensure_started finished successfully.")
    return true

func _abort_starting(reason: String):
    push_error(reason)
    emit_signal("progress_changed", "Error: " + reason, 0, 100)
    starting = false

func _download_manager(url: String, save_path: String, display_name: String) -> bool:
    print("[Downloader] Starting: ", display_name)
    var temp_path = save_path + ".tmp"

    if FileAccess.file_exists(temp_path):
        DirAccess.remove_absolute(temp_path)

    var http = HTTPRequest.new()
    add_child(http)
    http.use_threads = true
    http.set_download_file(temp_path)

    var err = http.request(url)
    if err != OK:
        http.queue_free()
        return false

    var is_completed = false
    var download_result = []

    http.request_completed.connect( func(result, response_code, headers, body):
        download_result = [result, response_code]
        is_completed = true
    )

    var last_bytes = 0
    var stall_counter = 0

    while not is_completed:
        var downloaded = http.get_downloaded_bytes()
        var total = http.get_body_size()

        if total > 0:
            var percent = int((float(downloaded) / total) * 100)
            emit_signal("progress_changed", "Downloading " + display_name, percent, 100)

            if downloaded >= total and total > 0:
                stall_counter += 1
                if stall_counter > 30:
                    print("[Downloader] ", display_name, " - 100% reached, forcing completion.")
                    download_result = [HTTPRequest.RESULT_SUCCESS, 200]
                    is_completed = true
                    break

        if downloaded < total and downloaded > 0:
            if downloaded == last_bytes:
                stall_counter += 1
            else:
                stall_counter = 0

            if stall_counter > 150:
                print("[Downloader] STALLED - Aborting.")
                http.cancel_request()
                break

        last_bytes = downloaded
        await get_tree().create_timer(0.1).timeout

    http.queue_free()

    if download_result.size() > 0 and download_result[1] == 200:
        if FileAccess.file_exists(temp_path):
            if FileAccess.file_exists(save_path):
                DirAccess.remove_absolute(save_path)

            await get_tree().create_timer(0.3).timeout
            var rename_err = DirAccess.rename_absolute(temp_path, save_path)

            if rename_err == OK:
                print("[Downloader] Success: ", display_name)
                return true
            else:
                print("[Downloader] Rename error code: ", rename_err)

    return false

func _start_llamafile():
    var ai_dir = _get_ai_dir()
    var ai_dir_quoted = "\"" + ai_dir + "\""
    var ids = local_llm_config.keys()
    ids.sort()

    for i in range(ids.size()):
        var id = ids[i]
        if enabled_models.has(id) and not enabled_models[id]: continue

        var cfg = local_llm_config[id]
        emit_signal("progress_changed", "Starting " + cfg["name"], i + 1, ids.size())
        var log_path = ai_dir.path_join("llamafile_" + id + ".log")
        var cmd = "cd /d " + ai_dir_quoted + " && .\\llamafile.exe --server -m " + cfg["model_file"] + " --port " + str(cfg["port"]) + " --host 127.0.0.1 -ngl 0 -c 2048 > \"" + log_path + "\" 2>&1"

        var pid = OS.create_process("cmd.exe", ["/c", cmd])
        local_llm_config[id]["pid"] = pid
        print("[AI Host] Process started for ", cfg["name"], " (PID: ", pid, ")")

func _poll_background():
    var active_ids = []
    for id in local_llm_config.keys():
        if not enabled_models.has(id) or enabled_models[id]:
            active_ids.append(id)

    for id in active_ids:
        ready_flags[id] = false
        _poll_model_ready(id)

    var start_time = Time.get_ticks_msec()
    while true:
        var ready_count = 0
        for id in active_ids:
            if ready_flags.get(id, false): ready_count += 1

        emit_signal("progress_changed", "Initializing Models...", ready_count, active_ids.size())

        if ready_count == active_ids.size():
            all_ready = true
            emit_signal("all_models_ready")
            print("[AI Host] ALL MODELS READY")
            break

        if (Time.get_ticks_msec() - start_time) > 120000:
            print("[AI Host] Poll timeout reached")
            break
        await get_tree().create_timer(1.0).timeout

func _poll_model_ready(id: String):
    var port = local_llm_config[id]["port"]
    var tcp = StreamPeerTCP.new()

    while not ready_flags.get(id, false):
        var err = tcp.connect_to_host("127.0.0.1", port)
        await get_tree().create_timer(1.0).timeout
        tcp.poll()
        if tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
            ready_flags[id] = true
            tcp.disconnect_from_host()
            print("[AI Host] Module ", id, " is READY on port ", port)
            return
