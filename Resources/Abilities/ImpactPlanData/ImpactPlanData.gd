extends Resource

class_name ImpactPlanData


enum Topology {
	TREE,
	QUEUE
}


@export var plan_id : String = ""

@export var topology : Topology = Topology.TREE

@export var nodes : Array[ImpactNodeData] = []
