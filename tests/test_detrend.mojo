from nami import DetrendKind, detrend
from std.collections import List
from std.math import ldexp
from std.memory import bitcast
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def assert_near(actual: Float64, expected: Float64, tolerance: Float64 = 1e-12) raises:
    assert_true(
        abs(actual - expected) <= tolerance,
        msg="detrend value differs from reference",
    )


def assert_values_near(actual: List[Float64], expected: List[Float64]) raises:
    assert_equal(len(actual), len(expected))
    for index in range(len(actual)):
        assert_near(actual[index], expected[index])


def fixture_signal() -> List[Float64]:
    return [1.2, 3.4, 2.8, 5.9, 4.1, 6.3, 8.0, 7.2]


def test_scipy_constant_fixture() raises:
    var signal = fixture_signal()
    assert_values_near(
        detrend(signal, DetrendKind.CONSTANT),
        [
            -3.6624999999999996,
            -1.4625,
            -2.0625,
            1.0375000000000005,
            -0.7625000000000002,
            1.4375,
            3.1375,
            2.3375000000000004,
        ],
    )


def test_scipy_linear_fixture() raises:
    var signal = fixture_signal()
    assert_values_near(
        detrend(signal),
        [
            -0.5916666666666668,
            0.7309523809523806,
            -0.7464285714285723,
            1.4761904761904763,
            -1.2011904761904777,
            0.12142857142856922,
            0.9440476190476179,
            -0.7333333333333352,
        ],
    )


def test_linear_kind_removes_an_exact_line() raises:
    var signal: List[Float64] = [2.5, 1.75, 1.0, 0.25, -0.5]
    assert_values_near(detrend(signal), [0.0, 0.0, 0.0, 0.0, 0.0])


def test_constant_kind_removes_a_constant_signal() raises:
    var signal: List[Float64] = [3.25, 3.25, 3.25, 3.25]
    assert_values_near(
        detrend(signal, DetrendKind.CONSTANT),
        [0.0, 0.0, 0.0, 0.0],
    )


def test_constant_result_has_zero_mean() raises:
    var signal = fixture_signal()
    var result = detrend(signal, DetrendKind.CONSTANT)
    var total = 0.0
    for index in range(len(result)):
        total += result[index]
    assert_near(total / Float64(len(result)), 0.0)


def test_single_sample_returns_zero_for_both_kinds() raises:
    var signal: List[Float64] = [4.5]
    assert_values_near(detrend(signal), [0.0])
    assert_values_near(detrend(signal, DetrendKind.CONSTANT), [0.0])


def test_empty_and_nonfinite_inputs_are_rejected() raises:
    var empty = List[Float64]()
    with assert_raises(
        contains="detrend signal must be non-empty; got signal_length=0"
    ):
        _ = detrend(empty)

    var nonfinite: List[Float64] = [1.0, Float64("nan")]
    with assert_raises(
        contains="detrend signal must contain only finite values; got signal[1]=nan"
    ):
        _ = detrend(nonfinite)


def test_kind_constants_are_distinct_and_writable() raises:
    assert_true(DetrendKind.CONSTANT != DetrendKind.LINEAR)
    assert_equal(String(DetrendKind.CONSTANT), "CONSTANT")
    assert_equal(String(DetrendKind.LINEAR), "LINEAR")


def test_explicit_kind_validation_rejects_corrupted_storage() raises:
    var kind = DetrendKind.LINEAR
    kind._value = 2
    with assert_raises(
        contains="DetrendKind _value must be 0 (CONSTANT) or 1 (LINEAR); got _value=2"
    ):
        kind.validate()
    assert_equal(String(kind), "INVALID(_value=2)")


def test_detrend_rejects_corrupted_kind_at_public_boundary() raises:
    var kind = DetrendKind.LINEAR
    kind._value = -1
    var signal: List[Float64] = [1.0, 2.0]
    with assert_raises(
        contains="DetrendKind _value must be 0 (CONSTANT) or 1 (LINEAR); got _value=-1"
    ):
        _ = detrend(signal, kind)


def test_near_maximum_constants_and_cancellation_stay_finite() raises:
    for magnitude in [1e308, -1e308, Float64("1.7976931348623157e308")]:
        var signal = List[Float64](length=8, fill=magnitude)
        for kind in [DetrendKind.CONSTANT, DetrendKind.LINEAR]:
            var result = detrend(signal, kind)
            for value in result:
                assert_equal(value, 0.0)
    var opposite: List[Float64] = [1e308, -1e308]
    var centered = detrend(opposite, DetrendKind.CONSTANT)
    assert_equal(centered[0], 1e308)
    assert_equal(centered[1], -1e308)
    assert_values_near(detrend(opposite), [0.0, 0.0])


def test_compensated_centering_retains_small_cancellation_term() raises:
    var signal: List[Float64] = [1e308, 1.0, -1e308]
    var result = detrend(signal, DetrendKind.CONSTANT)
    assert_near(result[1], 2.0 / 3.0)


def test_extreme_linear_fit_avoids_unrepresentable_intermediate_slope() raises:
    var line: List[Float64] = [-1e308, -5e307, 0.0, 5e307, 1e308]
    assert_values_near(detrend(line), [0.0, 0.0, 0.0, 0.0, 0.0])
    var symmetric: List[Float64] = [1e308, -1e308, -1e308, 1e308]
    for kind in [DetrendKind.CONSTANT, DetrendKind.LINEAR]:
        var result = detrend(symmetric, kind)
        for index in range(4):
            assert_equal(result[index], symmetric[index])


def test_mathematically_unrepresentable_detrend_residual_raises() raises:
    var signal: List[Float64] = [1.7e308, -1.7e308, -1.7e308]
    with assert_raises(contains="detrend result[0] is outside finite Float64"):
        _ = detrend(signal, DetrendKind.CONSTANT)
    var curved: List[Float64] = [-1.7e308, 1.7e308, -1.7e308]
    with assert_raises(contains="detrend result[1] is outside finite Float64"):
        _ = detrend(curved, DetrendKind.LINEAR)


def test_mixed_scale_constant_preserves_small_residual_in_every_order() raises:
    for tiny in [1e-308, -1e-308, 1e-100, Float64("5e-324")]:
        for tiny_index in range(3):
            for sign in [1.0, -1.0]:
                var signal = List[Float64](length=3, fill=tiny)
                signal[(tiny_index + 1) % 3] = sign * 1e308
                signal[(tiny_index + 2) % 3] = -sign * 1e308
                var result = detrend(signal, DetrendKind.CONSTANT)
                assert_true(
                    abs(result[tiny_index] / tiny - (tiny * (2.0 / 3.0)) / tiny) < 1e-14
                )


def test_mixed_scale_linear_retains_small_center_on_extreme_line() raises:
    for tiny in [1e-308, -1e-308, 1e-100, Float64("5e-324")]:
        var signal: List[Float64] = [1e308, tiny, -1e308]
        var result = detrend(signal, DetrendKind.LINEAR)
        assert_true(abs(result[1] / tiny - (tiny * (2.0 / 3.0)) / tiny) < 1e-14)
        assert_equal(result[0], -tiny / 3.0)
        assert_equal(result[2], -tiny / 3.0)


def test_mixed_scale_subnormal_centering_rounds_after_subtraction() raises:
    var tiny = Float64("5e-324")
    var signal: List[Float64] = [1e308, -1e308, tiny, tiny]
    var result = detrend(signal, DetrendKind.CONSTANT)
    # Both exact small residuals are half the minimum subnormal and tie to zero.
    assert_equal(result[2], 0.0)
    assert_equal(result[3], 0.0)


def test_mixed_scale_cancellation_across_multiple_exponent_bands() raises:
    var signal: List[Float64] = [1e308, -1e308, 1e100, -1e100, 1e-100, -1e-100, 1e-308]
    var result = detrend(signal, DetrendKind.CONSTANT)
    assert_true(abs(result[6] / 1e-308 - 6.0 / 7.0) < 1e-14)


def test_wide_range_keeps_overflow_relevant_values_in_one_band() raises:
    var signal: List[Float64] = [1.7e308, -1.7e308, -1.7e308, 8e307, 8e307, 1e-308]
    var result = detrend(signal, DetrendKind.CONSTANT)
    var expected: List[Float64] = [
        1.7 + 1.0 / 60.0,
        -1.7 + 1.0 / 60.0,
        -1.7 + 1.0 / 60.0,
        0.8 + 1.0 / 60.0,
        0.8 + 1.0 / 60.0,
        1.0 / 60.0,
    ]
    for index in range(len(signal)):
        assert_true(abs(result[index] / 1e308 - expected[index]) < 1e-14)
    var unrepresentable: List[Float64] = [1.7e308, -1.7e308, -1.7e308, 1e-308]
    with assert_raises(contains="detrend result[0] is outside finite Float64"):
        _ = detrend(unrepresentable, DetrendKind.CONSTANT)


def test_mean_is_not_rounded_before_residual_cancellation() raises:
    var large = ldexp(Float64(1.0), Int32(1020))
    var tiny = ldexp(Float64(1.0), Int32(900))
    var signal: List[Float64] = [large, 2.0 * large, 2.0 * large, 0.0, tiny]
    var result = detrend(signal, DetrendKind.CONSTANT)
    assert_true(abs(result[0] / tiny + 0.2) < 1e-14)


def test_nested_cancellation_retains_more_than_one_compensation_level() raises:
    var signal: List[Float64] = [1.0, 1e-20, 1e-40, -1e-20, -1.0]
    var result = detrend(signal, DetrendKind.CONSTANT)
    assert_true(abs(result[2] / 1e-40 - 0.8) < 1e-14)


def test_power_of_two_scaling_preserves_near_maximum_adjacent_values() raises:
    var lower = Float64(1e308)
    var upper = bitcast[DType.float64](bitcast[DType.uint64](lower) + UInt64(1))
    var signal: List[Float64] = [lower, upper]
    var result = detrend(signal, DetrendKind.CONSTANT)
    var half_difference = (upper - lower) / 2.0
    assert_equal(result[0], -half_difference)
    assert_equal(result[1], half_difference)


def test_cross_band_cancellation_precedes_common_division() raises:
    var medium = ldexp(Float64(1.0), Int32(769))
    var tiny = ldexp(Float64(1.0), Int32(600))
    var large = ldexp(Float64(1.0), Int32(1023))
    var lower = ldexp(Float64(1.0), Int32(-1000))
    var signal: List[Float64] = [
        medium / 2.0,
        3.5 * medium,
        0.0,
        0.0,
        tiny,
        large,
        -large,
        lower,
    ]
    var result = detrend(signal, DetrendKind.CONSTANT)
    assert_true(abs(result[0] / tiny + 1.0 / 8.0) < 1e-14)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
