class_name WebHubMerchant
extends Control

# Read-only previews, checked double-tap purchase, and separately confirmed sale.
# State changes go only through Region1RunController merchant APIs.
var host
var sell_mode: bool = false
var selected_key: String = ""
var stock_list: VBoxContainer
var details: WebEquipmentDetail
var notice: Label
var tabs: HBoxContainer
var sale_dialog: ConfirmationDialog

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
    root.add_theme_constant_override("separation",6)
    add_child(root)
    tabs = HBoxContainer.new()
    tabs.add_theme_constant_override("separation",9)
    root.add_child(tabs)
    _button(tabs,"購入",_switch_mode.bind(false))
    _button(tabs,"売却",_switch_mode.bind(true))
    var columns = HBoxContainer.new()
    columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
    columns.add_theme_constant_override("separation",9)
    root.add_child(columns)
    var scroll = ScrollContainer.new()
    scroll.name = "MerchantList"
    scroll.custom_minimum_size.x = 310
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_child(scroll)
    stock_list = VBoxContainer.new()
    stock_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stock_list.add_theme_constant_override("separation",6)
    scroll.add_child(stock_list)
    var detail_scroll = ScrollContainer.new()
    detail_scroll.name = "MerchantEquipmentDetail"
    detail_scroll.custom_minimum_size.x = 370
    detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_child(detail_scroll)
    details = WebEquipmentDetail.new()
    detail_scroll.add_child(details)
    notice = Label.new()
    notice.name = "MerchantNotice"
    notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    notice.add_theme_font_size_override("font_size",13)
    root.add_child(notice)
    sale_dialog = ConfirmationDialog.new()
    sale_dialog.title = "装備売却の最終確認"
    sale_dialog.ok_button_text = "売却する"
    add_child(sale_dialog)
    sale_dialog.popup_hide.connect(_on_sale_dialog_hidden)


func _button(parent: Node, label: String, callback: Callable, enabled: bool = true) -> Button:
    var btn = Button.new()
    btn.text = label
    btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    btn.custom_minimum_size.y = 49
    btn.disabled = not enabled
    btn.pressed.connect(callback)
    parent.add_child(btn)
    return btn

func _label(parent: Node, message: String, point: int = 14) -> Label:
    var result = Label.new()
    result.text = message
    result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    result.add_theme_font_size_override("font_size",point)
    parent.add_child(result)
    return result

func _clear(parent: Node) -> void:
    for child in parent.get_children():
        parent.remove_child(child)
        child.queue_free()

func refresh() -> void:
    if not is_inside_tree() or _run() == null:
        return
    var controller = _run()
    if str(controller.state.phase) != "hub":
        return
    # Stock initialization is a documented *first visit* operation, separate
    # from a purchase preview. Subsequent previews never write the save.
    if not controller.ensure_hub_shop():
        notice.text = "商人在庫の読み込みに失敗しました。"
        return
    _clear(stock_list)
    _label(stock_list,"拠点商人　Gold %dG" % int(controller.state.base_gold),17)
    if not sell_mode:
        var stock: Array = controller.state.get("hub_stock",[])
        for i in range(stock.size()):
            var item: Dictionary = stock[i]
            var enabled: bool = not item.is_empty() and controller.hub_buy_price(item)>0 and int(controller.state.base_gold)>=controller.hub_buy_price(item)
            _button(stock_list,"商品%d　%s　%dG" % [
                i+1,"売り切れ" if item.is_empty() else HubInventoryQuery.item_name(item),
                controller.hub_buy_price(item)],_tap_buy.bind(i),enabled)
        _button(stock_list,"商品更新 100G（2回タップ）",_tap_refresh,int(controller.state.base_gold)>=100)
    else:
        var uids: Array = controller.state.inventory.keys()
        uids.sort()
        var count: int = 0
        for raw_uid in uids:
            var uid: String = str(raw_uid)
            if controller.state.loadout.values().has(uid):
                continue
            var item: Dictionary = controller.state.inventory[uid]
            count += 1
            _button(stock_list,"%s　+%dG" % [HubInventoryQuery.item_name(item),controller.hub_sell_price(item)],_tap_sell.bind(uid))
        if count == 0:
            _label(stock_list,"売却可能な装備がありません。",13)
    if selected_key.begins_with("buy/"):
        var index: int = int(selected_key.trim_prefix("buy/"))
        var stock: Array = controller.state.get("hub_stock",[])
        details.display_item(stock[index] if index>=0 and index<stock.size() else {})
    elif selected_key.begins_with("sell/"):
        var uid: String = selected_key.trim_prefix("sell/")
        details.display_item(controller.state.inventory.get(uid,{}))
    else:
        details.display_item({})
    notice.text = "1回目：付属4カードと特殊効果を確認。2回目：%s。" % ["売却確認へ" if sell_mode else "購入確定"]

func _switch_mode(selling: bool) -> void:
    sell_mode = selling
    selected_key = ""
    if _gate() != null:
        _gate().cancel()
    refresh()

func _tap_buy(index: int) -> void:
    var controller = _run()
    if controller == null or _gate() == null:
        return
    var stock: Array = controller.state.get("hub_stock",[])
    if index<0 or index>=stock.size() or stock[index].is_empty() or not controller.state.forge_pending.is_empty() or controller.save_blocked:
        return
    var item: Dictionary = stock[index]
    var uid: String = str(item.get("instance_id",""))
    var price: int = controller.hub_buy_price(item)
    if price<=0 or int(controller.state.base_gold)<price:
        return
    var snapshot: String = JSON.stringify(item)
    var result: int = _gate().tap("merchant/buy/"+uid,{"uid":uid,"index":index,"snapshot":snapshot,"price":price})
    if result == WebSelectionGate.PREVIEW:
        selected_key = "buy/"+str(index)
        details.display_item(item)
        notice.text = "商品を選択中：%dG。内容を確認し、同じ商品をもう一度タップすると購入します。" % price
    elif result == WebSelectionGate.COMMIT:
        var ready: bool = JSON.stringify(controller.state.get("hub_stock",[])[index])==snapshot and int(controller.state.base_gold)>=price
        var ok: bool = ready and controller.buy_hub_item(index,uid)
        _gate().acknowledge_commit()
        selected_key = ""
        refresh()
        notice.text = "倉庫に購入しました。" if ok else "購入できませんでした（商品・所持Goldの変更を確認してください）。"

func _tap_sell(uid: String) -> void:
    var controller = _run()
    if controller == null or _gate() == null or controller.save_blocked or not controller.state.forge_pending.is_empty():
        return
    if not controller.state.inventory.has(uid) or controller.state.loadout.values().has(uid):
        return
    var item: Dictionary = controller.state.inventory[uid]
    var snapshot: String = JSON.stringify(item)
    var price: int = controller.hub_sell_price(item)
    var result: int = _gate().tap("merchant/sell/"+uid,{"uid":uid,"snapshot":snapshot,"price":price})
    if result == WebSelectionGate.PREVIEW:
        selected_key = "sell/"+uid
        details.display_item(item)
        notice.text = "+%dGで売却します。詳細を確認し、同じ商品をもう一度タップしてください。" % price
    elif result == WebSelectionGate.COMMIT:
        sale_dialog.dialog_text = "元に戻せません。\n%sを%dGで売却しますか？" % [HubInventoryQuery.item_name(item),price]
        for conn in sale_dialog.confirmed.get_connections():
            sale_dialog.confirmed.disconnect(conn.callable)
        for conn in sale_dialog.canceled.get_connections():
            sale_dialog.canceled.disconnect(conn.callable)
        sale_dialog.confirmed.connect(_finalize_sale.bind(uid,snapshot,price),CONNECT_ONE_SHOT)
        sale_dialog.canceled.connect(_abort_sale,CONNECT_ONE_SHOT)
        sale_dialog.popup_centered(Vector2i(570,250))

func _on_sale_dialog_hidden() -> void:
    call_deferred("_release_hidden_sale_dialog")

func _release_hidden_sale_dialog() -> void:
    if _gate()!=null and _gate().commit_pending and _gate().selected_id.begins_with("merchant/sell/"):
        _abort_sale()

func _abort_sale() -> void:
    if _gate() != null:
        _gate().acknowledge_commit()
    refresh()
    notice.text = "売却はキャンセルされました。"

func _finalize_sale(uid: String, snapshot: String, price: int) -> void:
    var controller = _run()
    var valid: bool = controller != null and str(controller.state.phase)=="hub" and not controller.save_blocked and controller.state.forge_pending.is_empty()
    if valid:
        valid = controller.state.inventory.has(uid) and not controller.state.loadout.values().has(uid)
    if valid:
        valid = JSON.stringify(controller.state.inventory[uid])==snapshot and controller.hub_sell_price(controller.state.inventory[uid])==price
    var ok: bool = valid and controller.sell_hub_item(uid)
    if _gate()!=null:
        _gate().acknowledge_commit()
    selected_key = ""
    refresh()
    notice.text = "装備を売却しました。" if ok else "売却できませんでした。"

func _tap_refresh() -> void:
    var controller = _run()
    if controller == null or _gate()==null or controller.save_blocked or not controller.state.forge_pending.is_empty() or int(controller.state.base_gold)<100:
        return
    var revision: int = int(controller.state.get("hub_shop_revision",0))
    var result: int = _gate().tap("merchant/refresh/%d" % revision,{"revision":revision})
    if result == WebSelectionGate.PREVIEW:
        notice.text = "在庫3件を入れ替えて100G消費します。もう一度タップで実行。"
    elif result == WebSelectionGate.COMMIT:
        var ok: bool = revision==int(controller.state.get("hub_shop_revision",0)) and controller.refresh_hub_shop()
        _gate().acknowledge_commit()
        selected_key = ""
        refresh()
        notice.text = "商人在庫を更新しました。" if ok else "商品更新に失敗しました。"
