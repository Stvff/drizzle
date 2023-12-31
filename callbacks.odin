package drizzle

import "core:runtime"
import "core:slice"
import "vendor:glfw"
import "soggy"

files_index := 0
files_to_open: [dynamic]string /* this string has zero-bytes allocated with it */

file_drop_callback :: proc "c" (window_handle: glfw.WindowHandle, count: i32, paths: [^]cstring) {
	context = runtime.default_context()
	for i in 0..<count {
		str := transmute([^]byte) paths[i]
		strlen := 0
		for str[strlen] != 0 do strlen += 1
		file_to_open := make([]byte, strlen + 1)
		for &c, i in file_to_open do c = str[i]
		append(&files_to_open,  transmute(string) file_to_open/*[:1]*/)
	}
//	println(files_to_open)
}

key_callback :: proc "c" (window_handle: glfw.WindowHandle, key, scancode, action, mods: i32) {
//	context = runtime.default_context()
    if key == glfw.KEY_SPACE && action == glfw.RELEASE do paused = !paused
}

wait_for_files_or_exit :: proc(winfo: ^soggy.Winfo) -> bool {
	waiting_text := "Drag a .wav file into this window from your file explorer"
	scale := i32(5)
	soggy.draw_bitfont_text(winfo.hi, {winfo.hi.size.x/2 - i32(len(waiting_text))*2*scale, winfo.hi.size.y/2}, scale, waiting_text, soggy.RED)
	for files_index >= len(files_to_open) {
		if !soggy.loop(winfo) do return true
		if winfo.window_size_changed {
			slice.fill(winfo.lo.tex, 0)
			slice.fill(winfo.hi.tex, 0)
			soggy.draw_bitfont_text(winfo.hi, {winfo.hi.size.x/2 - i32(len(waiting_text))*2*scale, winfo.hi.size.y/2}, scale, waiting_text, soggy.RED)
		}
	}
	return false
}
