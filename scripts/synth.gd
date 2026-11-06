class_name Synth
extends RefCounted
## Procedural sound effects so the slice needs no audio files.

const RATE := 22050


static func to_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


static func bell() -> AudioStreamWAV:
	# Inharmonic church-hand-bell partials with long decay.
	var n := int(RATE * 2.4)
	var s := PackedFloat32Array()
	s.resize(n)
	var base := 610.0
	var partials := [[0.5, 0.35, 1.2], [1.0, 0.5, 2.0], [1.19, 0.3, 2.6], [1.56, 0.22, 3.2], [2.0, 0.25, 3.8], [2.66, 0.12, 5.0], [3.01, 0.1, 6.0]]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for p in partials:
			v += sin(TAU * base * p[0] * t) * p[1] * exp(-t * p[2])
		v *= minf(1.0, t * 400.0)
		s[i] = v * 0.55
	return to_wav(s)


static func noise_burst(length: float, decay: float, lowpass: float, gain: float) -> AudioStreamWAV:
	var n := int(RATE * length)
	var s := PackedFloat32Array()
	s.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		y += (randf_range(-1.0, 1.0) - y) * lowpass
		s[i] = y * exp(-t * decay) * gain
	return to_wav(s)


static func gunshot() -> AudioStreamWAV:
	var n := int(RATE * 0.5)
	var s := PackedFloat32Array()
	s.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		y += (randf_range(-1.0, 1.0) - y) * 0.5
		var thump := sin(TAU * 70.0 * t) * exp(-t * 18.0)
		s[i] = (y * exp(-t * 14.0) + thump * 0.8) * 0.9
	return to_wav(s)


static func static_loop() -> AudioStreamWAV:
	var n := int(RATE * 1.0)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var crackle := 0.0
		if randf() < 0.004:
			crackle = randf_range(-1.0, 1.0)
		s[i] = randf_range(-0.35, 0.35) + crackle
	return to_wav(s, true)


static func drone() -> AudioStreamWAV:
	# Low industrial ambience: detuned sines + filtered rumble, loops cleanly.
	var length := 6.0
	var n := int(RATE * length)
	var s := PackedFloat32Array()
	s.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		var lfo := 0.5 + 0.5 * sin(TAU * t / length)
		y += (randf_range(-1.0, 1.0) - y) * 0.02
		var v := sin(TAU * 55.0 * t) * 0.25 + sin(TAU * 55.0 * 1.5 * t) * 0.08 * lfo
		v += sin(TAU * 41.0 * t + sin(TAU * t / 3.0)) * 0.15
		v += y * 1.6
		s[i] = v * 0.5
	return to_wav(s, true)


static func groan() -> AudioStreamWAV:
	var n := int(RATE * 1.2)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 90.0 + 25.0 * sin(TAU * 3.0 * t) - t * 30.0
		ph += TAU * f / RATE
		var env := sin(PI * t / 1.2)
		s[i] = (sin(ph) + 0.5 * sin(ph * 2.01) + randf_range(-0.2, 0.2)) * env * 0.4
	return to_wav(s)


static func blip(freq: float, length: float) -> AudioStreamWAV:
	var n := int(RATE * length)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = (1.0 if sin(TAU * freq * t) > 0.0 else -1.0) * 0.18 * (1.0 - t / length)
	return to_wav(s)


static func heartbeat() -> AudioStreamWAV:
	var n := int(RATE * 0.6)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var a := sin(TAU * 50.0 * t) * exp(-t * 25.0)
		var t2 := maxf(0.0, t - 0.22)
		var b := sin(TAU * 45.0 * t2) * exp(-t2 * 25.0) * (1.0 if t > 0.22 else 0.0)
		s[i] = (a + b * 0.7) * 0.9
	return to_wav(s)
