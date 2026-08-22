from nami import (
    ConvolutionMode,
    DetrendKind,
    PeakWorkspace,
    Peaks,
    WindowSampling,
    correlate,
    convolve,
    detrend,
    find_peaks_into,
    hann,
    savgol_filter,
)
from nami.spectral import periodogram, spectrogram, welch
from std.testing import assert_almost_equal, assert_equal, assert_true


def main() raises:
    var values = hann(4, WindowSampling.PERIODIC)
    assert_equal(len(values), 4)
    assert_true(abs(values[2] - 1.0) <= 1e-12)
    var signal: List[Float64] = [1.0, 2.0, 3.0]
    var kernel: List[Float64] = [1.0, 1.0]
    var filtered = convolve(signal, kernel, ConvolutionMode.VALID)
    assert_equal(len(filtered), 2)
    assert_true(abs(filtered[0] - 3.0) <= 1e-12)

    var correlated = correlate(signal, kernel)
    assert_equal(len(correlated), 4)
    assert_almost_equal(correlated[1], 3.0, atol=1e-12)

    var stationary = detrend(signal, DetrendKind.CONSTANT)
    assert_almost_equal(stationary[0], -1.0, atol=1e-12)
    assert_almost_equal(stationary[2], 1.0, atol=1e-12)

    var quadratic: List[Float64] = [1.0, 4.0, 9.0, 16.0, 25.0]
    var smoothed = savgol_filter(quadratic, 5, 2)
    for index in range(len(quadratic)):
        assert_almost_equal(smoothed[index], quadratic[index], atol=1e-10)

    var peak_signal: List[Float64] = [0.0, 2.0, 0.0, 1.0, 0.0]
    var peaks = Peaks()
    var workspace = PeakWorkspace()
    find_peaks_into(peak_signal, peaks, workspace)
    assert_equal(len(peaks), 2)
    find_peaks_into(peak_signal, peaks, workspace, min_height=1.5)
    assert_equal(len(peaks), 1)
    assert_equal(peaks.indices()[0], 1)

    var spectral_signal: List[Float64] = [0.0, 1.0, 0.0, -1.0, 0.0, 1.0, 0.0, -1.0]
    var direct_spectrum = periodogram(spectral_signal, 8.0)
    assert_equal(len(direct_spectrum), 5)
    var averaged_spectrum = welch(
        spectral_signal,
        8.0,
        segment_length=4,
        overlap=2,
    )
    assert_equal(len(averaged_spectrum), 3)
    var time_frequency = spectrogram(
        spectral_signal,
        8.0,
        segment_length=4,
        overlap=2,
    )
    assert_equal(time_frequency.frame_count(), 3)
    assert_equal(time_frequency.bin_count(), 3)
    assert_equal(len(time_frequency.power()), 9)
