class_name Kitchen
extends Node3D
## The one kitchen layout, used for all three levels. Built from LAYOUT on a
## grid of TILE_SIZE tiles, with grid pathfinding for NPCs.
##
## Furniture, floor and walls are KayKit Restaurant Bits models (CC0, in
## assets/models/kitchen/), listed in MODELS by layout character. KayKit pieces
## are two units per tile, so they are scaled by KAYKIT_SCALE. Each piece faces
## its tile's open side (a station faces its work tile). If a model file is
## missing, a coloured placeholder box is used instead.

## Row = z, column = x. The camera looks from the +x/+z corner, so the
## right-hand and front walls are kept low so they never hide the floor.
##
## Laid out like a commercial kitchen: a cook line along the back wall, two
## rows of counters (islands) with gaps between them, and the service counter
## at the front. NPCs have to route through the gaps, so where each station
## sits changes how far every errand is.
const LAYOUT: Array[String] = [
	"##############",
	"#RD=G==F===YX#",
	"#............#",
	"#.==P==..===.#",
	"#............#",
	"#B..===..==.K#",
	"#B...........#",
	"#####=C=######",
	"oooooooooooooo",
	"oooooooooooooo",
]
## The wall row between the kitchen and the customers.
const FRONT_ROW := 7

## Layout character -> station id. Station tiles are solid.
const STATION_CHARS := {"C": "counter", "G": "grill", "F": "fryer", "P": "prep", "K": "cleaning"}
## Solid furniture that is not a station: counter tops, break table, decor.
const FURNITURE_CHARS := ["=", "B", "R", "D", "X", "Y"]

const KAYKIT := "res://assets/models/kitchen/%s.gltf"
const KAYKIT_SCALE := 0.5
## Models per layout character: {"file", "y" (height offset, in tiles)}.
const MODELS := {
	".": [{"file": "floor_kitchen_small", "y": -0.25}],
	"=": [{"file": "kitchencounter_straight_A"}],
	"C": [{"file": "kitchencounter_straight_B"}],
	"G": [{"file": "stove_multi"}],
	"F": [{"file": "stove_single"}, {"file": "pan_A", "y": 0.47}],
	"P": [{"file": "kitchentable_A"}, {"file": "cuttingboard", "y": 0.5}],
	"K": [{"file": "kitchencounter_sink"}],
	"B": [{"file": "table_round_A_small"}],
	"R": [{"file": "fridge_A_decorated"}],
	"D": [{"file": "kitchencounter_straight_A_decorated"}],
	"X": [{"file": "crate_tomatoes"}],
	"Y": [{"file": "crate_carrots"}],
}
const WALL_MODEL := "wall"
const WINDOW_MODEL := "wall_window_closed"
const CORNER_MODEL := "pillar_A"
const BREAK_SEAT_MODEL := "chair_A"
## Seat height of the break chair, so a sitting NPC sits on it.
const BREAK_SEAT_HEIGHT := 0.25
## KayKit wall panels are 4 x 4 units and 0.5 thick before scaling.
const WALL_PANEL := Vector3(4.0, 4.0, 0.5)

const WALL_HEIGHT := 1.6
const LOW_WALL_HEIGHT := 0.35
const FURNITURE_HEIGHT := 0.9
const BENCH_HEIGHT := 0.45

const FLOOR_A := Color(0.62, 0.60, 0.56)
const FLOOR_B := Color(0.54, 0.52, 0.49)
const OUTSIDE := Color(0.36, 0.45, 0.33)
const WALL := Color(0.72, 0.66, 0.58)
const FURNITURE := Color(0.58, 0.40, 0.25)

var size := Vector2i.ZERO
var stations := {}  # station id -> Station
## Floor tiles next to the break table, one sitter each. Sitting here restores energy and mood.
var break_tiles: Array[Vector2i] = []
## Break tile -> the table tile it faces.
var break_tables := {}
## Walkable tiles around the break tables. Overflow breakers stand here and recover nothing.
var break_stand_tiles: Array[Vector2i] = []
var astar := AStarGrid2D.new()

var _materials := {}


func _ready() -> void:
	size = Vector2i(LAYOUT[0].length(), LAYOUT.size())
	astar.region = Rect2i(Vector2i.ZERO, size)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for z in size.y:
		for x in size.x:
			var c := LAYOUT[z][x]
			if c != "." and c != "o":
				astar.set_point_solid(Vector2i(x, z))
			elif c == "o":
				astar.set_point_solid(Vector2i(x, z))  # customers only
	for z in size.y:
		for x in size.x:
			_build_tile(Vector2i(x, z), LAYOUT[z][x])
	for station: Station in stations.values():
		station.handoff_tile = _handoff_tile(station)
	_collect_break_stands()


# --- Grid helpers -----------------------------------------------------------

func tile_to_world(t: Vector2i) -> Vector3:
	return Vector3((t.x + 0.5) * Balance.TILE_SIZE, 0.0, (t.y + 0.5) * Balance.TILE_SIZE)


func world_to_tile(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / Balance.TILE_SIZE), floori(p.z / Balance.TILE_SIZE))


## Distance between two world points, in tiles, on the floor plane.
static func tile_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length() / Balance.TILE_SIZE


func is_walkable(t: Vector2i) -> bool:
	return astar.is_in_boundsv(t) and LAYOUT[t.y][t.x] == "."


## Tiles immediately around the break seats and tables, not the seats themselves.
func _collect_break_stands() -> void:
	var seen := {}
	var seeds: Array[Vector2i] = []
	seeds.append_array(break_tiles)
	for seat in break_tables:
		seeds.append(break_tables[seat])
	for seed in seeds:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var t := seed + Vector2i(dx, dz)
				if break_tiles.has(t) or not is_walkable(t):
					continue
				seen[t] = true
	for t in seen:
		break_stand_tiles.append(t)


## World-space path from a point to the centre of a tile. Empty if none.
func find_path(from: Vector3, to_tile: Vector2i) -> PackedVector3Array:
	var start := _nearest_walkable(world_to_tile(from))
	var cells := astar.get_id_path(start, to_tile)
	var path := PackedVector3Array()
	for cell in cells:
		path.append(tile_to_world(cell))
	return path


func station_at_tile(t: Vector2i) -> Station:
	for station: Station in stations.values():
		if station.tile == t:
			return station
	return null


func center() -> Vector3:
	return tile_to_world(Vector2i(size.x / 2, 4))


# --- Building ---------------------------------------------------------------

func _build_tile(t: Vector2i, c: String) -> void:
	var pos := tile_to_world(t)
	if c == "o":
		_box(Vector3(1, 0.1, 1), pos + Vector3(0, -0.05, 0), OUTSIDE, false)
		return
	if c == "#":
		# No kitchen floor under walls: the panel sits on the kitchen side.
		if t.y == FRONT_ROW:
			_box(Vector3(1, 0.1, 1), pos + Vector3(0, -0.05, 0), OUTSIDE, false)
		_build_wall(t, pos)
		return
	if not _place_models(".", pos, 0.0):
		var shade := FLOOR_A if (t.x + t.y) % 2 == 0 else FLOOR_B
		_box(Vector3(1, 0.1, 1), pos + Vector3(0, -0.05, 0), shade, false)

	if c in STATION_CHARS:
		var open_side := _open_side(t)
		var station := Station.new()
		station.setup(STATION_CHARS[c], t, t + open_side)
		station.position = pos
		add_child(station)
		stations[station.station_id] = station
		if not _place_models(c, Vector3.ZERO, _yaw(open_side), station):
			_box(Vector3(0.9, FURNITURE_HEIGHT, 0.9), Vector3(0, FURNITURE_HEIGHT / 2, 0), station.color(), false, station)
		_collider(Vector3(1, FURNITURE_HEIGHT, 1), pos + Vector3(0, FURNITURE_HEIGHT / 2, 0))
		station.build_labels(FURNITURE_HEIGHT)
	elif c in FURNITURE_CHARS:
		var open_side := _open_side(t)
		var h := BENCH_HEIGHT if c == "B" else FURNITURE_HEIGHT
		if not _place_models(c, pos, _yaw(open_side)):
			_box(Vector3(0.95, h, 0.95), pos + Vector3(0, h / 2, 0), FURNITURE, false)
		_collider(Vector3(1, h, 1), pos + Vector3(0, h / 2, 0))
		if c == "B":
			var seat := t + open_side
			break_tiles.append(seat)
			break_tables[seat] = t
			_place_model(BREAK_SEAT_MODEL, tile_to_world(seat), _yaw(-open_side))


## A wall tile: a thin panel on the kitchen side, or a pillar in a corner.
## The whole tile is solid.
func _build_wall(t: Vector2i, pos: Vector3) -> void:
	var near_camera := t.x == size.x - 1 or t.y >= FRONT_ROW
	var h := LOW_WALL_HEIGHT if near_camera else WALL_HEIGHT
	_collider(Vector3(1, h, 1), pos + Vector3(0, h / 2, 0))
	var inner := Vector2i.ZERO
	var sides := 0
	if t.y == 0:
		inner += Vector2i(0, 1); sides += 1
	if t.y == FRONT_ROW:
		inner += Vector2i(0, -1); sides += 1
	if t.x == 0:
		inner += Vector2i(1, 0); sides += 1
	if t.x == size.x - 1:
		inner += Vector2i(-1, 0); sides += 1
	var thickness := WALL_PANEL.z * KAYKIT_SCALE
	if sides == 1:
		var file := WINDOW_MODEL if not near_camera and (t.x + t.y) % 4 == 2 else WALL_MODEL
		var at := pos + Vector3(inner.x, 0, inner.y) * (0.5 - thickness / 2.0)
		var panel_scale := Vector3(1.0 / WALL_PANEL.x, h / WALL_PANEL.y, KAYKIT_SCALE)
		if not _place_model(file, at, _yaw(inner), self, panel_scale):
			_box(Vector3(1, h, 1), pos + Vector3(0, h / 2, 0), WALL, false)
	else:
		# Corner: a pillar where the two inner faces meet.
		var at := pos + Vector3(inner.x, 0, inner.y) * (0.5 - thickness / 2.0)
		var pillar_scale := Vector3(KAYKIT_SCALE, h / 4.1, KAYKIT_SCALE)
		if not _place_model(CORNER_MODEL, at, 0.0, self, pillar_scale):
			_box(Vector3(1, h, 1), pos + Vector3(0, h / 2, 0), WALL, false)


## The neighbouring floor tile a piece of furniture faces: preferably one
## with a wall behind the furniture, then anything solid behind it.
func _open_side(t: Vector2i) -> Vector2i:
	var best := Vector2i.ZERO
	var best_rank := 0
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if not is_walkable(t + d):
			continue
		var behind := t - d
		var rank := 1
		if astar.is_in_boundsv(behind) and LAYOUT[behind.y][behind.x] == "#":
			rank = 3
		elif not is_walkable(behind):
			rank = 2
		if rank > best_rank:
			best = d
			best_rank = rank
	return best


## Where the counter NPC stands to hand over at a station: behind the cook if
## there is floor there, else beside them; never on another station's work
## tile. Falls back to the work tile itself.
func _handoff_tile(station: Station) -> Vector2i:
	var out := station.work_tile - station.tile
	var side := Vector2i(out.y, out.x)
	var work_tiles := stations.values().map(func(s: Station) -> Vector2i: return s.work_tile)
	for t: Vector2i in [station.work_tile + out, station.work_tile + side, station.work_tile - side]:
		if is_walkable(t) and not t in work_tiles:
			return t
	return station.work_tile


## Rotation that turns a model's front (+Z) toward a grid direction.
func _yaw(d: Vector2i) -> float:
	return atan2(float(d.x), float(d.y))


## Places every model listed for a layout character. False if any is missing.
func _place_models(c: String, pos: Vector3, yaw: float, parent: Node3D = self) -> bool:
	if not MODELS.has(c):
		return false
	for spec: Dictionary in MODELS[c]:
		if not ResourceLoader.exists(KAYKIT % spec.file):
			return false
	for spec: Dictionary in MODELS[c]:
		_place_model(spec.file, pos + Vector3(0, spec.get("y", 0.0), 0), yaw, parent)
	return true


func _place_model(file: String, pos: Vector3, yaw: float, parent: Node3D = self,
		model_scale := Vector3.ONE * KAYKIT_SCALE) -> bool:
	var path := KAYKIT % file
	if not ResourceLoader.exists(path):
		return false
	var model: Node3D = (load(path) as PackedScene).instantiate()
	model.position = pos
	model.rotation.y = yaw
	model.scale = model_scale
	parent.add_child(model)
	return true


func _box(box_size: Vector3, pos: Vector3, color: Color, solid: bool, parent: Node3D = self) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh.mesh = box
	mesh.material_override = _material(color)
	mesh.position = pos
	parent.add_child(mesh)
	if solid:
		_collider(box_size, pos)


func _collider(box_size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	add_child(body)


func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.9
		_materials[color] = m
	return _materials[color]


func _nearest_walkable(t: Vector2i) -> Vector2i:
	if is_walkable(t):
		return t
	for r in range(1, 4):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if is_walkable(t + Vector2i(dx, dz)):
					return t + Vector2i(dx, dz)
	return t
