extends SceneTree
const Gate = preload("res://scripts/web_ui/web_selection_gate.gd")
const Router = preload("res://scripts/web_ui/web_ui_router.gd")
const Shell = preload("res://scripts/web_ui/web_ui_shell.gd")

var failures: Array[String] = []
var checks: int = 0

func verify(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures.append(label)
        printerr("P1 FAIL: " + label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var gate = Gate.new()
    var previews: Array[String] = []
    var commits: Array[String] = []
    gate.preview_requested.connect(func(id: String, _details: Dictionary): previews.append(id))
    gate.commit_requested.connect(func(id: String, _details: Dictionary): commits.append(id))
    verify(gate.tap("chest/A", {"hp":10}) == Gate.PREVIEW, "first tap previews")
    verify(commits.is_empty(), "preview does not commit")
    verify(gate.tap("chest/B") == Gate.PREVIEW, "switch candidate previews")
    verify(gate.tap("chest/B") == Gate.COMMIT, "repeat same choice commits")
    verify(commits == ["chest/B"], "exactly one commit emitted")
    verify(gate.tap("chest/B") == Gate.NO_ACTION, "duplicate submission blocked")
    verify(not gate.cancel(), "pending commit cannot be cancelled")
    gate.acknowledge_commit()
    verify(gate.selected_id == "" and not gate.commit_pending, "acknowledge clears state")
    verify(gate.tap("merchant/A") == Gate.PREVIEW and gate.cancel(), "cancel only clears")
    verify(previews == ["chest/A", "chest/B", "merchant/A"], "previews have correct order")
    verify(gate.tap(" ") == Gate.NO_ACTION, "blank ID ignored")

    var route = Router.new()
    verify(not route.navigate("unknown"), "unknown route rejected")
    verify(route.navigate("hub") and route.navigate("reward"), "routes accepted")
    verify(route.back() and route.current_route == "hub", "back restores route")
    verify(not route.navigate("hub"), "no duplicate navigation")

    root.size = Vector2i(960,540)
    var shell = Shell.new()
    root.add_child(shell)
    await process_frame
    verify(not shell.visible and shell.page_host != null, "Web shell begins hidden")
    var hub = ColorRect.new()
    var reward = ColorRect.new()
    verify(shell.register_screen("hub",hub) and shell.register_screen("reward",reward), "screens register")
    verify(shell.activate("hub") and hub.visible and not reward.visible, "hub activated")
    verify(shell.activate("reward") and reward.visible and not hub.visible, "reward activated")
    verify(shell.go_back() and hub.visible, "shell goes back")
    verify(not shell.rotation_hint.visible, "landscape works")
    root.size = Vector2i(540,960)
    await process_frame
    shell._refresh_orientation()
    verify(shell.rotation_hint.visible, "portrait warning appears")
    root.size = Vector2i(960,540)
    await process_frame
    shell._refresh_orientation()
    verify(not shell.rotation_hint.visible, "landscape removes warning")
    shell.selection.tap("itemA")
    verify(shell.activate("reward") and shell.selection.selected_id == "", "navigation clears preview")
    shell.selection.tap("itemB")
    shell.selection.tap("itemB")
    verify(not shell.go_back(), "pending choice prevents navigation")
    shell.selection.acknowledge_commit()
    verify(shell.go_back(), "navigation resumes after acknowledgement")
    shell.close_shell()
    verify(not shell.visible, "shell closes")
    shell.queue_free()
    await process_frame
    print("WEB_UI_P1 PASS=%d FAIL=%d" % [checks-failures.size(),failures.size()])
    quit(0 if failures.is_empty() else 1)
