package soggy

mono_colour :: proc(clr: u8) -> [4]byte {
	return [4]byte{clr, clr, clr, 255}
}

draw_preddy_gradient :: proc(layer: Program_layer){
	y: i32 = 0
	for &pix, i in layer.tex {
		pix = [4]byte{255 - byte((210*y)/layer.size.x), 0, 255 - byte((210*i) / len(layer.tex)), 255}
		y = (y + 1)%layer.size.x
//		pix = [4]byte{0, 0, 255 - byte((255*i) / len(imgl.tex)), 255}
//		pix = {0, 0, 63, 255}
	}
}

Program_layer :: struct {
	size: [2]i32,
	tex: [][4]byte,
	data: [dynamic][4]byte
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
