class_name WebForgeScreen
extends Control

# The existing Region1RunController.forge and resolve_forge own all state.
# Costs and item/card previews are read-only until an explicit second tap.
var host
var chosen_uid: String = ""
var inventory_list: VBoxContainer
var operation_list: VBoxContainer
var details: WebEquipmentDetail
var notice: Label
var dialog: ConfirmationDialog

func bind_host(owner) -> void:
    host = owner

func _run():
    return host.region_run_ui.run if host != null and host.region_run_ui != null else null

func _gate():
    return host.web_ui_shell.selection if host != null and host.web_ui_shell != null else null

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var root = VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation",5)
    add_child(root)
    var columns = HBoxContainer.new()
    columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
    columns.add_theme_constant_override("separation",7)
    root.add_child(columns)

    var left = ScrollContainer.new()
    left.custom_minimum_size.x = 215
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_child(left)
    inventory_list = VBoxContainer.new()
    inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    inventory_list.add_theme_constant_override("separation",5)
    left.add_child(inventory_list)

    var center = ScrollContainer.new()
    center.custom_minimum_size.x = 320
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_child(center)
    details = WebEquipmentDetail.new()
    center.add_child(details)

    var right = ScrollContainer.new()
    right.custom_minimum_size.x = 260
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_child(right)
    operation_list = VBoxContainer.new()
    operation_list.add_theme_constant_override("separation",5)
    operation_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right.add_child(operation_list)
    notice = Label.new()
    notice.name = "ForgeNotice"
    notice.add_theme_font_size_override("font_size",13)
    notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(notice)
    dialog = ConfirmationDialog.new()
    dialog.title = "装備分解の最終確認"
    dialog.ok_button_text = "分解する"
    add_child(dialog)

func _wipe(node: Node) -> void:
    for child in node.get_children():
        node.remove_child(child)
        child.queue_free()

func _add_button(parent: Node, title: String, callback: Callable, enabled: bool = true) -> Button:
    var b = Button.new()
    b.text = title
    b.custom_minimum_size.y = 45
    b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    b.disabled = not enabled
    b.pressed.connect(callback)
    parent.add_child(b)
    return b

func _label(parent: Node, contents: String, size: int = 13) -> Label:
    var l = Label.new()
    l.text = contents
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_font_size_override("font_size",size)
    parent.add_child(l)
    return l

func _allowed(action: String, slot: int = -1) -> String:
    var controller = _run()
    if controller == null or str(controller.state.phase)!="hub" or controller.save_blocked:
        return "拠点の保存可能な状態でのみ加工できます。"
    if not controller.state.forge_pending.is_empty():
        return "先に再抽選候補を確定してください。"
    if not controller.state.inventory.has(chosen_uid):
        return "装備を選択してください。"
    var item: Dictionary = controller.state.inventory[chosen_uid]
    var template: Dictionary = controller.roller.templates.get(str(item.get("equipment_id","")),{})
    var gold: int = 250
    if action == "dismantle":
        return "装備中は分解できません。" if controller.state.loadout.values().has(chosen_uid) else ""
    elif action == "enhance":
        if int(item.get("enhance_level",0)) >= int(template.get("EnhanceCap",0)):
            return "HP強化上限です。"
        gold = 100*(int(item.get("enhance_level",0))+1)
    elif action == "socket":
        if int(item.get("socket_count",0)) >= int(template.get("SocketCap",0)):
            return "Socket上限です。"
        gold = 250+int(item.get("socket_count",0))*150
    elif action == "reroll":
        var counters: Array = item.get("reroll_counts",[])
        if slot<0 or slot>=2 or counters.size()!=2 or int(counters[slot])>=3:
            return "カード再抽選上限です。"
    elif action == "special_reroll":
        var effects: Array = item.get("special_effects",[])
        if slot<0 or slot>=effects.size() or int(item.get("special_reroll_count",0))>=3:
            return "特殊効果枠または再抽選回数が上限です。"
        var options: Array[String] = EquipmentSpecialEffectPolicy.eligible_ids(item)
        for e in effects:
            if e is Dictionary:
                options.erase(str(e.get("effect_id","")))
        if options.size()<2:
            return "新候補が2種類ありません。"
    else:
        return "不明な操作です。"
    if int(controller.state.base_gold)<gold:
        return "Gold不足です。"
    if int(controller.state.materials)<1:
        return "素材不足です。"
    return ""

func refresh() -> void:
    if not is_inside_tree() or _run() == null:
        return
    var controller = _run()
    var state: Dictionary = controller.state
    _wipe(inventory_list)
    _wipe(operation_list)
    if not state.inventory.has(chosen_uid):
        chosen_uid = ""
    var pending: Dictionary = state.forge_pending
    if not pending.is_empty():
        chosen_uid = str(pending.get("uid",""))
    _label(inventory_list,"鍛冶屋｜装備一覧",16)
    var ids: Array = state.inventory.keys()
    ids.sort()
    for value in ids:
        var uid: String = str(value)
        var item: Dictionary = state.inventory[uid]
        _add_button(inventory_list,("%s◆ " if state.loadout.values().has(uid) else "")+HubInventoryQuery.item_name(item),_choose_item.bind(uid),pending.is_empty() or uid == chosen_uid)
    if chosen_uid != "" and state.inventory.has(chosen_uid):
        details.display_item(state.inventory[chosen_uid])
    else:
        details.display_item({})
    if not pending.is_empty():
        _pending_ui(pending)
        notice.text = "候補A・B・現状維持のどれかを確定するまで、鍛冶屋から移動できません。"
        return
    _label(operation_list,"加工内容（2回タップで実行）",15)
    if chosen_uid == "" or not state.inventory.has(chosen_uid):
        notice.text = "装備をタップして、カード4枚と特殊効果を確認してください。"
        return
    var item: Dictionary = state.inventory[chosen_uid]
    var template: Dictionary = controller.roller.templates.get(str(item.get("equipment_id","")),{})
    var lv: int = int(item.get("enhance_level",0))
    var count: int = int(item.get("socket_count",0))
    _operation("HP強化 Lv%d→%d / %dG・素材1" % [lv,lv+1,100*(lv+1)],"enhance",-1)
    _operation("Socket %d→%d / %dG・素材1" % [count,count+1,250+count*150],"socket",-1)
    for slot in range(2):
        _operation("ランダム枠%dを再抽選 / 250G・素材1" % [slot+1],"reroll",slot)
    for slot in range(item.get("special_effects",[]).size()):
        _operation("特殊効果枠%dを再抽選 / 250G・素材1" % [slot+1],"special_reroll",slot)
    _operation("装備分解 / 素材 +%d" % [Region1RunController.RARITIES.find(str(item.get("rarity","")))+1],"dismantle",-1)
    _label(operation_list,"Gold %dG　素材 %d\nHP強化上限 %d / Socket上限 %d" % [
        int(state.base_gold),int(state.materials),int(template.get("EnhanceCap",0)),int(template.get("SocketCap",0))],12)
    notice.text = "加工を1回タップ：消費内容を確認。もう一度同じ加工をタップ：実行。分解はさらに確認。"

func _choose_item(uid: String) -> void:
    if _run() == null or not _run().state.inventory.has(uid):
        return
    if not _run().state.forge_pending.is_empty():
        return
    chosen_uid = uid
    if _gate() != null:
        _gate().cancel()
    refresh()
    notice.text = "装備の詳細を表示しています。加工の実行は右側の操作を2回タップしてください。"

func _operation(title: String, action: String, slot: int) -> void:
    var reason: String = _allowed(action,slot)
    var btn = _add_button(operation_list,title,_tap_operation.bind(action,slot),reason=="")
    if reason!="":
        btn.tooltip_text = reason

func _tap_operation(action: String, slot: int) -> void:
    var controller = _run()
    if controller == null or _gate() == null or _allowed(action,slot)!="":
        return
    var uid: String = chosen_uid
    var snapshot: String = JSON.stringify(controller.state.inventory[uid])
    var key: String = "forge/%s/%s/%d" % [uid,action,slot]
    var result: int = _gate().tap(key,{"uid":uid,"action":action,"slot":slot,"snapshot":snapshot})
    if result == WebSelectionGate.PREVIEW:
        notice.text = "%s｜選択装備とGold・素材を確認後、同じ加工をもう一度タップしてください。" % action
    elif result == WebSelectionGate.COMMIT:
        if action == "dismantle":
            dialog.dialog_text = "この装備を分解すると元に戻せません。\n%s　素材を獲得します。実行しますか？" % HubInventoryQuery.item_name(controller.state.inventory[uid])
            var confirmed_action: Callable = _finish_operation.bind(uid,action,slot,snapshot)
            for conn in dialog.confirmed.get_connections():
                dialog.confirmed.disconnect(conn.callable)
            for conn in dialog.canceled.get_connections():
                dialog.canceled.disconnect(conn.callable)
            dialog.confirmed.connect(confirmed_action,CONNECT_ONE_SHOT)
            dialog.canceled.connect(_cancel_pending_dialog,CONNECT_ONE_SHOT)
            dialog.popup_centered(Vector2i(570,250))
        else:
            _finish_operation(uid,action,slot,snapshot)

func _cancel_pending_dialog() -> void:
    if _gate() != null:
        _gate().acknowledge_commit()
    refresh()

func _finish_operation(uid: String, action: String, slot: int, snapshot: String) -> void:
    var controller = _run()
    var valid: bool = controller != null and chosen_uid==uid and controller.state.inventory.has(uid)
    if valid:
        valid = JSON.stringify(controller.state.inventory[uid]) == snapshot and _allowed(action,slot) == ""
    var ok: bool = valid and controller.forge(uid,action,slot)
    if _gate() != null:
        _gate().acknowledge_commit()
    refresh()
    notice.text = "加工を保存しました。" if ok else "条件が変化したため、加工は実行されませんでした。"

func _pending_ui(pending: Dictionary) -> void:
    _label(operation_list,"再抽選の候補選択",16)
    _label(operation_list,"支払済みのGold・素材・回数は現状維持でも戻りません。",12)
    var item: Dictionary = _run().state.inventory.get(chosen_uid,{})
    var is_special: bool = str(pending.get("kind","card")) == "special_effect"
    if is_special:
        var index: int = int(pending.get("effect_index",0))
        var effects: Array = item.get("special_effects",[])
        if index >= 0 and index<effects.size():
            var old_id: String = str(effects[index].get("effect_id",""))
            _label(operation_list,"現在：%s" % str(EquipmentSpecialEffectPolicy.NAMES.get(old_id,old_id)),12)
    else:
        var index: int = int(pending.get("slot",0))
        var cards: Array = item.get("random_cards",[])
        if index>=0 and index<cards.size():
            _label(operation_list,"現在：%s" % str(cards[index]),12)
    for i in range(pending.get("choices",[]).size()):
        var id: String = str(pending.choices[i])
        var title: String = str(EquipmentSpecialEffectPolicy.NAMES.get(id,id)) if is_special else id
        _add_button(operation_list,"候補%s：%s" % ["A" if i==0 else "B",title],_tap_resolve.bind(i))
    _add_button(operation_list,"現状維持（費用返却なし）",_tap_resolve.bind(-1))

func _tap_resolve(index: int) -> void:
    var controller = _run()
    if controller == null or _gate() == null or controller.state.forge_pending.is_empty():
        return
    var pending: Dictionary = controller.state.forge_pending
    var signature: String = JSON.stringify(pending)
    var key: String = "forge/resolve/%s/%d" % [signature,index]
    var result: int = _gate().tap(key,{"snapshot":signature,"index":index})
    if result == WebSelectionGate.PREVIEW:
        if index < 0:
            notice.text = "現状維持を選択中。もう一度タップで確定（費用は戻りません）。"
        elif str(pending.get("kind","card"))=="special_effect":
            var effect_id: String = str(pending.choices[index])
            notice.text = str(EquipmentSpecialEffectPolicy.NAMES.get(effect_id,effect_id))+"\n"+str(EquipmentSpecialEffectPolicy.DETAILS.get(effect_id,""))+"\n再タップで確定。"
        else:
            notice.text = "候補カード：\n"+details.analyzer.card_description(str(pending.choices[index]))+"\n再タップで確定。"
    elif result == WebSelectionGate.COMMIT:
        var ok: bool = signature == JSON.stringify(controller.state.forge_pending) and controller.resolve_forge(index)
        _gate().acknowledge_commit()
        refresh()
        notice.text = "候補が確定しました。" if ok else "候補を確定できませんでした。"
