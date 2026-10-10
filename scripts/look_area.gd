extends Control

signal look_delta(delta: Vector2)

var active_touch := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1:
			active_touch = event.index
			accept_event()
		elif not event.pressed and event.index == active_touch:
			active_touch = -1
			accept_event()
	elif event is InputEventScreenDrag and event.index == active_touch:
		look_delta.emit(event.relative)
		accept_event()
