extends Node
class_name SimpleSfx

var enabled := true

func tone(freq: float = 440.0, duration: float = 0.08, volume: float = 0.25, slide: float = 0.0) -> void:
	if not enabled:
		return
	var rate := 22050
	var frames := max(1, int(duration * rate))
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / float(rate)
		var p := float(i) / float(max(1, frames - 1))
		var f := max(40.0, freq + slide * p)
		var env := min(1.0, p * 20.0) * min(1.0, (1.0 - p) * 9.0)
		var sample := sin(TAU * f * t) * volume * env
		var v := int(clamp(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = v & 0xff
		data[i * 2 + 1] = (v >> 8) & 0xff
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	var player := AudioStreamPlayer.new()
	player.stream = wav
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func hit() -> void:
	tone(125.0, 0.11, 0.38, -45.0)

func click() -> void:
	tone(620.0, 0.045, 0.15, 90.0)

func win() -> void:
	tone(520.0, 0.11, 0.22, 180.0)
	await get_tree().create_timer(0.10).timeout
	tone(760.0, 0.17, 0.22, 120.0)
