from nami import ConvolutionMode, convolve
from nami.convolution import _output_length
from std.collections import List
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


def values3(a: Float64, b: Float64, c: Float64) -> List[Float64]:
    return [a, b, c]


def test_reference_values_for_all_output_modes() raises:
    var signal = values3(1.0, 2.0, 3.0)
    var kernel: List[Float64] = [4.0, 5.0]
    assert_values_near(convolve(signal, kernel), [4.0, 13.0, 22.0, 15.0])
    assert_values_near(
        convolve(signal, kernel, ConvolutionMode.same()),
        [4.0, 13.0, 22.0],
    )
    assert_values_near(
        convolve(signal, kernel, ConvolutionMode.valid()),
        [13.0, 22.0],
    )


def test_same_uses_left_center_for_even_kernel_of_length_four() raises:
    var signal: List[Float64] = [1.0, 2.0, 3.0, 4.0, 5.0]
    var kernel: List[Float64] = [1.0, 10.0, 100.0, 1000.0]
    assert_values_near(
        convolve(signal, kernel, ConvolutionMode.same()),
        [12.0, 123.0, 1234.0, 2345.0, 3450.0],
    )


def test_first_input_controls_same_and_valid_when_inputs_are_swapped() raises:
    var longer = values3(1.0, 2.0, 3.0)
    var shorter: List[Float64] = [4.0, 5.0]
    assert_values_near(
        convolve(longer, shorter, ConvolutionMode.same()),
        [4.0, 13.0, 22.0],
    )
    assert_values_near(
        convolve(shorter, longer, ConvolutionMode.same()),
        [13.0, 22.0],
    )
    assert_values_near(
        convolve(longer, shorter, ConvolutionMode.valid()),
        [13.0, 22.0],
    )
    with assert_raises(contains="signal length at least kernel length"):
        _ = convolve(shorter, longer, ConvolutionMode.valid())


def test_full_convolution_is_commutative() raises:
    var signal = values3(-1.0, 2.5, 4.0)
    var kernel: List[Float64] = [0.5, -3.0]
    assert_values_near(convolve(signal, kernel), convolve(kernel, signal))


def test_unit_impulse_preserves_signal_in_every_mode() raises:
    var signal = values3(-2.0, 0.5, 7.0)
    var impulse: List[Float64] = [1.0]
    assert_values_near(convolve(signal, impulse), signal)
    assert_values_near(convolve(signal, impulse, ConvolutionMode.same()), signal)
    assert_values_near(convolve(signal, impulse, ConvolutionMode.valid()), signal)


def test_constant_reference_and_input_ownership() raises:
    var signal = values3(1.0, 1.0, 1.0)
    var kernel: List[Float64] = [1.0, 1.0]
    assert_values_near(convolve(signal, kernel), [1.0, 2.0, 2.0, 1.0])
    assert_values_near(signal, [1.0, 1.0, 1.0])
    assert_values_near(kernel, [1.0, 1.0])


def test_output_shape_contract() raises:
    assert_equal(_output_length(5, 3, ConvolutionMode.full()), 7)
    assert_equal(_output_length(5, 3, ConvolutionMode.same()), 5)
    assert_equal(_output_length(5, 3, ConvolutionMode.valid()), 3)
    assert_equal(_output_length(4, 2, ConvolutionMode.same()), 4)


def test_empty_inputs_are_rejected() raises:
    var empty = List[Float64]()
    var value: List[Float64] = [1.0]
    with assert_raises(contains="convolution inputs must be non-empty"):
        _ = convolve(empty, value)
    with assert_raises(contains="convolution inputs must be non-empty"):
        _ = convolve(value, empty)


def test_valid_mode_rejects_kernel_longer_than_signal() raises:
    var signal: List[Float64] = [1.0, 2.0]
    var kernel = values3(1.0, 1.0, 1.0)
    with assert_raises(contains="signal length at least kernel length"):
        _ = convolve(signal, kernel, ConvolutionMode.valid())


def test_nonfinite_inputs_and_results_are_rejected() raises:
    var finite: List[Float64] = [1.0, 2.0]
    var nonfinite: List[Float64] = [Float64("nan")]
    with assert_raises(contains="inputs must contain only finite values"):
        _ = convolve(finite, nonfinite)

    var huge: List[Float64] = [1e308]
    var two: List[Float64] = [2.0]
    with assert_raises(contains="result must contain only finite values"):
        _ = convolve(huge, two)


def test_output_length_overflow_is_rejected_without_allocation() raises:
    with assert_raises(contains="output length overflows Int"):
        _ = _output_length(Int.MAX, 2, ConvolutionMode.full())


def test_every_reachable_mode_storage_value_is_semantic() raises:
    var mode = ConvolutionMode.full()
    var signal = values3(1.0, 2.0, 3.0)
    var kernel: List[Float64] = [4.0, 5.0]
    mode._selection = None
    assert_true(mode == ConvolutionMode.full())
    assert_values_near(convolve(signal, kernel, mode), [4.0, 13.0, 22.0, 15.0])

    mode._selection = False
    assert_true(mode == ConvolutionMode.same())
    assert_values_near(convolve(signal, kernel, mode), [4.0, 13.0, 22.0])

    mode._selection = True
    assert_true(mode == ConvolutionMode.valid())
    assert_values_near(convolve(signal, kernel, mode), [13.0, 22.0])


def test_mode_factories_are_distinct() raises:
    assert_true(ConvolutionMode.full() != ConvolutionMode.same())
    assert_true(ConvolutionMode.full() != ConvolutionMode.valid())
    assert_true(ConvolutionMode.same() != ConvolutionMode.valid())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
