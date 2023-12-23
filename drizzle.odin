package drizzle

import "soggy"
import "wav"
import "core:fmt"
import "core:slice"
import "core:time"
println :: fmt.println
printf :: fmt.printf

main :: proc() {
	winfo_actual := soggy.Winfo{
		window_title = "drizzle",
		hi_init_size = {1280, 800},
		lo_scale = 1,
		hi_minimum_size = {400, 400},
		draw_on_top = .hi,
	}
	winfo := &winfo_actual
	if !soggy.start(winfo) do return
	defer soggy.exit(winfo)

	audio, success := wav.read_wav("s/fly.wav")
	defer delete(audio.signal)

	power := cast(uint) log2(cast(int) winfo.lo.size.x)
	bin_size := int(1 << power)
	amount_of_bins := 1 + len(audio.signal) / bin_size
	bindex := 0

	piece := audio
	complex_buffer := make([]complex64, bin_size)
	fted := wav.Audio{ signal = make([]f32, bin_size/2) }
	println(f32(bin_size)/f32(audio.sample_freq), "s")
	defer delete(complex_buffer)
	defer delete(fted.signal)

	first_frame := true
	playing := true
	for soggy.loop(winfo) {
		start_time := time.now()
		if winfo.window_size_changed || first_frame {
			power = cast(uint) log2(cast(int) winfo.lo.size.x)
			bin_size = int(1 << power)
//			amount_of_bins = min(int(winfo.lo.size.y - 1), 1 + len(audio.signal) / bin_size)

			complex_buffer := make([]complex64, bin_size)
			fted = wav.Audio{ signal = make([]f32, bin_size/2) }
		
			slice.fill(winfo.lo.tex, 0)
		}

		if playing {
			for y in 0..<int(winfo.lo.size.y) - 1 {
				w := int(winfo.lo.size.x)
				this_line := winfo.lo.tex[w*y : w*y + w]
				next_line := winfo.lo.tex[w*y + w : w*y + 2*w]
				copy(this_line, next_line)
			}

			piece.signal = audio.signal[bindex * bin_size:]
			fted = wav.normalize(wav.fft(piece, power, complex_buffer, fted.signal))
			top_row := int(winfo.lo.size.x)*(int(winfo.lo.size.y) - 1)
			for f, x in fted.signal {
				winfo.lo.tex[top_row + x] = soggy.mono_colour(u8(255*f))
			}
		}

		bindex += 1
		playing = bindex < amount_of_bins
//		println(playing)
		first_frame = false
		println(time.duration_milliseconds(time.since(start_time)), "ms")
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