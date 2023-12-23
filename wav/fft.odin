package wav

peak :: proc(fted: Audio) -> (peak_freq: f32, peak_index: int) {
	maxf: f32
	maxi: int
	for f, i in fted.signal do if f > maxf { maxf = f; maxi = i }
	return f32(maxi)*f32(fted.sample_freq)/f32(len(fted.signal)), maxi
}

fft :: proc{ complex_fft, real_fft }

/* this takes two-channel input data and does the casting to float and such all by itself */
complex_fft :: proc(a: [][2]i16, power: uint, freqsi: []complex64 = nil, freqs: []f32 = nil) -> []f32 {
	freqsi := freqsi; freqs := freqs
	bin_size := uint(1 << power)
	assert(bin_size <= uint(len(a)))

	new_freqsi := freqsi == nil
	if new_freqsi do freqsi = make([]complex64, bin_size)
	defer if new_freqsi do delete(freqsi)

	for it in 0..<bin_size {
		freqsi[bit_reverse(it, power)] = complex(f32(a[it][0])/MAX_U15, f32(a[it][1])/MAX_U15)
	}
	// https://en.wikipedia.org/wiki/Cooley%E2%80%93Tukey_FFT_algorithm
	for step in 1..=uint(power) {
		N := 1 << step
		w_N := expi(-math.TAU/f32(N))
		for it := 0; it < int(bin_size); it += N {
			w_p := complex64(1)
			for k in 0..<N/2 {
				E := freqsi[it + k]
				O := w_p*freqsi[it + k + N/2]
				freqsi[it + k] = E + O
				freqsi[it + k + N/2] = E - O
				w_p = w_p*w_N
			}
		}
	}

	if freqs == nil do freqs = make([]f32, bin_size)
	for i in 0..<bin_size {
		freqs[(i + bin_size/2) % bin_size] = abs(freqsi[i])
	}
	return freqs
}

/* this returns a halfsized fft, since the fft of a real signal produces a perfectly mirrored result */
real_fft :: proc(a: Audio, power: uint, freqsi: []complex64 = nil, freqs: []f32 = nil) -> Audio {
	freqsi := freqsi; freqs := freqs
	bin_size := uint(1 << power)
//	assert(bin_size <= uint(len(a.signal)))

	new_freqsi := freqsi == nil
	if new_freqsi do freqsi = make([]complex64, bin_size)
	defer if new_freqsi do delete(freqsi)

	for it in 0..<bin_size {
		sample := a.signal[it] if it < len(a.signal) else 0
		freqsi[bit_reverse(it, power)] = complex(sample, 0)
	}
	// https://en.wikipedia.org/wiki/Cooley%E2%80%93Tukey_FFT_algorithm
	for step in 1..=uint(power) {
		N := 1 << step
		w_N := expi(-math.TAU/f32(N))
		for it := 0; it < int(bin_size); it += N {
			w_p := complex64(1)
			for k in 0..<N/2 {
				E := freqsi[it + k]
				O := w_p*freqsi[it + k + N/2]
				freqsi[it + k] = E + O
				freqsi[it + k + N/2] = E - O
				w_p = w_p*w_N
			}
		}
	}

	if freqs == nil do freqs = make([]f32, bin_size/2) /* we do half, cus it's mirrored past the middle for real values */
	for i in 0..<bin_size/2 {
		freqs[i] = abs(freqsi[i])
	}
	return Audio{ a.sample_freq/2, freqs }	
}

bit_reverse :: proc(n: uint, power: uint) -> (reversed: uint) {
	assert(power < 64)
	for i in 0..<power {
		bit := ((1 << i) & n) >> i
		reversed |= bit << (power - i - 1)
	}
	return reversed
}

import "core:math"
expi :: #force_inline proc(p: f32) -> complex64 {
	return complex(math.cos_f32(p), math.sin_f32(p))
}
