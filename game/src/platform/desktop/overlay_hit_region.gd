class_name OverlayHitRegion
extends RefCounted

var polygons: Array[PackedVector2Array] = []
var interaction_padding := 0
var source_label := ""


static func single(polygon: PackedVector2Array, padding := 0, label := "") -> OverlayHitRegion:
	var region := OverlayHitRegion.new()
	region.polygons = [polygon]
	region.interaction_padding = padding
	region.source_label = label
	return region


func is_empty() -> bool:
	return polygons.is_empty() or polygons[0].is_empty()


func bounds() -> Rect2:
	var result := Rect2()
	var initialized := false
	for polygon in polygons:
		for point in polygon:
			if not initialized:
				result = Rect2(point, Vector2.ZERO)
				initialized = true
			else:
				result = result.expand(point)
	if initialized and interaction_padding > 0:
		result = result.grow(float(interaction_padding))
	return result
