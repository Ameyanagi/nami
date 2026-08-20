from nami import WindowSampling, hann
from std.testing import assert_equal, assert_true


def main() raises:
    var values = hann(4, WindowSampling.PERIODIC)
    assert_equal(len(values), 4)
    assert_true(abs(values[2] - 1.0) <= 1e-12)
