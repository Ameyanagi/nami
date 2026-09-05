from nami.spectral import SpectralWorkspace, periodogram, welch
from std.collections import List
from std.math import cos, pi, sin
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def _direct_density(
    signal: Span[Float64, _], rate: Float64, windowed: Bool
) -> List[Float64]:
    # Deliberately independent O(n^2) DFT oracle for ordinary finite fixtures.
    var n = len(signal)
    var mean = 0.0
    for value in signal:
        mean += value
    mean /= Float64(n)
    var energy = 0.0
    var values = List[Float64](capacity=n)
    for index in range(n):
        var window = (
            0.5 - 0.5 * cos(2.0 * pi * Float64(index) / Float64(n)) if windowed else 1.0
        )
        energy += window * window
        values.append((signal[index] - mean) * window)
    var result = List[Float64](capacity=n // 2 + 1)
    for bin_index in range(n // 2 + 1):
        var re = 0.0
        var im = 0.0
        for index in range(n):
            var angle = 2.0 * pi * Float64(bin_index * index) / Float64(n)
            re += values[index] * cos(angle)
            im -= values[index] * sin(angle)
        var factor = 1.0 if bin_index == 0 or bin_index == n // 2 else 2.0
        result.append(factor * (re * re + im * im) / (rate * energy))
    return result^


def _assert_near(actual: Span[Float64, _], expected: Span[Float64, _]) raises:
    assert_equal(len(actual), len(expected))
    for index in range(len(actual)):
        assert_true(
            abs(actual[index] - expected[index])
            < 1e-12 * max(1.0, abs(expected[index]))
        )


def test_repeated_periodograms_match_dft_and_preserve_dc_nyquist() raises:
    for size in [2, 4, 8, 16]:
        var workspace = SpectralWorkspace(size)
        var output = List[Float64](length=workspace.bin_count(), fill=-1.0)
        var frequencies = List[Float64](length=workspace.bin_count(), fill=-1.0)
        var signal = List[Float64](length=size, fill=0.0)
        for frame in range(9):
            for index in range(size):
                signal[index] = Float64((index * 7 + frame * 3) % 11) - 5.0
            var expected = _direct_density(signal, Float64(frame + 1), False)
            workspace.periodogram_into(signal, output, Float64(frame + 1))
            workspace.frequencies_into(frequencies, Float64(frame + 1))
            _assert_near(output, expected)
            assert_equal(
                frequencies[workspace.bin_count() - 1], Float64(frame + 1) / 2.0
            )
        workspace.validate()

    var workspace = SpectralWorkspace(4)
    var output = List[Float64](length=3, fill=0.0)
    var nyquist: List[Float64] = [1.0, -1.0, 1.0, -1.0]
    workspace.periodogram_into(nyquist, output)
    assert_equal(output[0], 0.0)
    assert_equal(output[2], 4.0)


def test_repeated_welch_matches_dft_for_every_overlap() raises:
    var workspace = SpectralWorkspace(8)
    var output = List[Float64](length=5, fill=-1.0)
    var signal = List[Float64](length=29, fill=0.0)
    for repeat in range(3):
        for index in range(len(signal)):
            signal[index] = Float64((index * 11 + repeat * 7) % 19) - 9.0
        for overlap in range(8):
            var expected = List[Float64](length=5, fill=0.0)
            var step = 8 - overlap
            var count = (len(signal) - 8) // step + 1
            for frame in range(count):
                var start = frame * step
                var row = _direct_density(signal[start : start + 8], 13.0, True)
                for index in range(5):
                    expected[index] += row[index] / Float64(count)
            workspace.welch_into(signal, output, 13.0, overlap=overlap)
            _assert_near(output, expected)
        var default_result = welch(signal, 13.0, segment_length=8)
        workspace.welch_into(signal, output, 13.0)
        _assert_near(output, default_result.power())
    workspace.validate()


def test_workspace_reuses_scratch_across_estimators_and_numeric_errors() raises:
    var workspace = SpectralWorkspace(4)
    var output = List[Float64](length=3, fill=0.0)
    var signal: List[Float64] = [0.0, 1.0, 0.0, -1.0]
    with assert_raises(contains="spectral density is outside finite Float64"):
        workspace.periodogram_into(signal, output, 1e-308)
    workspace.welch_into(signal, output)
    var expected = _direct_density(signal, 1.0, True)
    _assert_near(output, expected)
    workspace.periodogram_into(signal, output)
    assert_equal(output[1], 2.0)
    assert_equal(workspace.size(), 4)
    assert_equal(workspace.bin_count(), 3)
    assert_equal(String(workspace), "SpectralWorkspace(fft_size=4, bins=3)")
    var equal = SpectralWorkspace(4)
    var different = SpectralWorkspace(8)
    assert_true(workspace == equal)
    assert_true(workspace != different)
    workspace.validate()


def test_workspace_rejects_invalid_inputs_before_output_mutation() raises:
    with assert_raises(contains="nearest are 4 and 8"):
        _ = SpectralWorkspace(6)
    with assert_raises(contains="no larger valid length fits Int"):
        _ = SpectralWorkspace(Int.MAX)
    var workspace = SpectralWorkspace(4)
    var output = List[Float64](length=3, fill=-7.0)
    var signal = List[Float64](length=4, fill=0.0)
    var short = List[Float64](length=2, fill=0.0)
    with assert_raises(contains="fft_size=4; got 2"):
        workspace.periodogram_into(short, output)
    with assert_raises(contains="bin_count=3; got 2"):
        workspace.periodogram_into(signal, short)
    with assert_raises(contains="bin_count=3; got 2"):
        workspace.frequencies_into(short)
    with assert_raises(contains="sample_rate must be positive and finite"):
        workspace.welch_into(signal, output, 0.0)
    with assert_raises(contains="overlap=-1"):
        workspace.welch_into(signal, output, overlap=-1)
    signal[2] = Float64("nan")
    with assert_raises(contains="signal[2]=nan"):
        workspace.periodogram_into(signal, output)
    for value in output:
        assert_equal(value, -7.0)
    workspace._frame.append(0.0)
    with assert_raises(contains="storage must match fft_size"):
        workspace.validate()


def test_welch_average_preserves_subnormal_bins_and_representable_large_average() raises:
    var workspace = SpectralWorkspace(4)
    var output = List[Float64](length=3, fill=0.0)
    var tiny = List[Float64](length=16, fill=0.0)
    for index in range(1, 16, 2):
        tiny[index] = 2e-162 if index % 4 == 1 else -2e-162
    workspace.welch_into(tiny, output, overlap=0)
    assert_equal(output[1], Float64("5e-324"))
    var large: List[Float64] = [0.0, 1.5e308, 0.0, -1.5e308, 0.0, 0.0, 0.0, 0.0]
    # The first individual frame density is 3e308, while its two-frame mean is 1.5e308.
    workspace.welch_into(large, output, 1e308, overlap=0)
    assert_true(abs(output[1] / 1.5e308 - 1.0) < 1e-14)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
