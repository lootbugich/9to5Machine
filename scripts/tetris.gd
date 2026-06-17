extends Control

signal exit_requested

@export var cols: int = 10
@export var rows: int = 20
@export var cell_size: int = 24
@export var fall_interval: float = 0.5

@export var block_texture: Texture2D

@onready var board: Control = $board
@onready var active_piece_root: Control = $board / active
@onready var locked_blocks_root: Control = $board / locked
@onready var fall_timer: Timer = $falltimer
@onready var score_label: Label = $score
@onready var game_over_label: Label = $gameover

var move_delay: = 0.15
var move_repeat: = 0.05
var key_timers: = {
    "ui_left": 0.0, 
    "ui_right": 0.0, 
    "ui_down": 0.0
}

var grid: Dictionary = {}
var active_piece: Array[Vector2i] = []
var active_nodes: Array[TextureRect] = []
var piece_pos: Vector2i = Vector2i.ZERO

var running: = false
var game_over: = false
var score: = 0

var shapes = {
    "I": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)], 
    "O": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], 
    "T": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)], 
    "S": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)], 
    "Z": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)], 
    "J": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)], 
    "L": [Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
}


func _ready():
    visible = false
    fall_timer.wait_time = fall_interval
    fall_timer.timeout.connect(_on_fall_timer_timeout)
    board.mouse_filter = Control.MOUSE_FILTER_IGNORE
    active_piece_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    locked_blocks_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    game_over_label.visible = false

func start_game():
    visible = true
    running = true
    game_over = false
    score = 0
    _clear_all()
    _spawn_piece()
    _update_score()
    game_over_label.visible = false
    fall_timer.start()
    cols = int(board.size.x / cell_size)
    rows = int(board.size.y / cell_size)

func stop_game():
    running = false
    game_over = false
    fall_timer.stop()
    visible = false

func _process(delta):
    if not running or not visible:
        return
    if Input.is_action_just_pressed("ui_cancel"):
        emit_signal("exit_requested")
        return
    if game_over:
        if Input.is_action_just_pressed("ui_accept"):
            start_game()
        return
    if Input.is_action_just_pressed("ui_up"):
        _rotate_piece()
    _handle_hold("ui_left", Vector2i.LEFT, delta)
    _handle_hold("ui_right", Vector2i.RIGHT, delta)
    _handle_hold("ui_down", Vector2i.DOWN, delta)

func _handle_hold(action: String, dir: Vector2i, delta: float):
    if Input.is_action_just_pressed(action):
        _move_piece(dir)
        key_timers[action] = move_delay
    elif Input.is_action_pressed(action):
        key_timers[action] -= delta
        if key_timers[action] <= 0.0:
            _move_piece(dir)
            key_timers[action] = move_repeat
    else:
        key_timers[action] = 0.0

func _on_fall_timer_timeout():
    if not running or game_over:
        return

    if not _move_piece(Vector2i.DOWN):
        _lock_piece()

func _move_piece(d: Vector2i) -> bool:
    if _is_colliding(piece_pos + d, active_piece):
        return false
    piece_pos += d
    _update_active_visuals()
    return true

func _rotate_piece():
    var new_shape: Array[Vector2i] = []
    for p in active_piece:
        new_shape.append(Vector2i( - p.y, p.x))

    if not _is_colliding(piece_pos, new_shape):
        active_piece = new_shape
        _update_active_visuals()

func _spawn_piece():
    var keys = shapes.keys()
    var type = keys[randi() % keys.size()]
    active_piece.clear()
    for p in shapes[type]:
        active_piece.append(p)
    piece_pos = Vector2i(int(cols / 2) - 2, 0)

    if _is_colliding(piece_pos, active_piece):
        _lose()
        return

    _rebuild_active_nodes()
    _update_active_visuals()
    print("Piece spawned at: ", piece_pos)
    print("Active nodes count: ", active_nodes.size())
    print("Board size: ", board.size)
    print("Active root size: ", active_piece_root.size)
    if active_nodes.size() > 0:
        print("First block pos: ", active_nodes[0].position)
        print("First block size: ", active_nodes[0].size)
        print("First block texture: ", active_nodes[0].texture)

func _lock_piece():
    for p in active_piece:
        var global_p = piece_pos + p
        var block: = TextureRect.new()
        block.texture = block_texture
        block.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        block.stretch_mode = TextureRect.STRETCH_SCALE
        block.mouse_filter = Control.MOUSE_FILTER_IGNORE
        block.size = Vector2(cell_size, cell_size)
        block.position = _cell_to_pos(global_p)
        locked_blocks_root.add_child(block)
        grid[global_p] = block

    _check_lines()
    _spawn_piece()

func _check_lines():
    var lines_cleared = 0
    for y in range(rows):
        var full = true
        for x in range(cols):
            if not grid.has(Vector2i(x, y)):
                full = false
                break
        if full:
            _delete_line(y)
            lines_cleared += 1

    if lines_cleared > 0:
        score += lines_cleared * 100
        _update_score()

func _delete_line(row: int):
    for x in range(cols):
        grid[Vector2i(x, row)].queue_free()
        grid.erase(Vector2i(x, row))

    var new_grid: = {}
    for p in grid.keys():
        if p.y < row:
            var block = grid[p]
            var new_p = p + Vector2i.DOWN
            block.position = _cell_to_pos(new_p)
            new_grid[new_p] = block
        else:
            new_grid[p] = grid[p]
    grid = new_grid

func _is_colliding(pos: Vector2i, shape: Array[Vector2i]) -> bool:
    for p in shape:
        var target = pos + p
        if target.x < 0 or target.x >= cols or target.y >= rows:
            return true
        if grid.has(target):
            return true
    return false

func _rebuild_active_nodes():
    for node in active_nodes:
        if is_instance_valid(node):
            node.queue_free()
    active_nodes.clear()

    for p in active_piece:
        var block: = TextureRect.new()
        block.texture = block_texture
        block.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        block.stretch_mode = TextureRect.STRETCH_SCALE
        block.mouse_filter = Control.MOUSE_FILTER_IGNORE
        block.size = Vector2(cell_size, cell_size)
        active_piece_root.add_child(block)
        active_nodes.append(block)

func _update_active_visuals():
    if active_nodes.size() != active_piece.size():
        _rebuild_active_nodes()

    for i in range(active_piece.size()):
        active_nodes[i].position = _cell_to_pos(piece_pos + active_piece[i])
        active_nodes[i].size = Vector2(cell_size, cell_size)

func _clear_all():
    for node in active_nodes:
        if is_instance_valid(node):
            node.queue_free()
    active_nodes.clear()

    for key in grid.keys():
        if is_instance_valid(grid[key]):
            grid[key].queue_free()
    grid.clear()

func _update_score():
    score_label.text = "Score: " + str(score)

func _lose():
    game_over = true
    fall_timer.stop()
    game_over_label.visible = true

func _cell_to_pos(cell: Vector2i) -> Vector2:
    return Vector2(cell.x * cell_size, cell.y * cell_size)
