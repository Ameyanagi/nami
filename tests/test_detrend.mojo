from nami import DetrendKind, detrend
from std.collections import List
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


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
