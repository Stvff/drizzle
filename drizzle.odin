package drizzle

import "soggy"
import "wav"
import "core:fmt"
import "core:slice"
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


	first_frame := true
	for soggy.loop(winfo) {
		if winfo.window_size_changed || first_frame {
			power := cast(uint) log2(cast(int) winfo.lo.size.x)
			bin_size := int(1 << power)

			amount_of_bins := min(int(winfo.lo.size.y - 1), 1 + len(audio.signal) / bin_size)

			piece := audio
			complex_buffer := make([]complex64, bin_size)
			defer delete(complex_buffer)
			fted := wav.Audio{ signal = make([]f32, bin_size/2) }
			defer delete(fted.signal)
		
			slice.fill(winfo.lo.tex, 0)
			for i_y in 0..<amount_of_bins {
				piece.signal = audio.signal[i_y * bin_size:]
				fted = wav.normalize(wav.fft(piece, power, complex_buffer, fted.signal))
	
				index := int(winfo.lo.size.x)*(int(winfo.lo.size.y) - i_y - 1)
				for f, x in fted.signal {
					winfo.lo.tex[index + x] = soggy.mono_colour(u8(255*f))
				}
			}
		}

		first_frame = false
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