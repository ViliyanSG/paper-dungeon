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
const C_WALL := Color(0.361, 0.322, 0.275)
const C_WALL_HI := Color(0.471, 0.424, 0.361)
const C_WALL_LO := Color(0.227, 0.196, 0.165)
const C_PANEL := Color(0.172, 0.149, 0.125)

# ---- Pixel sprites (8x8 maps + palette) ----
const SPRITES := {
	"enemy": ["........", "..GGGG..", ".GGGGGG.", "GGGGGGGG", "GWBGGWBG", "GGGGGGGG", "EGGGGGGE", ".EEEEEE."],
	"trap": ["........", "m.m.m.m.", "mmmmmmmm", "MmMmMmMm", "MMMMMMMM", "oooooooo", "OoOoOoOo", "OOOOOOOO"],
	"coin": ["..KKKK..", ".KgyygK.", "KgyyggsK", "KgygggsK", "KgygggsK", "KgggggsK", ".KgsssK.", "..KKKK.."],
	"heart": [".rr..rr.", "rprrrrrr", "rrrrrrrr", "rrrrrrrr", ".rrrrrr.", "..rrrr..", "...rr...", "........"],
	"chest": ["........", ".KKKKKK.", ".KwwwwK.", ".gggggg.", ".KwllwK.", ".KwllwK.", ".KKKKKK.", "........"],
	"player": ["...dd...", "..dddd..", "..ffff..", "..fKfK..", ".buuuub.", ".uUUUUu.", "..u..u..", "..b..b.."],
	"door": ["..DDDD..", ".DwwwwD.", "DwwwwwwD", "DwwwywwD", "DwwwwwwD", "DwwwwwwD", "DwwwwwwD", "DDDDDDDD"],
	"stairs": ["........", "QQ......", "QqQQ....", "QqQqQQ..", "QqQqQqQQ", "QqQqQqQq", "QqQqQqQq", "QQQQQQQQ"],
}
var SPRITE_PAL := {
	"K": Color8(43, 43, 43), "g": Color8(205, 161, 42), "y": Color8(244, 221, 132),
	"s": Color8(143, 111, 20), "r": Color8(194, 49, 66), "p": Color8(236, 111, 128),
	"G": Color8(90, 168, 108), "E": Color8(53, 96, 64), "B": Color8(22, 33, 15),
	"W": Color8(255, 255, 255), "n": Color8(233, 227, 209), "m": Color8(194, 198, 202),
	"M": Color8(123, 129, 134), "o": Color8(111, 86, 56), "O": Color8(84, 64, 31),
	"w": Color8(154, 101, 49), "l": Color8(36, 26, 14), "d": Color8(58, 42, 26),
	"f": Color8(227, 180, 140), "u": Color8(46, 90, 140), "U": Color8(29, 58, 92),
	"b": Color8(107, 74, 42), "D": Color8(74, 51, 32), "q": Color8(184, 176, 160),
	"Q": Color8(106, 98, 88),
}

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
	_style_button(b)
	parent.add_child(b)
	return b


func _style_button(b: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color8(58, 44, 30)
	sb.set_border_width_all(3)
	sb.border_color = Color8(201, 162, 39)
	sb.set_corner_radius_all(4)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.bg_color = Color8(82, 62, 40)
	var press: StyleBoxFlat = sb.duplicate()
	press.bg_color = Color8(40, 30, 20)
	var dis: StyleBoxFlat = sb.duplicate()
	dis.bg_color = Color8(48, 42, 36)
	dis.border_color = Color8(96, 86, 60)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", press)
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_color_override("font_color", Color8(244, 221, 132))
	b.add_theme_color_override("font_hover_color", Color8(255, 238, 160))
	b.add_theme_color_override("font_disabled_color", Color8(140, 128, 104))


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
	var counts := {
		"enemy": 1 + randi() % 10,   # 1..10
		"trap": 1 + randi() % 10,    # 1..10
		"coin": 1 + randi() % 10,    # 1..10
		"heart": 1 + randi() % 10,   # 1..10
		"chest": randi() % 6,        # 0..5
	}
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


func _draw_sprite(sprite_name: String, ctr: Vector2) -> void:
	var map: Array = SPRITES[sprite_name]
	var rows := map.size()
	var cols: int = map[0].length()
	var px := TILE / float(cols)
	var ox := ctr.x - cols * px / 2.0
	var oy := ctr.y - rows * px / 2.0
	for y in rows:
		var row: String = map[y]
		for x in cols:
			var ch := row[x]
			if SPRITE_PAL.has(ch):
				draw_rect(Rect2(ox + x * px, oy + y * px, px + 0.7, px + 0.7), SPRITE_PAL[ch], true)


func _draw() -> void:
	var grid_bottom := GRID_TOP + ROWS * TILE

	# framing panels (top + bottom) with gold trim
	draw_rect(Rect2(0, 0, COLS * TILE, GRID_TOP), C_PANEL, true)
	draw_rect(Rect2(0, grid_bottom, COLS * TILE, 460), C_PANEL, true)

	# parchment play field
	draw_rect(Rect2(0, GRID_TOP, COLS * TILE, ROWS * TILE), C_PAPER, true)

	# grid lines
	for i in range(COLS + 1):
		draw_line(Vector2(i * TILE, GRID_TOP), Vector2(i * TILE, grid_bottom), C_LINE, 1.0)
	for j in range(ROWS + 1):
		draw_line(Vector2(0, GRID_TOP + j * TILE), Vector2(COLS * TILE, GRID_TOP + j * TILE), C_LINE, 1.0)

	# gold trim around the field
	draw_rect(Rect2(0, GRID_TOP - 3, COLS * TILE, 3), C_GOLD, true)
	draw_rect(Rect2(0, grid_bottom, COLS * TILE, 3), C_GOLD, true)

	# walls — stone blocks, beveled only on the outer edge of each wall mass
	for w in walls:
		var wx: float = w.x * TILE
		var wy: float = GRID_TOP + w.y * TILE
		draw_rect(Rect2(wx, wy, TILE, TILE), C_WALL, true)
		if not is_wall(w + Vector2i(0, -1)):
			draw_rect(Rect2(wx, wy, TILE, 3), C_WALL_HI, true)
		if not is_wall(w + Vector2i(-1, 0)):
			draw_rect(Rect2(wx, wy, 3, TILE), C_WALL_HI, true)
		if not is_wall(w + Vector2i(0, 1)):
			draw_rect(Rect2(wx, wy + TILE - 3, TILE, 3), C_WALL_LO, true)
		if not is_wall(w + Vector2i(1, 0)):
			draw_rect(Rect2(wx + TILE - 3, wy, 3, TILE), C_WALL_LO, true)

	# entrance (stairs) + exit (door)
	_draw_sprite("stairs", cell_center(entrance_cell))
	_draw_sprite("door", cell_center(exit_cell))

	# travelled pencil line
	if path.size() >= 2:
		var pts := PackedVector2Array()
		for c in path:
			pts.append(cell_center(c))
		draw_polyline(pts, C_INK, 3.0, true)

	# entities (pixel sprites)
	for e in entities:
		var ctr := cell_center(e.pos)
		if not e.alive:
			_draw_dead(ctr)
		else:
			_draw_sprite(e.type, ctr)

	# movement options (after a roll) — show the full route incl. turns
	var pc_start := cell_center(player.pos)
	var opt_r := TILE * 0.40
	for opt in options:
		var op_path: Array = option_paths.get(opt, [])
		var pts2 := PackedVector2Array()
		pts2.append(pc_start)
		for c in op_path:
			pts2.append(cell_center(c))
		if pts2.size() >= 2:
			draw_polyline(pts2, Color(0.29, 0.49, 0.35, 0.5), 2.0, true)
		var oc := cell_center(opt)
		draw_circle(oc, opt_r, Color(0.29, 0.49, 0.35, 0.30))
		draw_arc(oc, opt_r, 0, TAU, 22, C_GREEN, 2.0)

	# player (hero sprite)
	_draw_sprite("player", cell_center(player.pos))


func _draw_dead(ctr: Vector2) -> void:
	var d := TILE * 0.22
	draw_line(ctr + Vector2(-d, -d), ctr + Vector2(d, d), C_GRAY, 2.5)
	draw_line(ctr + Vector2(d, -d), ctr + Vector2(-d, d), C_GRAY, 2.5)
