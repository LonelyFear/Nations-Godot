extends Node
class_name Tectonics

@export var map : UpdateTileMapLayer
@export var oceanDepth : float = 0.5
@export var worldGen : WorldGenerator

var tiles : Dictionary[Vector2i, WorldTile]
var plates : Array = []

var plateTarget : int
var worldSize : Vector2i
var randomIterator : int
var seed : int
var positions : Array[Vector2i]

enum CrustTypes {
	OCEANIC,
	CONTINENTAL
}

func _ready() -> void:
	#runSimulation(worldGen.worldSize, Vector2i(4, 4))
	pass

func runSimulation(fWorldSize : Vector2i, plates : Vector2i) -> Dictionary[Vector2i, float]:
	worldSize = fWorldSize
	seed = worldGen.seed
	createPlates(plates.x, plates.y)
	initHeightmap()
	var id : int = WorkerThreadPool.add_group_task(getPressure, worldSize.x * worldSize.y)
	WorkerThreadPool.wait_for_group_task_completion(id)
	getPressures()
	return getHeightMap()

func getHeightMap() -> Dictionary[Vector2i, float]:
	var heightMap : Dictionary[Vector2i, float]
	for x in worldSize.x:
		for y in worldSize.y:
			var tile : WorldTile = tiles[Vector2i(x,y)]
			heightMap.get_or_add(Vector2i(x,y), clampf(tile.topCrust.elevation, 0.0, 1.0))
	return heightMap

func getPressure(index : int) -> void:
	var x : int = positions[index].x
	var y : int = positions[index].y
	var tile : WorldTile = tiles[Vector2i(x,y)]
	var crust : Crust = tile.crust[0]
	crust.dir = crust.plate.dir
	
	for dx in range(-2,3):
		for dy in range(-2,3):
			var testPos : Vector2i = getNewPos(Vector2i(x,y), Vector2i(dx, dy))
			var testTile : WorldTile = tiles[testPos]
			var testCrust : Crust = testTile.crust[0]
			if (crust.plate != testCrust.plate):
				var relativeVel : Vector2 = crust.dir - testCrust.dir
				if (relativeVel.length() * relativeVel.normalized().dot(testCrust.pos - crust.pos) < 0):
					crust.pressure += relativeVel.length() * 0.1
				else:
					crust.pressure -= relativeVel.length() * 0.1
			if (crust.pressure > 0):
				# Convergence
				if (crust.crustType == CrustTypes.OCEANIC):
					# Island Chans
					crust.elevation += (randf_range(0.015, 0.15) * crust.pressure)/6
				else:
					# Mountains
					crust.elevation += (randf_range(0.015, 0.2) * crust.pressure)/6
			elif (crust.pressure < 0):
				# Divergence
				if (crust.crustType == CrustTypes.OCEANIC):
					# Mid ocean ridges
					crust.elevation += (randf_range(0.2, 0.4) * abs(crust.pressure))/6
				else:
					# Rift valleys
					crust.elevation += (randf_range(0.05, 0.1) * crust.pressure)/6
func getPressures() -> void:
	for x in worldSize.x:
		for y in worldSize.y:
			var tile : WorldTile = tiles[Vector2i(x,y)]
			var crust : Crust = tile.crust[0]
			crust.dir = crust.plate.dir

	for x in worldSize.x:
		for y in worldSize.y:
			var tile : WorldTile = tiles[Vector2i(x,y)]
			var crust : Crust = tile.crust[0]
			
			for dx in range(-2,3):
				for dy in range(-2,3):
					var testPos : Vector2i = getNewPos(Vector2i(x,y), Vector2i(dx, dy))
					var testTile : WorldTile = tiles[testPos]
					var testCrust : Crust = testTile.crust[0]
					if (crust.plate != testCrust.plate):
						var relativeVel : Vector2 = crust.dir - testCrust.dir
						if (relativeVel.length() * relativeVel.normalized().dot(testCrust.pos - crust.pos) < 0):
							crust.pressure += relativeVel.length() * 0.1
						else:
							crust.pressure -= relativeVel.length() * 0.1
					if (crust.pressure > 0):
						# Convergence
						if (crust.crustType == CrustTypes.OCEANIC):
							# Island Chans
							crust.elevation += (randf_range(0.015, 0.3) * crust.pressure)/6
						else:
							# Mountains
							crust.elevation += (randf_range(0.015, 0.32) * crust.pressure)/5
					elif (crust.pressure < 0):
						# Divergence
						if (crust.crustType == CrustTypes.OCEANIC):
							# Mid ocean ridges
							crust.elevation += (randf_range(0.1, 0.2) * abs(crust.pressure))/6
						else:
							# Rift valleys
							crust.elevation += (randf_range(0.05, 0.1) * crust.pressure)/6

func initTilemap() -> void:
	if (map):
		for x in worldSize.x:
			for y in worldSize.y:
				var currentPos : Vector2i = Vector2i(x,y)
				map.set_cell(currentPos, 0, Vector2i(0,0))

func updateTilemap() -> void:
	for x in worldSize.x:
		for y in worldSize.y:
			var color : Color
			var tile : WorldTile = tiles[Vector2i(x,y)]
			if (tile.topCrust != null):
				color = lerp(Color.BLACK, Color.WHITE, tile.topCrust.elevation)
				if (tile.topCrust.elevation > worldGen.seaLevel):
					color = lerp(Color.SEA_GREEN, Color.TAN, (tile.topCrust.elevation - worldGen.seaLevel)/(1 - worldGen.seaLevel))
				else:
					color = lerp(Color.DARK_BLUE, Color.DEEP_SKY_BLUE, tile.topCrust.elevation + oceanDepth)
				#color = lerp(Color.DARK_BLUE, Color.RED, tile.topCrust.pressure + 0.5)
				#color = tile.topCrust.plate.color
			map.update_tile_color(Vector2i(x,y), color)
		

func DeleteCrust(pos : Vector2i, crust : Crust) -> void:
	var tile : WorldTile = tiles[pos]
	tile.crust.erase(crust)
	crust.plate.crust.erase(crust)

func getNewPos(pos : Vector2i, dir : Vector2i) -> Vector2i:
	var newPos : Vector2i = pos + dir
	
	newPos.x = posmod(newPos.x, worldSize.x)
	newPos.y = posmod(newPos.y, worldSize.y)
	
	return newPos

func createPlates(gridSizeX : int, gridSizeY : int) -> void:
	for x in worldSize.x:
		for y in worldSize.y:
			positions.append(Vector2i(x,y))
			tiles[Vector2i(x,y)] = WorldTile.new()
	var densities : Array = []
	
	for i in range(gridSizeX * gridSizeY):
		densities.append(i)
	
	var ppcX : int = worldSize.x/gridSizeX
	var ppcY : int = worldSize.y/gridSizeY
	
	var points : Dictionary
	var plateOrigins : Dictionary
	# Makes plates
	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var pointRng : RandomNumberGenerator = RandomNumberGenerator.new()
	pointRng.seed = rand_from_seed(seed)[0]
	for gx in gridSizeX:
		for gy in gridSizeY:
			
			#var x = gx * ppcX + randi_range(0, ppcX)
			#var y = gy * ppcY + randi_range(0, ppcY)
			
			#points[Vector2i(gx,gy)] = Vector2i(x, y)
			points[Vector2i(gx,gy)] = Vector2i(pointRng.randi_range(0, worldSize.x - 1), pointRng.randi_range(0, worldSize.y - 1))
			pointRng.seed += rand_from_seed(pointRng.seed)[0]
			
			var newPlate : Plate = Plate.new()
			newPlate.color = Color(randf(), randf(), randf())
			
			
			newPlate.dir = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			rng.seed = rand_from_seed(rng.seed)[0]
			
			var di : int = randi_range(0, densities.size() - 1)
			newPlate.density = densities[di]
			densities.remove_at(di)
			
			plates.append(newPlate)
			plateOrigins[points[Vector2i(gx,gy)]] = newPlate
			map.update_tile_color(points[Vector2i(gx,gy)], newPlate.color)
	
	var freeTiles : int = (worldSize.x * worldSize.y)
	
	var fullPositions : Array[Vector2i]
	
	for x in worldSize.x:
		for y in worldSize.y:
			
			if (plateOrigins.has(Vector2i(x,y))):
				freeTiles -= 1
				var tile : WorldTile = tiles[Vector2i(x,y)]
				fullPositions.append(Vector2i(x,y))
				
				var plate : Plate = plateOrigins[Vector2i(x,y)]
				var newCrust : Crust = Crust.new()
				
				newCrust.plate = plate
				newCrust.pos = Vector2i(x,y)
				
				tile.crust.append(newCrust)
				tile.topCrust = newCrust
				plate.crust.append(newCrust)
	var attempts : int = freeTiles * 8
	
	while freeTiles > 0 && attempts > 0:
		rng.seed = rand_from_seed(rng.seed)[0]
		attempts -= 1
		for pos in fullPositions:
				var border : bool = false
				var tile : WorldTile = tiles[pos]
				var plate : Plate = tile.topCrust.plate
				
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						if (dx != 0 && dy != 0):
							continue
						var newPos : Vector2i = getNewPos(pos, Vector2i(dx, dy))
						var newTile : WorldTile = tiles[newPos]
						
						if (!newTile.topCrust):
							border = true
							if (rng.randf() <= 0.1):
								var newCrust : Crust = Crust.new()
								newCrust.plate = plate
								newCrust.pos = newPos
								
								newTile.crust.append(newCrust)
								newTile.topCrust = newCrust
								plate.crust.append(newCrust)
								
								fullPositions.append(newPos)
								freeTiles -= 1
				if !border:
					fullPositions.erase(pos)

func initHeightmap() -> void:
	var noise : FastNoiseLite = FastNoiseLite.new()
	noise.fractal_octaves = 8
	noise.seed = seed

	var falloffMap : Dictionary = Falloff.generateFalloff(worldSize.x, worldSize.y, 9.2, true)
	for x in worldSize.x:
		for y in worldSize.y:
			var height : float = clampf((noise.get_noise_2d(x/worldGen.mapScale,y/worldGen.mapScale) + 1)/2 - falloffMap[Vector2i(x,y)], 0, 1)
			var tile : WorldTile = tiles[Vector2i(x,y)]
			
			
			if height > worldGen.seaLevel:
				if (height > worldGen.seaLevel + 0.05):
					height = worldGen.seaLevel + 0.05
				tile.topCrust.crustType = CrustTypes.CONTINENTAL
			else:
				height = lerpf(worldGen.seaLevel - oceanDepth, worldGen.seaLevel, calcInverseFalloff(inverse_lerp(worldGen.seaLevel, 0, height)))
			tile.topCrust.elevation = height
	
func calcInverseFalloff(v : float) -> float:
	var a : float = 3
	var b : float= .15
	return 1 - pow(v, a) / (pow(v, a) + pow(b - b*v, a))

func getWrappedDist(a : Vector2, b : Vector2) -> float:
	var dx : int = abs(b.x - a.x) 
	if (dx > worldSize.x/2):
		dx = worldSize.x - dx
	var dy : int = abs(b.y - a.y)
	if (dy > worldSize.y/2):
		dy = worldSize.y - dy
	

	## Manhattan
	return dx + dy

class Plate:
	var velChanged : bool
	var density : int
	var color : Color
	var dir : Vector2
	var crust : Array = []

class WorldTile:
	var topCrust : Crust
	var lastPlate : Plate
	var crust : Array = []

class Crust:
	var dir : Vector2
	var moved : bool = false
	var age : int = 10
	var elevation : float = 0
	var lostElevation : float = 0
	var pos : Vector2i
	var plate : Plate
	var pressure : float
	var crustType : CrustTypes = CrustTypes.OCEANIC
