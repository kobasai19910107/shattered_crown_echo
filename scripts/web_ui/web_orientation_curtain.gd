class_name WebOrientationCurtain
extends ColorRect

# Always-on Web portrait guidance, including the legacy title and old UI.
# The WebUIShell alone cannot cover title/game dialogs outside itself.
func _ready() -> void:
    name = "WebPortraitOrientationCurtain"
    color = Color("0c1424")
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var center := CenterContainer.new()
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    var column := VBoxContainer.new()
    column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation",20)
    center.add_child(column)
    var emblem := Label.new()
    emblem.text = "↻"
    emblem.add_theme_font_size_override("font_size",54)
    emblem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(emblem)
    var message := Label.new()
    message.text = "画面を横向きにしてプレイしてください"
    message.add_theme_font_size_override("font_size",21)
    message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(message)
    get_viewport().size_changed.connect(refresh_orientation)
    refresh_orientation()

func refresh_orientation() -> void:
    var v: Vector2 = get_viewport().get_visible_rect().size
    visible = v.y > v.x
