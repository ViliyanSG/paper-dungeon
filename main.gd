extends Node2D
## Paper Dungeon — core loop (Godot 4)
## Roll a die: odd = diagonal move, even = orthogonal move; number = steps
## (stops at wall). After rolling, up to 4 destination options appear;
## click one to slide there in a straight line. The travelled path is kept
## as a continuous pencil line. Touch + mouse supported.

const TILE := 36
const COLS := 20
const ROWS := 20
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
const C_WALL := Color(0.33, 0.30, 0.27)

# ---- Game state ----
var player := {}
var current_n := 0
var diagonal := false
var options: Array[Vector2i] = []
var option_paths: Dictionary = {}
var awaiting_move := false
var path: Array[Vector2i] = []
var entities: Array = []
var walls: Dictionary = {}
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
	option_paths = {}
	awaiting_move = false
	path = [Vector2i(0, 0)]
	entities = []
	exit_cell = Vector2i(COLS - 1, ROWS - 1)
	spinning = false
	game_over = false
	log_lines = []

	_generate_level()

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


func is_wall(cell: Vector2i) -> bool:
	return walls.has(cell)


# Generate random walls, then scatter entities on free reachable cells.
# Regenerates until the exit is reachable from the entrance.
func _generate_level() -> void:
	var entrance := Vector2i(0, 0)
	for attempt in 25:
		walls = {}
		for y in ROWS:
			for x in COLS:
				var c := Vector2i(x, y)
				if c == entrance or c == exit_cell:
					continue
				if randf() < 0.14:
					walls[c] = true
		var reach := _reachable(entrance)
		if reach.has(exit_cell):
			_populate_entities(reach)
			return
	# fallback: no walls at all
	walls = {}
	_populate_entities(_reachable(entrance))


# Cells reachable by straight slides (1..6 in any of 8 directions), transitively.
func _reachable(start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var stack: Array = [start]
	var dirs: Array = ORTHO_DIRS + DIAG_DIRS
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		for d in dirs:
			var p: Vector2i = cur
			for step in 6:
				var np: Vector2i = p + d
				if np.x < 0 or np.y < 0 or np.x >= COLS or np.y >= ROWS:
					break
				if is_wall(np):
					break
				p = np
				if not seen.has(p):
					seen[p] = true
					stack.append(p)
	return seen


func _populate_entities(reach: Dictionary) -> void:
	entities = []
	var free: Array = []
	for c in reach:
		if c == Vector2i(0, 0) or c == exit_cell:
			continue
		free.append(c)
	free.shuffle()

	var idx := 0
	var counts := {"enemy": 6, "trap": 5, "coin": 8, "chest": 3}
	for etype in counts:
		for i in counts[etype]:
			if idx >= free.size():
				return
			_place(etype, free[idx].x, free[idx].y)
			idx += 1


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
	if options.is_empty():
		add_log("Няма накъде. Хвърли пак.")
		roll_button.disabled = false
	else:
		awaiting_move = true
		add_log("Хвърли %d (%s). Избери накъде." % [current_n, mode_txt])
	_update_roll_label()
	queue_redraw()


func _compute_options() -> void:
	options = []
	option_paths = {}
	_explore(player.pos, current_n, Vector2i.ZERO, [], true)
	for cell in option_paths:
		options.append(cell)


# Explore every route of `steps` cells: slide straight until a wall, then turn
# (never back the way we came) and spend the remaining steps. Each final cell
# becomes a clickable option with its full bent path stored.
func _explore(pos: Vector2i, steps: int, came_dir: Vector2i, acc: Array, is_root: bool) -> void:
	var dirs := DIAG_DIRS if diagonal else ORTHO_DIRS
	var advanced := false
	for d in dirs:
		if d == -came_dir:
			continue  # can't turn back the way you came
		var k := _max_steps(pos, d, steps)
		if k < 1:
			continue
		advanced = true
		var p := pos
		var seg: Array = []
		for i in k:
			p = p + d
			seg.append(p)
		var rem := steps - k
		if rem <= 0:
			_add_option(p, acc + seg)        # used all steps
		else:
			_explore(p, rem, d, acc + seg, false)  # hit wall, turn and continue
	if not advanced and not is_root:
		_add_option(pos, acc)  # stuck against a wall, stop here


func _add_option(cell: Vector2i, full_path: Array) -> void:
	if not option_paths.has(cell):
		option_paths[cell] = full_path


func _max_steps(from: Vector2i, d: Vector2i, n: int) -> int:
	var k := 0
	var p := from
	for i in n:
		var np: Vector2i = p + d
		if np.x < 0 or np.y < 0 or np.x >= COLS or np.y >= ROWS:
			break
		if is_wall(np):
			break  # walls block movement
		p = np
		k += 1
	return k


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
	var full_path: Array = option_paths.get(target, [])
	options = []
	option_paths = {}
	awaiting_move = false

	for cell in full_path:
		player.pos = cell
		path.append(cell)
		_resolve_tile(cell)
		if game_over:
			break

	update_hud()
	if not game_over:
		roll_button.disabled = false
	_update_roll_label()
	queue_redraw()


func _update_roll_label() -> void:
	var mode_txt := "диагонал" if diagonal else "право"
	roll_result_label.text = "%d\n%s" % [current_n, mode_txt]


func _resolve_tile(cell: Vector2i) -> void:
	if cell == exit_cell:
		_win()
		return
	var ent = entity_at(cell)
	if ent == null:
		return
	ent.alive = false
	match ent.type:
		"enemy":
			var dmg := 1 + randi() % 6
			player.hp -= dmg
			add_log("Враг! -%d HP." % dmg)
			_check_death()
		"trap":
			var loss := 1 + randi() % 6
			player.gold = maxi(0, player.gold - loss)
			add_log("Капан! -%d GP." % loss)
		"coin":
			player.gold += 1
			add_log("Монета! +1 GP.")
		"chest":
			var gain := 1 + randi() % 6
			player.gold += gain
			add_log("Сандък! +%d GP." % gain)


# =====================================================================
#  Death / win
# =====================================================================
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

	# walls (solid blocks)
	for w in walls:
		draw_rect(Rect2(w.x * TILE + 1, GRID_TOP + w.y * TILE + 1, TILE - 2, TILE - 2), C_WALL, true)

	# travelled pencil line
	if path.size() >= 2:
		var pts := PackedVector2Array()
		for c in path:
			pts.append(cell_center(c))
		draw_polyline(pts, C_INK, 3.0, true)

	# entities
	for e in entities:
		var ctr := cell_center(e.pos)
		if not e.alive:
			_draw_dead(ctr)
			continue
		match e.type:
			"enemy":
				draw_circle(ctr, TILE * 0.30, C_INK)
				draw_circle(ctr, TILE * 0.24, C_RED)
			"trap":
				var t := TILE * 0.28
				var tp := PackedVector2Array([
					ctr + Vector2(0, -t), ctr + Vector2(t, t * 0.85), ctr + Vector2(-t, t * 0.85)])
				draw_colored_polygon(tp, C_BROWN)
			"coin":
				draw_circle(ctr, TILE * 0.22, C_GOLD)
				draw_arc(ctr, TILE * 0.22, 0, TAU, 18, C_INK, 1.5)
			"chest":
				var hw := TILE * 0.40
				var hh := TILE * 0.32
				draw_rect(Rect2(ctr.x - hw, ctr.y - hh, hw * 2, hh * 2), C_GOLD, true)
				draw_rect(Rect2(ctr.x - hw, ctr.y - hh, hw * 2, hh * 2), C_INK, false, 1.5)
				draw_line(ctr + Vector2(-hw, -hh * 0.25), ctr + Vector2(hw, -hh * 0.25), C_INK, 1.2)

	# entrance + exit
	draw_rect(Rect2(2, GRID_TOP + 2, TILE - 4, TILE - 4), C_GRAY, false, 2.0)
	var ec := cell_center(exit_cell)
	var ew := TILE * 0.30
	var eh := TILE * 0.40
	draw_rect(Rect2(ec.x - ew, ec.y - eh, ew * 2, eh * 2), C_GREEN, true)
	draw_circle(ec + Vector2(ew * 0.5, 0), TILE * 0.07, C_PAPER)

	# movement options (after a roll) — show the full route incl. turns
	var pc_start := cell_center(player.pos)
	var opt_r := TILE * 0.40
	for opt in options:
		var op_path: Array = option_paths.get(opt, [])
		var pts := PackedVector2Array()
		pts.append(pc_start)
		for c in op_path:
			pts.append(cell_center(c))
		if pts.size() >= 2:
			draw_polyline(pts, Color(0.29, 0.49, 0.35, 0.5), 2.0, true)
		var oc := cell_center(opt)
		draw_circle(oc, opt_r, Color(0.29, 0.49, 0.35, 0.30))
		draw_arc(oc, opt_r, 0, TAU, 22, C_GREEN, 2.0)

	# player
	var pc := cell_center(player.pos)
	draw_circle(pc, TILE * 0.34, C_INK)
	draw_circle(pc, TILE * 0.27, C_BLUE)


func _draw_dead(ctr: Vector2) -> void:
	var d := TILE * 0.22
	draw_line(ctr + Vector2(-d, -d), ctr + Vector2(d, d), C_GRAY, 2.5)
	draw_line(ctr + Vector2(d, -d), ctr + Vector2(-d, d), C_GRAY, 2.5)
