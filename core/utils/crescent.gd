# Crescent: builds crescent-shaped polygons. Used for slash trails AND their hitboxes, so the two always match.
class_name Crescent
extends RefCounted

## Points per edge. Higher = smoother curve, more collision shapes after decomposition.
const SEGMENTS: int = 20


## The outer edge follows an ellipse (radius_x, radius_y) around the origin from from_deg to to_deg
## (0 = ahead, -90 = up, +90 = down). The inner edge is the same ellipse scaled by inner_ratio over a
## shorter arc (taper_deg less at each end), which gives the two pointed tips.
## Anything below clip_bottom (local y) is cut off flat, e.g. so a slash never reaches into the floor.
static func build(radius_x: float, radius_y: float, from_deg: float, to_deg: float,
		inner_ratio: float, taper_deg: float, clip_bottom: float = INF) -> PackedVector2Array:
	var start: float = deg_to_rad(minf(from_deg, to_deg))
	var end: float = deg_to_rad(maxf(from_deg, to_deg))
	var taper: float = minf(deg_to_rad(taper_deg), (end - start) * 0.45)
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in SEGMENTS + 1:
		var angle: float = lerpf(start, end, float(i) / SEGMENTS)
		points.append(Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	for i: int in range(SEGMENTS, -1, -1):
		var angle: float = lerpf(start + taper, end - taper, float(i) / SEGMENTS)
		points.append(Vector2(cos(angle) * radius_x, sin(angle) * radius_y) * inner_ratio)
	if is_inf(clip_bottom):
		return points
	var size: float = maxf(radius_x, radius_y) * 2.0
	var keep: PackedVector2Array = PackedVector2Array([
		Vector2(-size, -size), Vector2(size, -size), Vector2(size, clip_bottom), Vector2(-size, clip_bottom)])
	var clipped: Array[PackedVector2Array] = Geometry2D.intersect_polygons(points, keep)
	# One crescent stays one piece when clipped below its middle; fall back to the unclipped shape otherwise.
	return clipped[0] if clipped.size() == 1 else points
