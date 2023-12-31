package soggy

RED         :: [4]byte{0xFF, 0x00, 0x00, 0xFF}
GREEN       :: [4]byte{0x00, 0xFF, 0x00, 0xFF}
BLUE        :: [4]byte{0x00, 0x00, 0xFF, 0xFF}
WHITE       :: [4]byte{0xFF, 0xFF, 0xFF, 0xFF}
BLACK       :: [4]byte{0x00, 0x00, 0x00, 0xFF}
GRAY        :: [4]byte{0xAA, 0xAA, 0xAA, 0xFF}
GREY        :: [4]byte{0x22, 0x22, 0x22, 0xFF}
PASTEL_RED  :: [4]byte{0xFF, 0x40, 0x40, 0xFF}
PASTEL_PINK :: [4]byte{0xF5, 0xA9, 0xB8, 0xFF}
PASTEL_BLUE :: [4]byte{0x5B, 0xCE, 0xFA, 0xFF}

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

draw_bitfont_text :: proc(ui: Program_layer, txt_pos: [2]i32, scale: i32, txt: string, color: [4]byte){
	txt_pos := txt_pos
	for c in txt {
		draw_bitfont_char(ui, txt_pos, scale, c, color)
		txt_pos.x += 4*scale
	}
}

// font from fenster
// ascii - 32
bitfont5x3 := [?]u16{0x0000,0x2092,0x002d,0x5f7d,0x279e,0x52a5,0x7ad6,0x0012,0x4494,0x1491,0x017a,0x05d0,0x1400,0x01c0,0x0400,0x12a4,0x2b6a,0x749a,0x752a,0x38a3,0x4f4a,0x38cf,0x3bce,0x12a7,0x3aae,0x49ae,0x0410,0x1410,0x4454,0x0e38,0x1511,0x10e3,0x73ee,0x5f7a,0x3beb,0x624e,0x3b6b,0x73cf,0x13cf,0x6b4e,0x5bed,0x7497,0x2b27,0x5add,0x7249,0x5b7d,0x5b6b,0x3b6e,0x12eb,0x4f6b,0x5aeb,0x388e,0x2497,0x6b6d,0x256d,0x5f6d,0x5aad,0x24ad,0x72a7,0x6496,0x4889,0x3493,0x002a,0xf000,0x0011,0x6b98,0x3b79,0x7270,0x7b74,0x6750,0x95d6,0xb9ee,0x5b59,0x6410,0xb482,0x56e8,0x6492,0x5be8,0x5b58,0x3b70,0x976a,0xcd6a,0x1370,0x38f0,0x64ba,0x3b68,0x2568,0x5f68,0x54a8,0xb9ad,0x73b8,0x64d6,0x2492,0x3593,0x03e0}
draw_bitfont_char :: proc(ui: Program_layer, chr_pos: [2]i32, scale: i32, char: rune, color: [4]byte) {
	bmp: u16
	if 32 > char || char >= len(bitfont5x3) + 32 do bmp = 0
	else do bmp = bitfont5x3[char - 32]
	for y in i32(0)..<5*scale {
		for x in i32(0)..<3*scale {
			i_x := chr_pos.x + x
			i_y := chr_pos.y + (5*scale - y)
			if 0 > i_x || i_x >= ui.size.x do continue
			if 0 > i_y || i_y >= ui.size.y do continue
			if ((bmp >> uint(x/scale + (y/scale)*3)) & 1) == 1 do ui.tex[i_x + i_y*ui.size.x] = color
		}
	}
}
