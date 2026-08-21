from nami import detrend, find_peaks
from nami.spectral import welch
from std.collections import List
from std.math import pi, sin


def main() raises:
    var sample_rate = 800.0
    var samples = List[Float64](capacity=2048)
    for index in range(2048):
        var t = Float64(index) / sample_rate
        samples.append(
            sin(2.0 * pi * 50.0 * t)
            + 0.3 * sin(2.0 * pi * 175.0 * t)
            + 0.002 * Float64(index)
        )

    var stationary = detrend(samples)
    var spectrum = welch(
        stationary,
        sample_rate,
        segment_length=256,
    )
    var peaks = find_peaks(spectrum.power(), min_prominence=0.001)
    var frequencies = spectrum.frequencies()
    var peak_indices = peaks.indices()
    for position in range(len(peaks)):
        print("spectral line:", frequencies[peak_indices[position]], "Hz")
