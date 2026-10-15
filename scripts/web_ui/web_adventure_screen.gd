class_name WebAdventureScreen
extends Control

# P5: read-only preview + explicit second-tap confirmation. CampaignController
# alone owns rooms, loot, run Gold, HP, save and run completion.
const DESTINATIONS = {
    "battle":"通常戦","elite":"Elite戦","boss":"Boss戦",
    "event":"イベント","shop":"旅の施設","chest":"宝箱","rest":"休憩"
}

var host
var selected_key: String = ""
var chosen_retained: Array[int] = []
var title_label: Label
var header_label: Label
var option_list: VBoxContainer
var detail_scroll: ScrollContainer
var details: WebEquipmentDetail
var description: Label
var note: Label
var options: Array[Dictionary] = []
var return_button: Button

func bind_host(owner) -> void:
    host=owner

func _run():
    return host.region_run_ui.run if host != null and host.region_run_ui != null else null

func _gate():
    return host.web_ui_shell.selection if host != null and host.web_ui_shell != null else null

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var root=VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation",6)
    add_child(root)
    title_label=_label(root,"冒険",21)
    header_label=_label(root,"",13)
    var columns=HBoxContainer.new()
    columns.size_flags_vertical=Control.SIZE_EXPAND_FILL
    columns.add_theme_constant_override("separation",9)
    root.add_child(columns)
    var left=ScrollContainer.new()
    left.name="AdventureChoices"
    left.custom_minimum_size.x=330
    left.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    columns.add_child(left)
    option_list=VBoxContainer.new()
    option_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    option_list.add_theme_constant_override("separation",7)
    left.add_child(option_list)
    detail_scroll=ScrollContainer.new()
    detail_scroll.name="AdventureDetails"
    detail_scroll.custom_minimum_size.x=370
    detail_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    columns.add_child(detail_scroll)
    var detail_column=VBoxContainer.new()
    detail_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    detail_scroll.add_child(detail_column)
    description=_label(detail_column,"候補をタップして詳細確認",16)
    details=WebEquipmentDetail.new()
    detail_column.add_child(details)
    var footer=HBoxContainer.new()
    root.add_child(footer)
    note=_label(footer,"詳細を確認して、同じ候補をもう一度タップして決定。",13)
    note.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    return_button=Button.new()
    return_button.text="戦闘・冒険へ戻る"
    return_button.custom_minimum_size=Vector2(170,44)
    return_button.pressed.connect(_resume_legacy)
    footer.add_child(return_button)

func _label(parent: Node,value: String,point: int) -> Label:
    var label=Label.new()
    label.text=value
    label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size",point)
    parent.add_child(label)
    return label

func _clear(node: Node) -> void:
    for child in node.get_children():
        node.remove_child(child)
        child.queue_free()

func _phase() -> String:
    return str(_run().state.phase) if _run()!=null else ""

func _fingerprint() -> String:
    return JSON.stringify(_run().state) if _run()!=null else ""

func _add(action: String,title: String,summary: String,index: int=-1,item: Dictionary={},disabled: bool=false) -> void:
    var key: String="%s/%s/%d" % [_phase(),action,index]
    options.append({"key":key,"action":action,"title":title,"summary":summary,"index":index,"item":item.duplicate(true),"disabled":disabled})
    var btn=Button.new()
    btn.name="Choice_%d" % (options.size()-1)
    btn.text=title
    btn.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    btn.alignment=HORIZONTAL_ALIGNMENT_LEFT
    btn.custom_minimum_size=Vector2(300,64)
    btn.add_theme_font_size_override("font_size",16)
    btn.disabled=disabled
    btn.pressed.connect(_tap_choice.bind(options.size()-1))
    option_list.add_child(btn)

func _header() -> String:
    var run: Dictionary=_run().state.get("run",{})
    return "HP %d/%d　Run Gold %dG　素材 %d　部屋 %d　戦利品 %d　敗北確保上限 %d" % [
        int(run.get("hp",0)),int(run.get("max_hp",0)),int(run.get("gold",0)),
        int(run.get("materials",0)),int(run.get("rooms",0)),
        run.get("bag",[]).size(),int(run.get("body_cap",0))]

func refresh() -> void:
    if _run()==null or not is_inside_tree():
        return
    var phase: String=_phase()
    var state: Dictionary=_run().state
    var active: Dictionary=state.get("run",{})
    _clear(option_list)
    options.clear()
    header_label.text=_header()
    return_button.visible=false
    if phase=="route":
        title_label.text="道の選択　— 次の部屋へ"
        for i in range(active.get("routes",[]).size()):
            var kind: String=str(active.routes[i])
            var title: String="%d. %s" % [i+1,str(DESTINATIONS.get(kind,kind))]
            _add("route",title,"選ぶと「%s」へ進みます。部屋へ入ると選択は戻せません。" % title,i)
    elif phase=="reward":
        title_label.text="宝箱・戦闘報酬　— 装備を1つ選択"
        for i in range(active.get("rewards",[]).size()):
            var item: Dictionary=active.rewards[i]
            _add("reward","候補%d：%s" % [i+1,HubInventoryQuery.item_name(item)],"この装備を戦利品袋へ追加します（このラン中は装備不可）。",i,item)
        _add("reward","スキップ","装備を獲得せず先へ進みます。",-1)
    elif phase=="service":
        _populate_service(active)
    elif phase=="defeat":
        _populate_defeat(active)
    else:
        title_label.text="冒険画面"
        description.text="現在のフェーズでは選択できません。"
        details.display_item({})
        return_button.visible=true
        return
    var still_valid: bool=false
    for option in options:
        if str(option.key)==selected_key:
            still_valid=true
            break
    if not still_valid:
        selected_key=""
        description.text="候補をタップすると、内容と効果を確認できます。"
        details.display_item({})
    note.text="1回目：選択と詳細確認　/　2回目：同じ候補で決定"
    if phase=="defeat":
        note.text="戦利品の選択は仮設定。帰還を2回タップすると確定します。"

func _populate_service(run: Dictionary) -> void:
    var kind: String=str(run.get("kind",""))
    if kind=="event":
        title_label.text="イベント　— 行動を選択"
        _add("gold","80Gを得る","Run Gold +80Gで次の部屋へ進む。")
        _add("material","素材2を得る","ラン中の素材を2獲得して次へ進む。")
        _add("heal","HP20%回復","最大HPの20%を回復して次へ進む。")
    elif kind=="rest":
        title_label.text="休憩　— 焚き火"
        _add("heal","HP35%回復","最大HPの35%を回復して次の部屋へ進む。")
    elif kind=="shop":
        var priest: bool=str(run.get("shop_npc","merchant"))=="priest"
        title_label.text="旅の僧侶　— 次戦への支援" if priest else "遺品商　— 戦利品購入"
        if priest:
            var can_heal: bool=int(run.hp)<int(run.max_hp)
            _add("heal","HP35%回復　90G","Run Gold90Gを払い最大HPの35%を回復。",-1,{},not can_heal or int(run.gold)<90)
            _add("full_heal","HP全回復　220G","Run Gold220Gを払いHPを最大まで回復。",-1,{},not can_heal or int(run.gold)<220)
            for opt in [["attack","次戦：最初のAttack +1"],["block","次戦：初期Block +4"],["draw","次戦：Draw +1"]]:
                var action: String=str(opt[0])
                _add(action,str(opt[1])+"　60G","次の戦闘に支援を予約。Run Gold60G消費。",-1,{},int(run.gold)<60 or int(run.get("support",{}).get(action,0))>0)
        else:
            for i in range(run.get("stock",[]).size()):
                var item: Dictionary=run.stock[i]
                if item.is_empty():
                    _add("buy","商品%d：売り切れ" % [i+1],"購入済み",i,{},true)
                else:
                    _add("buy","商品%d：%s　280G" % [i+1,HubInventoryQuery.item_name(item)],
                        "購入した装備は戦利品袋へ追加。拠点帰還まで装備できません。",i,item,int(run.gold)<280)
            _add("refresh","商品更新　70G","現在の在庫を再抽選。Run Gold70Gを消費。",-1,{},int(run.gold)<70)
    _add("leave","購入せず先へ進む","旅の施設を離れ、次の部屋へ進みます。")

func _populate_defeat(run: Dictionary) -> void:
    title_label.text="敗北　— 戦利品を確保して帰還"
    var body_cap: int=int(run.get("body_cap",0))
    var bag: Array=run.get("bag",[])
    var retained_copy: Array[int]=[]
    for i in chosen_retained:
        if i>=0 and i<bag.size() and not retained_copy.has(i):
            retained_copy.append(i)
    chosen_retained=retained_copy
    for i in range(bag.size()):
        var item: Dictionary=bag[i]
        var btn=CheckButton.new()
        btn.name="Retain_%d"%i
        btn.text="%s　%s" % ["◆ 確保" if chosen_retained.has(i) else "選択",HubInventoryQuery.item_name(item)]
        btn.button_pressed=chosen_retained.has(i)
        btn.custom_minimum_size.y=50
        btn.toggled.connect(_toggle_retained.bind(i))
        option_list.add_child(btn)
        var inspect=Button.new()
        inspect.text="詳細：%s" % HubInventoryQuery.item_name(item)
        inspect.custom_minimum_size.y=43
        inspect.pressed.connect(_inspect_bag.bind(i))
        option_list.add_child(inspect)
    _add("return","確保して拠点へ帰還","%d/%d 個を確保。Run Goldは失われます。" % [chosen_retained.size(),body_cap],-1,{},chosen_retained.size()>body_cap)

func _inspect_bag(index: int) -> void:
    var bag: Array=_run().state.run.get("bag",[])
    if index>=0 and index<bag.size():
        details.display_item(bag[index])
        description.text="戦利品の詳細：%s。詳細表示は確保確定ではありません。" % HubInventoryQuery.item_name(bag[index])

func _toggle_retained(enabled: bool,index: int) -> void:
    if enabled and not chosen_retained.has(index):
        if chosen_retained.size()>=int(_run().state.run.get("body_cap",0)):
            note.text="確保できる上限を超えています。"
            refresh()
            return
        chosen_retained.append(index)
    elif not enabled:
        chosen_retained.erase(index)
    if _gate()!=null:
        _gate().cancel()
    refresh()

func _tap_choice(index: int) -> void:
    if _run()==null or _gate()==null or index<0 or index>=options.size():
        return
    var option: Dictionary=options[index]
    if bool(option.disabled):
        return
    var fingerprint: String=_fingerprint()
    var key: String=str(option.key)
    if _phase()=="defeat":
        key+="/"+str(chosen_retained)
    var result: int=_gate().tap(key,{"fingerprint":fingerprint,"retained":chosen_retained.duplicate(),"option":option.duplicate(true)})
    if result==WebSelectionGate.PREVIEW:
        selected_key=str(option.key)
        description.text="%s\n%s\nもう一度同じ候補をタップして確定。" % [str(option.title),str(option.summary)]
        if not option.item.is_empty():
            details.display_item(option.item)
        else:
            details.display_item({})
        note.text="詳細確認中：操作はまだ実行されていません。"
    elif result==WebSelectionGate.COMMIT:
        var safe: bool=str(_gate().selected_details.get("fingerprint",""))==_fingerprint()
        var ok: bool=safe and _execute(option)
        _gate().acknowledge_commit()
        selected_key=""
        if ok:
            if _phase()!="defeat":
                chosen_retained.clear()
            host.region_run_ui.render()
            host.tab_container.current_tab=host.region_run_ui.get_index()
            host._sync_web_campaign()
        else:
            refresh()
            note.text="操作できませんでした。現在の状態を確認して選び直してください。"

func _execute(option: Dictionary) -> bool:
    var controller=_run()
    if controller==null or controller.save_blocked:
        return false
    var phase: String=_phase()
    var action: String=str(option.action)
    var index: int=int(option.index)
    if phase=="route" and action=="route":
        return controller.choose_route(index)
    if phase=="reward" and action=="reward":
        return controller.take_reward(index)
    if phase=="service":
        return controller.service(action,index)
    if phase=="defeat" and action=="return":
        return controller.resolve_defeat(chosen_retained.duplicate())
    return false

func _resume_legacy() -> void:
    if host==null or host.web_ui_shell==null:
        return
    host.web_ui_shell.close_shell()
