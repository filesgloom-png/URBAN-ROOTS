extends Node3D

const WALK_SPEED := 4.2
const RUN_SPEED := 6.6
const LOOK_SENSITIVITY := 0.006
const ROOM_SIZE := Vector3(12.0, 3.2, 12.0)

var player: CharacterBody3D
var avatar_root: Node3D
var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var left_leg: MeshInstance3D
var right_leg: MeshInstance3D
var walk_phase := 0.0
var sprinting := false
var camera_pivot: Node3D
var camera: Camera3D
var first_person := false
var pitch := -0.12
var yaw := 0.0
var joystick_vector := Vector2.ZERO
var look_finger := -1
var look_last := Vector2.ZERO
var status_label: Label
var movement_label: Label
var stamina_label: Label
var interaction_hint: Label
var interact_button: Button
var ceiling_glow: OmniLight3D
var ceiling_fixture: MeshInstance3D
var switch_visual: MeshInstance3D
var tv_screen: MeshInstance3D
var fridge_visual: MeshInstance3D
var door_pivot: Node3D
var door_is_open := false
var apartment_zone_label: Label
var light_is_on := true
var tv_is_on := false
var fridge_is_open := false
var stamina := 100.0
var interaction_target := ""
var npc_residents: Array[Dictionary] = []
var npc_status_label: Label
var traffic_car: Node3D
var traffic_direction := 1.0

func _ready() -> void:
	_build_environment()
	_build_room()
	_build_player()
	_build_npc_residents()
	_build_second_pedestrian()
	_build_crosswalk_pedestrian()
	_build_moving_traffic()
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.19, 0.28)
	sky_mat.sky_horizon_color = Color(0.65, 0.72, 0.78)
	sky_mat.ground_bottom_color = Color(0.12, 0.13, 0.14)
	sky_mat.ground_horizon_color = Color(0.55, 0.58, 0.6)
	env.sky.sky_material = sky_mat
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.7, 0.78)
	env.ambient_light_energy = 0.7
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

func _material(color: Color, roughness := 0.8) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _box(parent: Node3D, label: String, size: Vector3, pos: Vector3, color: Color, collision := true) -> MeshInstance3D:
	var body := StaticBody3D.new() if collision else Node3D.new()
	body.name = label
	body.position = pos
	parent.add_child(body)
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _material(color)
	body.add_child(visual)
	if collision:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
	return visual

func _build_room() -> void:
	var floor_mat := Color(0.42, 0.34, 0.27)
	var wall_mat := Color(0.78, 0.77, 0.72)
	var trim_mat := Color(0.26, 0.29, 0.31)
	_box(self, "Floor", Vector3(ROOM_SIZE.x, 0.2, ROOM_SIZE.z), Vector3(0, -0.1, 0), floor_mat)
	_box(self, "BackWall", Vector3(ROOM_SIZE.x, ROOM_SIZE.y, 0.2), Vector3(0, ROOM_SIZE.y / 2.0, -ROOM_SIZE.z / 2.0), wall_mat)
	_box(self, "LeftWall", Vector3(0.2, ROOM_SIZE.y, ROOM_SIZE.z), Vector3(-ROOM_SIZE.x / 2.0, ROOM_SIZE.y / 2.0, 0), wall_mat)
	_box(self, "RightWall", Vector3(0.2, ROOM_SIZE.y, ROOM_SIZE.z), Vector3(ROOM_SIZE.x / 2.0, ROOM_SIZE.y / 2.0, 0), wall_mat)
	_box(self, "FrontWallLeft", Vector3(3.2, ROOM_SIZE.y, 0.2), Vector3(-4.4, ROOM_SIZE.y / 2.0, ROOM_SIZE.z / 2.0), wall_mat)
	_box(self, "FrontWallRight", Vector3(3.2, ROOM_SIZE.y, 0.2), Vector3(4.4, ROOM_SIZE.y / 2.0, ROOM_SIZE.z / 2.0), wall_mat)
	_box(self, "DoorHeader", Vector3(2.0, 0.7, 0.2), Vector3(0, 2.85, ROOM_SIZE.z / 2.0), wall_mat)
	_box(self, "BackWallBaseboard", Vector3(11.6, 0.16, 0.06), Vector3(0, 0.08, -5.86), Color(0.29, 0.25, 0.21), false)
	_box(self, "LeftWallBaseboard", Vector3(0.06, 0.16, 11.6), Vector3(-5.86, 0.08, 0), Color(0.29, 0.25, 0.21), false)
	_box(self, "RightWallBaseboard", Vector3(0.06, 0.16, 11.6), Vector3(5.86, 0.08, 0), Color(0.29, 0.25, 0.21), false)
	door_pivot = Node3D.new()
	door_pivot.name = "ApartmentDoorPivot"
	door_pivot.position = Vector3(-0.82, 1.25, 5.88)
	add_child(door_pivot)
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(1.7, 2.5, 0.08)
	var door_visual := MeshInstance3D.new()
	door_visual.name = "Door"
	door_visual.mesh = door_mesh
	door_visual.position = Vector3(0.85, 0, 0)
	door_visual.material_override = _material(Color(0.34, 0.22, 0.14))
	door_pivot.add_child(door_visual)
	_box(self, "DoorFrameLeft", Vector3(0.12, 2.55, 0.14), Vector3(-0.92, 1.27, 5.82), Color(0.25, 0.18, 0.13), false)
	_box(self, "DoorFrameRight", Vector3(0.12, 2.55, 0.14), Vector3(0.92, 1.27, 5.82), Color(0.25, 0.18, 0.13), false)
	_box(self, "DoorFrameTop", Vector3(1.95, 0.12, 0.14), Vector3(0, 2.54, 5.82), Color(0.25, 0.18, 0.13), false)
	_box(self, "LightSwitchPlate", Vector3(0.18, 0.28, 0.035), Vector3(1.2, 1.25, 5.82), Color(0.82, 0.8, 0.72), false)
	switch_visual = _box(self, "LightSwitchToggle", Vector3(0.07, 0.12, 0.025), Vector3(1.2, 1.25, 5.79), Color(0.35, 0.37, 0.34), false)
	_box(self, "EntryMat", Vector3(1.5, 0.035, 0.72), Vector3(0, 0.025, 5.25), Color(0.22, 0.29, 0.29), false)
	_box(self, "EntryMatStripeLeft", Vector3(0.045, 0.012, 0.62), Vector3(-0.56, 0.048, 5.25), Color(0.68, 0.56, 0.38), false)
	_box(self, "EntryMatStripeRight", Vector3(0.045, 0.012, 0.62), Vector3(0.56, 0.048, 5.25), Color(0.68, 0.56, 0.38), false)
	_box(self, "BedBase", Vector3(2.1, 0.35, 2.8), Vector3(-3.4, 0.2, -3.1), Color(0.32, 0.25, 0.22))
	_box(self, "Mattress", Vector3(2.0, 0.22, 2.65), Vector3(-3.4, 0.48, -3.1), Color(0.85, 0.83, 0.77), false)
	_box(self, "Pillow", Vector3(1.2, 0.16, 0.5), Vector3(-3.4, 0.65, -4.05), Color(0.92, 0.9, 0.85), false)
	_box(self, "Desk", Vector3(2.1, 0.12, 0.9), Vector3(3.4, 0.9, -4.3), Color(0.3, 0.2, 0.14))
	_box(self, "DeskLeg1", Vector3(0.12, 0.9, 0.12), Vector3(2.55, 0.45, -4.3), trim_mat)
	_box(self, "DeskLeg2", Vector3(0.12, 0.9, 0.12), Vector3(4.25, 0.45, -4.3), trim_mat)
	_box(self, "SofaBase", Vector3(2.8, 0.55, 1.0), Vector3(2.8, 0.32, 1.5), Color(0.28, 0.34, 0.37))
	_box(self, "SofaBack", Vector3(2.8, 0.9, 0.25), Vector3(2.8, 0.95, 2.0), Color(0.28, 0.34, 0.37))
	_box(self, "CoffeeTable", Vector3(1.5, 0.12, 0.8), Vector3(0.1, 0.5, 1.3), Color(0.35, 0.24, 0.16))
	_box(self, "Rug", Vector3(3.8, 0.025, 2.8), Vector3(0.2, 0.015, 1.3), Color(0.42, 0.35, 0.29), false)
	_box(self, "WindowGlass", Vector3(2.4, 1.4, 0.06), Vector3(-5.88, 1.95, -1.2), Color(0.35, 0.55, 0.68), false)
	_box(self, "WindowFrameTop", Vector3(2.6, 0.1, 0.14), Vector3(-5.82, 2.7, -1.2), Color(0.25, 0.25, 0.24))
	_box(self, "WindowFrameBottom", Vector3(2.6, 0.1, 0.14), Vector3(-5.82, 1.2, -1.2), Color(0.25, 0.25, 0.24))
	_box(self, "WindowFrameLeft", Vector3(0.1, 1.5, 0.14), Vector3(-5.82, 1.95, -2.45), Color(0.25, 0.25, 0.24))
	_box(self, "WindowFrameRight", Vector3(0.1, 1.5, 0.14), Vector3(-5.82, 1.95, 0.05), Color(0.25, 0.25, 0.24))
	_box(self, "WindowCurtainRod", Vector3(0.12, 0.12, 2.9), Vector3(-5.68, 2.78, -1.2), Color(0.3, 0.25, 0.2), false)
	_box(self, "WindowCurtainLeft", Vector3(0.12, 1.65, 0.78), Vector3(-5.7, 1.92, -2.12), Color(0.64, 0.57, 0.46), false)
	_box(self, "WindowCurtainRight", Vector3(0.12, 1.65, 0.78), Vector3(-5.7, 1.92, -0.28), Color(0.64, 0.57, 0.46), false)
	_box(self, "WindowCurtainTieLeft", Vector3(0.15, 0.08, 0.48), Vector3(-5.62, 1.85, -2.12), Color(0.42, 0.34, 0.26), false)
	_box(self, "WindowCurtainTieRight", Vector3(0.15, 0.08, 0.48), Vector3(-5.62, 1.85, -0.28), Color(0.42, 0.34, 0.26), false)
	_box(self, "WindowSill", Vector3(0.18, 0.12, 2.72), Vector3(-5.72, 1.12, -1.2), Color(0.48, 0.39, 0.29), false)
	_box(self, "WindowSillEndLeft", Vector3(0.18, 0.12, 0.12), Vector3(-5.72, 1.12, -2.52), Color(0.39, 0.31, 0.24), false)
	_box(self, "WindowSillEndRight", Vector3(0.18, 0.12, 0.12), Vector3(-5.72, 1.12, 0.12), Color(0.39, 0.31, 0.24), false)
	_box(self, "WindowMullionVertical", Vector3(0.08, 1.42, 0.1), Vector3(-5.78, 1.95, -1.2), Color(0.25, 0.25, 0.24), false)
	_box(self, "WindowMullionHorizontal", Vector3(0.08, 0.1, 2.42), Vector3(-5.78, 1.95, -1.2), Color(0.25, 0.25, 0.24), false)
	_box(self, "KitchenCounter", Vector3(2.8, 0.9, 0.75), Vector3(-3.9, 0.45, 2.5), Color(0.5, 0.5, 0.46))
	fridge_visual = _box(self, "Fridge", Vector3(0.85, 2.0, 0.8), Vector3(-5.0, 1.0, 3.6), Color(0.72, 0.75, 0.76))
	_box(self, "FridgeHandle", Vector3(0.055, 0.55, 0.07), Vector3(-4.55, 1.05, 3.62), Color(0.35, 0.38, 0.4), false)
	_box(self, "LampStem", Vector3(0.08, 1.1, 0.08), Vector3(4.5, 1.05, 0.1), trim_mat)
	_box(self, "LampShade", Vector3(0.55, 0.18, 0.55), Vector3(4.5, 1.65, 0.1), Color(0.9, 0.75, 0.48), false)
	# Small lived-in details: bedside table, wall art, media unit, plant and kitchen fixtures.
	_box(self, "BedsideTable", Vector3(0.65, 0.58, 0.62), Vector3(-4.85, 0.29, -4.0), Color(0.38, 0.27, 0.19))
	_box(self, "BedsideDrawer", Vector3(0.48, 0.18, 0.04), Vector3(-4.85, 0.38, -3.67), Color(0.55, 0.4, 0.29), false)
	_box(self, "BedsideHandle", Vector3(0.12, 0.035, 0.035), Vector3(-4.85, 0.38, -3.63), Color(0.78, 0.7, 0.52), false)
	_box(self, "WallPictureFrame", Vector3(1.25, 0.85, 0.08), Vector3(1.2, 2.05, -5.78), Color(0.24, 0.2, 0.16), false)
	_box(self, "WallPictureCanvas", Vector3(1.08, 0.68, 0.025), Vector3(1.2, 2.05, -5.72), Color(0.36, 0.53, 0.48), false)
	_box(self, "PictureSun", Vector3(0.24, 0.24, 0.03), Vector3(1.45, 2.17, -5.69), Color(0.9, 0.67, 0.36), false)
	_box(self, "TVStand", Vector3(2.2, 0.58, 0.55), Vector3(0.1, 0.29, -3.7), Color(0.28, 0.22, 0.18))
	tv_screen = _box(self, "TVScreen", Vector3(1.65, 0.95, 0.1), Vector3(0.1, 1.12, -3.95), Color(0.045, 0.075, 0.09), false)
	_box(self, "TVStandShelf", Vector3(1.7, 0.06, 0.4), Vector3(0.1, 0.15, -3.68), Color(0.4, 0.31, 0.23), false)
	_box(self, "PlantPot", Vector3(0.42, 0.38, 0.42), Vector3(5.0, 0.19, 2.55), Color(0.48, 0.25, 0.18))
	_box(self, "PlantStem", Vector3(0.1, 0.65, 0.1), Vector3(5.0, 0.65, 2.55), Color(0.2, 0.36, 0.23), false)
	_box(self, "PlantLeafLeft", Vector3(0.42, 0.35, 0.18), Vector3(4.78, 0.85, 2.55), Color(0.22, 0.43, 0.27), false)
	_box(self, "PlantLeafRight", Vector3(0.42, 0.38, 0.18), Vector3(5.2, 0.95, 2.55), Color(0.27, 0.49, 0.3), false)
	_box(self, "KitchenWorktop", Vector3(2.9, 0.12, 0.82), Vector3(-3.9, 0.95, 2.5), Color(0.72, 0.7, 0.64), false)
	_box(self, "StoveTop", Vector3(0.85, 0.06, 0.58), Vector3(-4.45, 1.05, 2.45), Color(0.18, 0.2, 0.21), false)
	_box(self, "StoveBurnerLeft", Vector3(0.26, 0.025, 0.26), Vector3(-4.63, 1.095, 2.38), Color(0.08, 0.09, 0.1), false)
	_box(self, "StoveBurnerRight", Vector3(0.26, 0.025, 0.26), Vector3(-4.27, 1.095, 2.38), Color(0.08, 0.09, 0.1), false)
	_box(self, "SinkBasin", Vector3(0.65, 0.06, 0.45), Vector3(-3.25, 1.04, 2.48), Color(0.38, 0.43, 0.45), false)
	ceiling_fixture = _box(self, "CeilingLight", Vector3(1.0, 0.08, 0.45), Vector3(0, 3.0, -0.2), Color(0.94, 0.84, 0.64), false)
	# Apartment building exterior and the first courtyard block.
	_box(self, "BuildingFacadeLeft", Vector3(5.0, 3.25, 0.32), Vector3(-3.5, 3.2, 6.12), Color(0.63, 0.61, 0.55))
	_box(self, "BuildingFacadeRight", Vector3(5.0, 3.25, 0.32), Vector3(3.5, 3.2, 6.12), Color(0.63, 0.61, 0.55))
	_box(self, "BuildingFacadeDoorHeader", Vector3(2.0, 0.7, 0.32), Vector3(0, 2.85, 6.12), Color(0.63, 0.61, 0.55))
	_box(self, "FacadeLowerBand", Vector3(12.0, 0.28, 0.38), Vector3(0, 1.55, 6.0), Color(0.37, 0.38, 0.36), false)
	_box(self, "FacadeUpperBand", Vector3(12.0, 0.16, 0.38), Vector3(0, 4.55, 6.0), Color(0.43, 0.43, 0.4), false)
	_box(self, "EntranceCanopy", Vector3(3.2, 0.18, 1.25), Vector3(0, 2.85, 6.85), Color(0.28, 0.31, 0.32))
	_box(self, "EntranceCanopySupportLeft", Vector3(0.12, 1.25, 0.12), Vector3(-1.35, 2.25, 7.3), Color(0.28, 0.3, 0.3), false)
	_box(self, "EntranceCanopySupportRight", Vector3(0.12, 1.25, 0.12), Vector3(1.35, 2.25, 7.3), Color(0.28, 0.3, 0.3), false)
	_box(self, "EntranceSign", Vector3(1.9, 0.36, 0.08), Vector3(0, 2.55, 6.28), Color(0.16, 0.22, 0.23), false)
	_box(self, "EntranceSignAccent", Vector3(0.08, 0.22, 0.035), Vector3(-0.72, 2.55, 6.225), Color(0.79, 0.62, 0.35), false)
	# Ground-floor windows and facade trim.
	for window_x in [-4.2, -2.4, 2.4, 4.2]:
		_box(self, "FacadeWindowFrame_" + str(window_x), Vector3(1.25, 1.35, 0.1), Vector3(window_x, 3.15, 5.91), Color(0.28, 0.29, 0.28), false)
		_box(self, "FacadeWindowGlass_" + str(window_x), Vector3(1.05, 1.15, 0.045), Vector3(window_x, 3.15, 5.84), Color(0.3, 0.48, 0.58), false)
		_box(self, "FacadeWindowDivider_" + str(window_x), Vector3(0.055, 1.12, 0.04), Vector3(window_x, 3.15, 5.805), Color(0.22, 0.24, 0.24), false)
	# Entrance landing and shallow steps: walkable transition from the apartment door to the courtyard.
	_box(self, "EntranceLanding", Vector3(3.2, 0.14, 0.9), Vector3(0, 0.015, 6.45), Color(0.52, 0.51, 0.47))
	_box(self, "EntranceStepTop", Vector3(3.0, 0.12, 0.42), Vector3(0, -0.005, 6.95), Color(0.49, 0.48, 0.44))
	_box(self, "EntranceStepMiddle", Vector3(3.4, 0.10, 0.42), Vector3(0, -0.025, 7.28), Color(0.46, 0.45, 0.42))
	_box(self, "EntranceStepBottom", Vector3(3.8, 0.08, 0.42), Vector3(0, -0.045, 7.6), Color(0.43, 0.43, 0.4))
	# Intercom and mailboxes beside the entrance, kept clear of the door swing and walking line.
	_box(self, "EntranceIntercomPanel", Vector3(0.28, 0.62, 0.09), Vector3(1.35, 1.35, 6.29), Color(0.19, 0.23, 0.24), false)
	_box(self, "EntranceIntercomScreen", Vector3(0.15, 0.12, 0.025), Vector3(1.35, 1.48, 6.235), Color(0.32, 0.62, 0.57), false)
	for mailbox_y in [1.15, 1.42, 1.69]:
		_box(self, "Mailbox_" + str(mailbox_y), Vector3(0.42, 0.22, 0.14), Vector3(-1.42, mailbox_y, 6.28), Color(0.38, 0.4, 0.39), false)
		_box(self, "MailboxSlot_" + str(mailbox_y), Vector3(0.22, 0.025, 0.025), Vector3(-1.42, mailbox_y + 0.025, 6.195), Color(0.12, 0.14, 0.14), false)
	# Exterior starter zone: ground, entrance porch, pavement, street and simple props.
	_box(self, "OutdoorGround", Vector3(30.0, 0.2, 24.0), Vector3(0, -0.16, 17.0), Color(0.23, 0.34, 0.22))
	_box(self, "EntrancePorch", Vector3(5.0, 0.12, 2.4), Vector3(0, -0.015, 7.1), Color(0.48, 0.47, 0.43))
	_box(self, "FrontWalkway", Vector3(3.8, 0.08, 7.5), Vector3(0, -0.035, 11.8), Color(0.48, 0.49, 0.47))
	_box(self, "WalkwayEdgeLeft", Vector3(0.12, 0.12, 7.6), Vector3(-1.98, -0.01, 11.8), Color(0.31, 0.32, 0.3), false)
	_box(self, "WalkwayEdgeRight", Vector3(0.12, 0.12, 7.6), Vector3(1.98, -0.01, 11.8), Color(0.31, 0.32, 0.3), false)
	_box(self, "StreetAsphalt", Vector3(18.0, 0.08, 5.0), Vector3(0, -0.045, 21.0), Color(0.16, 0.18, 0.19))
	_box(self, "Curb", Vector3(18.0, 0.16, 0.28), Vector3(0, 0.02, 18.35), Color(0.58, 0.57, 0.52))
	_box(self, "RoadMarking", Vector3(7.0, 0.015, 0.12), Vector3(0, 0.005, 21.0), Color(0.85, 0.82, 0.68), false)
	_box(self, "CourtyardTreeTrunk", Vector3(0.32, 1.8, 0.32), Vector3(-7.0, 0.8, 11.5), Color(0.3, 0.2, 0.13), false)
	_box(self, "CourtyardTreeCrown", Vector3(2.2, 2.0, 2.2), Vector3(-7.0, 2.4, 11.5), Color(0.18, 0.35, 0.2), false)
	_box(self, "CourtyardBenchSeat", Vector3(1.8, 0.12, 0.5), Vector3(5.0, 0.52, 12.5), Color(0.42, 0.28, 0.17), false)
	_box(self, "CourtyardBenchBack", Vector3(1.8, 0.75, 0.12), Vector3(5.0, 0.9, 12.72), Color(0.42, 0.28, 0.17), false)
	_box(self, "StreetLampPole", Vector3(0.12, 3.2, 0.12), Vector3(7.5, 1.6, 15.5), Color(0.2, 0.22, 0.23), false)
	_box(self, "StreetLampHead", Vector3(0.65, 0.14, 0.35), Vector3(7.5, 3.2, 15.5), Color(0.9, 0.8, 0.58), false)
	# Courtyard layout: side paths, low perimeter fencing and a wide gate aligned with the street.
	_box(self, "PathToTree", Vector3(5.6, 0.035, 1.55), Vector3(-4.9, -0.035, 11.7), Color(0.42, 0.44, 0.41), false)
	_box(self, "PathToBench", Vector3(4.2, 0.035, 1.5), Vector3(3.0, -0.035, 12.45), Color(0.42, 0.44, 0.41), false)
	for fence_z in [9.0, 11.0, 13.0, 15.0, 16.4]:
		_box(self, "LeftFencePost_" + str(fence_z), Vector3(0.16, 0.95, 0.16), Vector3(-9.2, 0.475, fence_z), Color(0.31, 0.33, 0.32), false)
		_box(self, "RightFencePost_" + str(fence_z), Vector3(0.16, 0.95, 0.16), Vector3(9.2, 0.475, fence_z), Color(0.31, 0.33, 0.32), false)
	_box(self, "LeftFenceRailUpper", Vector3(0.12, 0.12, 7.6), Vector3(-9.2, 0.82, 12.7), Color(0.31, 0.33, 0.32), false)
	_box(self, "LeftFenceRailLower", Vector3(0.1, 0.1, 7.6), Vector3(-9.2, 0.35, 12.7), Color(0.31, 0.33, 0.32), false)
	_box(self, "RightFenceRailUpper", Vector3(0.12, 0.12, 7.6), Vector3(9.2, 0.82, 12.7), Color(0.31, 0.33, 0.32), false)
	_box(self, "RightFenceRailLower", Vector3(0.1, 0.1, 7.6), Vector3(9.2, 0.35, 12.7), Color(0.31, 0.33, 0.32), false)
	# Small outdoor details to make the courtyard feel lived in without blocking traversal.
	_box(self, "CourtyardWasteBin", Vector3(0.58, 0.82, 0.58), Vector3(7.0, 0.41, 10.0), Color(0.28, 0.33, 0.32))
	_box(self, "WasteBinLid", Vector3(0.64, 0.08, 0.64), Vector3(7.0, 0.86, 10.0), Color(0.19, 0.23, 0.23), false)
	_box(self, "CourtyardPlanter", Vector3(1.35, 0.32, 0.7), Vector3(-5.2, 0.16, 15.0), Color(0.42, 0.31, 0.23))
	_box(self, "PlanterShrub", Vector3(1.12, 0.62, 0.52), Vector3(-5.2, 0.58, 15.0), Color(0.2, 0.39, 0.23), false)
	_box(self, "BenchSupportLeft", Vector3(0.12, 0.48, 0.12), Vector3(4.35, 0.25, 12.5), Color(0.22, 0.23, 0.22), false)
	_box(self, "BenchSupportRight", Vector3(0.12, 0.48, 0.12), Vector3(5.65, 0.25, 12.5), Color(0.22, 0.23, 0.22), false)
	# Expanded street block: sidewalks and two low-rise neighboring buildings beyond the road edges.
	_box(self, "LeftSidewalk", Vector3(3.2, 0.06, 5.4), Vector3(-10.7, -0.025, 21.0), Color(0.43, 0.44, 0.42))
	_box(self, "RightSidewalk", Vector3(3.2, 0.06, 5.4), Vector3(10.7, -0.025, 21.0), Color(0.43, 0.44, 0.42))
	_box(self, "LeftBuildingMain", Vector3(4.8, 5.8, 3.8), Vector3(-13.0, 2.9, 23.4), Color(0.57, 0.54, 0.48))
	_box(self, "LeftBuildingLowerBand", Vector3(4.86, 0.22, 3.9), Vector3(-13.0, 1.35, 21.42), Color(0.34, 0.36, 0.35), false)
	_box(self, "LeftBuildingRoofEdge", Vector3(5.0, 0.18, 4.0), Vector3(-13.0, 5.82, 23.4), Color(0.36, 0.36, 0.33), false)
	_box(self, "RightBuildingMain", Vector3(4.8, 5.0, 3.8), Vector3(13.0, 2.5, 23.4), Color(0.49, 0.54, 0.55))
	_box(self, "RightBuildingLowerBand", Vector3(4.86, 0.22, 3.9), Vector3(13.0, 1.25, 21.42), Color(0.31, 0.35, 0.36), false)
	_box(self, "RightBuildingRoofEdge", Vector3(5.0, 0.18, 4.0), Vector3(13.0, 5.02, 23.4), Color(0.32, 0.36, 0.37), false)
	# Street-facing windows and storefront-style ground-floor panels.
	for facade_x in [-14.0, -12.0, 12.0, 14.0]:
		var facade_is_left := facade_x < 0.0
		var facade_z := 21.43 if facade_is_left else 21.43
		_box(self, "StreetWindowFrame_" + str(facade_x), Vector3(0.92, 1.18, 0.09), Vector3(facade_x, 3.35 if facade_is_left else 2.95, facade_z), Color(0.25, 0.28, 0.29), false)
		_box(self, "StreetWindowGlass_" + str(facade_x), Vector3(0.74, 0.98, 0.04), Vector3(facade_x, 3.35 if facade_is_left else 2.95, facade_z - 0.055), Color(0.29, 0.48, 0.57), false)
		_box(self, "StreetWindowDivider_" + str(facade_x), Vector3(0.055, 0.94, 0.035), Vector3(facade_x, 3.35 if facade_is_left else 2.95, facade_z - 0.08), Color(0.21, 0.23, 0.24), false)
	_box(self, "LeftStorefrontSign", Vector3(2.0, 0.38, 0.1), Vector3(-13.0, 1.75, 21.38), Color(0.17, 0.25, 0.25), false)
	_box(self, "LeftStorefrontSignAccent", Vector3(0.12, 0.24, 0.035), Vector3(-13.65, 1.75, 21.315), Color(0.79, 0.62, 0.35), false)
	_box(self, "RightEntranceDoor", Vector3(0.9, 2.0, 0.08), Vector3(13.0, 1.05, 21.38), Color(0.25, 0.22, 0.18), false)
	_box(self, "RightEntranceDoorGlass", Vector3(0.58, 1.05, 0.035), Vector3(13.0, 1.25, 21.32), Color(0.3, 0.49, 0.56), false)
	# Road markings continue along the wider street, while the central walking route stays clear.
	_box(self, "RoadMarkingLeft", Vector3(5.0, 0.015, 0.1), Vector3(-5.2, 0.005, 21.0), Color(0.85, 0.82, 0.68), false)
	_box(self, "RoadMarkingRight", Vector3(5.0, 0.015, 0.1), Vector3(5.2, 0.005, 21.0), Color(0.85, 0.82, 0.68), false)
	_build_parked_car()
	ceiling_glow = OmniLight3D.new()
	ceiling_glow.name = "WarmCeilingGlow"
	ceiling_glow.position = Vector3(0, 2.85, -0.2)
	ceiling_glow.light_color = Color(1.0, 0.78, 0.52)
	ceiling_glow.light_energy = 1.15
	ceiling_glow.omni_range = 8.0
	ceiling_glow.shadow_enabled = false
	add_child(ceiling_glow)

func _build_parked_car() -> void:
	# A compact parked hatchback at the road edge, clear of the courtyard entrance and walking routes.
	var car := Node3D.new()
	car.name = "ParkedHatchback"
	car.position = Vector3(7.05, 0.0, 21.0)
	add_child(car)
	_box(car, "CarLowerBody", Vector3(1.72, 0.56, 3.35), Vector3(0, 0.55, 0), Color(0.16, 0.34, 0.48))
	_box(car, "CarHood", Vector3(1.62, 0.16, 0.88), Vector3(0, 0.78, -1.12), Color(0.19, 0.4, 0.55), false)
	_box(car, "CarRearDeck", Vector3(1.58, 0.14, 0.52), Vector3(0, 0.78, 1.28), Color(0.16, 0.34, 0.48), false)
	_box(car, "CarCabin", Vector3(1.3, 0.58, 1.55), Vector3(0, 1.08, -0.05), Color(0.12, 0.25, 0.32), false)
	_box(car, "CarWindshield", Vector3(1.14, 0.38, 0.035), Vector3(0, 1.12, -0.84), Color(0.32, 0.53, 0.61), false)
	_box(car, "CarRearWindow", Vector3(1.1, 0.34, 0.035), Vector3(0, 1.12, 0.73), Color(0.3, 0.49, 0.57), false)
	for side in [-1.0, 1.0]:
		_box(car, "CarSideWindow_" + str(side), Vector3(0.035, 0.34, 0.95), Vector3(side * 0.665, 1.12, -0.05), Color(0.3, 0.49, 0.57), false)
		_box(car, "CarDoorHandle_" + str(side), Vector3(0.035, 0.045, 0.2), Vector3(side * 0.87, 0.62, 0.08), Color(0.72, 0.74, 0.72), false)
		for axle_z in [-1.05, 1.05]:
			var wheel := MeshInstance3D.new()
			wheel.name = "CarWheel_" + str(side) + "_" + str(axle_z)
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.31
			wheel_mesh.bottom_radius = 0.31
			wheel_mesh.height = 0.2
			wheel.mesh = wheel_mesh
			wheel.material_override = _material(Color(0.075, 0.08, 0.085))
			wheel.position = Vector3(side * 0.86, 0.31, axle_z)
			wheel.rotation_degrees.z = 90.0
			car.add_child(wheel)
			var hub := MeshInstance3D.new()
			hub.name = "WheelHub_" + str(side) + "_" + str(axle_z)
			var hub_mesh := CylinderMesh.new()
			hub_mesh.top_radius = 0.14
			hub_mesh.bottom_radius = 0.14
			hub_mesh.height = 0.215
			hub.mesh = hub_mesh
			hub.material_override = _material(Color(0.58, 0.6, 0.59))
			hub.position = wheel.position
			hub.position.x += side * 0.012
			hub.rotation_degrees.z = 90.0
			car.add_child(hub)
	for side in [-1.0, 1.0]:
		_box(car, "CarHeadlight_" + str(side), Vector3(0.32, 0.13, 0.045), Vector3(side * 0.52, 0.62, -1.69), Color(0.96, 0.84, 0.56), false)
		_box(car, "CarTaillight_" + str(side), Vector3(0.28, 0.14, 0.045), Vector3(side * 0.54, 0.62, 1.69), Color(0.72, 0.12, 0.1), false)
	_box(car, "CarFrontBumper", Vector3(1.58, 0.12, 0.12), Vector3(0, 0.34, -1.68), Color(0.24, 0.26, 0.27), false)
	_box(car, "CarRearBumper", Vector3(1.58, 0.12, 0.12), Vector3(0, 0.34, 1.68), Color(0.24, 0.26, 0.27), false)

func _build_moving_traffic() -> void:
	# One low-speed traffic car follows the road axis and reverses at each end of the visible block.
	traffic_car = Node3D.new()
	traffic_car.name = "MovingTrafficHatchback"
	traffic_car.position = Vector3(-5.8, 0.0, 20.15)
	traffic_car.rotation.y = -PI / 2.0
	add_child(traffic_car)
	_box(traffic_car, "TrafficCarBody", Vector3(3.15, 0.52, 1.52), Vector3(0, 0.55, 0), Color(0.62, 0.25, 0.16), false)
	_box(traffic_car, "TrafficCarHood", Vector3(0.82, 0.15, 1.42), Vector3(1.05, 0.82, 0), Color(0.7, 0.29, 0.18), false)
	_box(traffic_car, "TrafficCarTrunk", Vector3(0.58, 0.14, 1.38), Vector3(-1.18, 0.81, 0), Color(0.58, 0.22, 0.15), false)
	_box(traffic_car, "TrafficCarCabin", Vector3(1.48, 0.56, 1.12), Vector3(-0.05, 1.02, 0), Color(0.12, 0.23, 0.29), false)
	_box(traffic_car, "TrafficCarFrontGlass", Vector3(0.035, 0.36, 0.94), Vector3(0.58, 1.08, 0), Color(0.36, 0.55, 0.62), false)
	_box(traffic_car, "TrafficCarRearGlass", Vector3(0.035, 0.34, 0.92), Vector3(-0.66, 1.08, 0), Color(0.32, 0.5, 0.58), false)
	for side in [-1.0, 1.0]:
		_box(traffic_car, "TrafficCarSideWindow_" + str(side), Vector3(0.9, 0.31, 0.035), Vector3(-0.05, 1.08, side * 0.57), Color(0.3, 0.48, 0.56), false)
		for axle_x in [-1.02, 1.02]:
			var wheel := MeshInstance3D.new()
			wheel.name = "TrafficWheel_" + str(side) + "_" + str(axle_x)
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.28
			wheel_mesh.bottom_radius = 0.28
			wheel_mesh.height = 0.16
			wheel.mesh = wheel_mesh
			wheel.material_override = _material(Color(0.07, 0.075, 0.08))
			wheel.position = Vector3(axle_x, 0.3, side * 0.79)
			wheel.rotation_degrees.x = 90.0
			traffic_car.add_child(wheel)
	_box(traffic_car, "TrafficHeadlightLeft", Vector3(0.12, 0.12, 0.3), Vector3(1.58, 0.62, -0.43), Color(0.98, 0.84, 0.56), false)
	_box(traffic_car, "TrafficHeadlightRight", Vector3(0.12, 0.12, 0.3), Vector3(1.58, 0.62, 0.43), Color(0.98, 0.84, 0.56), false)
	_box(traffic_car, "TrafficTaillightLeft", Vector3(0.1, 0.13, 0.28), Vector3(-1.59, 0.62, -0.43), Color(0.72, 0.12, 0.1), false)
	_box(traffic_car, "TrafficTaillightRight", Vector3(0.1, 0.13, 0.28), Vector3(-1.59, 0.62, 0.43), Color(0.72, 0.12, 0.1), false)
	# A clearly marked pedestrian crossing and a small stop area make the street feel functional.
	for stripe_x in [-3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0]:
		_box(self, "CrosswalkStripe_" + str(stripe_x), Vector3(0.58, 0.025, 1.15), Vector3(stripe_x, 0.012, 19.05), Color(0.86, 0.85, 0.78), false)
	_box(self, "BusStopPole", Vector3(0.09, 2.15, 0.09), Vector3(8.25, 1.05, 22.2), Color(0.23, 0.27, 0.28), false)
	_box(self, "BusStopSign", Vector3(0.48, 0.62, 0.08), Vector3(8.25, 2.15, 22.2), Color(0.18, 0.43, 0.52), false)
	_box(self, "BusStopSymbol", Vector3(0.2, 0.3, 0.025), Vector3(8.25, 2.15, 22.145), Color(0.9, 0.88, 0.78), false)
	_box(self, "StreetBenchSeat", Vector3(1.55, 0.12, 0.42), Vector3(7.55, 0.48, 22.6), Color(0.39, 0.27, 0.18), false)
	_box(self, "StreetBenchBack", Vector3(1.55, 0.62, 0.1), Vector3(7.55, 0.81, 22.78), Color(0.39, 0.27, 0.18), false)

func _update_moving_traffic(delta: float) -> void:
	if not is_instance_valid(traffic_car):
		return
	var crossing_occupied := false
	for resident in npc_residents:
		if not bool(resident.get("crossing", false)):
			continue
		var pedestrian: CharacterBody3D = resident["node"]
		if absf(pedestrian.global_position.x - traffic_car.global_position.x) < 3.2 and absf(pedestrian.global_position.z - traffic_car.global_position.z) < 2.2:
			crossing_occupied = true
			break
	if crossing_occupied:
		return
	traffic_car.position.x += traffic_direction * 1.8 * delta
	if traffic_car.position.x >= 5.6:
		traffic_car.position.x = 5.6
		traffic_direction = -1.0
		traffic_car.rotation.y = PI / 2.0
	elif traffic_car.position.x <= -5.8:
		traffic_car.position.x = -5.8
		traffic_direction = 1.0
		traffic_car.rotation.y = -PI / 2.0

func _build_second_pedestrian() -> void:
	# A second resident walks a longer route along the pavement, away from the first resident's courtyard loop.
	var npc := CharacterBody3D.new()
	npc.name = "StreetPedestrian"
	npc.position = Vector3(-10.4, 0.12, 20.7)
	add_child(npc)
	var body_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.26
	capsule.height = 1.62
	body_shape.shape = capsule
	body_shape.position.y = 0.81
	npc.add_child(body_shape)
	var visual := Node3D.new()
	visual.name = "PedestrianVisual"
	npc.add_child(visual)
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.23
	torso_mesh.height = 0.74
	var torso := MeshInstance3D.new()
	torso.name = "Torso"
	torso.mesh = torso_mesh
	torso.position.y = 1.0
	torso.material_override = _material(Color(0.2, 0.43, 0.56))
	visual.add_child(torso)
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.18
	head_mesh.height = 0.36
	var head := MeshInstance3D.new()
	head.name = "Head"
	head.mesh = head_mesh
	head.position.y = 1.6
	head.material_override = _material(Color(0.72, 0.52, 0.38))
	visual.add_child(head)
	var leg_mesh := CapsuleMesh.new()
	leg_mesh.radius = 0.085
	leg_mesh.height = 0.54
	for leg_x in [-0.11, 0.11]:
		var leg := MeshInstance3D.new()
		leg.name = "Leg_" + str(leg_x)
		leg.mesh = leg_mesh
		leg.position = Vector3(leg_x, 0.36, 0)
		leg.material_override = _material(Color(0.12, 0.15, 0.18))
		visual.add_child(leg)
	npc_residents.append({
		"node": npc,
		"visual": visual,
		"points": [Vector3(-10.4, 0.12, 20.7), Vector3(-10.4, 0.12, 21.6)],
		"target": 1,
		"speed": 0.85,
		"phase": 1.4
	})

func _build_crosswalk_pedestrian() -> void:
	# A resident crosses the marked road; traffic yields while the crossing is occupied.
	var npc := CharacterBody3D.new()
	npc.name = "CrosswalkPedestrian"
	npc.position = Vector3(3.5, 0.12, 18.35)
	add_child(npc)
	var body_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.6
	body_shape.shape = capsule
	body_shape.position.y = 0.8
	npc.add_child(body_shape)
	var visual := Node3D.new()
	visual.name = "CrosswalkPedestrianVisual"
	npc.add_child(visual)
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.22
	torso_mesh.height = 0.72
	var torso := MeshInstance3D.new()
	torso.name = "Torso"
	torso.mesh = torso_mesh
	torso.position.y = 0.98
	torso.material_override = _material(Color(0.65, 0.48, 0.18))
	visual.add_child(torso)
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.18
	head_mesh.height = 0.36
	var head := MeshInstance3D.new()
	head.name = "Head"
	head.mesh = head_mesh
	head.position.y = 1.58
	head.material_override = _material(Color(0.72, 0.51, 0.37))
	visual.add_child(head)
	var leg_mesh := CapsuleMesh.new()
	leg_mesh.radius = 0.085
	leg_mesh.height = 0.54
	for leg_x in [-0.11, 0.11]:
		var leg := MeshInstance3D.new()
		leg.name = "Leg_" + str(leg_x)
		leg.mesh = leg_mesh
		leg.position = Vector3(leg_x, 0.35, 0)
		leg.material_override = _material(Color(0.16, 0.18, 0.2))
		visual.add_child(leg)
	npc_residents.append({
		"node": npc,
		"visual": visual,
		"points": [Vector3(3.5, 0.12, 18.35), Vector3(3.5, 0.12, 23.0)],
		"target": 1,
		"speed": 0.72,
		"phase": 2.2,
		"crossing": true
	})

func _build_npc_residents() -> void:
	# First resident: a simple pedestrian who walks between two safe points in the courtyard.
	var npc := CharacterBody3D.new()
	npc.name = "CourtyardResident"
	npc.position = Vector3(-3.2, 0.12, 13.4)
	add_child(npc)
	var body_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.65
	body_shape.shape = capsule
	body_shape.position.y = 0.82
	npc.add_child(body_shape)
	var resident_visual := Node3D.new()
	resident_visual.name = "ResidentVisual"
	npc.add_child(resident_visual)
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.25
	torso_mesh.height = 0.78
	var torso := MeshInstance3D.new()
	torso.name = "Torso"
	torso.mesh = torso_mesh
	torso.position.y = 1.02
	torso.material_override = _material(Color(0.58, 0.31, 0.23))
	resident_visual.add_child(torso)
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.19
	head_mesh.height = 0.38
	var head := MeshInstance3D.new()
	head.name = "Head"
	head.mesh = head_mesh
	head.position.y = 1.62
	head.material_override = _material(Color(0.73, 0.54, 0.39))
	resident_visual.add_child(head)
	var leg_mesh := CapsuleMesh.new()
	leg_mesh.radius = 0.09
	leg_mesh.height = 0.56
	for leg_x in [-0.12, 0.12]:
		var leg := MeshInstance3D.new()
		leg.name = "Leg_" + str(leg_x)
		leg.mesh = leg_mesh
		leg.position = Vector3(leg_x, 0.38, 0)
		leg.material_override = _material(Color(0.16, 0.19, 0.22))
		resident_visual.add_child(leg)
	npc_residents.append({
		"node": npc,
		"visual": resident_visual,
		"points": [Vector3(-3.2, 0.12, 13.4), Vector3(3.2, 0.12, 14.2)],
		"target": 1,
		"speed": 1.15,
		"phase": 0.0
	})

func _update_npc_residents(delta: float) -> void:
	for resident in npc_residents:
		var npc: CharacterBody3D = resident["node"]
		var points: Array = resident["points"]
		var target_index: int = resident["target"]
		var target_point: Vector3 = points[target_index]
		var to_target := target_point - npc.global_position
		to_target.y = 0.0
		var player_nearby := is_instance_valid(player) and npc.global_position.distance_to(player.global_position) < 1.9
		var car_nearby := is_instance_valid(traffic_car) and not bool(resident.get("crossing", false)) and npc.global_position.distance_to(traffic_car.global_position) < 5.2
		if player_nearby:
			var toward_player := player.global_position - npc.global_position
			toward_player.y = 0.0
			if toward_player.length() > 0.05:
				npc.rotation.y = atan2(-toward_player.x, -toward_player.z)
			npc.velocity.x = 0.0
			npc.velocity.z = 0.0
			if is_instance_valid(npc_status_label):
				npc_status_label.text = "ЖИТЕЛЬ  •  ПРИВЕТСТВУЕТ ИГРОКА"
		elif car_nearby:
			var toward_car := traffic_car.global_position - npc.global_position
			toward_car.y = 0.0
			if toward_car.length() > 0.05:
				npc.rotation.y = atan2(-toward_car.x, -toward_car.z)
			if is_instance_valid(npc_status_label):
				npc_status_label.text = "ПЕШЕХОД  •  ВНИМАНИЕ, МАШИНА"
		else:
			if is_instance_valid(npc_status_label):
				npc_status_label.text = "ЖИТЕЛИ  •  ПРОГУЛКА ПО РАЙОНУ"
		if to_target.length() < 0.3 and not player_nearby:
			target_index = 0 if target_index == 1 else 1
			resident["target"] = target_index
			to_target = points[target_index] - npc.global_position
			to_target.y = 0.0
		if player_nearby or car_nearby:
			npc.velocity.x = 0.0
			npc.velocity.z = 0.0
		elif to_target.length() > 0.05:
			var direction := to_target.normalized()
			npc.velocity.x = direction.x * float(resident["speed"])
			npc.velocity.z = direction.z * float(resident["speed"])
			npc.rotation.y = atan2(-direction.x, -direction.z)
		else:
			npc.velocity.x = 0.0
			npc.velocity.z = 0.0
		if not npc.is_on_floor():
			npc.velocity.y -= 18.0 * delta
		else:
			npc.velocity.y = -0.1
		npc.move_and_slide()
		resident["phase"] = float(resident["phase"]) + delta * 5.0
		var visual: Node3D = resident["visual"]
		visual.position.y = absf(sin(float(resident["phase"]))) * 0.025

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 0.12, 3.5)
	add_child(player)
	avatar_root = Node3D.new()
	avatar_root.name = "Avatar"
	avatar_root.position.y = 0.12
	player.add_child(avatar_root)
	var shirt := _material(Color(0.18, 0.38, 0.56))
	var pants := _material(Color(0.12, 0.15, 0.19))
	var skin := _material(Color(0.78, 0.59, 0.43))
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.29
	torso_mesh.height = 0.82
	var torso := MeshInstance3D.new()
	torso.name = "Torso"
	torso.mesh = torso_mesh
	torso.position.y = 1.05
	torso.material_override = shirt
	avatar_root.add_child(torso)
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	var head := MeshInstance3D.new()
	head.name = "Head"
	head.mesh = head_mesh
	head.position.y = 1.66
	head.material_override = skin
	avatar_root.add_child(head)
	var leg_mesh := CapsuleMesh.new()
	leg_mesh.radius = 0.115
	leg_mesh.height = 0.62
	left_leg = MeshInstance3D.new()
	left_leg.name = "LeftLeg"
	left_leg.mesh = leg_mesh
	left_leg.position = Vector3(-0.14, 0.43, 0)
	left_leg.material_override = pants
	avatar_root.add_child(left_leg)
	right_leg = MeshInstance3D.new()
	right_leg.name = "RightLeg"
	right_leg.mesh = leg_mesh
	right_leg.position = Vector3(0.14, 0.43, 0)
	right_leg.material_override = pants
	avatar_root.add_child(right_leg)
	var arm_mesh := CapsuleMesh.new()
	arm_mesh.radius = 0.09
	arm_mesh.height = 0.62
	left_arm = MeshInstance3D.new()
	left_arm.name = "LeftArm"
	left_arm.mesh = arm_mesh
	left_arm.position = Vector3(-0.39, 1.06, 0)
	left_arm.material_override = shirt
	avatar_root.add_child(left_arm)
	right_arm = MeshInstance3D.new()
	right_arm.name = "RightArm"
	right_arm.mesh = arm_mesh
	right_arm.position = Vector3(0.39, 1.06, 0)
	right_arm.material_override = shirt
	avatar_root.add_child(right_arm)
	var shape := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.34
	capsule_shape.height = 1.75
	shape.shape = capsule_shape
	shape.position.y = 0.88
	player.add_child(shape)
	camera_pivot = Node3D.new()
	camera_pivot.position.y = 1.55
	player.add_child(camera_pivot)
	camera = Camera3D.new()
	camera_pivot.add_child(camera)
	camera.current = true
	_set_camera_mode()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MobileUI"
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.025, 0.04, 0.055, 0.72)
	panel.position = Vector2(20, 18)
	panel.size = Vector2(390, 100)
	layer.add_child(panel)
	var title := Label.new()
	title.text = "URBAN ROOTS  /  PROTOTYPE 0.1"
	title.position = Vector2(36, 25)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.93, 0.9, 0.82))
	layer.add_child(title)
	status_label = Label.new()
	status_label.text = "Квартира 01  •  Исследуй пространство"
	status_label.position = Vector2(36, 54)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.84))
	layer.add_child(status_label)
	apartment_zone_label = Label.new()
	apartment_zone_label.name = "ZoneLabel"
	apartment_zone_label.text = "ДОМ 01  •  КВАРТИРА"
	apartment_zone_label.anchor_left = 0.5
	apartment_zone_label.anchor_right = 0.5
	apartment_zone_label.position = Vector2(-150, 18)
	apartment_zone_label.size = Vector2(300, 28)
	apartment_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	apartment_zone_label.add_theme_font_size_override("font_size", 16)
	apartment_zone_label.add_theme_color_override("font_color", Color(0.93, 0.82, 0.58))
	layer.add_child(apartment_zone_label)
	npc_status_label = Label.new()
	npc_status_label.name = "ResidentStatus"
	npc_status_label.text = "ЖИТЕЛЬ ДВОРА  •  ПРОГУЛКА"
	npc_status_label.position = Vector2(36, 99)
	npc_status_label.add_theme_font_size_override("font_size", 14)
	npc_status_label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.65))
	layer.add_child(npc_status_label)
	stamina_label = Label.new()
	stamina_label.name = "StaminaStatus"
	stamina_label.text = "ЭНЕРГИЯ  •  100%"
	stamina_label.position = Vector2(36, 77)
	stamina_label.add_theme_font_size_override("font_size", 15)
	stamina_label.add_theme_color_override("font_color", Color(0.65, 0.88, 0.66))
	layer.add_child(stamina_label)
	var motion_panel := ColorRect.new()
	motion_panel.name = "MovementStatusPanel"
	motion_panel.color = Color(0.025, 0.04, 0.055, 0.72)
	motion_panel.anchor_left = 1.0
	motion_panel.anchor_right = 1.0
	motion_panel.position = Vector2(-230, 18)
	motion_panel.size = Vector2(210, 58)
	layer.add_child(motion_panel)
	movement_label = Label.new()
	movement_label.name = "MovementStatus"
	movement_label.text = "ХОДЬБА  •  4.2"
	movement_label.anchor_left = 1.0
	movement_label.anchor_right = 1.0
	movement_label.position = Vector2(-220, 34)
	movement_label.size = Vector2(190, 28)
	movement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	movement_label.add_theme_font_size_override("font_size", 18)
	movement_label.add_theme_color_override("font_color", Color(0.72, 0.9, 0.82))
	layer.add_child(movement_label)
	var joystick := Control.new()
	joystick.name = "MovementJoystick"
	joystick.set_script(load("res://scripts/joystick.gd"))
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.position = Vector2(34, -194)
	joystick.size = Vector2(174, 174)
	layer.add_child(joystick)
	joystick.value_changed.connect(_on_joystick_value_changed)
	var cam_btn := Button.new()
	cam_btn.text = "КАМЕРА"
	cam_btn.position = Vector2(-190, -100)
	cam_btn.size = Vector2(160, 58)
	cam_btn.anchor_left = 1.0
	cam_btn.anchor_right = 1.0
	cam_btn.anchor_top = 1.0
	cam_btn.anchor_bottom = 1.0
	cam_btn.add_theme_font_size_override("font_size", 18)
	cam_btn.pressed.connect(_toggle_camera)
	layer.add_child(cam_btn)
	var run_btn := Button.new()
	run_btn.text = "БЕГ"
	run_btn.position = Vector2(-365, -100)
	run_btn.size = Vector2(145, 58)
	run_btn.anchor_left = 1.0
	run_btn.anchor_right = 1.0
	run_btn.anchor_top = 1.0
	run_btn.anchor_bottom = 1.0
	run_btn.add_theme_font_size_override("font_size", 20)
	run_btn.button_down.connect(func(): sprinting = true)
	run_btn.button_up.connect(func(): sprinting = false)
	layer.add_child(run_btn)
	interact_button = Button.new()
	interact_button.name = "InteractButton"
	interact_button.text = "ДЕЙСТВИЕ"
	interact_button.position = Vector2(-535, -100)
	interact_button.size = Vector2(155, 58)
	interact_button.anchor_left = 1.0
	interact_button.anchor_right = 1.0
	interact_button.anchor_top = 1.0
	interact_button.anchor_bottom = 1.0
	interact_button.disabled = true
	interact_button.add_theme_font_size_override("font_size", 17)
	interact_button.pressed.connect(_interact_with_target)
	layer.add_child(interact_button)
	interaction_hint = Label.new()
	interaction_hint.name = "InteractionHint"
	interaction_hint.text = "Подойди к выключателю или телевизору"
	interaction_hint.anchor_left = 0.5
	interaction_hint.anchor_right = 0.5
	interaction_hint.anchor_top = 1.0
	interaction_hint.anchor_bottom = 1.0
	interaction_hint.position = Vector2(-230, -62)
	interaction_hint.size = Vector2(460, 24)
	interaction_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_hint.add_theme_font_size_override("font_size", 16)
	interaction_hint.add_theme_color_override("font_color", Color(0.96, 0.86, 0.62))
	layer.add_child(interaction_hint)
	var help := Label.new()
	help.text = "Джойстик — движение • БЕГ — ускорение • свайп справа — обзор"
	help.anchor_left = 0.5
	help.anchor_right = 0.5
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.position = Vector2(-270, -32)
	help.size = Vector2(540, 24)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 14)
	layer.add_child(help)

func _on_joystick_value_changed(value: Vector2) -> void:
	joystick_vector = value

func _update_interaction_target() -> void:
	interaction_target = ""
	var is_outside := player.global_position.z > 6.2
	if is_instance_valid(apartment_zone_label):
		apartment_zone_label.text = "ДВОР  •  УЛИЦА" if is_outside else "ДОМ 01  •  КВАРТИРА"
	var distances := {
		"light": player.global_position.distance_to(Vector3(1.2, 1.25, 5.7)),
		"tv": player.global_position.distance_to(Vector3(0.1, 1.12, -3.65)),
		"bed": player.global_position.distance_to(Vector3(-3.4, 0.7, -3.1)),
		"sofa": player.global_position.distance_to(Vector3(2.8, 0.7, 1.5)),
		"fridge": player.global_position.distance_to(Vector3(-5.0, 1.0, 3.6)),
		"door": player.global_position.distance_to(Vector3(0.0, 1.25, 5.65))
	}
	var nearest_distance := 2.25
	for target in distances:
		if distances[target] <= nearest_distance:
			nearest_distance = distances[target]
			interaction_target = target
	if is_instance_valid(interact_button):
		interact_button.disabled = interaction_target == ""
	if is_instance_valid(interaction_hint):
		match interaction_target:
			"light":
				interaction_hint.text = "Нажми «ДЕЙСТВИЕ»: " + ("выключить свет" if light_is_on else "включить свет")
			"tv":
				interaction_hint.text = "Нажми «ДЕЙСТВИЕ»: " + ("выключить телевизор" if tv_is_on else "включить телевизор")
			"bed":
				interaction_hint.text = "Нажми «ДЕЙСТВИЕ»: восстановить энергию на кровати"
			"sofa":
				interaction_hint.text = "Нажми «ДЕЙСТВИЕ»: отдохнуть на диване"
			"fridge":
				interaction_hint.text = "Нажми «ДЕЙСТВИЕ»: " + ("закрыть холодильник" if fridge_is_open else "открыть холодильник")
			"door":
				interaction_hint.text = "Нажми «ДЕЙСТВИЕ»: " + ("закрыть входную дверь" if door_is_open else "открыть дверь и выйти во двор")
			_:
				interaction_hint.text = "Подойди к выключателю или телевизору"

func _interact_with_target() -> void:
	match interaction_target:
		"light":
			light_is_on = not light_is_on
			if is_instance_valid(ceiling_glow):
				ceiling_glow.visible = light_is_on
			if is_instance_valid(ceiling_fixture):
				ceiling_fixture.material_override = _material(Color(0.94, 0.84, 0.64) if light_is_on else Color(0.25, 0.26, 0.27))
			if is_instance_valid(switch_visual):
				switch_visual.material_override = _material(Color(0.35, 0.37, 0.34) if light_is_on else Color(0.85, 0.62, 0.3))
			if is_instance_valid(status_label):
				status_label.text = "Свет включён" if light_is_on else "Свет выключен"
		"tv":
			tv_is_on = not tv_is_on
			if is_instance_valid(tv_screen):
				var screen_material := _material(Color(0.12, 0.55, 0.72) if tv_is_on else Color(0.045, 0.075, 0.09), 0.35)
				if tv_is_on:
					screen_material.emission_enabled = true
					screen_material.emission = Color(0.08, 0.32, 0.48)
					screen_material.emission_energy_multiplier = 0.8
				tv_screen.material_override = screen_material
			if is_instance_valid(status_label):
				status_label.text = "Телевизор включён" if tv_is_on else "Телевизор выключен"
		"bed", "sofa":
			stamina = 100.0
			if is_instance_valid(status_label):
				status_label.text = "Ты отдохнул. Энергия восстановлена"
		"fridge":
			fridge_is_open = not fridge_is_open
			if is_instance_valid(fridge_visual):
				fridge_visual.material_override = _material(Color(0.42, 0.49, 0.52) if fridge_is_open else Color(0.72, 0.75, 0.76))
			if is_instance_valid(status_label):
				status_label.text = "Холодильник открыт" if fridge_is_open else "Холодильник закрыт"
		"door":
			door_is_open = not door_is_open
			if is_instance_valid(door_pivot):
				door_pivot.rotation.y = -1.35 if door_is_open else 0.0
			if is_instance_valid(status_label):
				status_label.text = "Дверь открыта — выходи во двор" if door_is_open else "Входная дверь закрыта"
	_update_interaction_target()

func _toggle_camera() -> void:
	first_person = not first_person
	_set_camera_mode()
	if status_label:
		status_label.text = "Камера: от первого лица" if first_person else "Камера: от третьего лица"

func _set_camera_mode() -> void:
	if not is_instance_valid(camera):
		return
	if first_person:
		camera.position = Vector3(0, 0.12, 0.04)
		camera.fov = 78.0
	else:
		camera.position = Vector3(0, 1.15, 4.6)
		camera.fov = 68.0
	camera.rotation = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V:
			_toggle_camera()
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if event.position.x > get_viewport().get_visible_rect().size.x * 0.42:
			yaw -= event.relative.x * LOOK_SENSITIVITY
			pitch = clampf(pitch - event.relative.y * LOOK_SENSITIVITY, -1.1, 0.65)
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x > get_viewport().get_visible_rect().size.x * 0.42:
				look_finger = event.index
				look_last = event.position
		elif event.index == look_finger:
			look_finger = -1
	if event is InputEventScreenDrag and event.index == look_finger:
		var delta: Vector2 = event.position - look_last
		look_last = event.position
		yaw -= delta.x * LOOK_SENSITIVITY
		pitch = clampf(pitch - delta.y * LOOK_SENSITIVITY, -1.1, 0.65)

func _physics_process(_delta: float) -> void:
	_update_npc_residents(_delta)
	_update_moving_traffic(_delta)
	if not is_instance_valid(player):
		return
	var input_dir := Vector2(
		float(Input.is_action_pressed("move_right")) - float(Input.is_action_pressed("move_left")),
		float(Input.is_action_pressed("move_back")) - float(Input.is_action_pressed("move_forward"))
	)
	if joystick_vector.length() > 0.05:
		input_dir = joystick_vector
	var direction := Vector3.ZERO
	if input_dir.length() > 0.05:
		input_dir = input_dir.normalized()
		var basis := Basis(Vector3.UP, yaw)
		direction = basis * Vector3(input_dir.x, 0, input_dir.y)
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-direction.x, -direction.z), 0.2)
	if sprinting and input_dir.length() > 0.05 and stamina > 0.0:
		stamina = maxf(0.0, stamina - _delta * 22.0)
	else:
		stamina = minf(100.0, stamina + _delta * 12.0)
	if stamina <= 0.0:
		sprinting = false
	var current_speed := RUN_SPEED if sprinting else WALK_SPEED
	if is_instance_valid(stamina_label):
		stamina_label.text = "ЭНЕРГИЯ  •  %d%%" % int(round(stamina))
		stamina_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.42) if stamina < 25.0 else Color(0.65, 0.88, 0.66))
	if is_instance_valid(movement_label):
		movement_label.text = "БЕГ  •  6.6" if sprinting else "ХОДЬБА  •  4.2"
		movement_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.38) if sprinting else Color(0.72, 0.9, 0.82))
	player.velocity.x = direction.x * current_speed
	player.velocity.z = direction.z * current_speed
	if not player.is_on_floor():
		player.velocity.y -= 18.0 * _delta
	else:
		player.velocity.y = -0.1
	player.move_and_slide()
	_update_interaction_target()
	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	if horizontal_speed > 0.12:
		walk_phase += _delta * horizontal_speed * 2.4
	else:
		walk_phase = lerpf(walk_phase, 0.0, minf(1.0, _delta * 8.0))
	var swing := sin(walk_phase) * minf(0.65, horizontal_speed / RUN_SPEED * 0.65)
	if is_instance_valid(left_leg):
		left_leg.rotation.x = swing
		right_leg.rotation.x = -swing
		left_arm.rotation.x = -swing * 0.7
		right_arm.rotation.x = swing * 0.7
		avatar_root.position.y = 0.12 + (absf(sin(walk_phase * 2.0)) * 0.035 if horizontal_speed > 0.12 else 0.0)
	camera_pivot.rotation.y = yaw
	camera_pivot.rotation.x = pitch
