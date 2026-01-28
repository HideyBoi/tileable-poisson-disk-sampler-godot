extends RefCounted
class_name PoissonDiscSampler

var size : Vector2i
var radius : float

var attempts : int = 6
var total_candidates : int

var cell_size : float
var grid : Grid
var active_samples : PackedVector2Array
var active_neighbor_samples : PackedVector2Array

var rng : RandomNumberGenerator

## Initializes the sampler[br]
## See more:[br]
## Based on: http://gregschlom.com/devlog/2014/06/29/Poisson-disc-sampling-Unity.html
func _init(poisson_radius: float, grid_size: Vector2i, pick_attempts: int = 64, rand: RandomNumberGenerator = null) -> void:
	radius = poisson_radius
	cell_size = radius / sqrt(2)
	size = grid_size

	#print("Calculated cell_size " + str(cell_size))

	grid = Grid.new(ceil(size.x / cell_size), ceil(size.y / cell_size))

	#print("Calculated cell_size/height " + str(grid.width))

	attempts = pick_attempts

	if rand:
		rng = rand
	else:
		rng = RandomNumberGenerator.new()
		rng.randomize()

## Runs the algorithm. This function call is [b]slow[/b] and will take a while to complete.
## You should be calling it in a separate thread or only during the initialization of a new level.
func find_points() -> PackedVector2Array:
	# add initial sample
	_add_sample(Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y)))
	
	# while samples to process exist
	while active_samples.size() > 0:
		#print("Remaining samples " + str(active_samples.size()))
		var index = rng.randi_range(0,active_samples.size() -1)
		var selected_sample = active_samples[index]

		var found := false
		for _attempt in range(0, attempts):
			# pick and angle and put a candidate there
			var angle := 2 * PI * rng.randf()
			var candidate:Vector2 = selected_sample + radius * Vector2(cos(angle), sin(angle))

			if _is_valid(candidate):
				found = true
				_add_sample(candidate)

		# if we couldn't find a valid candidate here, remove the sample
		if not found:
			active_samples.remove_at(index)

	# print(grid)
	return grid.to_packed_array()

func _add_sample(pos: Vector2) -> void:
	active_samples.append(pos)
	grid.grid_set(pos, cell_size)

func _is_in_bounds(candidate: Vector2) -> bool:
	if candidate.x < 0 or candidate.x >= size.x or candidate.y < 0 or candidate.y >= size.y:
		return false

	return true

func _is_valid(candidate: Vector2) -> bool:
	if not _is_in_bounds(candidate):
		return false

	var candidate_x := int(candidate.x/cell_size)
	var candidate_y := int(candidate.y/cell_size)

	var col_start:int = min(0, candidate_x - 1)
	var col_end:int = max(candidate_x + 1, grid.width)

	var row_start:int = min(0, candidate_y - 1)
	var row_end:int = max(candidate_y + 1, grid.height)

	# loop all points in sub-grid
	for col in range(col_start, col_end):
		for row in range(row_start, row_end):
			var point = grid.grid_get(col, row)
			# Check if point is undefined
			if not point == Vector2.ZERO:
				# Check if candidate is too close existing point
				if candidate.distance_to(point) < radius:
					return false
	
	# check all neighboring samples
	for point in active_neighbor_samples:
		if candidate.distance_to(point) < radius:
			return false

	return true

## Adds in neighboring points. The offset should be the relative position of the neighbor with respect to the calling node. Ex: [code]neighbor.global_position - self.global_position[/code]
func add_seamless_points(points: PackedVector2Array, offset: Vector2) -> void:
	for point in points:
		active_neighbor_samples.append(point + offset)
		# # check
		# var v2 = Vector2(int(point.x / cell_size), int(point.y / cell_size))
		# print(str(v2) + " real " + str(point + offset))

## Returns the edges of the internal grid. This should be passed into [code]add_seamless_points()[/code] with an offset to make use of seamless point generation.
func get_seamless_points() -> PackedVector2Array:
	var final : PackedVector2Array

	# top
	for col in range(0, grid.width):
		var value = grid.grid_get(col, 0)
		if value == Vector2.ZERO: continue
		final.append(value)

	for row in range(0, grid.height):
		var value = grid.grid_get(grid.width-1, row)
		if value == Vector2.ZERO: continue
		final.append(value)

	for col in range(0, grid.width):
		var value = grid.grid_get(col, grid.height-1)
		if value == Vector2.ZERO: continue
		final.append(value)

	for row in range(0, grid.height-1):
		var value = grid.grid_get(0, row)
		if value == Vector2.ZERO: continue
		final.append(value)

	return final

class Grid extends RefCounted:
	var width : int
	var height : int

	var total : int

	var data : Array[Array]
	var is_seamless := false

	func _init(x: int, y: int, seamless: bool = false):
		total = x*y
		width = x
		height = y

		is_seamless = seamless

		# fill grid with empty values
		for col in range(0, width):
			var col_arr : Array
			for row in range(0, height):
				col_arr.append(Vector2.ZERO)
			
			data.append(col_arr)

		print(str(data.size()) + " length")
	
	func grid_get(x: int, y: int) -> Vector2:
		return data[x][y]

	var farthest := 0
	var nearest := 255
	func grid_set(pos: Vector2, cell_size: float, is_neighbor: bool = false) -> void:
		var x:int = floor(pos.x / cell_size)
		var y:int = floor(pos.y / cell_size)

		if is_seamless and not is_neighbor:
			x += 1
			y += 1

		if x >= width or y >= height:
			print(str(Vector2(x, y)) + " real:" + str(pos) + " out of bounds")
			return

		data[x][y] = pos

	func to_packed_array(skip_v2_0: bool = true) -> PackedVector2Array:
		var final : PackedVector2Array

		for col in range(0, width):
			for row in range(0, height):
				if skip_v2_0 and data[col][row] == Vector2.ZERO:
					continue
				
				final.append(data[col][row])
		
		return final

	func _to_string() -> String:
		var string = ""
		for row in range(0, height):
			for col in range(0, width):
				string += str(data[row][col])
			string+="\n"
		
		return string
