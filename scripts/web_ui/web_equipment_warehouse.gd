class_name WebEquipmentWarehouse
extends Control

var host
var chosen_uid: String = ""
var slot_filter: String = ""
var listing: VBoxContainer
var details: WebEquipmentDetail
var hint: Label
var slot_row: HBoxContainer

func bind_host(owner) -> void:
    host = owner

func _run():
    return host.region_run_ui.run if host != null and host.region_run_ui != null else null

func _gate():
    return host.web_ui_shell.selection if host != null and host.web_ui_shell != null else null

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var body = VBoxContainer.new()
    body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    body.add_theme_constant_override("separation",7)
    add_child(body)
    slot_row = HBoxContainer.new()
    slot_row.add_theme_constant_override("separation",5)
    body.add_child(slot_row)
    var box = HBoxContainer.new()
    box.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_theme_constant_override("separation",8)
    body.add_child(box)
    var scroll = ScrollContainer.new()
    scroll.name = "InventoryScroll"
    scroll.custom_minimum_size.x = 300
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    box.add_child(scroll)
    listing = VBoxContainer.new()
    listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    listing.add_theme_constant_override("separation",5)
    scroll.add_child(listing)
    var info = ScrollContainer.new()
    info.name = "EquipmentDetailScroll"
    info.custom_minimum_size.x = 370
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    box.add_child(info)
    details = WebEquipmentDetail.new()
    details.name = "EquipmentDetail"
    info.add_child(details)
    hint = Label.new()
    hint.text = "1回タップ：4カードを確認。もう一度同じ装備をタップ：装備確定。"
    hint.add_theme_font_size_override("font_size",13)
    body.add_child(hint)

func refresh() -> void:
    if _run() == null or not is_inside_tree():
        return
    var state: Dictionary = _run().state
    if str(state.phase) != "hub":
        return
    for child in slot_row.get_children():
        slot_row.remove_child(child)
        child.queue_free()
    var slots: Array = [""]
    slots.append_array(HubDeckAnalyzer.SLOTS)
    for slot in slots:
        var button = Button.new()
        button.text = "すべて" if slot=="" else str({"main_weapon":"主武器","offhand":"副装備","head":"頭","body":"胴","hands":"手","feet":"足"}.get(slot,slot))
        button.custom_minimum_size = Vector2(89,43)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(_filter.bind(slot))
        slot_row.add_child(button)
    for child in listing.get_children():
        listing.remove_child(child)
        child.queue_free()
    var ids: Array = state.inventory.keys()
    ids.sort()
    if not state.inventory.has(chosen_uid):
        chosen_uid = ""
    for raw_uid in ids:
        var uid: String = str(raw_uid)
        var item: Dictionary = state.inventory[uid]
        if slot_filter != "" and str(item.get("slot","")) != slot_filter:
            continue
        var btn = Button.new()
        btn.name = "Inventory_"+uid
        btn.custom_minimum_size = Vector2(290,53)
        btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
        btn.text = "%s%s [%s]  HP%d" % [
            "◆ " if state.loadout.values().has(uid) else "",
            HubInventoryQuery.item_name(item),str(item.get("rarity","")),
            int(item.get("effective_hp",item.get("base_hp",0)))]
        btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        btn.pressed.connect(_tap_item.bind(uid))
        listing.add_child(btn)
    if chosen_uid != "" and state.inventory.has(chosen_uid):
        _show_selected()
    else:
        details.display_item({})
    hint.text = "装備を1回タップしてカードを確認。もう一度同じ装備をタップして装備確定。"

func _filter(slot: String) -> void:
    slot_filter = slot
    if _gate() != null:
        _gate().cancel()
    refresh()

func _show_selected() -> void:
    var state: Dictionary = _run().state
    var item: Dictionary = state.inventory.get(chosen_uid,{})
    var report: Dictionary = HubEquipmentComparison.new().compare(_run().items_from_state(),item)
    var comparison: String = ""
    if bool(report.get("valid",false)):
        var before: Dictionary = report.before
        var after: Dictionary = report.after
        comparison = "装備変更後：最大HP %d → %d　24枚 %d → %d\n完成ペア %d → %d" % [
            int(before.hp),int(after.hp),int(before.card_count),int(after.card_count),
            int(before.completed_pairs.size()),int(after.completed_pairs.size())]
    details.display_item(item,comparison)

func _tap_item(uid: String) -> void:
    var controller = _run()
    if controller == null or _gate() == null:
        return
    if str(controller.state.phase) != "hub" or controller.save_blocked or not controller.state.forge_pending.is_empty():
        return
    if not controller.state.inventory.has(uid):
        return
    var item: Dictionary = controller.state.inventory[uid]
    var action: int = _gate().tap("equip/"+uid,{"uid":uid,"snapshot":JSON.stringify(item)})
    if action == WebSelectionGate.PREVIEW:
        chosen_uid = uid
        _show_selected()
        hint.text = "選択中：%s。付属4カードを確認して、同じ装備を再タップすると装備確定。" % HubInventoryQuery.item_name(item)
    elif action == WebSelectionGate.COMMIT:
        var check: bool = str(controller.state.phase)=="hub" and not controller.save_blocked and controller.state.forge_pending.is_empty() and controller.state.inventory.has(uid)
        check = check and JSON.stringify(controller.state.inventory.get(uid,{})) == str(_gate().selected_details.get("snapshot",""))
        var applied: bool = false
        if check and not controller.state.loadout.values().has(uid):
            applied = controller.equip(uid)
        _gate().acknowledge_commit()
        chosen_uid = uid
        refresh()
        hint.text = "装備変更を保存しました。" if applied else "変更なし、または装備変更できませんでした。"
