from nami.spectral import spectrogram
from std.collections import List
from std.math import pi, sin


def main() raises:
    var sample_rate = 128.0
    var samples = List[Float64](capacity=512)
    for index in range(512):
        var frequency = 8.0 if index < 256 else 24.0
        samples.append(sin(2.0 * pi * frequency * Float64(index) / sample_rate))

    var result = spectrogram(
        samples,
        sample_rate,
        segment_length=128,
        overlap=64,
    )
    var times = result.times()
    var frequencies = result.frequencies()
    var power = result.power()
    for frame_index in range(result.frame_count()):
        var strongest_bin = 0
        var frame_offset = frame_index * result.bin_count()
        for bin_index in range(1, result.bin_count()):
            if power[frame_offset + bin_index] > power[frame_offset + strongest_bin]:
                strongest_bin = bin_index
        print(times[frame_index], "s:", frequencies[strongest_bin], "Hz")
