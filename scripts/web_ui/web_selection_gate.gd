class_name WebSelectionGate
extends RefCounted

signal preview_requested(choice_id: String, details: Dictionary)
signal commit_requested(choice_id: String, details: Dictionary)
signal selection_cleared

const NO_ACTION = 0
const PREVIEW = 1
const COMMIT = 2

var selected_id: String = ""
var selected_details: Dictionary = {}
var commit_pending: bool = false

func tap(choice_id: String, details: Dictionary = {}) -> int:
    if choice_id.strip_edges().is_empty() or commit_pending:
        return NO_ACTION
    if selected_id != choice_id:
        selected_id = choice_id
        selected_details = details.duplicate(true)
        preview_requested.emit(choice_id, selected_details.duplicate(true))
        return PREVIEW
    commit_pending = true
    commit_requested.emit(choice_id, selected_details.duplicate(true))
    return COMMIT

func cancel() -> bool:
    if commit_pending:
        return false
    _clear()
    return true

func acknowledge_commit() -> void:
    _clear()
    commit_pending = false

func is_selected(choice_id: String) -> bool:
    return selected_id != "" and selected_id == choice_id and not commit_pending

func _clear() -> void:
    if selected_id != "":
        selected_id = ""
        selected_details.clear()
        selection_cleared.emit()
