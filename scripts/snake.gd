extends Control

signal exit_requested

@export var grid_w: int = 18
@export var grid_h: int = 16
@export var cell_size: int = 32
@export var move_interval: float = 0.12

@export var head_texture: Texture2D
@export var body_texture: Texture2D
@export var food_texture: Texture2D

@onready var playfield: Control = $playfield
@onready var head: TextureRect = $playfield / head
@onready var food_node: TextureRect = $playfield / food
@onready var segments_root: Control = $playfield / segments
@onready var move_timer: Timer = $movetimer
@onready var score_label: Label = $score
@onready var game_over_label: Label = $gameover

var snake: Array[Vector2i] = []
var body_nodes: Array[TextureRect] = []

var dir: Vector2i = Vector2i.RIGHT
var next_dir: Vector2i = Vector2i.RIGHT
var food: Vector2i = Vector2i.ZERO

var running: = false
var game_over: = false
var turn_locked: = false
var score: = 0


func _ready():
    visible = false

    move_timer.wait_time = move_interval
    move_timer.timeout.connect(_on_move_timer_timeout)

    head.texture = head_texture
    food_node.texture = food_texture

    head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    head.stretch_mode = TextureRect.STRETCH_SCALE
    food_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    food_node.stretch_mode = TextureRect.STRETCH_SCALE

    head.mouse_filter = Control.MOUSE_FILTER_IGNORE
    food_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    playfield.mouse_filter = Control.MOUSE_FILTER_IGNORE
    segments_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

    game_over_label.visible = false


func start_game():
    visible = true
    running = true
    game_over = false
    score = 0
    _clear_body()

    snake = [
        Vector2i(5, 5), 
        Vector2i(4, 5), 
        Vector2i(3, 5)
    ]

    dir = Vector2i.RIGHT
    next_dir = Vector2i.RIGHT
    move_timer.wait_time = move_interval

    _spawn_food()
    _update_score()
    _update_visuals()
    game_over_label.visible = false
    move_timer.start()

func stop_game():
    running = false
    game_over = false
    move_timer.stop()
    visible = false


func _process(_delta):
    if not running or not visible:
        return

    if Input.is_action_just_pressed("ui_cancel"):
        emit_signal("exit_requested")
        return

    if game_over:
        if Input.is_action_just_pressed("ui_accept"):
            start_game()
        return

    if turn_locked:
        return

    if Input.is_action_just_pressed("ui_up"):
        _try_set_dir(Vector2i.UP)
    elif Input.is_action_just_pressed("ui_down"):
        _try_set_dir(Vector2i.DOWN)
    elif Input.is_action_just_pressed("ui_left"):
        _try_set_dir(Vector2i.LEFT)
    elif Input.is_action_just_pressed("ui_right"):
        _try_set_dir(Vector2i.RIGHT)


func _try_set_dir(new_dir: Vector2i):
    if new_dir == - dir:
        return
    next_dir = new_dir
    turn_locked = true


func _on_move_timer_timeout():
    if not running or game_over: return

    dir = next_dir
    var new_head = snake[0] + dir

    if new_head.x < 0 or new_head.y < 0 or new_head.x >= grid_w or new_head.y >= grid_h:
        _lose()
        return
    for i in range(snake.size() - 1):
        if snake[i] == new_head:
            _lose()
            return

    var grow = (new_head == food)
    snake.push_front(new_head)

    if grow:
        score += 1
        _update_score()
        _spawn_food()
    else:
        snake.pop_back()

    _update_visuals()
    turn_locked = false

func _spawn_food():
    var free_cells: Array[Vector2i] = []

    for y in range(grid_h):
        for x in range(grid_w):
            var cell = Vector2i(x, y)
            if not snake.has(cell):
                free_cells.append(cell)

    if free_cells.is_empty():
        _win()
        return

    food = free_cells[randi() % free_cells.size()]


func _update_visuals():
    var px_size = Vector2(cell_size, cell_size)

    head.size = px_size
    head.position = _cell_to_pos(snake[0])

    food_node.size = px_size
    food_node.position = _cell_to_pos(food)
    var need_count = max(0, snake.size() - 1)

    while body_nodes.size() < need_count:
        var part: = TextureRect.new()
        part.texture = body_texture
        part.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        part.stretch_mode = TextureRect.STRETCH_SCALE
        part.mouse_filter = Control.MOUSE_FILTER_IGNORE
        part.size = px_size
        segments_root.add_child(part)
        body_nodes.append(part)

    while body_nodes.size() > need_count:
        var last = body_nodes.pop_back()
        last.queue_free()

    for i in range(need_count):
        body_nodes[i].position = _cell_to_pos(snake[i + 1])
        body_nodes[i].size = px_size

func _update_score():
    score_label.text = "Score: " + str(score)

func _lose():
    game_over = true
    move_timer.stop()
    game_over_label.visible = true

func _win():
    game_over = true
    move_timer.stop()
    game_over_label.visible = true

func _clear_body():
    for node in body_nodes:
        if is_instance_valid(node):
            node.queue_free()
    body_nodes.clear()

func _cell_to_pos(cell: Vector2i) -> Vector2:
    return Vector2(cell.x * cell_size, cell.y * cell_size)

func _is_outside(cell: Vector2i) -> bool:
    return cell.x < 0 or cell.y < 0 or cell.x >= grid_w or cell.y >= grid_h

func _dir_to_rotation(d: Vector2i) -> float:
    if d == Vector2i.RIGHT:
        return 0.0
    if d == Vector2i.DOWN:
        return PI / 2.0
    if d == Vector2i.LEFT:
        return PI
    if d == Vector2i.UP:
        return - PI / 2.0
    return 0.0
