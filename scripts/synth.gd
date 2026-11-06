class_name Synth
extends RefCounted
## The two sounds with no suitable CC0 recording are synthesised here:
## an old bell telephone ring and a slightly detuned music box.
## Every other sound in the game is a CC0 recording (see CREDITS.md).

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


static func phone_ring() -> AudioStreamWAV:
	# Electromechanical bell: two clapper tones struck 20x a second,
	# 2 s ring + 4 s silence, looping.
	var n := int(RATE * 6.0)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		if t > 2.0:
			s[i] = 0.0
			continue
		var strike := fmod(t, 0.05) / 0.05
		var env := exp(-strike * 3.0) * minf(1.0, t * 40.0) * minf(1.0, (2.0 - t) * 30.0)
		var v := sin(TAU * 1150.0 * t) * 0.6 + sin(TAU * 1360.0 * t) * 0.45 + sin(TAU * 2900.0 * t) * 0.15
		s[i] = v * env * 0.35
	return to_wav(s, true)


static func music_box() -> AudioStreamWAV:
	# A wind-down lullaby: plucked metal tines (inharmonic partials), the
	# mechanism slowing toward the end.
	var notes := [76, 74, 72, 74, 76, 76, 76, 0, 74, 74, 74, 0, 76, 79, 79, 0,
		76, 74, 72, 74, 76, 76, 76, 76, 74, 74, 76, 74, 72, 0, 0, 0]
	var total := 0.0
	var starts: Array = []
	for k in notes.size():
		starts.append(total)
		total += 0.36 * (1.0 + float(k) / notes.size() * 0.6)
	var n := int(RATE * (total + 1.5))
	var s := PackedFloat32Array()
	s.resize(n)
	for k in notes.size():
		if notes[k] == 0:
			continue
		var f := 440.0 * pow(2.0, (float(notes[k]) - 69.0) / 12.0) * 1.003
		var i0 := int(starts[k] * RATE)
		for j in int(RATE * 1.4):
			var i := i0 + j
			if i >= n:
				break
			var t := float(j) / RATE
			var v := sin(TAU * f * t) * exp(-t * 3.0) + sin(TAU * f * 2.76 * t) * 0.3 * exp(-t * 9.0) + sin(TAU * f * 5.4 * t) * 0.12 * exp(-t * 16.0)
			s[i] += v * 0.28 * minf(1.0, t * 2000.0)
	return to_wav(s)
