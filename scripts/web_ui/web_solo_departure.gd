class_name WebSoloDeparture
extends Control

# One-tap preview/two-tap confirmation for region, stage and departure.
# Region and stage previews only mutate local view state. The saved Region
# changes only after the final departure confirmation.
var host
var chosen_region: int = -1
var chosen_stage: int = 0
var seed_value: int = 20261008
var root_layout: VBoxContainer
var detail_label: Label
var status_label: Label
var launch_button: Button
var region_row: HBoxContainer
var stage_row: HBoxContainer
var equipment_box: VBoxContainer
var seed_spin: SpinBox

func bind_host(owner) -> void:
    host = owner

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_layout = VBoxContainer.new()
    root_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_layout.add_theme_constant_override("separation",7)
    add_child(root_layout)
    _build()

func _run():
    return host.region_run_ui.run if host != null and host.region_run_ui != null else null

func _gate():
    return host.web_ui_shell.selection if host != null and host.web_ui_shell != null else null

func _current_region() -> int:
    if chosen_region >= 0:
        return chosen_region
    var controller = _run()
    return int(controller.state.get("active_region",0)) if controller != null else 0

func _stage_limit(region: int) -> int:
    return mini(4,int(_run().state.region_progress[region])+1)

func _valid_region(region: int) -> bool:
    var controller = _run()
    if controller == null or region < 0 or region > 5:
        return false
    if region == 0:
        return true
    return int(controller.state.region_progress[region-1]) == 4

func _valid_stage(region: int, stage: int) -> bool:
    return stage >= 1 and stage <= _stage_limit(region)

func _resolved_stage() -> int:
    var region: int = _current_region()
    return chosen_stage if _valid_stage(region,chosen_stage) else _stage_limit(region)

func _clear() -> void:
    for node in root_layout.get_children():
        root_layout.remove_child(node)
        node.queue_free()

func _add_label(parent: Node, value: String, font_size: int = 15) -> Label:
    var label = Label.new()
    label.text = value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size",font_size)
    parent.add_child(label)
    return label

func _build() -> void:
    if root_layout == null or host == null or _run() == null:
        return
    _clear()
    var region: int = _current_region()
    var stage: int = _resolved_stage()
    var controller = _run()
    var title = _add_label(root_layout,"ソロ冒険の準備 — 装備確定後はラン中変更不可",20)
    title.custom_minimum_size.y = 30

    region_row = HBoxContainer.new()
    region_row.add_theme_constant_override("separation",5)
    root_layout.add_child(region_row)
    for i in range(6):
        var button = Button.new()
        button.name = "Region_%d" % i
        button.text = "R%d\n%d/4" % [i+1,int(controller.state.region_progress[i])]
        button.custom_minimum_size = Vector2(94,56)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.disabled = not _valid_region(i)
        button.add_theme_font_size_override("font_size",14)
        button.pressed.connect(_tap_region.bind(i))
        if region == i:
            _highlight(button)
        region_row.add_child(button)

    stage_row = HBoxContainer.new()
    stage_row.add_theme_constant_override("separation",7)
    root_layout.add_child(stage_row)
    for i in range(1,5):
        var stage_button = Button.new()
        stage_button.name = "Stage_%d" % i
        var cleared: int = int(controller.state.region_progress[region])
        stage_button.text = "B%02d%s" % [i,"　再挑戦" if i<=cleared else "　次の目標" if i==cleared+1 else "　未解放"]
        stage_button.custom_minimum_size = Vector2(145,56)
        stage_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        stage_button.disabled = not _valid_stage(region,i)
        if stage == i:
            _highlight(stage_button)
        stage_button.pressed.connect(_tap_stage.bind(i))
        stage_row.add_child(stage_button)

    var columns = HBoxContainer.new()
    columns.add_theme_constant_override("separation",12)
    root_layout.add_child(columns)
    equipment_box = VBoxContainer.new()
    equipment_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_child(equipment_box)
    _add_label(equipment_box,"出発時の装備6部位",16)
    var items: Dictionary = controller.items_from_state()
    var combined: Array[String] = []
    for slot in HubDeckAnalyzer.SLOTS:
        var item: Dictionary = items.get(slot,{})
        var slot_name: String = str(HubEquipmentPanel.SLOT_NAMES.get(slot,slot))
        combined.append("%s：%s" % [slot_name,HubInventoryQuery.item_name(item) if not item.is_empty() else "未装備"])
    _add_label(equipment_box,"　".join(combined),12)

    var right = VBoxContainer.new()
    right.custom_minimum_size.x = 215
    columns.add_child(right)
    var analysis: Dictionary = HubDeckAnalyzer.new().analyze(items)
    _add_label(right,"デッキ：%d/24枚\n最大HP：%d\nラン開始Gold：100G" % [int(analysis.card_count),int(analysis.hp)],14)
    _add_label(right,"Seed",14)
    seed_spin = SpinBox.new()
    seed_spin.min_value = 1
    seed_spin.max_value = 999999999
    seed_spin.step = 1
    seed_spin.value = seed_value
    seed_spin.custom_minimum_size.y = 38
    seed_spin.value_changed.connect(_seed_changed)
    right.add_child(seed_spin)

    detail_label = _add_label(root_layout,"1回目：候補の詳細、2回目：その候補を決定。出発も同様です。",13)
    detail_label.custom_minimum_size.y = 28
    var footer = HBoxContainer.new()
    footer.add_theme_constant_override("separation",10)
    root_layout.add_child(footer)
    launch_button = Button.new()
    launch_button.name = "StartSoloRun"
    launch_button.text = "▶ R%d - B%02d へ出発（2回タップで確定）" % [region+1,stage]
    launch_button.custom_minimum_size = Vector2(350,52)
    launch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    launch_button.pressed.connect(_tap_depart)
    footer.add_child(launch_button)
    var back = Button.new()
    back.text = "拠点へ戻る"
    back.custom_minimum_size = Vector2(150,52)
    back.pressed.connect(_back_to_hub)
    footer.add_child(back)
    status_label = _add_label(root_layout,"",12)
    _update_departure_availability()

func _highlight(button: Button) -> void:
    var style = StyleBoxFlat.new()
    style.bg_color = Color("374561")
    style.border_color = Color("e2c07b")
    style.set_border_width_all(2)
    style.set_corner_radius_all(7)
    button.add_theme_stylebox_override("normal",style)

func _update_departure_availability() -> void:
    if host == null or _run() == null:
        return
    var controller = _run()
    var analysis: Dictionary = HubDeckAnalyzer.new().analyze(controller.items_from_state())
    var ready: bool = (str(controller.state.phase) == "hub"
        and not controller.save_blocked
        and controller.state.forge_pending.is_empty()
        and controller.state.loadout.size() == 6
        and bool(analysis.get("complete",false))
        and _valid_region(_current_region()) and _valid_stage(_current_region(),_resolved_stage()))
    launch_button.disabled = not ready
    if not ready:
        status_label.text = "出発できません。装備6部位・24枚デッキ・鍛冶屋の未確定選択を確認してください。"
    else:
        status_label.text = "確認のみではGold・装備・セーブデータは変更されません。"

func refresh() -> void:
    if host == null or _run() == null:
        return
    if chosen_region >= 0 and not _valid_region(chosen_region):
        chosen_region = -1
        chosen_stage = 0
    _build()

func _tap_region(region: int) -> void:
    if not _valid_region(region) or _gate() == null:
        return
    var result: int = _gate().tap("solo/region/%d" % region,{"region":region})
    if result == WebSelectionGate.PREVIEW:
        detail_label.text = "Region %d — Boss %d/4。もう一度タップすると地域選択を確定します。" % [
            region+1,int(_run().state.region_progress[region])]
    elif result == WebSelectionGate.COMMIT:
        chosen_region = region
        chosen_stage = 0
        _gate().acknowledge_commit()
        _build()

func _tap_stage(stage: int) -> void:
    var region: int = _current_region()
    if not _valid_stage(region,stage) or _gate() == null:
        return
    var result: int = _gate().tap("solo/stage/%d/%d" % [region,stage],{"stage":stage})
    if result == WebSelectionGate.PREVIEW:
        detail_label.text = "R%d / B%02d — %s。もう一度タップで選択確定。" % [
            region+1,stage,"クリア済・再挑戦" if stage <= int(_run().state.region_progress[region]) else "次の攻略目標"]
    elif result == WebSelectionGate.COMMIT:
        chosen_stage = stage
        _gate().acknowledge_commit()
        _build()

func _seed_changed(value: float) -> void:
    seed_value = int(value)
    if _gate() != null:
        _gate().cancel()
    if detail_label != null:
        detail_label.text = "Seedを変更しました。出発の確認は最初からやり直してください。"

func _tap_depart() -> void:
    _update_departure_availability()
    if launch_button.disabled or _gate() == null:
        return
    var region: int = _current_region()
    var stage: int = _resolved_stage()
    var key: String = "solo/depart/%d/%d/%d" % [region,stage,seed_value]
    var result: int = _gate().tap(key,{"region":region,"stage":stage,"seed":seed_value})
    if result == WebSelectionGate.PREVIEW:
        detail_label.text = "最終確認：R%d / B%02d、Seed %d、装備6部位・24枚、Run Gold 100G。もう一度「出発」で開始。" % [region+1,stage,seed_value]
        launch_button.text = "確定して出発（もう一度タップ）"
    elif result == WebSelectionGate.COMMIT:
        var controller = _run()
        var old_region: int = int(controller.state.active_region)
        var selected: bool = true
        if old_region != region:
            selected = controller.select_region(region)
        var started: bool = selected and controller.begin(seed_value,stage)
        _gate().acknowledge_commit()
        if started:
            host.region_run_ui.solo_selected_stage = 0
            host.region_run_ui.render()
            host.tab_container.current_tab = host.region_run_ui.get_index()
            host.web_ui_shell.close_shell()
        else:
            status_label.text = "ラン開始に失敗しました。現在の選択は保持されます。"
            launch_button.text = "▶ R%d - B%02d へ出発（2回タップで確定）" % [region+1,stage]

func _back_to_hub() -> void:
    if host != null:
        host._activate_web_hub()
