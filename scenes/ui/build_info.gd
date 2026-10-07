extends CanvasLayer
## Always-visible release identity, sourced from the project's application metadata.
var version_label: Label
func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 layer = 100
 version_label = Label.new()
 version_label.name = "VersionLabel"
 version_label.text = "v%s  •  build %s" % [ProjectSettings.get_setting("application/config/version", "dev"), ProjectSettings.get_setting("application/config/build", 0)]
 version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
 version_label.add_theme_font_size_override("font_size", 14)
 version_label.add_theme_color_override("font_color", Color.WHITE)
 version_label.add_theme_color_override("font_shadow_color", Color.BLACK)
 version_label.add_theme_constant_override("shadow_offset_x", 1)
 version_label.add_theme_constant_override("shadow_offset_y", 1)
 add_child(version_label)
 version_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
 version_label.offset_left = -250
 version_label.offset_right = -14
 version_label.offset_top = -28
 version_label.offset_bottom = -8
 DisplayServer.window_set_title("Apple Legends " + version_label.text)
 print("APPLE_LEGENDS_BUILD: ", version_label.text)
