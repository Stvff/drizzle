package soggy

Program_layer :: struct {
	size: [2]i32,
	tex: []rgba,
	data: [dynamic]rgba
}

rgba :: [4]byte

mono_colour :: proc(clr: u8) -> rgba {
	return rgba{clr, clr, clr, 255}
}

area :: proc(v: [2]i32) -> int {
	return int(v.x)*int(v.y)
}

vec_max :: proc(v: [2]i32, m: [2]i32) -> [2]i32 {
	return [2]i32{max(v.x, m.x), max(v.y, m.y)}
}

vec_clamp :: proc(v: [2]i32, l, h: [2]i32) -> [2]i32 {
	return {
		clamp(v.x, l.x, h.x),
		clamp(v.y, l.y, h.y)
	}
}

import "core:math"
mag :: proc(v: [2]i32) -> i32 {
	return cast(i32) math.sqrt(f64(v.x*v.x + v.y*v.y))
}
magsq :: proc(v: [2]i32) -> i32 {
	return v.x*v.x + v.y*v.y
}

is_in_space :: proc(point_pos, size: [2]i32) -> bool {
	if 0 > point_pos.x || point_pos.x >= size.x do return false
	if 0 > point_pos.y || point_pos.y >= size.y do return false
	return true
}
is_in_rect :: proc(point_pos, rect_pos, rect_size: [2]i32) -> bool {
	if rect_pos.x > point_pos.x || point_pos.x >= rect_pos.x + rect_size.x do return false
	if rect_pos.y > point_pos.y || point_pos.y >= rect_pos.y + rect_size.y do return false
	return true
}
