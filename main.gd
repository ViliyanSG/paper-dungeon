extends Node2D
## Paper Dungeon — core loop (Godot 4)
## Roll a die: odd = diagonal move, even = orthogonal move; number = steps
## (stops at wall). After rolling, up to 4 destination options appear;
## click one to slide there in a straight line. The travelled path is kept
## as a continuous pencil line. Touch + mouse supported.

const TILE := 60
const COLS := 12
const ROWS := 12
const GRID_TOP := 100   # px from top where the play field starts

const ORTHO_DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAG_DIRS := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

# ---- Paper theme colors ----
const C_PAPER := Color(0.957, 0.937, 0.882)
const C_LINE := Color(0.85, 0.81, 0.70)
const C_INK := Color(0.17, 0.17, 0.17)
const C_RED := Color(0.70, 0.23, 0.28)
const C_GREEN := Color(0.29, 0.49, 0.35)
const C_GOLD := Color(0.79, 0.64, 0.15)
const C_BROWN := Color(0.54, 0.43, 0.23)
const C_BLUE := Color(0.11, 0.23, 0.36)
const C_GRAY := Color(0.6, 0.6, 0.6)
const C_TEXT := Color(0.90, 0.86, 0.76)

# ---- Game state ----
var player := {}
var current_n := 0
var diagonal := false
var options: Array[Vector2i] = []
var awaiting_move := false
var path: Array[Vector2i] = []
var entities: Array = []
var exit_cell := Vector2i(COLS - 1, ROWS - 1)
var spinning := false
var game_over := false
var log_lines: Array[String] = []

# ---- UI nodes ----
var hp_label: Label
var gold_label: Label
var roll_button: Button
var roll_result_label: Label
var reset_button: Button
var log_label: Label


func _ready() -> void:
	randomize()
	_build_ui()
	new_level()


# =====================================================================
#  UI
# =====================================================================
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# top bar
	hp_label = _make_label(root, Vector2(20, 26), Vector2(340, 50), 36, C_RED)
	gold_label = _make_label(root, Vector2(360, 26), Vector2(340, 50), 36, C_GOLD)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# bottom controls
	roll_button = _make_button(root, "Хвърли зар", Vector2(20, 870), Vector2(430, 120))
	roll_button.pressed.connect(_on_roll)

	roll_result_label = _make_label(root, Vector2(470, 870), Vector2(230, 120), 34, C_GOLD)
	roll_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roll_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	roll_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	reset_button = _make_button(root, "Ново ниво", Vector2(470, 1010), Vector2(230, 70))
	reset_button.add_theme_font_size_override("font_size", 22)
	reset_button.pressed.connect(new_level)

	log_label = _make_label(root, Vector2(20, 1100), Vector2(680, 170), 22, C_TEXT)
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _make_label(parent: Control, pos: Vector2, sz: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _make_button(parent: Control, text: String, pos: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", 32)
	parent.add_child(b)
	return b


# =====================================================================
#  Level setup
# =====================================================================
func new_level() -> void:
	player = {"pos": Vector2i(0, 0), "hp": 10, "max_hp": 10, "atk": 3, "gold": 0}
	current_n = 0
	diagonal = false
	options = []
	awaiting_move = false
	path = [Vector2i(0, 0)]
	entities = []
	exit_cell = Vector2i(COLS - 1, ROWS - 1)
	spinning = false
	game_over = false
	log_lines = []

	# Hand-designed layout
	_place("enemy", 3, 1, {"hp": 4, "atk": 2})
	_place("enemy", 6, 4, {"hp": 5, "atk": 3})
	_place("enemy", 9, 8, {"hp": 7, "atk": 4})   # mini-boss
	_place("trap", 2, 4)
	_place("trap", 7, 7)
	_place("trap", 4, 9)
	_place("chest", 5, 2, {"gold": 8})
	_place("chest", 8, 6, {"gold": 12})
	_place("chest", 1, 8, {"gold": 6})

	add_log("Ново подземие. Хвърли зар за да започнеш.")
	roll_button.disabled = false
	roll_result_label.text = ""
	update_hud()
	queue_redraw()


func _place(type: String, x: int, y: int, extra: Dictionary = {}) -> void:
	var e := {"type": type, "pos": Vector2i(x, y), "alive": true, "hp": 1, "atk": 0, "gold": 0}
	for k in extra:
		e[k] = extra[k]
	entities.append(e)


func entity_at(cell: Vector2i):
	for e in entities:
		if e.alive and e.pos == cell:
			return e
	return null


# =====================================================================
#  Roll the die
# =====================================================================
func _on_roll() -> void:
	if game_over or spinning or awaiting_move:
		return
	spinning = true
	roll_button.disabled = true
	options = []
	queue_redraw()

	var total := 16 + randi() % 8
	for i in total:
		roll_result_label.text = str(1 + randi() % 6)
		await get_tree().create_timer(0.05 + i * 0.004).timeout

	current_n = 1 + randi() % 6
	diagonal = (current_n % 2) == 1
	spinning = false
	_compute_options()

	var mode_txt := "диагонал" if diagonal else "право"
	roll_result_label.text = "%d\n%s" % [current_n, mode_txt]

	if options.is_empty():
		add_log("Няма накъде. Хвърли пак.")
		roll_button.disabled = false
	else:
		awaiting_move = true
		add_log("Хвърли %d (%s). Избери накъде." % [current_n, mode_txt])
	queue_redraw()


func _compute_options() -> void:
	options = []
	var dirs := DIAG_DIRS if diagonal else ORTHO_DIRS
	for d in dirs:
		var k := _max_steps(player.pos, d, current_n)
		if k >= 1:
			options.append(player.pos + d * k)


func _max_steps(from: Vector2i, d: Vector2i, n: int) -> int:
	var limit := n
	if d.x > 0:
		limit = mini(limit, (COLS - 1) - from.x)
	elif d.x < 0:
		limit = mini(limit, from.x)
	if d.y > 0:
		limit = mini(limit, (ROWS - 1) - from.y)
	elif d.y < 0:
		limit = mini(limit, from.y)
	return limit


# =====================================================================
#  Input — pick a destination option
# =====================================================================
func _unhandled_input(event: InputEvent) -> void:
	var sp = null
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		sp = event.position
	elif event is InputEventScreenTouch and event.pressed:
		sp = event.position
	if sp == null:
		return
	if game_over or spinning or not awaiting_move:
		return

	var world: Vector2 = get_global_transform_with_canvas().affine_inverse() * sp
	if world.y < GRID_TOP:
		return
	var cell := Vector2i(int(world.x / TILE), int((world.y - GRID_TOP) / TILE))
	if cell in options:
		_do_move(cell)


func _do_move(target: Vector2i) -> void:
	var d := Vector2i(signi(target.x - player.pos.x), signi(target.y - player.pos.y))
	var steps := maxi(absi(target.x - player.pos.x), absi(target.y - player.pos.y))
	awaiting_move = false
	options = []

	for i in steps:
		var cell: Vector2i = player.pos + d
		player.pos = cell
		path.append(cell)
		_resolve_tile(cell)
		if game_over:
			break

	update_hud()
	queue_redraw()
	if not game_over:
		roll_button.disabled = false


func _resolve_tile(cell: Vector2i) -> void:
	if cell == exit_cell:
		_win()
		return
	var ent = entity_at(cell)
	if ent == null:
		return
	match ent.type:
		"trap":
			player.hp -= 2
			ent.alive = false
			add_log("Капан! -2 HP.")
			_check_death()
		"chest":
			player.gold += ent.gold
			ent.alive = false
			add_log("Сандък! +%d GP." % ent.gold)
		"enemy":
			_fight(ent)


# =====================================================================
#  Combat
# =====================================================================
func _fight(enemy: Dictionary) -> void:
	add_log("Битка! Враг HP %d." % enemy.hp)
	while enemy.hp > 0 and player.hp > 0:
		var my_roll: int = player.atk + (randi() % 3)
		enemy.hp -= my_roll
		add_log("  Удряш за %d → враг HP %d." % [my_roll, max(0, enemy.hp)])
		if enemy.hp <= 0:
			break
		var enemy_roll: int = enemy.atk + (randi() % 2)
		player.hp -= enemy_roll
		add_log("  Врагът удря за %d → твой HP %d." % [enemy_roll, max(0, player.hp)])
	if enemy.hp <= 0:
		enemy.alive = false
		add_log("  Победи врага!")
	_check_death()


func _check_death() -> void:
	if player.hp <= 0:
		player.hp = 0
		game_over = true
		awaiting_move = false
		add_log("Загина. Натисни „Ново ниво\".")
		roll_button.disabled = true


func _win() -> void:
	game_over = true
	awaiting_move = false
	add_log("Победа! Стигна изхода със %d GP." % player.gold)
	roll_button.disabled = true


# =====================================================================
#  HUD / log
# =====================================================================
func update_hud() -> void:
	hp_label.text = "HP %d/%d" % [player.hp, player.max_hp]
	gold_label.text = "GP %d" % player.gold


func add_log(msg: String) -> void:
	log_lines.append(msg)
	while log_lines.size() > 7:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)


# =====================================================================
#  Rendering
# =====================================================================
func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE / 2.0, GRID_TOP + c.y * TILE + TILE / 2.0)


func _draw() -> void:
	# paper background of the play field
	draw_rect(Rect2(0, GRID_TOP, COLS * TILE, ROWS * TILE), C_PAPER, true)

	# grid lines
	for i in range(COLS + 1):
		draw_line(Vector2(i * TILE, GRID_TOP), Vector2(i * TILE, GRID_TOP + ROWS * TILE), C_LINE, 1.0)
	for j in range(ROWS + 1):
		draw_line(Vector2(0, GRID_TOP + j * TILE), Vector2(COLS * TILE, GRID_TOP + j * TILE), C_LINE, 1.0)

	# travelled pencil line
	if path.size() >= 2:
		var pts := PackedVector2Array()
		for c in path:
			pts.append(cell_center(c))
		draw_polyline(pts, C_INK, 4.0, true)

	# entities
	for e in entities:
		var ctr := cell_center(e.pos)
		if not e.alive:
			_draw_dead(ctr)
			continue
		match e.type:
			"enemy":
				if e.atk >= 4:
					draw_circle(ctr, 20, C_INK)
					draw_circle(ctr, 17, C_RED)
				else:
					draw_circle(ctr, 15, C_RED)
			"trap":
				var tp := PackedVector2Array([
					ctr + Vector2(0, -15), ctr + Vector2(15, 13), ctr + Vector2(-15, 13)])
				draw_colored_polygon(tp, C_BROWN)
			"chest":
				draw_rect(Rect2(ctr.x - 13, ctr.y - 11, 26, 22), C_GOLD, true)
				draw_rect(Rect2(ctr.x - 13, ctr.y - 11, 26, 22), C_INK, false, 2.0)

	# entrance + exit
	draw_rect(Rect2(2, GRID_TOP + 2, TILE - 4, TILE - 4), C_GRAY, false, 2.0)
	var ec := cell_center(exit_cell)
	draw_rect(Rect2(ec.x - 16, ec.y - 20, 32, 40), C_GREEN, true)
	draw_circle(ec + Vector2(9, 0), 3, C_PAPER)

	# movement options (after a roll)
	var pc_start := cell_center(player.pos)
	for opt in options:
		var oc := cell_center(opt)
		draw_line(pc_start, oc, Color(0.29, 0.49, 0.35, 0.55), 2.0)
		draw_circle(oc, 22, Color(0.29, 0.49, 0.35, 0.30))
		draw_arc(oc, 22, 0, TAU, 24, C_GREEN, 2.5)

	# player
	var pc := cell_center(player.pos)
	draw_circle(pc, 18, C_INK)
	draw_circle(pc, 14, C_BLUE)


func _draw_dead(ctr: Vector2) -> void:
	draw_line(ctr + Vector2(-11, -11), ctr + Vector2(11, 11), C_GRAY, 3.0)
	draw_line(ctr + Vector2(11, -11), ctr + Vector2(-11, 11), C_GRAY, 3.0)
