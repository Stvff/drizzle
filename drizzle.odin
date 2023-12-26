package drizzle

import "soggy"
import "wav"
import "core:fmt"
import "core:slice"
import "core:time"
import "core:os"

import "vendor:raylib"

println :: fmt.println
printf :: fmt.printf

main :: proc() {
	if len(os.args) <= 1 {
		println("give this program a wav file and watch the thing!")
		return
	}

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

	audio, success := wav.read_wav(os.args[1])
	if !success do return
	defer delete(audio.signal)

	raylib.InitAudioDevice()
	defer raylib.CloseAudioDevice()
	soundname := make([]byte, len(os.args[1]) + 1)
	copy(soundname, transmute([]byte) os.args[1])
	rlsound := raylib.LoadSound(transmute(cstring) raw_data(soundname) )
	defer raylib.UnloadSound(rlsound)

	power := cast(uint) log2(cast(int) winfo.lo.size.x)
	bin_size := int(1 << power)
	amount_of_bins := 1 + len(audio.signal) / bin_size
	bindex := 0

	piece := audio
	complex_buffer := make([]complex64, bin_size)
	fted := wav.Audio{ signal = make([]f32, bin_size/2) }
	bin_time := time.Duration(f64(bin_size)/f64(audio.sample_freq)*1e9)
	defer delete(complex_buffer)
	defer delete(fted.signal)

	first_frame := true
	playing := true
	start_start_time := time.now()
	acc: time.Duration = 0
	raylib.PlaySound(rlsound)
	for soggy.loop(winfo) {
		start_time := time.now()
		if winfo.window_size_changed || first_frame {
			power = cast(uint) log2(cast(int) winfo.lo.size.x)
			bin_size = int(1 << power)
			amount_of_bins = 1 + len(audio.signal) / bin_size

			delete(complex_buffer)
			complex_buffer = make([]complex64, bin_size)
			delete(fted.signal)
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
		first_frame = false
		{
			time_to_sleep := bin_time - (time.since(start_start_time) - bin_time*time.Duration(bindex - 1))
			for time_to_sleep < 0 {
				println("frame took too long:", time_to_sleep)
				time_to_sleep += bin_time
				bindex += 1
			}
			time.sleep(time_to_sleep)
		}
//		println((time.since(start_start_time) - bin_time*time.Duration(bindex)))
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
