class_name FoundationBootstrapNode
extends Node

var foundation: FoundationBootstrap
var initialization_result: Dictionary


func _ready() -> void:
	foundation = FoundationBootstrap.new()
	initialization_result = foundation.initialize()
	print("FOUNDATION_BOOTSTRAP %s" % JSON.stringify(initialization_result, "", true, true))
