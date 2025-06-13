extends Node

class_name GameManager

static var Instance: GameManager

const TEXTURE_SIZE = 1024
const TILE_SIZE = 64

## Texture passed to tilemap shader containing all ground textures
var MegaTexture: ImageTexture = null

## Texture used in tilemap shader for tile blending
var TileBlendTexture: Texture2D = null

var MapNoise: NoiseTexture2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Instance = self
	_create_mega_texture()
	_create_tile_blend_texture()
	_init_map_noise()
	PlayerCamera.init(self) # Assuming PlayerCamera is a globally accessible class or autoload

# Using a seamless noise map to let it go infinite
func _init_map_noise(seed: int = 1337) -> void:
	var noise_texture = NoiseTexture2D.new()
	noise_texture.seamless = true
	noise_texture.width = 128
	noise_texture.height = 128
	var fast_noise = FastNoiseLite.new()
	# Set a seed for the FastNoiseLite instance directly
	fast_noise.seed = seed
	noise_texture.noise = fast_noise
	MapNoise = noise_texture

func _get_ground_textures() -> Array[Texture2D]:
	var texture_list: Array[Texture2D] = []
	texture_list.append(ResourceLoader.load("res://Assets/Textures/free_water.png"))
	texture_list.append(ResourceLoader.load("res://Assets/Textures/free_grass.png"))
	texture_list.append(ResourceLoader.load("res://Assets/Textures/free_sand.png"))
	texture_list.append(ResourceLoader.load("res://Assets/Textures/free_rock.png"))

	return texture_list

func _get_noise_gen(seed: int = 1337) -> NoiseTexture2D:
	var noise_texture = NoiseTexture2D.new()
	noise_texture.seamless = true
	noise_texture.width = 1024
	noise_texture.height = 1024
	var fast_noise = FastNoiseLite.new()
	fast_noise.seed = seed
	#fast_noise.period = 56.0
	#fast_noise.persistence = 0.0
	fast_noise.fractal_lacunarity = 0.1
	noise_texture.noise = fast_noise
	return noise_texture

func _create_tile_blend_texture(smooth_edge: float = 24.0, smooth_corner: float = 16.0,
								edge_percentage: float = 50.0, corner_percentage: float = 25.0,
								texture_size: int = 16, debug: bool = true) -> void:
	if TileBlendTexture != null:
		return

	# Noise (Same seed always to get same result always)
	var noise_x = _get_noise_gen(1234)
	var noise_y = _get_noise_gen(4321)
	var noise_c = _get_noise_gen(1243)

	#TileBlendTexture
	var half_tile: int = TILE_SIZE / 2

	var blend_image: Image = Image.create(TILE_SIZE * texture_size, TILE_SIZE * texture_size, false, Image.FORMAT_RGBAF)

	var test_image_r: Image = null
	var test_image_g: Image = null
	var test_image_b: Image = null
	var test_image_a: Image = null

	if debug:
		test_image_r = Image.create(TILE_SIZE * texture_size, TILE_SIZE * texture_size, false, Image.FORMAT_RGBAF)
		test_image_g = Image.create(TILE_SIZE * texture_size, TILE_SIZE * texture_size, false, Image.FORMAT_RGBAF)
		test_image_b = Image.create(TILE_SIZE * texture_size, TILE_SIZE * texture_size, false, Image.FORMAT_RGBAF)
		test_image_a = Image.create(TILE_SIZE * texture_size, TILE_SIZE * texture_size, false, Image.FORMAT_RGBAF)

	# Loop through all pixels in the image and create colors
	# We make 'texture_size' rows and columns
	for row in range(texture_size):
		for column in range(texture_size):
			for x in range(TILE_SIZE):
				for y in range(TILE_SIZE):
					var image_x_pos: int = x + (column * TILE_SIZE)
					var image_y_pos: int = y + (row * TILE_SIZE)

					# Find closest edges
					var x_edge: float = 0.0 if x < half_tile else float(TILE_SIZE - 1)
					var y_edge: float = 0.0 if y < half_tile else float(TILE_SIZE - 1)

					# Get distance to closest edges
					var x_dist: float = Vector2(x, 0).distance_to(Vector2(x_edge, 0))
					var y_dist: float = Vector2(0, y).distance_to(Vector2(0, y_edge))
					var corner_dist: float = Vector2(x, y).distance_to(Vector2(x_edge, y_edge))

					# Calculate smoothing percentages to all edges (rounded)
					var x_smooth: float = round((1.0 - smoothstep(0.0, smooth_edge, min(x_dist, smooth_edge))) * edge_percentage)
					var y_smooth: float = round((1.0 - smoothstep(0.0, smooth_edge, min(y_dist, smooth_edge))) * edge_percentage)
					var corner_smooth: float = round((1.0 - smoothstep(0.0, smooth_corner, min(corner_dist, smooth_corner))) * corner_percentage)

					# Add noise based on distance from edge
					# Noise count more closer to the center
					var noise_val_x: float = noise_x.noise.get_noise_2d(image_x_pos, image_y_pos) * (x_dist / smooth_edge)
					var noise_val_y: float = noise_y.noise.get_noise_2d(image_x_pos, image_y_pos) * (y_dist / smooth_edge)
					var noise_val_c: float = noise_c.noise.get_noise_2d(image_x_pos, image_y_pos) * (corner_dist / smooth_corner)

					x_smooth = min(x_smooth * (1.0 - noise_val_x), edge_percentage)
					y_smooth = min(y_smooth * (1.0 - noise_val_y), edge_percentage)
					corner_smooth = min(corner_smooth * (1.0 - noise_val_c), corner_percentage)

					# Subtract corner input from both X / Y and clamp to 0
					x_smooth = max(0.0, x_smooth - corner_smooth)
					y_smooth = max(0.0, y_smooth - corner_smooth)

					# Calculate remainder for main texture
					var self_percentage: float = 100.0 - x_smooth - y_smooth - corner_smooth

					# Now we got a percentage that will add up to 100%
					# x_smooth = effect of horizontal texture
					# y_smooth = effect of vertical texture
					# corner_smooth = effect of corner texture
					# self_percentage = effect of primary texture
					# Write to rgba
					var col: Color = Color(x_smooth / 255.0, y_smooth / 255.0, corner_smooth / 255.0, self_percentage / 255.0)
					blend_image.set_pixel(image_x_pos, image_y_pos, col)

					if debug:
						col = Color(x_smooth / 255.0, x_smooth / 255.0, x_smooth / 255.0, 1.0)
						test_image_r.set_pixel(image_x_pos, image_y_pos, col)

						col = Color(y_smooth / 255.0, y_smooth / 255.0, y_smooth / 255.0, 1.0)
						test_image_g.set_pixel(image_x_pos, image_y_pos, col)

						col = Color(corner_smooth / 255.0, corner_smooth / 255.0, corner_smooth / 255.0, 1.0)
						test_image_b.set_pixel(image_x_pos, image_y_pos, col)

						col = Color(self_percentage / 255.0, self_percentage / 255.0, self_percentage / 255.0, 1.0)
						test_image_a.set_pixel(image_x_pos, image_y_pos, col)

	# Create debug sprite
	TileBlendTexture = ImageTexture.create_from_image(blend_image) #, (uint)Texture2D.FLAGS_REPEAT) # Flag usage in GDScript

	if debug:
		blend_image.save_png("user://blendTest.png")
		test_image_r.save_png("user://blendTestR.png")
		test_image_g.save_png("user://blendTestG.png")
		test_image_b.save_png("user://blendTestB.png")
		test_image_a.save_png("user://blendTestA.png")

## Simple method to create a mega texture
func _create_mega_texture() -> void:
	# Hardcoded for now
	# a full 16384 x 16384 texture takes 768 mb of vram (roughly 3 mb per 1024x1024 texture)

	# Get tiles
	var tile_list: Array[Texture2D] = _get_ground_textures()
	var count: float = float(tile_list.size()) # .Count in C# is .size() in GDScript

	# Calculate width / height of mega texture and create it
	var height: int = TEXTURE_SIZE * ceil(count / 16.0)
	var width: int = TEXTURE_SIZE * int(min(count, 16.0)) # Cast to int for width
	var mega_img: Image = Image.create(width, height, false, Image.FORMAT_RGB8)
	var pos_x: int = 0
	var pos_y: int = 0

	# Copy image data to mega texture
	for texture in tile_list:
		var img: Image = texture.get_image()
		var target_pos: Vector2i = Vector2i(pos_x * TEXTURE_SIZE, pos_y * TEXTURE_SIZE)
		mega_img.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), target_pos)

		# Ensure we only get 16 per row
		pos_x += 1
		if pos_x > 15:
			pos_x = 0
			pos_y += 1

	# Create debug sprite
	MegaTexture = ImageTexture.create_from_image(mega_img) #, (uint)Texture2D.FLAGS_MIPMAPS) # Flag usage in GDScript
