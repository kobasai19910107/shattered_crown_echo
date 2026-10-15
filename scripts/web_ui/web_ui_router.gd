class_name WebUIRouter
extends RefCounted

signal route_changed(route: String)
const ROUTES = ["hub","equipment","forge","merchant","solo","battle","route","reward","event","rest","victory","defeat"]
var current_route: String = ""
var history: Array[String] = []

func supports(route: String) -> bool:
    return route in ROUTES

func navigate(route: String) -> bool:
    if not supports(route) or route == current_route:
        return false
    if current_route != "":
        history.append(current_route)
    current_route = route
    route_changed.emit(route)
    return true

func back() -> bool:
    if history.is_empty():
        return false
    current_route = history.pop_back()
    route_changed.emit(current_route)
    return true
