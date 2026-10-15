class_name WebEquipmentDetail
extends VBoxContainer

# Display-only equipment/card viewer shared by Web warehouse, forge and merchant.
# Every Card_* button opens its formal text; none initiates a transaction.
var analyzer = HubDeckAnalyzer.new()
var heading: Label
var attributes: Label
var card_buttons: GridContainer
var formal: Label
var effects: Label
var comparison: Label
var current_item: Dictionary = {}
var current_cards: Array = []
var viewed_index: int = -1

func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation",5)
    heading = Label.new()
    heading.name = "ItemHeading"
    heading.add_theme_font_size_override("font_size",17)
    heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_child(heading)
    attributes = _label("属性・HP・ソケット",13)
    card_buttons = GridContainer.new()
    card_buttons.columns = 2
    card_buttons.name = "FourCards"
    add_child(card_buttons)
    formal = _label("カードをタップすると正式本文が表示されます。",12)
    effects = _label("",12)
    comparison = _label("",12)

func _label(value: String, point: int) -> Label:
    var label = Label.new()
    label.text = value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size",point)
    add_child(label)
    return label

func display_item(item: Dictionary, comparison_text: String = "") -> void:
    current_item = item.duplicate(true)
    current_cards = item.get("cards",[]).duplicate()
    viewed_index = -1
    if heading == null:
        return
    if item.is_empty():
        heading.text = "装備を選択してください"
        attributes.text = ""
        effects.text = ""
        comparison.text = ""
        formal.text = ""
        for child in card_buttons.get_children():
            child.queue_free()
        return
    heading.text = "%s　[%s]" % [HubInventoryQuery.item_name(item),str(item.get("rarity",""))]
    attributes.text = "%s / HP %d / Socket %d / 強化 Lv%d\n抽選属性 %s / 武器Affinity %s" % [
        str(item.get("slot","")),int(item.get("effective_hp",item.get("base_hp",0))),
        int(item.get("socket_count",0)),int(item.get("enhance_level",0)),
        str(item.get("rolled_attribute","未設定")),str(item.get("affinity_weapon","未設定"))]
    for child in card_buttons.get_children():
        card_buttons.remove_child(child)
        child.queue_free()
    for i in range(current_cards.size()):
        var card_id: String = str(current_cards[i])
        var card: Dictionary = analyzer.cards.get(card_id,{})
        var button = Button.new()
        button.name = "Card_%d" % i
        button.text = "%s%d：%s" % ["固定" if i<2 else "抽選",i+1,str(card.get("display_name",card_id))]
        button.clip_text = true
        button.custom_minimum_size = Vector2(154,39)
        button.add_theme_font_size_override("font_size",12)
        button.pressed.connect(view_card.bind(i))
        card_buttons.add_child(button)
    effects.text = "装備特殊効果（装備由来4カードのみ）\n"+EquipmentSpecialEffectPolicy.summary(item)
    comparison.text = comparison_text
    if not current_cards.is_empty():
        view_card(0)

func view_card(index: int) -> void:
    if index < 0 or index >= current_cards.size():
        return
    viewed_index = index
    var id: String = str(current_cards[index])
    formal.text = analyzer.card_description(id)
    for child in card_buttons.get_children():
        if child is Button:
            child.set_pressed_no_signal(false) if child.toggle_mode else null
