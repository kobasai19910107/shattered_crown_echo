class_name WebHubHome
extends Control

# Web-only presentation. No campaign mutation in this screen.
var host
var title_label: Label
var status_label: Label
var notice_label: Label
var actions: GridContainer
var claim_button: Button

func bind_host(owner) -> void:
    host = owner

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build()

func _build() -> void:
    # Landscape Safari's toolbars and safe area can leave substantially less
    # vertical space than desktop Chromium. Do not EXPAND grid rows: at a
    # short viewport that makes the 2nd row and footer unreachable.
    var scroll = ScrollContainer.new()
    scroll.name = "HubScroller"
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    scroll.follow_focus = true
    add_child(scroll)

    var layout = VBoxContainer.new()
    layout.name = "HubContent"
    layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    layout.add_theme_constant_override("separation",6)
    scroll.add_child(layout)

    title_label = Label.new()
    title_label.text = "拠点 — SHATTERED CROWN ECHO"
    title_label.add_theme_font_size_override("font_size",19)
    title_label.add_theme_color_override("font_color",Color("f6e8ca"))
    layout.add_child(title_label)

    status_label = Label.new()
    status_label.add_theme_font_size_override("font_size",16)
    status_label.add_theme_color_override("font_color",Color("d4e4f5"))
    layout.add_child(status_label)

    notice_label = Label.new()
    notice_label.add_theme_font_size_override("font_size",12)
    notice_label.add_theme_color_override("font_color",Color("f2d89c"))
    notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    notice_label.visible = false
    layout.add_child(notice_label)

    actions = GridContainer.new()
    actions.name = "HubFacilityGrid"
    actions.columns = 2
    actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    actions.size_flags_vertical = Control.SIZE_FILL
    actions.add_theme_constant_override("h_separation",8)
    actions.add_theme_constant_override("v_separation",8)
    layout.add_child(actions)

    _destination("装備・倉庫", "装備6部位・24枚デッキ", "equipment")
    _destination("鍛冶屋", "強化・ソケット・再抽選", "forge")
    _destination("商人", "商品の比較・購入・売却", "merchant")
    _destination("ソロ出発", "Region / Boss / Seedを選択", "solo")

    var footer = HBoxContainer.new()
    footer.name = "HubFooter"
    footer.add_theme_constant_override("separation",8)
    layout.add_child(footer)
    claim_button = Button.new()
    claim_button.text = "初期装備の受取・設定（従来画面）"
    claim_button.custom_minimum_size = Vector2(225,44)
    claim_button.pressed.connect(_open_legacy_home)
    footer.add_child(claim_button)
    var title_button = Button.new()
    title_button.text = "タイトル画面"
    title_button.custom_minimum_size = Vector2(142,44)
    title_button.pressed.connect(_open_title)
    footer.add_child(title_button)

func _destination(title_value: String, subtitle: String, route: String) -> void:
    var button = Button.new()
    button.name = "Hub_"+route
    button.text = title_value + "\n" + subtitle
    button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    button.add_theme_font_size_override("font_size",16)
    button.add_theme_color_override("font_color",Color("f0e7d9"))
    button.add_theme_color_override("font_hover_color",Color("ffffff"))
    button.add_theme_color_override("font_pressed_color",Color("ffffff"))
    button.custom_minimum_size = Vector2(215,76)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.size_flags_vertical = Control.SIZE_FILL
    var normal = StyleBoxFlat.new()
    normal.bg_color = Color("263449")
    normal.border_color = Color("52657d")
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(8)
    button.add_theme_stylebox_override("normal",normal)
    var hover = normal.duplicate()
    hover.bg_color = Color("334762")
    button.add_theme_stylebox_override("hover",hover)
    var pressed = normal.duplicate()
    pressed.bg_color = Color("4c617e")
    button.add_theme_stylebox_override("pressed",pressed)
    button.pressed.connect(_open_route.bind(route))
    actions.add_child(button)

func refresh() -> void:
    if not is_inside_tree() or host == null or host.region_run_ui == null:
        return
    var run = host.region_run_ui.run
    var state: Dictionary = run.state
    if str(state.phase) != "hub":
        notice_label.text = "冒険中です。元の画面から進行を再開してください。"
        return
    var region: int = int(state.get("active_region",0))
    var count: int = int(state.region_progress[region])
    status_label.text = "Region %d — Boss %d/4　拠点 %dG　素材 %d" % [
        region+1,count,int(state.base_gold),int(state.materials)]
    var pending: bool = not state.forge_pending.is_empty()
    notice_label.text = "鍛冶屋の選択を完了してください。" if pending else str(run.notice)
    notice_label.visible = pending or not notice_label.text.strip_edges().is_empty()
    claim_button.visible = not bool(state.get("initial_claimed",false))
    for child in actions.get_children():
        if child is Button:
            child.disabled = pending and child.name != "Hub_forge"

func _open_route(route: String) -> void:
    if host == null or host.web_ui_shell == null:
        return
    var run = host.region_run_ui.run
    if str(run.state.phase) != "hub":
        return
    if not run.state.forge_pending.is_empty() and route != "forge":
        return
    if route == "solo":
        if host.web_ui_shell.activate("solo") and host.web_solo_screen != null:
            host.web_solo_screen.refresh()
    elif route in ["equipment","forge","merchant"]:
        var screen = {
            "equipment":host.web_equipment_screen,
            "forge":host.web_forge_screen,
            "merchant":host.web_merchant_screen
        }.get(route,null)
        if screen != null and host.web_ui_shell.activate(route):
            screen.refresh()
    else:
        host._open_legacy_hub_page(route)

func _open_legacy_home() -> void:
    if host != null:
        host._open_legacy_hub_page("home")

func _open_title() -> void:
    if host != null:
        host._show_title_screen()
