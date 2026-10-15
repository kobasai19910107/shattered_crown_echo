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
    var layout = VBoxContainer.new()
    layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layout.add_theme_constant_override("separation",10)
    add_child(layout)

    title_label = Label.new()
    title_label.text = "拠点 — SHATTERED CROWN ECHO"
    title_label.add_theme_font_size_override("font_size",23)
    layout.add_child(title_label)

    status_label = Label.new()
    status_label.add_theme_font_size_override("font_size",17)
    layout.add_child(status_label)

    notice_label = Label.new()
    notice_label.add_theme_font_size_override("font_size",13)
    notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(notice_label)

    actions = GridContainer.new()
    actions.columns = 2
    actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    actions.size_flags_vertical = Control.SIZE_EXPAND_FILL
    actions.add_theme_constant_override("h_separation",12)
    actions.add_theme_constant_override("v_separation",12)
    layout.add_child(actions)

    _destination("装備・倉庫", "装備6部位・24枚デッキ", "equipment")
    _destination("鍛冶屋", "強化・ソケット・再抽選", "forge")
    _destination("商人", "商品の比較・購入・売却", "merchant")
    _destination("ソロ出発", "Region / Boss / Seedを選択", "solo")

    var footer = HBoxContainer.new()
    footer.add_theme_constant_override("separation",10)
    layout.add_child(footer)
    claim_button = Button.new()
    claim_button.text = "初期装備の受取・設定（従来画面）"
    claim_button.custom_minimum_size = Vector2(260,44)
    claim_button.pressed.connect(_open_legacy_home)
    footer.add_child(claim_button)
    var title_button = Button.new()
    title_button.text = "タイトル画面"
    title_button.custom_minimum_size = Vector2(170,44)
    title_button.pressed.connect(_open_title)
    footer.add_child(title_button)

func _destination(title_value: String, subtitle: String, route: String) -> void:
    var button = Button.new()
    button.name = "Hub_"+route
    button.text = title_value + "\n" + subtitle
    button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    button.add_theme_font_size_override("font_size",18)
    button.custom_minimum_size = Vector2(250,111)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
