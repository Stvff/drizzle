package drizzle

import "soggy"
import "wav"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:time"
import "core:math"

import ma "vendor:miniaudio"
import "vendor:glfw"

println :: fmt.println
printf :: fmt.printf

main :: proc() {
	winfo_actual := soggy.Winfo{
		window_title = "drizzle",
		hi_init_size = {1280, 800},
		lo_scale = 2,
		hi_minimum_size = {400, 400},
		draw_on_top = .hi,
	}
	winfo := &winfo_actual
	if !soggy.start(winfo) do return
	defer soggy.exit(winfo)
	glfw.SetDropCallback(winfo._window_handle, file_drop_callback)
	glfw.SetKeyCallback(winfo._window_handle, key_callback)

	for i in 1..<len(os.args) {
		str := transmute([]byte) os.args[i]
		file_to_open := make([]byte, len(os.args[i]) + 1)
		for c, i in str do file_to_open[i] = c
		append(&files_to_open,  transmute(string) file_to_open[:len(os.args[i])])
	}
	if wait_for_files_or_exit(winfo) do return

	audio, success := wav.read_wav(files_to_open[files_index])
	piece := wav.Audio{sample_freq = audio.sample_freq}
	if !success do return
	defer delete(audio.signal)
	
	audio_engine: ma.engine;
	engine_sound: ma.sound;
	{
		ma_result := ma.engine_init(nil, &audio_engine)
		if ma_result != .SUCCESS {
			println("miniaudio: failed to initialize audio engine, with error:", ma_result)
			return
		}
		ma_result = ma.sound_init_from_file(&audio_engine, transmute(cstring) raw_data(files_to_open[files_index]), 0, nil, nil, &engine_sound)
		if ma_result != .SUCCESS {
			println("miniaudio: failed to init sound, with error:", ma_result)
			return
		}
		ma.engine_set_volume(&audio_engine, volume)
		ma.sound_start(&engine_sound)
	} defer {
		ma.engine_uninit(&audio_engine)
	}

	power: uint
	bin_size, stride, amount_of_bins, bindex: int
	bin_time: time.Duration
	complex_buffer: []complex64
	fted: wav.Audio
	defer {
		delete(complex_buffer)
		delete(fted.signal)
	}

	first_frame := true
	done := true
	was_paused := paused
	pause_start_time := time.now()
	start_start_time := time.now()
	for soggy.loop(winfo) {
//		start_time := time.now()
		if winfo.window_size_changed || first_frame {
			old_index := bindex * stride
			power = 13
			bin_size = int(1 << power)
			stride = int(1 << 10)
			amount_of_bins = 1 + len(audio.signal) / stride
			bindex = old_index / stride
			bin_time = time.Duration(f64(stride)/f64(audio.sample_freq)*1e9)

			delete(complex_buffer)
			complex_buffer = make([]complex64, bin_size)
			delete(fted.signal)
			fted = wav.Audio{ signal = make([]f32, bin_size/2) }

			slice.fill(winfo.lo.tex, 0)
			slice.fill(winfo.hi.tex, 0)
			for x in 0..<(winfo.hi.size.x*i32(bindex))/i32(amount_of_bins) {
				winfo.hi.tex[11*winfo.hi.size.x + x] = soggy.RED
				winfo.hi.tex[10*winfo.hi.size.x + x] = soggy.RED
				winfo.hi.tex[ 9*winfo.hi.size.x + x] = soggy.RED
			}
			first_frame = false
			redraw_queue = true
			volume_set = true
		}
		if redraw_queue do draw_queue(winfo)
		if volume_set {
			soggy.draw_bitfont_char(winfo.hi, {20, 15}, 3, '-', soggy.GREEN)
			soggy.draw_bitfont_char(winfo.hi, {100, 15}, 3, '+', soggy.GREEN)
			yw := winfo.hi.size.x
			for x in i32(0)..<60 {
				clr := [4]byte{} if x >= i32(volume*60) else soggy.GREEN
				winfo.hi.tex[22*yw + x + 35] = clr
				winfo.hi.tex[23*yw + x + 35] = clr
				winfo.hi.tex[24*yw + x + 35] = clr
			}
//			for x in 0..<i32(volume*50) do winfo.hi.tex[ypos + x + 25] = soggy.GREEN
			ma.engine_set_volume(&audio_engine, volume)
			volume_set = false
		}

		done = !(len(audio.signal) > bindex*stride)
		if !done && !paused {
			copy(winfo.lo.tex, winfo.lo.tex[winfo.lo.size.x:])
			piece.signal = audio.signal[bindex * stride:]
			fted = wav.normalize(wav.fft(piece, power, complex_buffer, fted.signal))
			top_row := int(winfo.lo.size.x)*(int(winfo.lo.size.y) - 1)
			max_f := cast(f64) fted.sample_freq
			min_f := cast(f64) 20
			log_max_f := math.log10(max_f)
			max_x := cast(f64) winfo.lo.size.x
			max_i := f64(len(fted.signal)) - 1
			x_at_min_f := max_x*math.log10(min_f)/log_max_f
			x_at_max_f := max_x*math.log10(max_f)/log_max_f
			for x in 0..<int(x_at_max_f) {
				curr_freq := min(max_f, math.pow(10.0, (f64(x) + x_at_min_f)*log_max_f/max_x))
//				println(curr_freq)
				i := int( max_i*curr_freq/max_f )
				winfo.lo.tex[top_row + x] = soggy.mono_colour(u8(255*fted.signal[i]))
			}
			{
				x := (winfo.hi.size.x*i32(bindex))/i32(amount_of_bins)
				winfo.hi.tex[10*winfo.hi.size.x + x] = soggy.RED
				winfo.hi.tex[11*winfo.hi.size.x + x] = soggy.RED
				winfo.hi.tex[ 9*winfo.hi.size.x + x] = soggy.RED
			}
		}

		if done do paused = true
		if !was_paused && paused {
			ma.sound_stop(&engine_sound)
			pause_start_time = time.now()
		}
		if was_paused && !paused {
			ma.sound_start(&engine_sound)
			start_start_time = time.time_add(start_start_time, time.since(pause_start_time))
		}
		was_paused = paused

		if !paused && !done {
			bindex += 1
			time_to_sleep := bin_time - (time.since(start_start_time) - bin_time*time.Duration(bindex - 1))
			for time_to_sleep < 0 {
//				println("frame took too long:", time_to_sleep)
				time_to_sleep += bin_time
				bindex += 1
			}
//			println(bin_time - time_to_sleep, bin_time)
			time.sleep(time_to_sleep)
		}

		if done || new_song_selected {
			ma.sound_stop(&engine_sound)
			ma.sound_uninit(&engine_sound)
			files_index += 1
			if files_index >= len(files_to_open) {
				if wait_for_files_or_exit(winfo) do return
			}
			/* load new audio */
			delete(audio.signal)
			audio, success = wav.read_wav(files_to_open[files_index])
			piece = wav.Audio{sample_freq = audio.sample_freq}
			if !success {
				files_index += 1
				break
			}
			ma_result := ma.sound_init_from_file(&audio_engine, transmute(cstring) raw_data(files_to_open[files_index]), 0, nil, nil, &engine_sound)
			if ma_result != .SUCCESS {
				println("miniaudio: failed to init sound, with error:", ma_result)
				return
			}
			bindex = 0
			pause_start_time = time.now()
			start_start_time = time.now()
			if !paused {
				ma.sound_start(&engine_sound)
			}
			first_frame = true
			new_song_selected = false
		}
	}

}

truncate_filename :: proc(name: string) -> string {
	e := len(name) - 1
	for e != 0 {
		if name[e] == '\\' || name[e] == '/' do break
		e -= 1
	}
	if e != len(name) - 1 do e += 1
	return name[e:]
}

log2 :: proc(n: int) -> int {
	l, q: int
	if n == 0 do return 0
	q = n
	for q != 0 {
		q = q >> 1
		l += 1
	}
	return l
}
