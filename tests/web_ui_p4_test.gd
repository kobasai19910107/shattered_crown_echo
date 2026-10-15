extends SceneTree

# P4 integration: run only in a disposable Godot user:// environment.
const Shell = preload("res://scripts/web_ui/web_ui_shell.gd")
const Home = preload("res://scripts/web_ui/web_hub_home.gd")
const Warehouse = preload("res://scripts/web_ui/web_equipment_warehouse.gd")
const Forge = preload("res://scripts/web_ui/web_forge_screen.gd")
const Merchant = preload("res://scripts/web_ui/web_hub_merchant.gd")
var count: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
    count += 1
    if not ok:
        failures.append(label)
        printerr("WEB_UI_P4 FAIL: "+label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if OS.get_environment("SCE_WEB_UI_ISOLATED_TEST")!="1":
        quit(2)
        return
    root.size=Vector2i(960,540)
    var game=load("res://main.tscn").instantiate()
    root.add_child(game)
    for i in range(5):
        await process_frame
    game._hide_title_screen()
    var ui: Region1RunUI=game.region_run_ui
    ui.run.save_path="user://web_p4_disposable_fixture.json"
    var helper=load("res://tests/hub_inventory_analysis_test.gd").new()
    check(ui.run.adopt_initial(helper.make_items(ui.run.roller,517901)), "isolated six equipment fixture")
    helper.free()
    var next: Dictionary=ui.run.state.duplicate(true)
    next.base_gold=10000
    next.materials=100
    var old_uid: String=str(next.loadout.main_weapon)
    var alternate: Dictionary=next.inventory[old_uid].duplicate(true)
    var alternate_uid: String="P4_ALTERNATIVE_MAIN_WEAPON"
    alternate.instance_id=alternate_uid
    next.inventory[alternate_uid]=alternate
    check(ui.run._commit(next), "isolated extra unequipped item and resources")
    ui.render()
    game.tab_container.current_tab=ui.get_index()

    var shell=Shell.new()
    root.add_child(shell)
    await process_frame
    var home=Home.new()
    var warehouse=Warehouse.new()
    var forge=Forge.new()
    var merchant=Merchant.new()
    for page in [home,warehouse,forge,merchant]:
        page.bind_host(game)
    check(shell.register_screen("hub",home),"hub route")
    check(shell.register_screen("equipment",warehouse),"equipment route")
    check(shell.register_screen("forge",forge),"forge route")
    check(shell.register_screen("merchant",merchant),"merchant route")
    game.web_ui_shell=shell
    game.web_hub_screen=home
    game.web_equipment_screen=warehouse
    game.web_forge_screen=forge
    game.web_merchant_screen=merchant
    shell.navigation_allowed=func() -> bool: return ui.run.state.forge_pending.is_empty()

    check(shell.activate("hub"),"hub starts")
    home._open_route("equipment")
    check(shell.router.current_route=="equipment","one tap opens warehouse")
    warehouse.refresh()
    var inventory_before: String=JSON.stringify(ui.run.state)
    var save_before: String=FileAccess.get_file_as_string(ui.run.save_path)
    warehouse._tap_item(alternate_uid)
    check(warehouse.chosen_uid==alternate_uid,"one tap selects candidate")
    check(warehouse.details.current_cards.size()==4,"four item cards visible")
    check(warehouse.details.effects.text.contains("装備特殊効果"),"special effects described")
    warehouse.details.view_card(2)
    check(warehouse.details.formal.text!="" and warehouse.details.viewed_index==2,"formal card text visible without equipping")
    check(JSON.stringify(ui.run.state)==inventory_before,"inventory preview is read-only")
    check(FileAccess.get_file_as_string(ui.run.save_path)==save_before,"preview never writes save")
    warehouse._tap_item(alternate_uid)
    check(str(ui.run.state.loadout.main_weapon)==alternate_uid,"second tap equips chosen instance")
    check(int(ui.run.state.base_gold)==10000,"equipment exchange does not spend Gold")
    check(shell.selection.selected_id=="","confirmed equip releases selection")

    check(shell.activate("forge"),"open Web forge")
    forge.refresh()
    forge._choose_item(old_uid)
    var before_forge: String=JSON.stringify(ui.run.state)
    var before_gold: int=int(ui.run.state.base_gold)
    var before_mat: int=int(ui.run.state.materials)
    forge._tap_operation("enhance",-1)
    check(before_forge==JSON.stringify(ui.run.state),"first forge tap previews without payment")
    forge._tap_operation("enhance",-1)
    check(int(ui.run.state.base_gold)==before_gold-100,"second forge tap pays correct Gold")
    check(int(ui.run.state.materials)==before_mat-1,"enhance consumes exactly one material")
    check(int(ui.run.state.inventory[old_uid].enhance_level)==1,"existing forge controller enhanced item")
    check(shell.selection.selected_id=="","forge transaction unlocks gate")

    if forge._allowed("reroll",0)=="":
        forge._tap_operation("reroll",0)
        check(ui.run.state.forge_pending.is_empty(),"reroll first tap previews only")
        forge._tap_operation("reroll",0)
        check(not ui.run.state.forge_pending.is_empty(),"second reroll tap generates saved candidates")
        check(not shell.go_back(),"pending forge candidates block navigation")
        var snapshot: String=JSON.stringify(ui.run.state)
        var pending_save: String=FileAccess.get_file_as_string(ui.run.save_path)
        forge._tap_resolve(-1)
        check(JSON.stringify(ui.run.state)==snapshot and FileAccess.get_file_as_string(ui.run.save_path)==pending_save,"previewing keep-current is read-only")
        forge._tap_resolve(-1)
        check(ui.run.state.forge_pending.is_empty(),"second keep-current tap resolves pending state")
        check(shell.selection.selected_id=="","reroll gate unlocked")
    else:
        check(false,"random card reroll eligible on test item")

    check(shell.activate("merchant"),"merchant route")
    merchant.refresh()
    check(ui.run.state.hub_stock.size()==3,"merchant first visit initializes three stock items")
    var shop_saved: String=FileAccess.get_file_as_string(ui.run.save_path)
    var shop_gold: int=int(ui.run.state.base_gold)
    var item: Dictionary=ui.run.state.hub_stock[0].duplicate(true)
    var stock_price: int=ui.run.hub_buy_price(item)
    merchant._tap_buy(0)
    check(shop_saved==FileAccess.get_file_as_string(ui.run.save_path),"buy preview leaves save bytes intact")
    check(int(ui.run.state.base_gold)==shop_gold,"buy preview charges nothing")
    check(merchant.details.current_cards.size()==4,"merchant shows four card details")
    merchant._tap_buy(0)
    check(ui.run.state.hub_stock[0].is_empty(),"double tap consumes one stock entry")
    check(ui.run.state.inventory.has(str(item.instance_id)),"bought item added to warehouse")
    check(int(ui.run.state.base_gold)==shop_gold-stock_price,"buy charged exactly once")

    merchant._switch_mode(true)
    var sell_snapshot: String=JSON.stringify(ui.run.state.inventory[old_uid])
    var sale_before: String=JSON.stringify(ui.run.state)
    merchant._tap_sell(old_uid)
    check(sale_before==JSON.stringify(ui.run.state),"sell selection is read-only")
    merchant._tap_sell(old_uid)
    check(sale_before==JSON.stringify(ui.run.state),"second sale tap only opens destructive confirmation")
    check(shell.selection.commit_pending,"sale confirmation holds pending lock")
    var sale_price: int=ui.run.hub_sell_price(ui.run.state.inventory[old_uid])
    merchant._finalize_sale(old_uid,sell_snapshot,sale_price)
    check(not ui.run.state.inventory.has(old_uid),"explicit sale confirmation deletes exactly chosen item")
    check(not shell.selection.commit_pending,"sale confirmation unlocks UI")

    merchant._switch_mode(false)
    var revision: int=int(ui.run.state.hub_shop_revision)
    var refresh_before: String=FileAccess.get_file_as_string(ui.run.save_path)
    merchant._tap_refresh()
    check(FileAccess.get_file_as_string(ui.run.save_path)==refresh_before,"first refresh tap previews without payment")
    merchant._tap_refresh()
    check(int(ui.run.state.hub_shop_revision)==revision+1,"second refresh tap changes stock exactly once")
    check(shell.selection.selected_id=="","stock refresh clears selection")

    game.queue_free()
    shell.queue_free()
    await process_frame
    print("WEB_UI_P4 PASS=%d FAIL=%d" % [count-failures.size(),failures.size()])
    quit(0 if failures.is_empty() else 1)
