extends Control

signal value_changed(value: Vector2)

const RADIUS := 72.0
const DEADZONE := 0.12
var knob_position := Vector2.ZERO
var active_touch := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	knob_position = size / 2.0
	queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	draw_circle(center, RADIUS, Color(0.04, 0.06, 0.08, 0.48))
	draw_arc(center, RADIUS, 0.0, TAU, 64, Color(0.78, 0.84, 0.85, 0.8), 3.0, true)
	draw_circle(knob_position, 31.0, Color(0.55, 0.72, 0.76, 0.9))
	draw_arc(knob_position, 31.0, 0.0, TAU, 48, Color(0.94, 0.96, 0.92, 0.95), 2.0, true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1:
			active_touch = event.index
			_update_from_position(event.position)
		elif not event.pressed and event.index == active_touch:
			_reset_stick()
	elif event is InputEventScreenDrag and event.index == active_touch:
		_update_from_position(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			active_touch = -2
			_update_from_position(event.position)
		else:
			_reset_stick()
	elif event is InputEventMouseMotion and active_touch == -2 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_from_position(event.position)

func _update_from_position(position: Vector2) -> void:
	var offset := position - size / 2.0
	if offset.length() > RADIUS:
		offset = offset.normalized() * RADIUS
	knob_position = size / 2.0 + offset
	var value := Vector2(offset.x / RADIUS, offset.y / RADIUS)
	if value.length() < DEADZONE:
		value = Vector2.ZERO
	value_changed.emit(value)
	queue_redraw()

func _reset_stick() -> void:
	active_touch = -1
	knob_position = size / 2.0
	value_changed.emit(Vector2.ZERO)
	queue_redraw()
