extends RefCounted

class_name MapShaderDataProvider

# Signals in GDScript are the equivalent of events in C#.
# Define them with the `signal` keyword.
signal on_visible_segments_changed(segment_area: Rect2i)
signal on_chunk_inactive(segment: Vector2, chunk: MapShaderChunk)

func notify_visible_segments_changed(segment_area: Rect2i) -> void:
	# Emit the signal to notify listeners.
	on_visible_segments_changed.emit(segment_area)

func set_inactive(segment: Vector2, chunk: MapShaderChunk) -> void:
	# Emit the signal to notify listeners.
	on_chunk_inactive.emit(segment, chunk)

func get_tile(x: int, y: int) -> int:
	# Very simple noise gen
	var noise: float = GameManager.Instance.MapNoise.noise.get_noise_2d(x, y)
	if noise < 0.01:
		return 0
	elif noise < 0.2:
		return 1
	elif noise < 0.4:
		return 2
	else:
		return 3
