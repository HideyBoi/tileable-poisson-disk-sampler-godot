# A poisson disc sampler for Godot
Self-contained in a single gdscript file. Easily reusable anywhere in your codebase.

Based on [Gregory Schlomoff's implementation for Unity.](http://gregschlom.com/devlog/2014/06/29/Poisson-disc-sampling-Unity.html)

## Purpose
I think that this implementation can be useful in a variety of projects, but also as a learning tool to implement your own sampler.

This exact implementation is being used in an upcoming personal project of mine. This implementation generates points in a rect and packages them up in a `PackedVector2Array`. 

I'm specifically using it to find ideal locations for foliage/resources within a square chunk. This is the specific reason I'd implemented the ability to tile these samplers; without it, very prominent voids or clusters will form on the boundary between chunks.

## Usage
Just put the `poisson_disc_sampler.gd` file anywhere in your Godot project and use it as seen in the examples below.

### Regular example:
```gdscript
func create() -> void:
	# initialize sampler
	var sampler = PoissonDiscSampler.new(30, Vector2i(1000, 1000), 16)

	# calculate points
	# this could take a really long time, so you should call this from a separate thread
	var points: PackedVector2Array = sampler.find_points()

	# loop points and spawn a little dot
	for point in points:
		var new:Node2D = point_scene.instantiate()
		new.position = point
		add_child(new)
```
This very simply generates a bunch of samples, loops through them, and spawns a sprite.

### Seamless/tileable example:
```gdscript
@tool
extends Node2D

var neighboring_points : PackedVector2Array

@export var neighbors: Array[EarthChunk]
var sampler : PoissonDiscSampler

func create_points() -> void:
	# initialize sampler
	sampler = PoissonDiscSampler.new(220, Vector2i(ChunkManager.CHUNK_SIZE, ChunkManager.CHUNK_SIZE), 16)

	for neighbor in neighbors:
		# calculate the offset between neighbors so that points are 
		# correctly positioned in space
		var offset = neighbor.global_position - global_position
		
		# adds the neighboring points into the sampler
		sampler.add_seamless_points(neighbor.neighboring_points, offset)

	# spinning up a thread with a lambda function so
	# the editor doesn't freeze if the sampler takes too long
	var thread = Thread.new()
	thread.start(func():
		var points = sampler.find_points()
		receive_points.call_deferred(points)
	)

func receive_points(points: PackedVector2Array):
	# loop points and spawn a little dot
	for point in points:
		var new:Sprite2D = point_scene.instantiate()
		new.position = point
		new.texture = point_tex[hash(new.position) % point_tex.size()]
		add_child(new)
		# new.owner = get_tree().edited_scene_root

		# track dots so i can remove them for debugging purposes
		cache.append(new)

	# retrieves the points on the edge of the internal grid
	# and saves them so new chunks can retrieve them
	neighboring_points = sampler.get_seamless_points()
```
This example retrieves the neighboring chunk's edge data and uses it to generate samples that correctly space themselves with neighboring chunks. It additionally uses a simple thread for debugging purposes. 

Though, sampling points isn't something you're going to want to do every frame anyways. You should be using a thread, or at most, running it once for level initialization.

# Documentation
## Initialization
Example:
```gdscript
var sampler := PoissonDiscSampler.new(100, Vector2i(1000, 1000))
```
This creates a sampler with a 100px radius and a size of 1000 x 1000px.
|Argument name		|Description		|
|-------|-------|
|**poisson_radius**: `int`| The radius in which samples are placed away from one another|
|**grid_size**: `Vector2i`| The size in which points are allowed to be placed|
|**pick_attempts**: `int` (optional, default=64)| How many times is the algorithm allowed to place points. Smaller numbers are faster but yield worse results|
|**rand**: `RandomNumberGenerator` (optional, default=null)| Allows for the user to specify a specific `RandomNumberGenerator` for the sampler to use instead of creating its own|
## find_points() -> `PackedVector2Array`
Generates sample points and returns them in a `PackedVector2Array`.

This method is slow. It is recommended to call it from a separate thread, or during some sort of one-time initialization.

## add_seamless_points()
Takes the passed in `PackedVector2Array` and applies the given `offset` so that they can be used when calling `find_points()` to ensure seamlessness/tileability.

Should be called BEFORE calling `find_points()`. Otherwise the algorithm wont use the neighboring points when generating.
|Argument name|Description|
|----|----|
|**points**: `PackedVector2Array`|Points retrieved using `get_seamless_points()`|
|**offset**: `Vector2`|The relative position of the points' neighbor|

## get_seamless_points() -> `PackedVector2Array`
Retrieves the points from the edges of the internal grid structure. These points in combination with a proper `offset` value can allow another `PoissonDiscSampler` to generate new points that seamlessly integrate with itself.

Should only be called AFTER `find_points` is called. Otherwise, there will be nothing to retrieve from the grid.

# Credits
[Gregory Schlomoff's implementation for Unity.](http://gregschlom.com/devlog/2014/06/29/Poisson-disc-sampling-Unity.html)


[Godot](https://github.com/godotengine/godot)
