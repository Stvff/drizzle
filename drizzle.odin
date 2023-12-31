package drizzle

import "soggy"
import "wav"
import "core:fmt"
import "core:slice"
import "core:time"
import "core:math"

import ma "vendor:miniaudio"
import "vendor:glfw"

println :: fmt.println
printf :: fmt.printf

paused := false

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

	if wait_for_files_or_exit(winfo) do return

	audio, success := wav.read_wav(files_to_open[files_index])
	piece := wav.Audio{sample_freq = audio.sample_freq}
	if !success do return
	defer delete(audio.signal)

	audio_engine: ma.engine; {
		ma_result := ma.engine_init(nil, &audio_engine)
		if ma_result != .SUCCESS {
			println("miniaudio: failed to initialize audio engine, with error:", ma_result)
			return
		}
		ma_result = ma.engine_play_sound(&audio_engine, transmute(cstring) raw_data(files_to_open[files_index]), nil)
		if ma_result != .SUCCESS {
			println("miniaudio: failed to play sound, with error:", ma_result)
			return
		}
	} defer ma.engine_uninit(&audio_engine)

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
	playing := true
	was_paused := paused
	start_start_time := time.now()
	pause_start_time: time.Time
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
				winfo.hi.tex[10*winfo.hi.size.x + x] = soggy.RED
			}
			first_frame = false
			
			{/* draw the queue */
//				txt := "word"
//				w := winfo.hi
//				soggy.draw_bitfont_text(w, {winfo
			
			}
		}

		playing = len(audio.signal) > bindex*stride
		if playing && !paused {
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
			winfo.hi.tex[10*winfo.hi.size.x + (winfo.hi.size.x*i32(bindex))/i32(amount_of_bins)] = soggy.RED
			winfo.hi.tex[11*winfo.hi.size.x + (winfo.hi.size.x*i32(bindex))/i32(amount_of_bins)] = soggy.RED
			winfo.hi.tex[9*winfo.hi.size.x + (winfo.hi.size.x*i32(bindex))/i32(amount_of_bins)] = soggy.RED
		}

		if !was_paused && paused {
			ma.engine_stop(&audio_engine)
			pause_start_time = time.now()
		}
		if was_paused && !paused {
			ma.engine_start(&audio_engine)
			start_start_time = time.time_add(start_start_time, time.since(pause_start_time))
		}
		was_paused = paused
		if !paused {
			bindex += 1
			time_to_sleep := bin_time - (time.since(start_start_time) - bin_time*time.Duration(bindex - 1))
			for time_to_sleep < 0 {
				println("frame took too long:", time_to_sleep)
				time_to_sleep += bin_time
				bindex += 1
			}
//			println(bin_time - time_to_sleep, bin_time)
			time.sleep(time_to_sleep)
		}

		if !playing {
			files_index += 1
			if wait_for_files_or_exit(winfo) do return
			first_frame = true
			/* load new audio */
			delete(audio.signal)
			audio, success = wav.read_wav(files_to_open[files_index])
			piece = wav.Audio{sample_freq = audio.sample_freq}
			if !success do return
			/* play new audio */
			ma_result := ma.engine_play_sound(&audio_engine, transmute(cstring) raw_data(files_to_open[files_index]), nil)
			if ma_result != .SUCCESS {
				println("miniaudio: failed to play sound, with error:", ma_result)
				return
			}
			bindex = 0
			start_start_time = time.now()
		}
	}

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
