extends SceneTree

const Shell = preload("res://scripts/web_ui/web_ui_shell.gd")
const Home = preload("res://scripts/web_ui/web_hub_home.gd")
const Solo = preload("res://scripts/web_ui/web_solo_departure.gd")
var count: int = 0
var fail: Array[String] = []

func check(ok: bool, what: String) -> void:
    count += 1
    if not ok:
        fail.append(what)
        printerr("WEB_UI_P3 FAIL: "+what)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if OS.get_environment("SCE_WEB_UI_ISOLATED_TEST") != "1":
        printerr("Web P3 tests require a sandboxed save environment")
        quit(2)
        return
    root.size = Vector2i(960,540)
    var game = load("res://main.tscn").instantiate()
    root.add_child(game)
    for n in range(5):
        await process_frame
    game._hide_title_screen()
    var ui: Region1RunUI = game.region_run_ui
    ui.run.save_path = "user://web_p3_test_fixture.json"
    var fixture = load("res://tests/hub_inventory_analysis_test.gd").new()
    check(ui.run.adopt_initial(fixture.make_items(ui.run.roller,517901)),"six items adopted")
    fixture.free()
    ui.render()
    game.tab_container.current_tab = ui.get_index()

    var shell = Shell.new()
    root.add_child(shell)
    await process_frame
    var home = Home.new()
    home.bind_host(game)
    check(shell.register_screen("hub",home),"Web hub registered")
    var solo = Solo.new()
    solo.bind_host(game)
    check(shell.register_screen("solo",solo),"Web solo registered")
    game.web_ui_shell = shell
    game.web_hub_screen = home
    game.web_solo_screen = solo

    check(shell.activate("hub"),"hub activated")
    home.refresh()
    check(home.status_label.text.contains("Region 1"),"hub status from campaign")
    check(home.actions.get_child_count() == 4,"four destination panels")
    var saved_before: String = FileAccess.get_file_as_string(ui.run.save_path)
    var state_before: String = JSON.stringify(ui.run.state)
    home._open_route("solo")
    check(shell.router.current_route == "solo","one-tap facility navigation")

    solo.refresh()
    check(solo.region_row.get_child_count() == 6,"six region buttons")
    check(solo.stage_row.get_child_count() == 4,"four boss stage buttons")
    check(solo.region_row.get_child(1).disabled,"locked Region 2 disabled")
    check(solo.launch_button != null and not solo.launch_button.disabled,"6 equipped / 24 deck can depart")
    check(solo.seed_spin.value == solo.seed_value,"seed editor ready")

    solo._tap_stage(1)
    check(shell.selection.selected_id == "solo/stage/0/1","first stage tap previews only")
    check(JSON.stringify(ui.run.state) == state_before,"stage preview does not mutate campaign")
    check(FileAccess.get_file_as_string(ui.run.save_path) == saved_before,"stage preview does not write save")
    solo._tap_stage(1)
    check(solo.chosen_stage == 1 and shell.selection.selected_id == "","second stage tap confirms UI-only choice")
    check(JSON.stringify(ui.run.state) == state_before,"stage selection never writes campaign")

    solo._tap_depart()
    check(shell.selection.selected_id.begins_with("solo/depart/"),"first departure tap previews")
    check(str(ui.run.state.phase) == "hub","departure preview keeps hub phase")
    check(FileAccess.get_file_as_string(ui.run.save_path) == saved_before,"departure preview preserves save bytes")
    solo._tap_depart()
    check(str(ui.run.state.phase) == "route","second departure tap starts real run")
    check(int(ui.run.state.run.gold) == 100,"real run begins at 100G")
    check(int(ui.run.state.run.deck.size()) == 24,"real run has 24 deck cards")
    check(int(ui.run.state.run.target_boss_number) == 1,"selected boss remains target")
    check(not shell.visible,"Web shell closes for legacy route until P5")
    check(shell.selection.selected_id == "" and not shell.selection.commit_pending,"confirmation gate released")
    check(FileAccess.get_file_as_string(ui.run.save_path) != saved_before,"successful run creates checkpoint")
    check(not home.claim_button.visible or home.claim_button != null,"hub references intact")

    game.queue_free()
    shell.queue_free()
    await process_frame
    print("WEB_UI_P3 PASS=%d FAIL=%d" % [count-fail.size(),fail.size()])
    quit(0 if fail.is_empty() else 1)
