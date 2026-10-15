extends SceneTree

# A layout test for the exact iPhone landscape CSS-like short viewport sizes.
# Does not load campaign saves or mutate any gameplay state.
const Shell = preload("res://scripts/web_ui/web_ui_shell.gd")
const Home = preload("res://scripts/web_ui/web_hub_home.gd")
var checks: int = 0
var errors: Array[String] = []

func verify(ok: bool, name: String) -> void:
    checks += 1
    if not ok:
        errors.append(name)
        printerr("WEB_UI_P6_LAYOUT FAIL: " + name)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for size in [Vector2i(844,390), Vector2i(932,430), Vector2i(960,540)]:
        root.size=size
        var shell=Shell.new()
        root.add_child(shell)
        await process_frame
        var home=Home.new()
        verify(shell.register_screen("hub",home),"register hub at %s"%str(size))
        verify(shell.activate("hub"),"activate hub at %s"%str(size))
        await process_frame
        await process_frame
        var grid: GridContainer=home.actions
        verify(grid.get_child_count()==4,"four hub destinations at %s"%str(size))
        var available: Rect2=shell.page_host.get_global_rect()
        var footer: HBoxContainer=home.get_node("HubScroller/HubContent/HubFooter")
        for child in grid.get_children():
            var rect: Rect2=child.get_global_rect()
            verify(rect.size.y>=44,"44-unit touch target %s at %s"%[child.name,str(size)])
            verify(rect.end.y <= available.end.y + 1.0,"facility fully visible %s at %s"%[child.name,str(size)])
        verify(footer.get_global_rect().end.y <= available.end.y + 1.0,"footer fully visible at %s"%str(size))
        var scroll: ScrollContainer=home.get_node("HubScroller")
        verify(scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED,"no horizontal scrolling")
        verify(grid.size_flags_vertical != Control.SIZE_EXPAND_FILL,"facility rows do not stretch vertically")
        shell.queue_free()
        await process_frame
    print("WEB_UI_P6_LAYOUT PASS=%d FAIL=%d" % [checks-errors.size(),errors.size()])
    quit(0 if errors.is_empty() else 1)
