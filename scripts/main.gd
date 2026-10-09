extends Node3D

const WALK_SPEED := 4.2
const LOOK_SENSITIVITY := 0.006
const ROOM_SIZE := Vector3(12.0, 3.2, 12.0)
const JOYSTICK_RADIUS := 72.0

var player: CharacterBody3D
var camera_pivot: Node3D
var camera: Camera3D
var first_person := false
var pitch := -0.12
var yaw := 0.0
var joystick_vector := Vector2.ZERO
var joystick_center := Vector2.ZERO
var joystick_knob := Vector2.ZERO
var joystick_touch_index := -1
var look_finger := -1
var look_last := Vector2.ZERO
var status_label: Label

func _ready() -> void:
	_build_environment()
	_build_room()
	_build_player()
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
	_box(self, "Door", Vector3(1.7, 2.5, 0.08), Vector3(0, 1.25, 5.88), Color(0.34, 0.22, 0.14), false)
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
	_box(self, "KitchenCounter", Vector3(2.8, 0.9, 0.75), Vector3(-3.9, 0.45, 2.5), Color(0.5, 0.5, 0.46))
	_box(self, "Fridge", Vector3(0.85, 2.0, 0.8), Vector3(-5.0, 1.0, 3.6), Color(0.72, 0.75, 0.76))
	_box(self, "LampStem", Vector3(0.08, 1.1, 0.08), Vector3(4.5, 1.05, 0.1), trim_mat)
	_box(self, "LampShade", Vector3(0.55, 0.18, 0.55), Vector3(4.5, 1.65, 0.1), Color(0.9, 0.75, 0.48), false)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 0.12, 3.5)
	add_child(player)
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.34
	capsule.height = 1.75
	var avatar := MeshInstance3D.new()
	avatar.name = "Avatar"
	avatar.mesh = capsule
	avatar.position.y = 0.88
	avatar.material_override = _material(Color(0.18, 0.38, 0.56))
	player.add_child(avatar)
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
	panel.size = Vector2(390, 72)
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
	var joystick := Control.new()
	joystick.name = "MovementJoystick"
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.position = Vector2(34, -194)
	joystick.size = Vector2(174, 174)
	joystick.mouse_filter = Control.MOUSE_FILTER_STOP
	joystick.draw.connect(_draw_joystick.bind(joystick))
	joystick.gui_input.connect(_on_joystick_input)
	layer.add_child(joystick)
	joystick_center = joystick.size / 2.0
	joystick_knob = joystick_center
	joystick.queue_redraw()
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
	var help := Label.new()
	help.text = "Левый джойстик — ходьба • свайп справа — обзор"
	help.anchor_left = 0.5
	help.anchor_right = 0.5
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.position = Vector2(-270, -32)
	help.size = Vector2(540, 24)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 14)
	layer.add_child(help)

func _draw_joystick(control: Control) -> void:
	var center := control.size / 2.0
	control.draw_circle(center, JOYSTICK_RADIUS, Color(0.04, 0.06, 0.08, 0.48))
	control.draw_arc(center, JOYSTICK_RADIUS, 0.0, TAU, 64, Color(0.78, 0.84, 0.85, 0.8), 3.0, true)
	control.draw_circle(joystick_knob, 31.0, Color(0.55, 0.72, 0.76, 0.9))
	control.draw_arc(joystick_knob, 31.0, 0.0, TAU, 48, Color(0.94, 0.96, 0.92, 0.95), 2.0, true)

func _on_joystick_input(event: InputEvent) -> void:
	var control := get_node("MobileUI/MovementJoystick") as Control
	if event is InputEventScreenTouch:
		if event.pressed and joystick_touch_index == -1:
			joystick_touch_index = event.index
			_update_joystick(event.position - control.global_position, control)
		elif not event.pressed and event.index == joystick_touch_index:
			joystick_touch_index = -1
			joystick_vector = Vector2.ZERO
			joystick_knob = joystick_center
			control.queue_redraw()
	elif event is InputEventScreenDrag and event.index == joystick_touch_index:
		_update_joystick(event.position - control.global_position, control)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			joystick_touch_index = -2
			_update_joystick(event.position, control)
		else:
			joystick_touch_index = -1
			joystick_vector = Vector2.ZERO
			joystick_knob = joystick_center
			control.queue_redraw()
	elif event is InputEventMouseMotion and joystick_touch_index == -2 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_joystick(event.position, control)

func _update_joystick(local_position: Vector2, control: Control) -> void:
	var offset := local_position - joystick_center
	if offset.length() > JOYSTICK_RADIUS:
		offset = offset.normalized() * JOYSTICK_RADIUS
	joystick_knob = joystick_center + offset
	joystick_vector = Vector2(offset.x / JOYSTICK_RADIUS, offset.y / JOYSTICK_RADIUS)
	if joystick_vector.length() < 0.12:
		joystick_vector = Vector2.ZERO
	control.queue_redraw()

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
	player.velocity.x = direction.x * WALK_SPEED
	player.velocity.z = direction.z * WALK_SPEED
	if not player.is_on_floor():
		player.velocity.y -= 18.0 * _delta
	else:
		player.velocity.y = -0.1
	player.move_and_slide()
	camera_pivot.rotation.y = yaw
	camera_pivot.rotation.x = pitch
