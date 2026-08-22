from nami import ConvolutionMode, convolve, correlate
from nami.convolution import _convolve_core, _convolve_core_scalar, _output_length
from std.collections import List
from std.sys import simd_width_of
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def assert_near(actual: Float64, expected: Float64, tolerance: Float64 = 1e-12) raises:
    assert_true(
        abs(actual - expected) <= tolerance,
        msg="convolution value differs from reference",
    )


def assert_values_near(actual: List[Float64], expected: List[Float64]) raises:
    assert_equal(len(actual), len(expected))
    for index in range(len(actual)):
        assert_near(actual[index], expected[index])


def assert_values_equal(actual: List[Float64], expected: List[Float64]) raises:
    assert_equal(len(actual), len(expected))
    for index in range(len(actual)):
        assert_equal(actual[index], expected[index])


def values3(a: Float64, b: Float64, c: Float64) -> List[Float64]:
    return [a, b, c]


def test_reference_values_for_all_output_modes() raises:
    var signal = values3(1.0, 2.0, 3.0)
    var kernel: List[Float64] = [4.0, 5.0]
    assert_values_near(convolve(signal, kernel), [4.0, 13.0, 22.0, 15.0])
    assert_values_near(
        convolve(signal, kernel, ConvolutionMode.SAME),
        [4.0, 13.0, 22.0],
    )
    assert_values_near(
        convolve(signal, kernel, ConvolutionMode.VALID),
        [13.0, 22.0],
    )


def test_same_uses_left_center_for_even_kernel_of_length_four() raises:
    var signal: List[Float64] = [1.0, 2.0, 3.0, 4.0, 5.0]
    var kernel: List[Float64] = [1.0, 10.0, 100.0, 1000.0]
    assert_values_near(
        convolve(signal, kernel, ConvolutionMode.SAME),
        [12.0, 123.0, 1234.0, 2345.0, 3450.0],
    )


def test_same_even_kernel_longer_than_signal_keeps_first_input_length() raises:
    var signal: List[Float64] = [1.0, 2.0]
    var kernel: List[Float64] = [1.0, 10.0, 100.0, 1000.0]
    assert_values_near(
        convolve(signal, kernel, ConvolutionMode.SAME),
        [12.0, 120.0],
    )


def test_first_input_controls_same_and_valid_when_inputs_are_swapped() raises:
    var longer = values3(1.0, 2.0, 3.0)
    var shorter: List[Float64] = [4.0, 5.0]
    assert_values_near(
        convolve(longer, shorter, ConvolutionMode.SAME),
        [4.0, 13.0, 22.0],
    )
    assert_values_near(
        convolve(shorter, longer, ConvolutionMode.SAME),
        [13.0, 22.0],
    )
    assert_values_near(
        convolve(longer, shorter, ConvolutionMode.VALID),
        [13.0, 22.0],
    )
    with assert_raises(
        contains=(
            "valid convolution requires kernel length <= signal length; got "
            "kernel=3, signal=2"
        )
    ):
        _ = convolve(shorter, longer, ConvolutionMode.VALID)


def test_full_convolution_is_commutative() raises:
    var signal = values3(-1.0, 2.5, 4.0)
    var kernel: List[Float64] = [0.5, -3.0]
    assert_values_near(convolve(signal, kernel), convolve(kernel, signal))


def test_unit_impulse_preserves_signal_in_every_mode() raises:
    var signal = values3(-2.0, 0.5, 7.0)
    var impulse: List[Float64] = [1.0]
    assert_values_near(convolve(signal, impulse), signal)
    assert_values_near(convolve(signal, impulse, ConvolutionMode.SAME), signal)
    assert_values_near(convolve(signal, impulse, ConvolutionMode.VALID), signal)


def test_constant_reference_and_input_ownership() raises:
    var signal = values3(1.0, 1.0, 1.0)
    var kernel: List[Float64] = [1.0, 1.0]
    assert_values_near(convolve(signal, kernel), [1.0, 2.0, 2.0, 1.0])
    assert_values_near(signal, [1.0, 1.0, 1.0])
    assert_values_near(kernel, [1.0, 1.0])


def test_output_shape_contract() raises:
    assert_equal(_output_length(5, 3, ConvolutionMode.FULL), 7)
    assert_equal(_output_length(5, 3, ConvolutionMode.SAME), 5)
    assert_equal(_output_length(5, 3, ConvolutionMode.VALID), 3)
    assert_equal(_output_length(4, 2, ConvolutionMode.SAME), 4)


def test_empty_inputs_are_rejected() raises:
    var empty = List[Float64]()
    var value: List[Float64] = [1.0]
    with assert_raises(
        contains="convolution signal must be non-empty; got signal_length=0"
    ):
        _ = convolve(empty, value)
    with assert_raises(
        contains="convolution kernel must be non-empty; got kernel_length=0"
    ):
        _ = convolve(value, empty)


def test_valid_mode_rejects_kernel_longer_than_signal() raises:
    var signal: List[Float64] = [1.0, 2.0]
    var kernel = values3(1.0, 1.0, 1.0)
    with assert_raises(
        contains=(
            "valid convolution requires kernel length <= signal length; got "
            "kernel=3, signal=2"
        )
    ):
        _ = convolve(signal, kernel, ConvolutionMode.VALID)


def test_nonfinite_inputs_and_results_are_rejected() raises:
    var finite: List[Float64] = [1.0, 2.0]
    var nonfinite_signal: List[Float64] = [Float64("nan")]
    with assert_raises(
        contains="convolution signal must contain only finite values; got signal[0]=nan"
    ):
        _ = convolve(nonfinite_signal, finite)

    var correlation_kernel: List[Float64] = [1.0, Float64("nan"), 2.0]
    with assert_raises(
        contains="convolution kernel must contain only finite values; got kernel[1]=nan"
    ):
        _ = correlate(finite, correlation_kernel)

    var huge: List[Float64] = [1e308]
    var two: List[Float64] = [2.0]
    with assert_raises(contains="got output[0]="):
        _ = convolve(huge, two)


def test_simd_core_matches_scalar_for_chunks_tails_and_modes() raises:
    var signal: List[Float64] = [
        0.25,
        -1.5,
        2.0,
        0.75,
        -0.125,
        4.0,
        -2.5,
        1.25,
        0.5,
        -0.75,
        3.0,
    ]
    var kernel: List[Float64] = [0.2, -0.5, 0.75, 1.25, -0.125]
    for mode in [ConvolutionMode.FULL, ConvolutionMode.SAME, ConvolutionMode.VALID]:
        assert_values_near(
            convolve(signal, kernel, mode),
            _convolve_core_scalar(signal, kernel, mode),
        )

    var one: List[Float64] = [1.5]
    assert_values_near(
        convolve(signal, one), _convolve_core_scalar(signal, one, ConvolutionMode.FULL)
    )


def test_simd_core_matches_scalar_exactly_for_randomized_native_width_cases() raises:
    comptime width = simd_width_of[DType.float64]()
    var kernel_lengths = List[Int]()
    kernel_lengths.append(1)
    if width > 1:
        kernel_lengths.append(width - 1)
    kernel_lengths.append(width)
    kernel_lengths.append(width + 1)
    kernel_lengths.append(2 * width - 1)
    kernel_lengths.append(2 * width)
    kernel_lengths.append(2 * width + 1)

    for case_index in range(len(kernel_lengths)):
        var kernel_length = kernel_lengths[case_index]
        var signal_length = kernel_length + 11
        var signal = List[Float64](capacity=signal_length)
        var kernel = List[Float64](capacity=kernel_length)
        for index in range(signal_length):
            var numerator = (index * 37 + case_index * 11) % 29 - 14
            signal.append(Float64(numerator) / 8.0)
        for index in range(kernel_length):
            var numerator = (index * 19 + case_index * 7) % 23 - 11
            kernel.append(Float64(numerator) / 16.0)

        for mode in [
            ConvolutionMode.FULL,
            ConvolutionMode.SAME,
            ConvolutionMode.VALID,
        ]:
            var scalar = _convolve_core_scalar(signal, kernel, mode)
            assert_values_equal(_convolve_core(signal, kernel, mode), scalar)
            assert_values_equal(convolve(signal, kernel, mode), scalar)


def test_correlate_matches_reversed_scalar_for_simd_chunks_tails_and_modes() raises:
    comptime width = simd_width_of[DType.float64]()
    for kernel_length in [width, width + 1, 2 * width + 1]:
        var signal_length = kernel_length + 9
        var signal = List[Float64](capacity=signal_length)
        var kernel = List[Float64](capacity=kernel_length)
        var reversed_kernel = List[Float64](capacity=kernel_length)
        for index in range(signal_length):
            signal.append(Float64((index * 13) % 17 - 8) / 8.0)
        for index in range(kernel_length):
            kernel.append(Float64((index * 7) % 13 - 6) / 4.0)
        for index in range(kernel_length):
            reversed_kernel.append(kernel[kernel_length - index - 1])

        for mode in [
            ConvolutionMode.FULL,
            ConvolutionMode.SAME,
            ConvolutionMode.VALID,
        ]:
            assert_values_equal(
                correlate(signal, kernel, mode),
                _convolve_core_scalar(signal, reversed_kernel, mode),
            )


def test_simd_and_scalar_overflow_paths_reject_nonfinite_results() raises:
    var signal: List[Float64] = [1e308, 1.0, 1.0]
    var kernel: List[Float64] = [2.0, 1.0, 1.0, 1.0, 1.0]
    with assert_raises(contains="got output[0]="):
        _ = convolve(signal, kernel)
    with assert_raises(contains="got output[0]="):
        _ = _convolve_core_scalar(signal, kernel, ConvolutionMode.FULL)


def test_vector_tail_and_correlation_overflow_paths_match_across_modes() raises:
    comptime width = simd_width_of[DType.float64]()
    var length = width + 1
    var signal = List[Float64](length=length, fill=0.0)
    signal[0] = 1e308
    var vector_kernel = List[Float64](length=length, fill=0.0)
    vector_kernel[0] = 2.0
    var tail_kernel = List[Float64](length=length, fill=0.0)
    tail_kernel[width] = 2.0
    var correlation_vector_kernel = List[Float64](length=length, fill=0.0)
    correlation_vector_kernel[width] = 2.0
    var correlation_tail_kernel = List[Float64](length=length, fill=0.0)
    correlation_tail_kernel[0] = 2.0
    var reversed_correlation_vector_kernel = List[Float64](capacity=length)
    var reversed_correlation_tail_kernel = List[Float64](capacity=length)
    for index in range(length):
        reversed_correlation_vector_kernel.append(
            correlation_vector_kernel[length - index - 1]
        )
        reversed_correlation_tail_kernel.append(
            correlation_tail_kernel[length - index - 1]
        )

    for mode in [
        ConvolutionMode.FULL,
        ConvolutionMode.SAME,
        ConvolutionMode.VALID,
    ]:
        with assert_raises(contains="got output[0]="):
            _ = convolve(signal, vector_kernel, mode)
        with assert_raises(contains="got output[0]="):
            _ = _convolve_core_scalar(signal, vector_kernel, mode)
        with assert_raises(contains=String("got output[", width, "]=")):
            _ = convolve(signal, tail_kernel, mode)
        with assert_raises(contains=String("got output[", width, "]=")):
            _ = _convolve_core_scalar(signal, tail_kernel, mode)
        with assert_raises(contains="got output[0]="):
            _ = correlate(signal, correlation_vector_kernel, mode)
        with assert_raises(contains="got output[0]="):
            _ = _convolve_core_scalar(signal, reversed_correlation_vector_kernel, mode)
        with assert_raises(contains=String("got output[", width, "]=")):
            _ = correlate(signal, correlation_tail_kernel, mode)
        with assert_raises(contains=String("got output[", width, "]=")):
            _ = _convolve_core_scalar(signal, reversed_correlation_tail_kernel, mode)


def test_output_length_overflow_is_rejected_without_allocation() raises:
    with assert_raises(
        contains=(
            "convolution output length overflows Int; got signal_length="
            "9223372036854775807, kernel_length=2"
        )
    ):
        _ = _output_length(Int.MAX, 2, ConvolutionMode.FULL)
    with assert_raises(
        contains="got signal_length=9223372036854775807, kernel_length=2"
    ):
        _ = _output_length(Int.MAX, 2, ConvolutionMode.SAME)
    with assert_raises(
        contains="got signal_length=9223372036854775807, kernel_length=2"
    ):
        _ = _output_length(Int.MAX, 2, ConvolutionMode.VALID)


def test_explicit_mode_validation_rejects_corrupted_storage() raises:
    var mode = ConvolutionMode.FULL
    mode._value = 3
    with assert_raises(
        contains=(
            "ConvolutionMode _value must be 0 (FULL), 1 (SAME), or 2 (VALID); "
            "got _value=3"
        )
    ):
        mode.validate()

    var signal: List[Float64] = [1.0, 2.0]
    var kernel: List[Float64] = [1.0]
    with assert_raises(contains="got _value=3"):
        _ = convolve(signal, kernel, mode)
    with assert_raises(contains="got _value=3"):
        _ = correlate(signal, kernel, mode)
    with assert_raises(contains="got _value=3"):
        _ = _output_length(2, 1, mode)
    assert_equal(String(mode), "INVALID(_value=3)")


def test_mode_constants_are_distinct() raises:
    assert_true(ConvolutionMode.FULL != ConvolutionMode.SAME)
    assert_true(ConvolutionMode.FULL != ConvolutionMode.VALID)
    assert_true(ConvolutionMode.SAME != ConvolutionMode.VALID)


def test_mode_writes_constant_names() raises:
    assert_equal(String(ConvolutionMode.FULL), "FULL")
    assert_equal(String(ConvolutionMode.SAME), "SAME")
    assert_equal(String(ConvolutionMode.VALID), "VALID")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
