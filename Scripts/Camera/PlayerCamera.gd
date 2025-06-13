extends Camera2D

class_name PlayerCamera

const GROUP_CAMERAS = "Cameras"

static var Instance: PlayerCamera = null

## For camera zoom
const ZOOM_MIN: Vector2 = Vector2(0.25, 0.25)
const ZOOM_MAX: Vector2 = Vector2(20.0, 20.0)
const ZOOM_STEP: Vector2 = Vector2(0.2, 0.2)
const ZOOM_SNAP_DISTANCE: float = 0.02
const ZOOM_FACTOR: float = 10.0
var _target_zoom: Vector2 = Vector2.ONE

## For camera pan
const PAN_FACTOR: float = 10.0
const PAN_SPEED: float = 2.5
var _is_dragging: bool = false
var _last_mouse_pos: Vector2
var _target_camera_position: Vector2
var _active: bool = true

var _camera_bounds: Rect2


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Instance != null:
		print("Tried to add more than one PlayerCamera")
		queue_free()
		return

	name = "PlayerCamera"
	Instance = self
	add_to_group(GROUP_CAMERAS)
	_target_camera_position = global_position # Initialize with current global position

	# This might need to be adjusted when your primary actor moves
	_camera_bounds = Rect2(Vector2(-499999999.0, -499999999.0), Vector2(999999999.0, 999999999.0))
	_target_zoom = ZOOM_MIN


func _exit_tree() -> void:
	if Instance == self:
		Instance = null

func _process(delta: float) -> void:
	# We don't disable this so we could subscribe to events for panning / zooming the camera from cinematics
	if _is_dragging:
		_update_target_position()
		_last_mouse_pos = get_global_mouse_position()

	# Adjust zoom
	zoom = zoom - ((zoom - _target_zoom) * delta * ZOOM_FACTOR)
	if zoom.distance_to(_target_zoom) <= ZOOM_SNAP_DISTANCE:
		zoom = _target_zoom

	# Adjust pan pos
	global_position = global_position - ((global_position - _target_camera_position) * delta * PAN_FACTOR)

func _update_target_position() -> void:
	_target_camera_position += (get_global_mouse_position() - _last_mouse_pos) * PAN_SPEED * -1 # Invert mouse movement for pan direction
	# The original C# code effectively subtracted `GetGlobalMousePosition()` from `_lastMousePos`,
	# which means `_lastMousePos - new_mouse_pos`. For panning, if new_mouse_pos is right of last_mouse_pos,
	# you want the camera to move left (subtract from target position).
	# So `(_last_mouse_pos - get_global_mouse_position())` is correct for the desired pan.

	# Clamp target camera position within bounds
	# Note: Rect2.has_point checks if a point is *inside* the rectangle.
	# We need to manually clamp the position to the rectangle's boundaries.
	_target_camera_position.x = clamp(_target_camera_position.x, _camera_bounds.position.x, _camera_bounds.position.x + _camera_bounds.size.x)
	_target_camera_position.y = clamp(_target_camera_position.y, _camera_bounds.position.y, _camera_bounds.position.y + _camera_bounds.size.y)


func _input(event: InputEvent) -> void:
	if not _active:
		return

	if event is InputEventMouseButton:
		_update_camera(event as InputEventMouseButton)

func _update_camera(input_event: InputEventMouseButton) -> void:
	_update_zoom(input_event)
	_update_pan(input_event)

func pan(pan_amount: Vector2) -> void:
	_target_camera_position += pan_amount

func _update_pan(input_event: InputEventMouseButton) -> void:
	if input_event.button_index == MOUSE_BUTTON_MIDDLE:
		get_viewport().set_input_as_handled()
		_is_dragging = input_event.is_pressed()
		_last_mouse_pos = get_global_mouse_position()
		_target_camera_position = global_position # Reset target to current position when drag starts


func _update_zoom(input_event: InputEventMouseButton) -> void:
	# Adjust our zoom target
	if input_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_target_zoom += ZOOM_STEP
		get_viewport().set_input_as_handled()
	elif input_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_target_zoom -= ZOOM_STEP
		get_viewport().set_input_as_handled()

	# Make sure values are limited using clamp
	_target_zoom.x = clamp(_target_zoom.x, ZOOM_MIN.x, ZOOM_MAX.x)
	_target_zoom.y = clamp(_target_zoom.y, ZOOM_MIN.y, ZOOM_MAX.y)


static func init(parent: Node) -> void:
	if Instance == null:
		var cam: PlayerCamera = PlayerCamera.new()
		parent.add_child(cam)
		cam.make_current()

static func get_tile_under_mouse() -> Vector2i:
	if Instance == null:
		return Vector2i(0, 0)

	var mouse_pos: Vector2 = Instance.get_global_mouse_position()
	var pos_x: int = int(floor(mouse_pos.x / GameManager.TILE_SIZE))
	var pos_y: int = int(floor(mouse_pos.y / GameManager.TILE_SIZE))
	return Vector2i(pos_x, pos_y)

static func get_current_view_area_tiles_as_rect() -> Rect2i:
	if Instance == null:
		return Rect2i()

	var v_trans: Transform2D = Instance.get_canvas_transform()
	# The origin of the canvas transform is the top-left corner of the viewport *in global coordinates*
	# when the camera is at (0,0) and zoom is (1,1).
	# To get the top-left of the currently visible area, we need to invert the transform.
	var top_left_visible: Vector2 = -v_trans.origin / v_trans.get_scale() # This gives world coordinates of the top-left corner of the viewport
	var viewport_size_pixels: Vector2 = Instance.get_viewport_rect().size # Size of the viewport in screen pixels
	var view_size_world: Vector2 = viewport_size_pixels * Instance.zoom # Size of the visible area in world units based on current zoom

	var top_left_tile_x: int = int(floor(top_left_visible.x / GameManager.TILE_SIZE))
	var top_left_tile_y: int = int(floor(top_left_visible.y / GameManager.TILE_SIZE))
	var bottom_right_tile_x: int = int(ceil((top_left_visible.x + view_size_world.x) / GameManager.TILE_SIZE))
	var bottom_right_tile_y: int = int(ceil((top_left_visible.y + view_size_world.y) / GameManager.TILE_SIZE))

	var top_left_tile_pos: Vector2i = Vector2i(top_left_tile_x, top_left_tile_y)
	var size_x: int = bottom_right_tile_x - top_left_tile_x
	var size_y: int = bottom_right_tile_y - top_left_tile_y

	return Rect2i(top_left_tile_pos, Vector2i(size_x, size_y))

static func get_top_left_tile() -> Vector2i:
	if Instance == null:
		return Vector2i(0, 0)

	var v_trans: Transform2D = Instance.get_canvas_transform()
	var top_left_visible: Vector2 = -v_trans.origin / v_trans.get_scale()

	return Vector2i(int(floor(top_left_visible.x / GameManager.TILE_SIZE)),
					int(floor(top_left_visible.y / GameManager.TILE_SIZE)))

static func get_bottom_right_tile() -> Vector2i:
	if Instance == null:
		return Vector2i(0, 0)

	var v_trans: Transform2D = Instance.get_canvas_transform()
	var top_left_visible: Vector2 = -v_trans.origin / v_trans.get_scale()
	var viewport_size_pixels: Vector2 = Instance.get_viewport_rect().size
	var view_size_world: Vector2 = viewport_size_pixels * Instance.zoom

	return Vector2i(int(ceil((top_left_visible.x + view_size_world.x) / GameManager.TILE_SIZE)),
					int(ceil((top_left_visible.y + view_size_world.y) / GameManager.TILE_SIZE)))
