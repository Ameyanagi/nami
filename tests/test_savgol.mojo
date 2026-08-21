from nami import savgol_coefficients, savgol_filter
from std.collections import List
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def assert_near(actual: Float64, expected: Float64, tolerance: Float64 = 1e-10) raises:
    assert_true(
        abs(actual - expected) <= tolerance,
        msg="Savitzky-Golay value differs from reference",
    )


def assert_values_near(
    actual: List[Float64],
    expected: List[Float64],
    tolerance: Float64 = 1e-10,
) raises:
    assert_equal(len(actual), len(expected))
    for index in range(len(actual)):
        assert_near(actual[index], expected[index], tolerance)


def fixture_signal() -> List[Float64]:
    return [2.0, 1.5, 3.2, 4.8, 4.1, 5.5, 7.0, 6.2, 8.1, 9.4, 8.8, 10.5]


def test_scipy_coefficient_fixtures() raises:
    assert_values_near(
        savgol_coefficients(5, 2),
        [
            -0.08571428571428584,
            0.3428571428571426,
            0.4857142857142854,
            0.34285714285714275,
            -0.08571428571428567,
        ],
    )
    assert_values_near(
        savgol_coefficients(7, 3),
        [
            -0.09523809523809956,
            0.14285714285714182,
            0.2857142857142858,
            0.3333333333333336,
            0.285714285714286,
            0.1428571428571441,
            -0.09523809523809094,
        ],
    )
    assert_values_near(
        savgol_coefficients(5, 2, derivative=1, delta=0.5),
        [
            0.3999999999999998,
            0.20000000000000007,
            3.7956885960165205e-16,
            -0.19999999999999965,
            -0.4000000000000001,
        ],
    )
    assert_values_near(
        savgol_coefficients(9, 4, derivative=2),
        [
            -0.07342657342657548,
            0.21620046620046612,
            0.08799533799533779,
            -0.12296037296037371,
            -0.21561771561771675,
            -0.12296037296037385,
            0.0879953379953377,
            0.21620046620046598,
            -0.07342657342657535,
        ],
    )


def test_scipy_filter_window_five_fixture() raises:
    var signal = fixture_signal()
    assert_values_near(
        savgol_filter(signal, 5, 2),
        [
            1.5485714285714296,
            2.4057142857142866,
            3.19142857142857,
            4.234285714285712,
            4.648571428571427,
            5.534285714285711,
            6.365714285714282,
            6.911428571428568,
            7.928571428571425,
            8.928571428571423,
            9.694285714285716,
            10.131428571428572,
        ],
    )


def test_scipy_filter_window_seven_fixture() raises:
    var signal = fixture_signal()
    assert_values_near(
        savgol_filter(signal, 7, 3),
        [
            1.6690476190476202,
            2.323809523809522,
            3.038095238095236,
            3.828571428571405,
            5.033333333333313,
            5.499999999999981,
            6.066666666666647,
            7.280952380952361,
            7.890476190476173,
            8.67857142857143,
            9.485714285714286,
            10.311904761904762,
        ],
    )


def test_filter_reproduces_quadratic_at_interior_and_edges() raises:
    var signal = List[Float64](capacity=12)
    for index in range(12):
        var coordinate = Float64(index)
        signal.append(0.5 + 1.25 * coordinate - 0.3 * coordinate * coordinate)
    assert_values_near(savgol_filter(signal, 5, 2), signal, tolerance=1e-9)


def test_coefficient_sum_invariants() raises:
    var smoothing = savgol_coefficients(7, 3)
    var smoothing_sum = 0.0
    for index in range(len(smoothing)):
        smoothing_sum += smoothing[index]
    assert_near(smoothing_sum, 1.0)

    var first_derivative = savgol_coefficients(5, 2, derivative=1)
    var derivative_sum = 0.0
    for index in range(len(first_derivative)):
        derivative_sum += first_derivative[index]
    assert_near(derivative_sum, 0.0)


def test_invalid_coefficient_parameters_include_values() raises:
    with assert_raises(contains="got window_length=4"):
        _ = savgol_coefficients(4, 2)
    with assert_raises(contains="got poly_order=5, window_length=5"):
        _ = savgol_coefficients(5, 5)
    with assert_raises(contains="got derivative=3, poly_order=2"):
        _ = savgol_coefficients(5, 2, derivative=3)
    with assert_raises(contains="got delta=0"):
        _ = savgol_coefficients(5, 2, delta=0.0)


def test_filter_rejects_short_and_nonfinite_inputs_with_values() raises:
    var short_signal: List[Float64] = [1.0, 2.0, 3.0, 4.0]
    with assert_raises(contains="got signal_length=4, window_length=5"):
        _ = savgol_filter(short_signal, 5, 2)

    var nonfinite: List[Float64] = [1.0, Float64("nan"), 3.0, 4.0, 5.0]
    with assert_raises(contains="got signal[1]="):
        _ = savgol_filter(nonfinite, 5, 2)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
