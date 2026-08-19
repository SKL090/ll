## Разрушаемая тайловая карта города
## - строит город из тайлов (полы/стены/двери/кровати)
## - хранит материал и прочность каждого тайла
## - огонь распространяется по горючим материалам
## - A* поиск пути по сетке
class_name WorldMap
extends Node2D

signal fire_started(cell: Vector2i)
signal fire_extinguished(cell: Vector2i)
signal tile_destroyed(cell: Vector2i, material: String)
signal door_toggled(cell: Vector2i, open: bool)

const MAP_W := 60
const MAP_H := 44

# Размер тайла 64×64 (автоматически уточняется по спрайту grass.png)
var tile_size: int = 64

# Слои отрисовки
const Z_FLOOR := 0
const Z_OBJECT := 1
const Z_WALL := 2
const Z_FIRE := 4

# Физические слои (совпадает с project.godot)
const LAYER_WORLD := 1
const LAYER_NPCS := 2

# Материалы: прочность, горючесть, шанс распространения, чем заменить при сгорании
const MATERIAL := {
	"wood_wall":  {"hp": 100.0, "flammable": true,  "spread": 0.7, "replace": "dirt"},
	"stone_wall": {"hp": 400.0, "flammable": false, "spread": 0.0, "replace": ""},
	"wood_floor": {"hp": 80.0,  "flammable": true,  "spread": 0.55, "replace": "dirt"},
	"stone_floor": {"hp": 9999.0, "flammable": false, "spread": 0.0, "replace": ""},
	"grass":      {"hp": 60.0,  "flammable": true,  "spread": 0.12, "replace": "dirt"},
	"dirt":       {"hp": 9999.0, "flammable": false, "spread": 0.0, "replace": ""},
	"door":       {"hp": 60.0,  "flammable": true,  "spread": 0.6, "replace": ""},
	"bed":        {"hp": 50.0,  "flammable": true,  "spread": 0.8, "replace": ""},
}

const BURN_TICK := 0.25
const DAMAGE_PER_SEC := 14.0

var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var object_layer: TileMapLayer
var fire_layer: TileMapLayer

var tile_set: TileSet
var source_ids: Dictionary = {}   # имя спрайта -> id источника

var cell_mat: Dictionary = {}     # Vector2i -> название материала
var cell_hp: Dictionary = {}      # Vector2i -> float
var cell_max_hp: Dictionary = {}
var blocked: Dictionary = {}      # Vector2i -> true (непроходимая стена)
var door_open: Dictionary = {}    # Vector2i -> bool

var fires: Dictionary = {}        # Vector2i -> {life: float, spread_timer: float}

# Пол под объектами (дверь/кровать) — что останется после сгорания объекта
var under_floor: Dictionary = {}  # Vector2i -> материал пола

# Кровати и здания (для систем)
var bed_cells: Array[Vector2i] = []
var building_rects: Dictionary = {}  # имя -> Rect2i (в клетках)

var _burn_accum: float = 0.0


func _ready() -> void:
	_create_layers()
	_build_tileset()
	_build_city()
	print("🗺️ Карта построена: %d x %d тайлов" % [MAP_W, MAP_H])


func _process(delta: float) -> void:
	if GameManager.is_paused:
		return
	_burn_accum += delta
	if _burn_accum >= BURN_TICK:
		_tick_fire(BURN_TICK)
		_burn_accum = 0.0


## Полный сброс карты (новая игра)
func rebuild() -> void:
	floor_layer.clear()
	wall_layer.clear()
	object_layer.clear()
	fire_layer.clear()
	cell_mat.clear()
	cell_hp.clear()
	cell_max_hp.clear()
	blocked.clear()
	door_open.clear()
	fires.clear()
	under_floor.clear()
	bed_cells.clear()
	building_rects.clear()
	_burn_accum = 0.0
	_build_city()
	print("🗺️ Карта пересоздана")


# ============================================================ ПОСТРОЕНИЕ ТАЙЛСЕТА

func _create_layers() -> void:
	floor_layer = TileMapLayer.new()
	floor_layer.name = "FloorLayer"
	floor_layer.z_index = Z_FLOOR
	floor_layer.collision_enabled = false
	add_child(floor_layer)

	wall_layer = TileMapLayer.new()
	wall_layer.name = "WallLayer"
	wall_layer.z_index = Z_WALL
	wall_layer.collision_enabled = true
	wall_layer.collision_layer = LAYER_WORLD
	wall_layer.collision_mask = 0
	add_child(wall_layer)

	object_layer = TileMapLayer.new()
	object_layer.name = "ObjectLayer"
	object_layer.z_index = Z_OBJECT
	object_layer.collision_enabled = false
	add_child(object_layer)

	fire_layer = TileMapLayer.new()
	fire_layer.name = "FireLayer"
	fire_layer.z_index = Z_FIRE
	fire_layer.collision_enabled = false
	add_child(fire_layer)


func _build_tileset() -> void:
	# Автоопределение размера тайла по спрайту травы
	var grass_tex: Texture2D = load("res://assets/sprites/grass.png")
	if grass_tex and int(grass_tex.get_width()) >= 8:
		tile_size = int(grass_tex.get_width())
		print("🟩 Размер тайла: %d px" % tile_size)

	tile_set = TileSet.new()
	tile_set.tile_size = Vector2i(tile_size, tile_size)
	_add_source("grass", "res://assets/sprites/grass.png", false)
	_add_source("dirt", "res://assets/sprites/dirt.png", false)
	_add_source("wood_floor", "res://assets/sprites/wood_floor.png", false)
	_add_source("stone_floor", "res://assets/sprites/stone_floor.png", false)
	_add_source("wood_wall", "res://assets/sprites/wood_wall.png", true)
	_add_source("stone_wall", "res://assets/sprites/stone_wall.png", true)
	_add_source("door_closed", "res://assets/sprites/door_closed.png", false)
	_add_source("door_opened", "res://assets/sprites/door_opened.png", false)
	_add_source("bed", "res://assets/sprites/bed.png", false)
	_add_source("fire", "res://assets/sprites/fire.png", false)

	floor_layer.tile_set = tile_set
	wall_layer.tile_set = tile_set
	object_layer.tile_set = tile_set
	fire_layer.tile_set = tile_set


func _add_source(name: String, path: String, solid: bool) -> int:
	var src := TileSetAtlasSource.new()
	var tex: Texture2D = load(path)
	src.texture = tex
	src.texture_region_size = Vector2i(tile_size, tile_size)
	src.create_tile(Vector2i(0, 0))
	if solid:
		var td: TileData = src.get_tile_data(Vector2i(0, 0), 0)
		_add_solid_collision(td)
	var id := source_ids.size()
	source_ids[name] = id
	tile_set.add_source(src, id)
	return id


func _add_solid_collision(td: TileData) -> void:
	td.add_collision_polygon(0)
	var pts := PackedVector2Array([
		Vector2(0, 0),
		Vector2(tile_size, 0),
		Vector2(tile_size, tile_size),
		Vector2(0, tile_size),
	])
	td.set_collision_polygon_points(0, 0, pts)


# ============================================================ ПОСТРОЕНИЕ ГОРОДА

func _build_city() -> void:
	# газон
	_fill_floor(Rect2i(0, 0, MAP_W, MAP_H), "grass")
	# дороги
	_fill_floor(Rect2i(28, 0, 3, MAP_H), "dirt")
	_fill_floor(Rect2i(0, 20, MAP_W, 3), "dirt")
	# площадь (перекрывает перекрёсток)
	_fill_floor(Rect2i(24, 16, 14, 9), "stone_floor")

	# поле фермы
	_fill_floor(Rect2i(2, 4, 7, 6), "dirt")

	# здания: (имя, rect, стены, пол, [двери], кровати)
	_add_building("castle", Rect2i(10, 4, 12, 8), "stone_wall", "stone_floor", [Vector2i(15, 11), Vector2i(16, 11)], 2)
	_add_building("barracks", Rect2i(2, 13, 8, 7), "stone_wall", "stone_floor", [Vector2i(6, 19)], 3)
	_add_building("cathedral", Rect2i(38, 4, 12, 8), "stone_wall", "stone_floor", [Vector2i(43, 11), Vector2i(44, 11)], 1)
	_add_building("inquisition", Rect2i(40, 13, 9, 7), "stone_wall", "stone_floor", [Vector2i(44, 19)], 1)
	_add_building("prison", Rect2i(2, 26, 7, 6), "stone_wall", "stone_floor", [Vector2i(5, 31)], 0)
	_add_building("shop", Rect2i(38, 26, 9, 6), "wood_wall", "wood_floor", [Vector2i(42, 31)], 1)
	_add_building("house1", Rect2i(10, 26, 7, 6), "wood_wall", "wood_floor", [Vector2i(13, 31)], 2)
	_add_building("house2", Rect2i(48, 26, 7, 6), "wood_wall", "wood_floor", [Vector2i(51, 31)], 2)
	_add_building("house3", Rect2i(38, 33, 7, 6), "wood_wall", "wood_floor", [Vector2i(41, 38)], 2)
	_add_building("house4", Rect2i(46, 33, 7, 6), "wood_wall", "wood_floor", [Vector2i(49, 38)], 2)


func _add_building(name: String, rect: Rect2i, wall_mat: String, floor_mat: String, doors: Array, beds: int) -> void:
	building_rects[name] = rect
	_build_building(rect, wall_mat, floor_mat, doors, beds)


func _fill_floor(rect: Rect2i, mat: String) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			set_floor(Vector2i(x, y), mat)


func _build_building(rect: Rect2i, wall_mat: String, floor_mat: String, doors: Array, beds: int) -> void:
	var inner := Rect2i(rect.position + Vector2i(1, 1), rect.size - Vector2i(2, 2))
	_fill_floor(inner, floor_mat)

	for x in range(rect.position.x, rect.end.x):
		set_wall(Vector2i(x, rect.position.y), wall_mat)
		set_wall(Vector2i(x, rect.end.y - 1), wall_mat)
	for y in range(rect.position.y, rect.end.y):
		set_wall(Vector2i(rect.position.x, y), wall_mat)
		set_wall(Vector2i(rect.end.x - 1, y), wall_mat)

	for d in doors:
		_clear_cell_from_map(d)
		set_door(d, floor_mat)

	if beds > 0:
		var candidates: Array = []
		for y in range(inner.position.y, inner.end.y):
			for x in range(inner.position.x, inner.end.x):
				candidates.append(Vector2i(x, y))
		candidates.shuffle()
		for i in range(min(beds, candidates.size())):
			set_bed(candidates[i], floor_mat)


# ============================================================ УСТАНОВКА ТАЙЛОВ

func set_floor(cell: Vector2i, mat: String) -> void:
	floor_layer.set_cell(cell, source_ids[mat], Vector2i(0, 0))
	_set_mat(cell, mat)


func set_wall(cell: Vector2i, mat: String) -> void:
	wall_layer.set_cell(cell, source_ids[mat], Vector2i(0, 0))
	_set_mat(cell, mat)
	blocked[cell] = true


func set_door(cell: Vector2i, floor_mat: String = "stone_floor") -> void:
	# под дверью всегда пол — останется, когда дверь сгорит
	floor_layer.set_cell(cell, source_ids[floor_mat], Vector2i(0, 0))
	under_floor[cell] = floor_mat
	wall_layer.set_cell(cell, source_ids["door_closed"], Vector2i(0, 0))
	_set_mat(cell, "door")
	door_open[cell] = false


func set_bed(cell: Vector2i, floor_mat: String = "wood_floor") -> void:
	object_layer.set_cell(cell, source_ids["bed"], Vector2i(0, 0))
	under_floor[cell] = floor_mat
	bed_cells.append(cell)
	_set_mat(cell, "bed")


func _set_mat(cell: Vector2i, mat: String) -> void:
	cell_mat[cell] = mat
	var info: Dictionary = MATERIAL.get(mat, {})
	var hp: float = info.get("hp", 100.0)
	cell_hp[cell] = hp
	cell_max_hp[cell] = hp


func _clear_cell_from_map(cell: Vector2i) -> void:
	wall_layer.erase_cell(cell)
	object_layer.erase_cell(cell)
	fire_layer.erase_cell(cell)
	blocked.erase(cell)
	door_open.erase(cell)
	cell_mat.erase(cell)
	cell_hp.erase(cell)
	cell_max_hp.erase(cell)


# ============================================================ ДВЕРИ

func toggle_door(cell: Vector2i) -> void:
	if not door_open.has(cell):
		return
	var open: bool = not door_open[cell]
	door_open[cell] = open
	wall_layer.set_cell(cell, source_ids["door_opened" if open else "door_closed"], Vector2i(0, 0))
	emit_signal("door_toggled", cell, open)


func open_door_near(pos: Vector2, radius: float = -1.0) -> void:
	if radius < 0.0:
		radius = tile_size * 0.8
	var center := _world_to_cell(pos)
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			var cell := Vector2i(x, y)
			if door_open.has(cell) and not door_open[cell]:
				toggle_door(cell)


# ============================================================ ОГОНЬ

func ignite(cell: Vector2i) -> void:
	if fires.has(cell):
		return
	var mat: String = cell_mat.get(cell, "")
	if not _is_flammable(mat):
		return
	fires[cell] = {"life": randf_range(4.0, 9.0), "spread_timer": randf_range(0.2, 0.6)}
	fire_layer.set_cell(cell, source_ids["fire"], Vector2i(0, 0))
	emit_signal("fire_started", cell)


func extinguish(cell: Vector2i) -> void:
	if not fires.has(cell):
		return
	fires.erase(cell)
	fire_layer.erase_cell(cell)
	emit_signal("fire_extinguished", cell)


func _is_flammable(mat: String) -> bool:
	return bool(MATERIAL.get(mat, {}).get("flammable", false))


## Публичная проверка горючести материала
func is_flammable_mat(mat: String) -> bool:
	return _is_flammable(mat)


func _tick_fire(dt: float) -> void:
	var keys: Array = fires.keys()
	for cell in keys:
		if not fires.has(cell):
			continue
		var f: Dictionary = fires[cell]
		f["life"] -= dt
		if f["life"] <= 0.0:
			extinguish(cell)
			continue

		var mat: String = cell_mat.get(cell, "")
		if _is_flammable(mat):
			var hp: float = cell_hp.get(cell, 0.0) - DAMAGE_PER_SEC * dt
			cell_hp[cell] = hp
			if hp <= 0.0:
				_destroy_cell(cell)
				continue

		f["spread_timer"] -= dt
		if f["spread_timer"] <= 0.0:
			f["spread_timer"] = randf_range(0.4, 0.9)
			_try_spread(cell)


func _try_spread(cell: Vector2i) -> void:
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	dirs.shuffle()
	for d in dirs:
		var n: Vector2i = cell + d
		var mat: String = cell_mat.get(n, "")
		if not _is_flammable(mat):
			continue
		if fires.has(n):
			continue
		var spread: float = MATERIAL.get(mat, {}).get("spread", 0.5)
		if randf() < spread:
			ignite(n)
		return


func _destroy_cell(cell: Vector2i) -> void:
	var mat: String = cell_mat.get(cell, "")
	fires.erase(cell)

	# дверь/кровать стоят ПОВЕРХ пола — пол остаётся
	if mat == "door" or mat == "bed":
		var under: String = under_floor.get(cell, "dirt")
		_clear_cell_from_map(cell)
		cell_mat[cell] = under
		cell_hp[cell] = MATERIAL.get(under, {}).get("hp", 9999.0)
		cell_max_hp[cell] = cell_hp[cell]
		emit_signal("tile_destroyed", cell, mat)
		return

	# стена/пол/трава — после догорания остаётся грязь
	var replace: String = MATERIAL.get(mat, {}).get("replace", "dirt")
	_clear_cell_from_map(cell)
	floor_layer.set_cell(cell, source_ids[replace], Vector2i(0, 0))
	_set_mat(cell, replace)
	emit_signal("tile_destroyed", cell, mat)


# ============================================================ НАВИГАЦИЯ

func is_walkable_cell(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= MAP_W or cell.y >= MAP_H:
		return false
	return not blocked.has(cell)


func is_walkable_world(pos: Vector2) -> bool:
	return is_walkable_cell(_world_to_cell(pos))


func _world_to_cell(pos: Vector2) -> Vector2i:
	var lp := to_local(pos)
	return Vector2i(floori(lp.x / tile_size), floori(lp.y / tile_size))


## Текущий размер тайла (px)
func get_tile_size() -> int:
	return tile_size


## Размер карты в мировых координатах (для камеры)
func get_world_rect() -> Rect2:
	return Rect2(0, 0, MAP_W * tile_size, MAP_H * tile_size)


## Публичная обёртка: мировые координаты -> клетка
func world_to_cell(pos: Vector2) -> Vector2i:
	return _world_to_cell(pos)


## Свободная кровать ближайшая к точке (и занять её)
func claim_bed_near(pos: Vector2) -> Vector2:
	var best: Vector2i = Vector2i(-1, -1)
	var best_d: float = INF
	for cell in bed_cells:
		var d: float = cell_center_world(cell).distance_to(pos)
		if d < best_d:
			best_d = d
			best = cell
	if best.x >= 0:
		bed_cells.erase(best)
		return cell_center_world(best)
	return Vector2.ZERO


## Случайная проходимая клетка внутри здания (мировые координаты)
func get_random_in_building(building: String) -> Vector2:
	var rect: Rect2i = building_rects.get(building, Rect2i())
	if rect.size == Vector2i.ZERO:
		return random_walkable_position()
	var inner := Rect2i(rect.position + Vector2i(1, 1), rect.size - Vector2i(2, 2))
	for _i in 100:
		var cell := Vector2i(randi_range(inner.position.x, inner.end.x - 1), randi_range(inner.position.y, inner.end.y - 1))
		if is_walkable_cell(cell):
			return cell_center_world(cell)
	return cell_center_world(inner.position)


## Горючие клетки стен/пола здания (для поджога)
func get_flammable_building_cells(building: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var rect: Rect2i = building_rects.get(building, Rect2i())
	if rect.size == Vector2i.ZERO:
		return result
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			var mat: String = cell_mat.get(cell, "")
			if _is_flammable(mat):
				result.append(cell)
	return result


func cell_center_world(cell: Vector2i) -> Vector2:
	var lp := Vector2(cell.x * tile_size + tile_size * 0.5, cell.y * tile_size + tile_size * 0.5)
	return to_global(lp)


func find_path_world(from_pos: Vector2, to_pos: Vector2) -> Array[Vector2]:
	var start := _world_to_cell(from_pos)
	var end := _world_to_cell(to_pos)
	var cells := _astar(start, end)
	var path: Array[Vector2] = []
	for c in cells:
		path.append(cell_center_world(c))
	if path.size() > 0:
		path[path.size() - 1] = to_pos
	return path


func _astar(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	if not is_walkable_cell(end):
		end = closest_walkable_cell(end)
	if start == end:
		return [end]

	var open: Array = [start]
	var came_from: Dictionary = {}
	var g: Dictionary = {start: 0.0}
	var f: Dictionary = {start: _heuristic(start, end)}
	var visited: Dictionary = {}

	while open.size() > 0:
		var current: Vector2i = open[0]
		var best: float = f.get(current, INF)
		for c in open:
			var cf: float = f.get(c, INF)
			if cf < best:
				current = c
				best = cf
		if current == end:
			return _reconstruct(came_from, current)
		open.erase(current)
		visited[current] = true

		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = current + d
			if visited.has(n):
				continue
			if not is_walkable_cell(n):
				continue
			var tentative: float = g.get(current, INF) + 1.0
			if tentative < g.get(n, INF):
				came_from[n] = current
				g[n] = tentative
				f[n] = tentative + _heuristic(n, end)
				if not open.has(n):
					open.append(n)
	return []


func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return float(absi(a.x - b.x) + absi(a.y - b.y))


func _reconstruct(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		cells.push_front(current)
	return cells


func closest_walkable_cell(cell: Vector2i) -> Vector2i:
	for radius in range(1, 16):
		for y in range(cell.y - radius, cell.y + radius + 1):
			for x in range(cell.x - radius, cell.x + radius + 1):
				var c := Vector2i(x, y)
				if is_walkable_cell(c):
					return c
	return Vector2i(MAP_W / 2, MAP_H / 2)


func random_walkable_position() -> Vector2:
	for _i in 200:
		var cell := Vector2i(randi_range(1, MAP_W - 2), randi_range(1, MAP_H - 2))
		if is_walkable_cell(cell):
			return cell_center_world(cell)
	return cell_center_world(Vector2i(MAP_W / 2, MAP_H / 2))


func get_walkable_position_near(pos: Vector2, radius_tiles: int = 3) -> Vector2:
	var center := _world_to_cell(pos)
	for r in range(0, radius_tiles + 1):
		for y in range(center.y - r, center.y + r + 1):
			for x in range(center.x - r, center.x + r + 1):
				var c := Vector2i(x, y)
				if is_walkable_cell(c):
					return cell_center_world(c)
	return cell_center_world(center)


# ============================================================ ЗРЕНИЕ / LOS

func has_line_of_sight(from_pos: Vector2, to_pos: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from_pos, to_pos, LAYER_WORLD)
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	return hit.is_empty()


func get_tile_material_at(pos: Vector2) -> String:
	return cell_mat.get(_world_to_cell(pos), "")


## Поджечь тайл под точкой (инструмент серого кардинала)
func ignite_at(pos: Vector2) -> void:
	ignite(_world_to_cell(pos))


func has_fire_near(pos: Vector2, radius: float = 100.0) -> bool:
	for cell in fires.keys():
		if cell_center_world(cell).distance_to(pos) <= radius:
			return true
	return false
