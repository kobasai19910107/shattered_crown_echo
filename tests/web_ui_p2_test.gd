extends SceneTree
const Shell = preload("res://scripts/web_ui/web_ui_shell.gd")
const Screen = preload("res://scripts/web_ui/web_battle_screen.gd")
var total: int = 0
var failed: Array[String] = []

func check(ok: bool, label: String) -> void:
    total += 1
    if not ok:
        failed.append(label)
        printerr("WEB_UI_P2 FAIL "+label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size = Vector2i(960,540)
    var game = load("res://main.tscn").instantiate()
    root.add_child(game)
    for i in range(4): await process_frame
    game._hide_title_screen()
    game.tab_container.current_tab = 0
    var shell = Shell.new()
    root.add_child(shell)
    await process_frame
    var screen = Screen.new()
    screen.bind_host(game)
    check(shell.register_screen("battle",screen),"screen registered")
    game.web_ui_shell = shell
    game.web_battle_screen = screen
    check(shell.activate("battle"),"battle activated")
    screen.refresh()
    check(screen.stats_label.text.contains("Mana"),"shared HP/Mana/Block visible")
    check(screen.enemy_grid.get_child_count() == game.battle.get_enemy_count(),"all enemies shown")
    check(screen.hand_row.get_child_count() == game.battle.hand.size(),"hand mirrors Battle Core")
    check(screen.hand_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO,"hand supports swiping")
    check(screen.detail_button != null and screen.end_turn_button != null,"action buttons available")
    var first: int = -1
    for i in range(game.battle.hand.size()):
        if game.battle.can_use_card(i):
            first = i
            break
    check(first >= 0,"playable card exists")
    if first >= 0:
        var before: String = JSON.stringify(game.battle.export_region1_state())
        screen._tap_card(first)
        check(game.selected_hand_index == first,"single tap selects a card")
        check(before == JSON.stringify(game.battle.export_region1_state()),"preview does not change battle")
        check(not screen.detail_button.disabled,"tap detail enabled")
        var target_type: String = game.battle.get_effective_target_type(first)
        if target_type == "enemy":
            var living: int = -1
            for i in range(game.battle.get_enemy_count()):
                if game.battle.is_enemy_target_valid(i):
                    living = i
                    break
            check(living >= 0,"living enemy available")
            if living >= 0: screen._tap_enemy(living)
        else:
            screen._tap_card(first)
        check(game.selected_hand_index == -1,"confirmation clears selection")
        check(before != JSON.stringify(game.battle.export_region1_state()),"confirmed card changes battle state")
    screen.refresh()
    check(screen.hand_row.get_child_count() == game.battle.hand.size(),"hand refreshes after action")
    if not game.battle.combat_over and not game.battle.is_hand_selection_active():
        var turn: int = game.battle.turn_number
        screen._end_turn()
        check(game.battle.turn_number == turn + 1 or game.battle.combat_over,"turn end uses existing controller")
    shell.close_shell()
    check(not shell.visible,"shell may close without touching campaign")
    game.queue_free()
    shell.queue_free()
    await process_frame
    print("WEB_UI_P2 PASS=%d FAIL=%d" % [total-failed.size(),failed.size()])
    quit(0 if failed.is_empty() else 1)
