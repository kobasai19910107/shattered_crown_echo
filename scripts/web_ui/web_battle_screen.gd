class_name WebBattleScreen
extends Control

# Web P2. This view delegates all card, target and turn transitions to main.gd.
# The original BattleController remains the only owner of combat state.
var host
var battle: BattleController
var stats_label: Label
var trait_label: Label
var phase_label: Label
var hint_label: Label
var action_label: Label
var enemy_grid: GridContainer
var hand_scroll: ScrollContainer
var hand_row: HBoxContainer
var detail_button: Button
var cancel_button: Button
var use_button: Button
var end_turn_button: Button
var auto_button: CheckButton
var card_dialog: AcceptDialog
var enemy_dialog: AcceptDialog

func bind_host(value) -> void:
    host = value

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build()

func _build() -> void:
    var root := VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation",4)
    add_child(root)

    var top := HBoxContainer.new()
    top.custom_minimum_size.y = 36
    root.add_child(top)
    stats_label = _label(top,"",18)
    stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    trait_label = _label(top,"",12)
    trait_label.clip_text = true

    var phase := HBoxContainer.new()
    phase.custom_minimum_size.y = 27
    root.add_child(phase)
    phase_label = _label(phase,"敵とIntent",15)
    phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var hub_button = _button(phase,"拠点を見る",_return_to_campaign)
    hub_button.custom_minimum_size = Vector2(100,36)

    enemy_grid = GridContainer.new()
    enemy_grid.columns = 3
    enemy_grid.custom_minimum_size.y = 130
    enemy_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    enemy_grid.add_theme_constant_override("h_separation",7)
    root.add_child(enemy_grid)

    hint_label = _label(root,"カードをタップして選択",13)
    hint_label.custom_minimum_size.y = 20
    hint_label.clip_text = true
    _label(root,"手札：6枚以上は横スワイプ",13)

    hand_scroll = ScrollContainer.new()
    hand_scroll.name = "TouchHandScroll"
    hand_scroll.custom_minimum_size.y = 139
    hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    root.add_child(hand_scroll)
    hand_row = HBoxContainer.new()
    hand_row.add_theme_constant_override("separation",6)
    hand_scroll.add_child(hand_row)

    var actions := HBoxContainer.new()
    actions.name = "BattleActions"
    actions.custom_minimum_size.y = 44
    actions.add_theme_constant_override("separation",6)
    root.add_child(actions)
    detail_button = _button(actions,"カード詳細",_show_card_detail)
    cancel_button = _button(actions,"取消",_cancel)
    use_button = _button(actions,"使用",_use)
    auto_button = CheckButton.new()
    auto_button.text = "自動"
    auto_button.custom_minimum_size = Vector2(87,44)
    auto_button.toggled.connect(_toggle_auto)
    actions.add_child(auto_button)
    end_turn_button = _button(actions,"ターン終了",_end_turn)
    end_turn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    action_label = _label(root,"",12)
    action_label.clip_text = true

    card_dialog = AcceptDialog.new()
    card_dialog.ok_button_text = "閉じる"
    add_child(card_dialog)
    enemy_dialog = AcceptDialog.new()
    enemy_dialog.ok_button_text = "閉じる"
    add_child(enemy_dialog)

func _label(parent: Node, value: String, font_size: int) -> Label:
    var item := Label.new()
    item.text = value
    item.add_theme_font_size_override("font_size",font_size)
    parent.add_child(item)
    return item

func _button(parent: Node, value: String, call: Callable) -> Button:
    var item := Button.new()
    item.text = value
    item.custom_minimum_size = Vector2(92,44)
    item.pressed.connect(call)
    parent.add_child(item)
    return item

func _clear(parent: Node) -> void:
    for item in parent.get_children():
        parent.remove_child(item)
        item.queue_free()

func _name(card: Dictionary) -> String:
    var name_value: String = str(card.get("display_name","")).strip_edges()
    if name_value != "":
        name_value = name_value.split(" / ")[0]
    return name_value if name_value != "" else str(card.get("id","?"))

func refresh() -> void:
    if host == null or not is_inside_tree():
        return
    battle = host.battle
    if battle == null:
        return
    stats_label.text = "♥ %d/%d    Mana %d    Block %d" % [battle.player_hp,battle.player_max_hp,battle.current_mana,battle.player_block]
    var traits: Array[String] = []
    for name_value in battle.weapon_traits:
        if bool(battle.weapon_traits[name_value]):
            traits.append(str(name_value)+" ON")
    for name_value in battle.attribute_traits:
        if int(battle.attribute_traits[name_value]) > 0:
            traits.append("%s %d" % [str(name_value),int(battle.attribute_traits[name_value])])
    trait_label.text = "  ".join(traits).substr(0,65)
    phase_label.text = "%s　Turn %d" % [battle.get_active_enemy_preset(),battle.turn_number]
    _show_enemies()
    _show_cards()
    var chosen: int = host.selected_hand_index
    var has_card: bool = chosen >= 0 and chosen < battle.hand.size()
    var choosing: bool = battle.is_hand_selection_active()
    if battle.combat_over:
        hint_label.text = "戦闘終了。拠点・冒険画面で結果を確認できます。"
    elif choosing:
        hint_label.text = battle.get_hand_selection_prompt()
    elif has_card:
        hint_label.text = "%s 選択中 → 敵をタップ／自分対象なら再タップまたは［使用］" % _name(battle.hand[chosen])
    else:
        hint_label.text = "カードを1回タップして選択（Manaはまだ消費しません）"
    detail_button.disabled = not has_card
    cancel_button.disabled = not has_card or choosing
    use_button.visible = has_card and not choosing and battle.get_effective_target_type(chosen) != "enemy"
    use_button.disabled = not has_card or choosing
    end_turn_button.disabled = has_card or choosing or battle.combat_over or not battle.resolving_card.is_empty()
    auto_button.set_pressed_no_signal(host.auto_battle_enabled)
    action_label.text = "戦闘終了" if battle.combat_over else str(battle.last_notice).substr(0,115)

func _show_enemies() -> void:
    _clear(enemy_grid)
    enemy_grid.columns = maxi(1,mini(3,battle.get_enemy_count()))
    for i in range(battle.get_enemy_count()):
        var enemy: Dictionary = battle.get_enemy(i)
        var alive: bool = int(enemy.get("hp",0)) > 0
        var target := Button.new()
        target.name = "Enemy_%d" % i
        target.custom_minimum_size = Vector2(118,130)
        target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        target.disabled = not alive or battle.combat_over
        target.pressed.connect(_tap_enemy.bind(i))
        enemy_grid.add_child(target)
        var info := VBoxContainer.new()
        info.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        info.mouse_filter = Control.MOUSE_FILTER_IGNORE
        info.add_theme_constant_override("separation",1)
        target.add_child(info)
        var portrait := TextureRect.new()
        portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
        portrait.texture = MonsterPortrait.texture_for(str(enemy.get("id","")))
        portrait.custom_minimum_size.y = 66
        portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        info.add_child(portrait)
        var life := _label(info,"#%d %s　HP %d/%d" % [int(enemy.get("order_index",i+1)),str(enemy.get("id","敵")),int(enemy.get("hp",0)),int(enemy.get("max_hp",0))],12)
        life.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        life.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var intent := _label(info,"次: "+battle.get_enemy_intent_display_label(i) if alive else "撃破",12)
        intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        intent.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _show_cards() -> void:
    _clear(hand_row)
    var chosen: int = host.selected_hand_index
    var choosing: bool = battle.is_hand_selection_active()
    for i in range(battle.hand.size()):
        var card: Dictionary = battle.hand[i]
        var button := Button.new()
        button.name = "Card_%d" % i
        button.custom_minimum_size = Vector2(166,132)
        button.add_theme_font_size_override("font_size",14)
        button.clip_text = true
        button.disabled = battle.combat_over or (not choosing and not battle.can_use_card(i) and chosen != i)
        button.text = "Cost %d　%s\n%s\nATK %d　BLK %d\n特性 +%d%s" % [
            battle.get_effective_cost(i),str(card.get("card_type","")).to_upper(),
            _name(card),int(card.get("base_damage",0)),int(card.get("base_block",0)),
            int(card.get("attribute_trait_gain",0)),"\n●選択中" if chosen==i else ""]
        if chosen == i:
            var style := StyleBoxFlat.new()
            style.bg_color = Color("30415c")
            style.border_color = Color("eecb83")
            style.set_border_width_all(3)
            style.set_corner_radius_all(9)
            button.add_theme_stylebox_override("normal",style)
            button.add_theme_stylebox_override("hover",style)
        button.pressed.connect(_tap_card.bind(i))
        hand_row.add_child(button)

func _tap_card(index: int) -> void:
    if host == null or battle == null:
        return
    if battle.is_hand_selection_active():
        host._on_card_pressed(index)
    elif host.selected_hand_index == index:
        if battle.get_effective_target_type(index) == "enemy":
            host._cancel_selection()
        else:
            host._on_use_pressed()
    else:
        host._on_card_pressed(index)

func _tap_enemy(index: int) -> void:
    if host == null or battle == null:
        return
    var index_card: int = host.selected_hand_index
    if index_card >= 0 and index_card < battle.hand.size() and battle.get_effective_target_type(index_card) == "enemy":
        host._on_enemy_pressed(index)
        return
    var enemy: Dictionary = battle.get_enemy(index)
    enemy_dialog.title = str(enemy.get("name",enemy.get("id","敵")))
    enemy_dialog.dialog_text = "HP %d/%d　Block %d\n次の行動: %s" % [
        int(enemy.get("hp",0)),int(enemy.get("max_hp",0)),int(enemy.get("block",0)),battle.get_enemy_intent_display_label(index)]
    enemy_dialog.popup_centered(Vector2i(520,250))

func _show_card_detail() -> void:
    if host == null or battle == null:
        return
    var index: int = host.selected_hand_index
    if index < 0 or index >= battle.hand.size():
        return
    var card: Dictionary = battle.hand[index]
    card_dialog.title = "%s / Cost %d" % [_name(card),battle.get_effective_cost(index)]
    card_dialog.dialog_text = WeaponTraitCardDescription.combined_text(card)
    card_dialog.popup_centered(Vector2i(730,370))

func _cancel() -> void:
    if host != null:
        host._cancel_selection()

func _use() -> void:
    if host != null:
        host._on_use_pressed()

func _end_turn() -> void:
    if host != null:
        host._on_end_turn_pressed()

func _toggle_auto(enabled: bool) -> void:
    if host != null:
        host._on_auto_battle_toggled(enabled)

func _return_to_campaign() -> void:
    if host == null or host.region_run_ui == null or host.web_ui_shell == null:
        return
    if host.region_run_ui.animation_busy:
        return
    if host.auto_battle_enabled:
        host._on_auto_battle_toggled(false)
    host.region_run_ui.sync_battle()
    host.region_run_ui.render()
    host.tab_container.current_tab = host.region_run_ui.get_index()
    # While combat is still active, this button is an explicit escape
    # to the legacy run overview. Reopening the Web battle would trap users.
    var phase: String=str(host.region_run_ui.run.state.phase)
    if phase=="battle":
        host.web_ui_shell.close_shell()
    elif host.web_adventure_screen != null:
        host._sync_web_campaign()
    else:
        host.web_ui_shell.close_shell()
        if phase=="hub":
            host._activate_web_hub()
