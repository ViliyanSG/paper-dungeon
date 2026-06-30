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
const C_HEART := Color(0.88, 0.25, 0.40)

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
var entrance_cell := Vector2i(0, 0)
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
	# entrance and exit in two different quarters of the board
	var q_start := randi() % 4
	var q_exit := (q_start + 1 + randi() % 3) % 4
	entrance_cell = _rand_in_quarter(q_start)
	exit_cell = _rand_in_quarter(q_exit)

	player = {"pos": entrance_cell, "hp": 10, "max_hp": 10, "atk": 3, "gold": 0}
	current_n = 0
	diagonal = false
	options = []
	option_paths = {}
	awaiting_move = false
	path = [entrance_cell]
	entities = []
	spinning = false
	game_over = false
	log_lines = []

	_generate_level()

	add_log("Ново подземие. Хвърли зар за да започнеш.")
	roll_button.disabled = false
	roll_result_label.text = ""
	update_hud()
	queue_redraw()


# Random cell inside quarter q (0=top-left, 1=top-right, 2=bottom-left, 3=bottom-right).
func _rand_in_quarter(q: int) -> Vector2i:
	var hx := COLS / 2
	var hy := ROWS / 2
	var x := (q % 2) * hx + randi() % hx
	var y := (q / 2) * hy + randi() % hy
	return Vector2i(x, y)


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
	var entrance := entrance_cell
	var target := int(COLS * ROWS * 0.15)
	for attempt in 30:
		walls = {}
		var placed := 0
		var tries := 0
		while placed < target and tries < 300:
			tries += 1
			var wall := _make_wall()
			if wall.size() < 4:
				continue
			for c in wall:
				walls[c] = true
			placed += wall.size()
		var reach := _reachable(entrance)
		if reach.has(exit_cell):
			_populate_entities(reach)
			return
	# fallback: no walls at all
	walls = {}
	_populate_entities(_reachable(entrance))


# Lay one wall: a 1-cell-thick line that runs straight and occasionally turns
# 90° (an L / gentle snake). Never forms a 2x2 block and stays isolated from
# other walls by at least one empty cell.
func _make_wall() -> Array:
	var cells := {}
	var ordered: Array = []
	var cur := Vector2i(randi() % COLS, randi() % ROWS)
	if not _wall_cell_ok(cur, cells):
		return []
	cells[cur] = true
	ordered.append(cur)

	var dir := _rand_axis_dir()
	var total_len := 4 + randi() % 8     # 4..11 cells
	var until_bend := 3 + randi() % 4    # run straight a bit before turning
	while ordered.size() < total_len:
		var nxt: Vector2i = cur + dir
		if not _wall_cell_ok(nxt, cells):
			break
		cells[nxt] = true
		ordered.append(nxt)
		cur = nxt
		until_bend -= 1
		if until_bend <= 0 and randi() % 100 < 45:
			dir = _perp(dir)
			until_bend = 3 + randi() % 4
	return ordered


func _wall_cell_ok(cell: Vector2i, cells: Dictionary) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= COLS or cell.y >= ROWS:
		return false
	if cell == entrance_cell or cell == exit_cell:
		return false
	if walls.has(cell) or cells.has(cell):
		return false
	# isolation: no committed wall (from another wall) in the 8-neighbourhood
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if walls.has(cell + Vector2i(dx, dy)):
				return false
	# keep 1-thick: adding this cell must not complete any 2x2 block
	if _would_make_square(cell, cells):
		return false
	return true


func _would_make_square(cell: Vector2i, cells: Dictionary) -> bool:
	for corner in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
		var full := true
		for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var cc: Vector2i = cell + corner + off
			if cc != cell and not cells.has(cc):
				full = false
				break
		if full:
			return true
	return false


func _rand_axis_dir() -> Vector2i:
	match randi() % 4:
		0: return Vector2i(1, 0)
		1: return Vector2i(-1, 0)
		2: return Vector2i(0, 1)
		_: return Vector2i(0, -1)


func _perp(d: Vector2i) -> Vector2i:
	if d.x != 0:
		return Vector2i(0, 1) if randi() % 2 == 0 else Vector2i(0, -1)
	return Vector2i(1, 0) if randi() % 2 == 0 else Vector2i(-1, 0)


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
		if c == entrance_cell or c == exit_cell:
			continue
		free.append(c)
	free.shuffle()

	var idx := 0
	var counts := {"enemy": 6, "trap": 5, "coin": 8, "chest": 3, "heart": 4}
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

	var start_pos: Vector2i = player.pos
	var hp_before: int = player.hp
	var gold_before: int = player.gold

	for cell in full_path:
		player.pos = cell
		path.append(cell)
		_resolve_tile(cell)
		if game_over:
			break

	update_hud()
	if not game_over:
		roll_button.disabled = false
		var steps := full_path.size()
		var first_dir: Vector2i = full_path[0] - start_pos if steps > 0 else Vector2i.ZERO
		var msg := "Ход %s, %d стъпки." % [_dir_word(first_dir), steps]
		var gd: int = player.gold - gold_before
		var hd: int = player.hp - hp_before
		if gd != 0:
			msg += " %+d GP." % gd
		if hd != 0:
			msg += " %+d HP." % hd
		add_log(msg)
	_update_roll_label()
	queue_redraw()


func _dir_word(d: Vector2i) -> String:
	var h := ""
	var v := ""
	if d.x > 0:
		h = "дясно"
	elif d.x < 0:
		h = "ляво"
	if d.y > 0:
		v = "долу"
	elif d.y < 0:
		v = "горе"
	if h != "" and v != "":
		return v + "-" + h
	elif h != "":
		return "на" + h
	elif v != "":
		return "на" + v
	return "?"


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
			player.hp -= 1 + randi() % 6
			_check_death()
		"trap":
			player.gold = maxi(0, player.gold - (1 + randi() % 6))
		"coin":
			player.gold += 1
		"chest":
			player.gold += 1 + randi() % 6
		"heart":
			player.hp = mini(player.max_hp, player.hp + 1 + randi() % 6)


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
	log_label.text = msg  # only the most recent event


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

	# walls (solid blocks — fill whole cell so adjacent walls merge seamlessly)
	for w in walls:
		draw_rect(Rect2(w.x * TILE, GRID_TOP + w.y * TILE, TILE, TILE), C_WALL, true)

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
			"heart":
				_draw_heart(ctr)

	# entrance + exit
	draw_rect(Rect2(entrance_cell.x * TILE + 2, GRID_TOP + entrance_cell.y * TILE + 2, TILE - 4, TILE - 4), C_GRAY, false, 2.0)
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


func _draw_heart(ctr: Vector2) -> void:
	var s := TILE * 0.32
	draw_circle(ctr + Vector2(-s * 0.42, -s * 0.18), s * 0.42, C_HEART)
	draw_circle(ctr + Vector2(s * 0.42, -s * 0.18), s * 0.42, C_HEART)
	var tri := PackedVector2Array([
		ctr + Vector2(-s * 0.78, -s * 0.02),
		ctr + Vector2(s * 0.78, -s * 0.02),
		ctr + Vector2(0, s * 0.72)])
	draw_colored_polygon(tri, C_HEART)


func _draw_dead(ctr: Vector2) -> void:
	var d := TILE * 0.22
	draw_line(ctr + Vector2(-d, -d), ctr + Vector2(d, d), C_GRAY, 2.5)
	draw_line(ctr + Vector2(d, -d), ctr + Vector2(-d, d), C_GRAY, 2.5)
