from nami import ConvolutionMode, convolve, correlate
from std.collections import List
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def assert_near(actual: Float64, expected: Float64, tolerance: Float64 = 1e-12) raises:
    assert_true(
        abs(actual - expected) <= tolerance,
        msg="correlation value differs from reference",
    )


def assert_values_near(actual: List[Float64], expected: List[Float64]) raises:
    assert_equal(len(actual), len(expected))
    for index in range(len(actual)):
        assert_near(actual[index], expected[index])


def fixture_signal() -> List[Float64]:
    return [0.5, -1.25, 2.0, 3.5, -0.75, 1.5]


def fixture_kernel_odd() -> List[Float64]:
    return [1.0, -2.0, 0.5]


def fixture_kernel_even() -> List[Float64]:
    return [0.25, -1.0, 2.0, 0.5]


def test_odd_kernel_scipy_fixtures() raises:
    var signal = fixture_signal()
    var kernel = fixture_kernel_odd()
    assert_values_near(
        correlate(signal, kernel),
        [0.25, -1.625, 4.0, -3.5, -5.375, 5.75, -3.75, 1.5],
    )
    assert_values_near(
        correlate(signal, kernel, ConvolutionMode.SAME),
        [-1.625, 4.0, -3.5, -5.375, 5.75, -3.75],
    )
    assert_values_near(
        correlate(signal, kernel, ConvolutionMode.VALID),
        [4.0, -3.5, -5.375, 5.75],
    )


def test_even_kernel_scipy_fixtures() raises:
    var signal = fixture_signal()
    var kernel = fixture_kernel_even()
    assert_values_near(
        correlate(signal, kernel),
        [0.25, 0.375, -2.0, 7.125, 4.3125, -3.75, 4.625, -1.6875, 0.375],
    )
    assert_values_near(
        correlate(signal, kernel, ConvolutionMode.SAME),
        [0.375, -2.0, 7.125, 4.3125, -3.75, 4.625],
    )
    assert_values_near(
        correlate(signal, kernel, ConvolutionMode.VALID),
        [7.125, 4.3125, -3.75],
    )


def assert_matches_reversed_convolution(
    signal: List[Float64], kernel: List[Float64]
) raises:
    var reversed_kernel = List[Float64](capacity=len(kernel))
    for index in range(len(kernel)):
        reversed_kernel.append(kernel[len(kernel) - index - 1])

    assert_values_near(
        correlate(signal, kernel),
        convolve(signal, reversed_kernel),
    )
    assert_values_near(
        correlate(signal, kernel, ConvolutionMode.SAME),
        convolve(signal, reversed_kernel, ConvolutionMode.SAME),
    )
    assert_values_near(
        correlate(signal, kernel, ConvolutionMode.VALID),
        convolve(signal, reversed_kernel, ConvolutionMode.VALID),
    )


def test_correlation_equals_convolution_with_reversed_kernel() raises:
    var signal = fixture_signal()
    var odd = fixture_kernel_odd()
    var even = fixture_kernel_even()
    assert_matches_reversed_convolution(signal, odd)
    assert_matches_reversed_convolution(signal, even)


def test_full_output_index_encodes_positive_impulse_lag() raises:
    var shift = 2
    var signal: List[Float64] = [0.0, 0.0, 0.0, 1.0, 0.0, 0.0]
    var kernel: List[Float64] = [0.0, 1.0, 0.0]
    var result = correlate(signal, kernel)
    var peak_index = 0
    for index in range(1, len(result)):
        if result[index] > result[peak_index]:
            peak_index = index
    assert_equal(peak_index, len(kernel) - 1 + shift)
    assert_equal(result[peak_index], 1.0)


def test_empty_inputs_are_rejected() raises:
    var empty = List[Float64]()
    var value: List[Float64] = [1.0]
    with assert_raises(
        contains="convolution signal must be non-empty; got signal_length=0"
    ):
        _ = correlate(empty, value)
    with assert_raises(
        contains="convolution kernel must be non-empty; got kernel_length=0"
    ):
        _ = correlate(value, empty)


def test_nonfinite_input_is_rejected() raises:
    var finite: List[Float64] = [1.0, 2.0]
    var nonfinite: List[Float64] = [Float64("nan")]
    with assert_raises(
        contains="convolution kernel must contain only finite values; got kernel[0]=nan"
    ):
        _ = correlate(finite, nonfinite)


def test_valid_mode_reports_signal_and_kernel_lengths() raises:
    var signal: List[Float64] = [1.0]
    var kernel: List[Float64] = [1.0, 2.0]
    with assert_raises(
        contains=(
            "valid convolution requires kernel length <= signal length; got "
            "kernel=2, signal=1"
        )
    ):
        _ = correlate(signal, kernel, ConvolutionMode.VALID)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
