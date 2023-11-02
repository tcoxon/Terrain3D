extends Node3D
class_name RuntimeNavigationRegion3D

@export var template: NavigationMesh
@export var track: Node3D
@export var terrain: Terrain3D
@export var size := Vector3(256,1024,256)
@export var track_size := Vector3(128,512,128)

var scene_geometry: NavigationMeshSourceGeometryData3D
var nav_region: NavigationRegion3D
var center := Vector3()
var bake_task_id = null

func _ready():
	if Engine.is_editor_hint():
		return
	nav_region = NavigationRegion3D.new()
	nav_region.top_level = true
	add_child(nav_region, true)

	scene_geometry = NavigationMeshSourceGeometryData3D.new()
	var start := Time.get_ticks_usec()
	NavigationMeshGenerator.parse_source_geometry_data(template, scene_geometry, self)
	var end := Time.get_ticks_usec()
	print("parse_source_geometry_data: ", end - start, "us")

func _process(_delta):
	if !track:
		return
	var track_pos: Vector3 = track.global_position
	var new_center: Vector3 = round(track_pos / track_size) * track_size
	if new_center != center || nav_region.navigation_mesh == null:
		_recenter(new_center)

func _recenter(new_center: Vector3) -> void:
	if bake_task_id != null && !WorkerThreadPool.is_task_completed(bake_task_id):
		return
	center = new_center
	bake_task_id = WorkerThreadPool.add_task(_recenter_task)

func _recenter_task() -> void:
	var nav_mesh := template.duplicate()
	nav_mesh.filter_baking_aabb = AABB(-size * 0.5, size)
	nav_mesh.filter_baking_aabb_offset = center
	
	# Duplicate source geometry so that we can add terrain mesh to it without it permanently growing
	# in size until the game crashes.
	var source_geometry = scene_geometry.duplicate()
	
	if terrain:
		var aabb: AABB = nav_mesh.filter_baking_aabb.grow(1)
		aabb.position += center
		
		var start := Time.get_ticks_usec()
		var faces := terrain.generate_nav_mesh_source_geometry(aabb)
		var end := Time.get_ticks_usec()
		print("terrain.bake_nav_mesh_source_geometry_faces: ", end - start, "us")
		
		start = Time.get_ticks_usec()
		source_geometry.add_faces(faces, terrain.global_transform)
		end = Time.get_ticks_usec()
		print("source_geometry.add_faces: ", end - start, "us")
	
	if !source_geometry.has_data():
		return
	
	var start := Time.get_ticks_usec()
	NavigationMeshGenerator.bake_from_source_geometry_data(nav_mesh, source_geometry)
	var end := Time.get_ticks_usec()
	print("bake_from_source_geometry_data: ", end - start, "us")
	_update_nav_mesh.call_deferred(nav_mesh)

func _update_nav_mesh(nav_mesh: NavigationMesh):
	var start := Time.get_ticks_usec()
	nav_region.navigation_mesh = nav_mesh
	var end := Time.get_ticks_usec()
	print("nav_region: ", end - start, "us")
