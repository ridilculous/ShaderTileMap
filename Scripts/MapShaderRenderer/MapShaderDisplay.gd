extends Node2D

class_name MapShaderDisplay

# For debugging only, if you got more than one display this will not work
static var Instance: MapShaderDisplay

const SCENE_SHADER_CHUNK = "res://Scenes/Map/MapShaderChunk.tscn"

# The size of each chunk, they are square by default
# Should be a power of 2
const WORLD_SEGMENT_SIZE = 128

# How many extra chunks to load
const SEGMENTS_OUTSIDE_VIEW_TO_LOAD = 2

# How often should we update
const UPDATE_INTERVAL = 0.3

# Used for the queue, set higher than update interval to trigger immediate update
var _update_counter: float = UPDATE_INTERVAL + 1.0

# Active map segments
var _active_map_segments: Dictionary = {} # Stores Vector2: MapShaderChunk

var _inactive_chunks: Array[MapShaderChunk] = []

var _data_provider: MapShaderDataProvider

var _segment_counter: int = 0

var _inactive_parent: Node2D

var _last_segment_area: Rect2i = Rect2i()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Instance = self
	_data_provider = MapShaderDataProvider.new()
	_data_provider.on_chunk_inactive.connect(_on_chunk_inactive)

	_inactive_parent = Node2D.new()
	_inactive_parent.name = "InactiveSegments"
	add_child(_inactive_parent)

func _physics_process(delta: float) -> void:
	# Add anything that needs to be rendered to queue
	_update_counter += delta
	if _update_counter > UPDATE_INTERVAL:
		_update_counter = 0.0
		_update_shader_map()

## Check if we need to update the map
func _update_shader_map() -> void:
	# Get segments to process
	var segment_area: Rect2i = _get_segment_area()

	# Go through from top left to bottom right
	# Note: segment_area.end is exclusive, so the loop condition is correct.
	for x in range(segment_area.position.x, segment_area.end.x):
		for y in range(segment_area.position.y, segment_area.end.y):
			_draw_segment(Vector2(x, y))

	# Tell all existing segments that we changed area
	if _last_segment_area != segment_area:
		_last_segment_area = segment_area
		_data_provider.notify_visible_segments_changed(segment_area)

## Trigger the rendering of some segment
func _draw_segment(segment: Vector2) -> void:
	# Check if it is already drawn, if so ignore
	if _active_map_segments.has(segment):
		return

	# Look for a free map renderer or create one if none found
	var chunk: MapShaderChunk = null
	if not _inactive_chunks.is_empty():
		chunk = _inactive_chunks.pop_front() # Use pop_front for list removal
		_inactive_parent.remove_child(chunk)
		add_child(chunk)
	else:
		var scene: PackedScene = ResourceLoader.load(SCENE_SHADER_CHUNK) as PackedScene
		chunk = scene.instantiate() as MapShaderChunk
		_segment_counter += 1
		chunk.name = "Segment%d" % _segment_counter # Use string formatting
		call_deferred("add_child", chunk) # Use call_deferred for adding children dynamically

	chunk.set_active(_data_provider, segment)
	_active_map_segments[segment] = chunk # Add to dictionary

func _on_chunk_inactive(segment: Vector2, chunk: MapShaderChunk) -> void:
	_active_map_segments.erase(segment) # Use erase() for dictionaries
	_inactive_chunks.append(chunk) # Use append() for adding to arrays
	remove_child(chunk)
	_inactive_parent.add_child(chunk)

## Get area we are supposed to draw
func _get_segment_area() -> Rect2i:
	# Get camera position
	var pos: Rect2i = PlayerCamera.get_current_view_area_tiles_as_rect()

	# Convert to top left / bottom right segment
	var top_left_segment: Vector2i = Vector2i(floor(pos.position.x / WORLD_SEGMENT_SIZE) - SEGMENTS_OUTSIDE_VIEW_TO_LOAD, \
											  floor(pos.position.y / WORLD_SEGMENT_SIZE) - SEGMENTS_OUTSIDE_VIEW_TO_LOAD)

	# In Godot 4, Rect2i.end is the exclusive bottom-right corner,
	# so `pos.position.x + pos.size.x` directly corresponds to the end.
	var bottom_right_segment: Vector2i = Vector2i(floor((pos.position.x + pos.size.x) / WORLD_SEGMENT_SIZE) + SEGMENTS_OUTSIDE_VIEW_TO_LOAD, \
												  floor((pos.position.y + pos.size.y) / WORLD_SEGMENT_SIZE) + SEGMENTS_OUTSIDE_VIEW_TO_LOAD)

	# Rect2i expects position and size. The size is calculated from the top_left_segment
	# and bottom_right_segment.
	var size_x = bottom_right_segment.x - top_left_segment.x
	var size_y = bottom_right_segment.y - top_left_segment.y

	return Rect2i(top_left_segment, Vector2i(size_x, size_y))

#region Debugging methods

## Mainly for debugging
func set_shader_parameter(name: String, value) -> void:
	for chunk in _active_map_segments.values():
		chunk.set_shader_parameter(name, value)
	for chunk in _inactive_chunks: # Iterate directly over Array
		chunk.set_shader_parameter(name, value)

#endregion
