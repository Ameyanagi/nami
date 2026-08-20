from nami import ConvolutionMode, WindowSampling, convolve, hann
from std.testing import assert_equal, assert_true


def main() raises:
    var values = hann(4, WindowSampling.PERIODIC)
    assert_equal(len(values), 4)
    assert_true(abs(values[2] - 1.0) <= 1e-12)
    var filtered = convolve(
        [1.0, 2.0, 3.0],
        [1.0, 1.0],
        ConvolutionMode.VALID,
    )
    assert_equal(len(filtered), 2)
    assert_true(abs(filtered[0] - 3.0) <= 1e-12)
