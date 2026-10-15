class_name WebUIShell
extends Control

const RouterScript = preload("res://scripts/web_ui/web_ui_router.gd")
const GateScript = preload("res://scripts/web_ui/web_selection_gate.gd")
signal screen_changed(route: String)

var router = RouterScript.new()
var selection = GateScript.new()
var screens: Dictionary = {}
var navigation_allowed: Callable
var page_host: Control
var route_label: Label
var rotation_hint: ColorRect

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build()
    router.route_changed.connect(_on_route_changed)
    get_viewport().size_changed.connect(_refresh_orientation)
    visible = false
    _refresh_orientation()

func _build() -> void:
    var backdrop = ColorRect.new()
    backdrop.color = Color("101723")
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)

    var safe = MarginContainer.new()
    safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right"]:
        safe.add_theme_constant_override("margin_" + side, 14)
    for side in ["top", "bottom"]:
        safe.add_theme_constant_override("margin_" + side, 9)
    add_child(safe)

    var column = VBoxContainer.new()
    column.add_theme_constant_override("separation", 7)
    safe.add_child(column)
    var top = HBoxContainer.new()
    top.custom_minimum_size.y = 46
    column.add_child(top)
    var back_button = Button.new()
    back_button.text = "戻る"
    back_button.custom_minimum_size = Vector2(80,44)
    back_button.pressed.connect(go_back)
    top.add_child(back_button)
    route_label = Label.new()
    route_label.text = "Web UI"
    route_label.add_theme_font_size_override("font_size", 19)
    route_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    route_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    top.add_child(route_label)
    page_host = Control.new()
    page_host.name = "WebPageHost"
    page_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(page_host)

    rotation_hint = ColorRect.new()
    rotation_hint.name = "LandscapeOnly"
    rotation_hint.color = Color("101723")
    rotation_hint.mouse_filter = Control.MOUSE_FILTER_STOP
    rotation_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(rotation_hint)
    var center = CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    rotation_hint.add_child(center)
    var message = Label.new()
    message.text = "横向きにしてプレイしてください"
    message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message.add_theme_font_size_override("font_size",22)
    center.add_child(message)

func register_screen(route: String, screen: Control) -> bool:
    if not router.supports(route) or screens.has(route) or screen == null:
        return false
    if screen.get_parent() != null:
        return false
    screen.name = "WebPage_" + route
    page_host.add_child(screen)
    screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    screen.visible = false
    screens[route] = screen
    return true

func activate(route: String) -> bool:
    if not screens.has(route) or selection.commit_pending:
        return false
    if router.current_route != route and not router.navigate(route):
        return false
    visible = true
    _show_current()
    _refresh_orientation()
    return true

func go_back() -> bool:
    if selection.commit_pending or router.history.is_empty():
        return false
    if navigation_allowed.is_valid() and not bool(navigation_allowed.call()):
        return false
    var previous = router.history.back()
    if not screens.has(previous):
        return false
    return router.back()

func close_shell() -> void:
    if selection.commit_pending:
        return
    selection.cancel()
    visible = false

func _on_route_changed(route: String) -> void:
    selection.cancel()
    _show_current()
    screen_changed.emit(route)

func _show_current() -> void:
    for key in screens:
        var page: Control = screens[key]
        page.visible = key == router.current_route
        if page.visible and page.has_method("refresh"):
            page.call_deferred("refresh")
    if route_label != null:
        route_label.text = {"hub":"拠点","equipment":"装備・倉庫","forge":"鍛冶屋","merchant":"商人",
            "solo":"ソロ出発","battle":"戦闘","route":"道の選択","reward":"報酬",
            "event":"イベント","rest":"休憩","victory":"勝利","defeat":"敗北"}.get(router.current_route,"Web UI")

func _refresh_orientation() -> void:
    if rotation_hint == null:
        return
    var viewport_size = get_viewport().get_visible_rect().size
    rotation_hint.visible = viewport_size.y > viewport_size.x
