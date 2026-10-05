extends Control
## Tiny original porcelain robot portrait, drawn sharply at any UI scale.
var accent := Color("25b9cf")
func _ready() -> void:
	custom_minimum_size = Vector2(42, 42)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color.WHITE
	shell.set_corner_radius_all(13)
	shell.border_color = Color("d7e4e8")
	shell.set_border_width_all(1)
	draw_style_box(shell, Rect2(2, 2, 38, 38))
	var visor := StyleBoxFlat.new()
	visor.bg_color = Color("203c46")
	visor.set_corner_radius_all(8)
	draw_style_box(visor, Rect2(7, 11, 28, 17))
	draw_circle(Vector2(15, 19), 3, accent)
	draw_circle(Vector2(27, 19), 3, accent)
