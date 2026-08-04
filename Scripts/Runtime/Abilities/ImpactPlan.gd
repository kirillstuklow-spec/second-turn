extends RefCounted

class_name ImpactPlan


enum Topology {
	TREE,
	QUEUE
}


const MAX_DEPTH : int = 10


var execution_id : StringName = &""

var topology : Topology = Topology.TREE

var impacts : Array[Impact] = []


static func create(
	new_execution_id : StringName,
	new_topology : Topology
) -> ImpactPlan:
	var plan := ImpactPlan.new()
	plan.execution_id = new_execution_id
	plan.topology = new_topology
	return plan


func add_root_impact(impact : Impact) -> bool:
	if impact == null:
		return false

	impact.parent_impact_id = &""
	return _append_impact(impact)


func add_child_impact(
	parent_impact_id : StringName,
	impact : Impact
) -> bool:
	if topology != Topology.TREE:
		return false

	if impact == null or get_impact(parent_impact_id) == null:
		return false

	impact.parent_impact_id = parent_impact_id
	return _append_impact(impact)


func append_queue_impact(impact : Impact) -> bool:
	if topology != Topology.QUEUE or impact == null:
		return false

	impact.parent_impact_id = &""
	return _append_impact(impact)


func get_impact(impact_id : StringName) -> Impact:
	for impact in impacts:
		if impact != null and impact.impact_id == impact_id:
			return impact

	return null


func get_impacts_in_order() -> Array[Impact]:
	var ordered : Array[Impact] = []
	ordered.append_array(impacts)
	ordered.sort_custom(_compare_impacts)
	return ordered


func get_root_impacts() -> Array[Impact]:
	var roots : Array[Impact] = []

	for impact in impacts:
		if impact != null and impact.parent_impact_id == &"":
			roots.append(impact)

	roots.sort_custom(_compare_impacts)
	return roots


func get_children(
	parent_impact_id : StringName
) -> Array[Impact]:
	var children : Array[Impact] = []

	for impact in impacts:
		if (
			impact != null
			and impact.parent_impact_id == parent_impact_id
		):
			children.append(impact)

	children.sort_custom(_compare_impacts)
	return children


func get_depth(impact : Impact) -> int:
	if impact == null:
		return -1

	var depth := 0
	var current := impact
	var visited : Dictionary = {}

	while current.parent_impact_id != &"":
		if visited.has(current.impact_id):
			return MAX_DEPTH + 1

		visited[current.impact_id] = true
		current = get_impact(current.parent_impact_id)

		if current == null:
			return MAX_DEPTH + 1

		depth += 1

		if depth > MAX_DEPTH:
			return depth

	return depth


func _append_impact(impact : Impact) -> bool:
	if impact.impact_id == &"" or get_impact(impact.impact_id) != null:
		return false

	if impact.execution_id == &"":
		impact.execution_id = execution_id

	if impact.execution_id != execution_id:
		return false

	if impact.order_index < 0:
		impact.order_index = impacts.size()

	impacts.append(impact)
	return true


func _compare_impacts(left : Impact, right : Impact) -> bool:
	if left.order_index == right.order_index:
		return String(left.impact_id) < String(right.impact_id)

	return left.order_index < right.order_index
