extends Node

class_name EventQueue


var events: Array[Dictionary] = []


func push_event(event: Dictionary) -> void:
	if event.is_empty():
		push_error("EventQueue: empty event")
		return

	if not event.has("type"):
		push_error("EventQueue: event has no type")
		return

	events.append(event)

	print("EventQueue event: ", event["type"])


func clear() -> void:
	events.clear()


func print_events() -> void:
	print("")
	print("EventQueue events count: ", events.size())

	for event in events:
		print(event)
