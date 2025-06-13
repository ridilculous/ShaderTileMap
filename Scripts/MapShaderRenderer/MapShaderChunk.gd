extends Node2D

class_name MapShaderChunk

const SHADER_PARAM_TEXTURE_ATLAS = "textureAtlas"
const SHADER_PARAM_BLEND_TEXTURE = "blendTexture"
const SHADER_PARAM_MAP_DATA = "mapData"
const SHADER_PARAM_MAP_TILES_COUNT_X = "mapTilesCountX"
const SHADER_PARAM_MAP_TILES_COUNT_Y = "mapTilesCountY"
const SHADER_PARAM_TILE_SIZE_PIXELS = "tileSizeInPixels"
const SHADER_PARAM_HALF_TILE_SIZE_PIXELS = "halfTileSizeInPixels"

var _segment: Vector2 = Vector2.INF
var _data_provider: MapShaderDataProvider = null
var _map_renderer: Sprite2D = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_map_renderer = get_node("MapRenderer") as Sprite2D

	# Setup shader
	var mat: ShaderMaterial = _map_renderer.material as ShaderMaterial
	mat.set_shader_parameter(SHADER_PARAM_TEXTURE_ATLAS, GameManager.Instance.MegaTexture)
	mat.set_shader_parameter(SHADER_PARAM_BLEND_TEXTURE, GameManager.Instance.TileBlendTexture)
	mat.set_shader_parameter(SHADER_PARAM_MAP_TILES_COUNT_X, MapShaderDisplay.WORLD_SEGMENT_SIZE)
	mat.set_shader_parameter(SHADER_PARAM_MAP_TILES_COUNT_Y, MapShaderDisplay.WORLD_SEGMENT_SIZE)
	mat.set_shader_parameter(SHADER_PARAM_TILE_SIZE_PIXELS, GameManager.TILE_SIZE)
	mat.set_shader_parameter(SHADER_PARAM_HALF_TILE_SIZE_PIXELS, GameManager.TILE_SIZE / 2.0)

	# Important is that the base picture for this image is the same as our tile size
	# If not you have to adjust the scale calculation accordingly
	_map_renderer.scale = Vector2(MapShaderDisplay.WORLD_SEGMENT_SIZE, MapShaderDisplay.WORLD_SEGMENT_SIZE)

func set_shader_parameter(name: String, value) -> void:
	var mat: ShaderMaterial = _map_renderer.material as ShaderMaterial
	mat.set_shader_parameter(name, value)

func set_active(provider: MapShaderDataProvider, segment: Vector2) -> void:
	_segment = segment
	_data_provider = provider
	_data_provider.on_visible_segments_changed.connect(_on_visible_segments_changed)
	call_deferred("perform_initial_render")

func _on_visible_segments_changed(segment_area: Rect2i) -> void:
	if _segment == Vector2.INF or _map_renderer == null:
		return

	# We do our own check since the Size of segmentArea is actually the bottom right corner not the size
	if segment_area.position.x > _segment.x or segment_area.end.x < _segment.x or \
	   segment_area.position.y > _segment.y or segment_area.end.y < _segment.y:
		#GD.Printt("SegmentArea:", segment_area, "does not contain segment:", _segment)
		# Time to go inactive
		_data_provider.on_visible_segments_changed.disconnect(_on_visible_segments_changed)
		_data_provider.set_inactive(_segment, self)
		_data_provider = null
		_map_renderer.visible = false

## Does the initial rendering of this segment
func perform_initial_render() -> void:
	var area: Rect2i = _get_rect_from_segment(_segment)

	# Position ourselves, area has -1 / +1 on it's size
	global_position = Vector2((area.position.x + 1) * GameManager.TILE_SIZE, \
							 (area.position.y + 1) * GameManager.TILE_SIZE)

	#Vector2 topLeft = new Vector2(area.Position.X * GameWorldManager.TILE_SIZE, area.Position.Y * GameWorldManager.TILE_SIZE)
	# TODO: Calculate start offset

	_generate_map_texture(area)

func _generate_map_texture(area: Rect2i) -> void:
	# Setup dimensions
	var start: Vector2i = area.position
	var size: Vector2i = area.size
	# In Godot 4.x, Rect2i.size is already the width/height, not the bottom-right corner.
	# So `area.size - area.position` from C# is equivalent to just `area.size` here,
	# as `area.position` is the top-left and `area.size` is the width/height.

	var byte_array = PackedByteArray()
	byte_array.resize(size.x * size.y)

	# Draw image
	var index = 0
	for y in range(size.y):
		for x in range(size.x):
			var cell = _data_provider.get_tile(start.x + x, start.y + y)
			byte_array[index] = cell
			index += 1

	var img: Image = Image.create_from_data(size.x, size.y, false, Image.FORMAT_R8, byte_array)
	var texture: ImageTexture = ImageTexture.create_from_image(img)

	# Set to shader
	(_map_renderer.material as ShaderMaterial).set_shader_parameter(SHADER_PARAM_MAP_DATA, texture)
	_map_renderer.visible = true

func _get_rect_from_segment(segment: Vector2) -> Rect2i:
	# Render 1 extra cell in each direction so shading gets ok
	var top_left: Vector2i = Vector2i(int(segment.x * MapShaderDisplay.WORLD_SEGMENT_SIZE) - 1, \
									  int(segment.y * MapShaderDisplay.WORLD_SEGMENT_SIZE) - 1)
	var bottom_right: Vector2i = Vector2i(int(segment.x * MapShaderDisplay.WORLD_SEGMENT_SIZE) + MapShaderDisplay.WORLD_SEGMENT_SIZE + 1, \
										  int(segment.y * MapShaderDisplay.WORLD_SEGMENT_SIZE) + MapShaderDisplay.WORLD_SEGMENT_SIZE + 1)

	# In Godot 4, Rect2i(position, size) expects size as width/height.
	# To get the width/height from top_left and bottom_right, we calculate
	# (bottom_right.x - top_left.x) and (bottom_right.y - top_left.y).
	var size_x = bottom_right.x - top_left.x
	var size_y = bottom_right.y - top_left.y

	return Rect2i(top_left, Vector2i(size_x, size_y))
