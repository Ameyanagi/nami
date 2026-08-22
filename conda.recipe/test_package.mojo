from nami import (
    ConvolutionMode,
    PeakWorkspace,
    Peaks,
    WindowSampling,
    convolve,
    find_peaks_into,
    hann,
)
from std.testing import assert_equal, assert_true


def main() raises:
    var values = hann(4, WindowSampling.PERIODIC)
    assert_equal(len(values), 4)
    assert_true(abs(values[2] - 1.0) <= 1e-12)
    var signal: List[Float64] = [1.0, 2.0, 3.0]
    var kernel: List[Float64] = [1.0, 1.0]
    var filtered = convolve(signal, kernel, ConvolutionMode.VALID)
    assert_equal(len(filtered), 2)
    assert_true(abs(filtered[0] - 3.0) <= 1e-12)
    var peaks = Peaks()
    var workspace = PeakWorkspace()
    find_peaks_into(signal, peaks, workspace)
    assert_equal(len(peaks), 0)
