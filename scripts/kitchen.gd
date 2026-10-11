class_name Kitchen
extends Node3D
## The one kitchen layout, used for all three levels. Built from LAYOUT on a
## grid of TILE_SIZE tiles, with grid pathfinding for NPCs.
##
## Everything is placeholder boxes for now. To use real models (e.g. the
## KayKit Restaurant Bits pack), put a path in MODELS for a layout character:
## the model is placed on that tile instead of the box. Models should have
## their origin at floor level, centred on the tile, one unit per tile.

## Row = z, column = x. The camera looks from the +x/+z corner, so the
## right-hand and front walls are kept low so they never hide the floor.
const LAYOUT: Array[String] = [
	"##############",
	"#...G..F..P..#",
	"#............#",
	"#............#",
	"#B..........K#",
	"#B...........#",
	"#............#",
	"#####=C=######",
	"oooooooooooooo",
	"oooooooooooooo",
]

## Layout character -> station id. Station tiles are solid.
const STATION_CHARS := {"C": "counter", "G": "grill", "F": "fryer", "P": "prep", "K": "cleaning"}
## Model to use for a layout character instead of the placeholder box.
## Empty means placeholder. Keys: "#" wall, "." floor, "o" outside floor,
## "=" counter top, "B" break bench, or a station character above.
const MODELS := {
	"#": "", ".": "", "o": "", "=": "", "B": "",
	"C": "", "G": "", "F": "", "P": "", "K": "",
}

const WALL_HEIGHT := 1.6
const LOW_WALL_HEIGHT := 0.35
const FURNITURE_HEIGHT := 0.9
const BENCH_HEIGHT := 0.45

const FLOOR_A := Color(0.62, 0.60, 0.56)
const FLOOR_B := Color(0.54, 0.52, 0.49)
const OUTSIDE := Color(0.36, 0.45, 0.33)
const WALL := Color(0.72, 0.66, 0.58)
const COUNTER_TOP := Color(0.58, 0.40, 0.25)
const BENCH := Color(0.45, 0.30, 0.20)

var size := Vector2i.ZERO
var stations := {}  # station id -> Station
## Floor tiles next to the break bench, where NPCs take breaks.
var break_tiles: Array[Vector2i] = []
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
			_build_tile(Vector2i(x, z), LAYOUT[z][x])
	for station: Station in stations.values():
		station.work_tile = _free_neighbour(station.tile)


# --- Grid helpers -----------------------------------------------------------

func tile_to_world(t: Vector2i) -> Vector3:
	return Vector3((t.x + 0.5) * Balance.TILE_SIZE, 0.0, (t.y + 0.5) * Balance.TILE_SIZE)


func world_to_tile(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / Balance.TILE_SIZE), floori(p.z / Balance.TILE_SIZE))


## Distance between two world points, in tiles, on the floor plane.
static func tile_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length() / Balance.TILE_SIZE


func is_walkable(t: Vector2i) -> bool:
	return astar.is_in_boundsv(t) and not astar.is_point_solid(t) and LAYOUT[t.y][t.x] == "."


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
	var outside := c == "o"
	var floor_color := OUTSIDE if outside else (FLOOR_A if (t.x + t.y) % 2 == 0 else FLOOR_B)
	if not _place_model("o" if outside else ".", pos):
		_box(Vector3(1, 0.1, 1), pos + Vector3(0, -0.05, 0), floor_color, false)

	match c:
		".":
			pass
		"o":
			astar.set_point_solid(t)  # customers only; not part of the kitchen grid
		"#":
			astar.set_point_solid(t)
			var near_camera := t.x == size.x - 1 or t.y == size.y - 1 or t.y >= 7
			var h := LOW_WALL_HEIGHT if near_camera else WALL_HEIGHT
			if not _place_model(c, pos):
				_box(Vector3(1, h, 1), pos + Vector3(0, h / 2, 0), WALL, true)
			else:
				_collider(Vector3(1, h, 1), pos + Vector3(0, h / 2, 0))
		"=":
			astar.set_point_solid(t)
			_furniture(c, pos, FURNITURE_HEIGHT, COUNTER_TOP)
		"B":
			astar.set_point_solid(t)
			_furniture(c, pos, BENCH_HEIGHT, BENCH)
			break_tiles.append(t + Vector2i(1, 0))
		_:
			if c in STATION_CHARS:
				astar.set_point_solid(t)
				var station := Station.new()
				station.setup(STATION_CHARS[c], t, t)
				station.position = pos
				add_child(station)
				stations[station.station_id] = station
				if not _place_model(c, Vector3.ZERO, station):
					_box(Vector3(0.9, FURNITURE_HEIGHT, 0.9), Vector3(0, FURNITURE_HEIGHT / 2, 0), station.color(), false, station)
				_collider(Vector3(1, FURNITURE_HEIGHT, 1), pos + Vector3(0, FURNITURE_HEIGHT / 2, 0))
				station.build_labels(FURNITURE_HEIGHT)


func _furniture(c: String, pos: Vector3, h: float, color: Color) -> void:
	if not _place_model(c, pos):
		_box(Vector3(0.95, h, 0.95), pos + Vector3(0, h / 2, 0), color, false)
	_collider(Vector3(1, h, 1), pos + Vector3(0, h / 2, 0))


func _place_model(c: String, pos: Vector3, parent: Node3D = self) -> bool:
	var path: String = MODELS.get(c, "")
	if path == "" or not ResourceLoader.exists(path):
		return false
	var model: Node3D = (load(path) as PackedScene).instantiate()
	model.position = pos
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


func _free_neighbour(t: Vector2i) -> Vector2i:
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if is_walkable(t + d):
			return t + d
	return t


func _nearest_walkable(t: Vector2i) -> Vector2i:
	if is_walkable(t):
		return t
	for r in range(1, 4):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if is_walkable(t + Vector2i(dx, dz)):
					return t + Vector2i(dx, dz)
	return t
