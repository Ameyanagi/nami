from nami import (
    WindowNormalization,
    WindowSampling,
    blackman,
    blackman_harris,
    flattop,
    general_cosine,
    hamming,
    hann,
    nuttall,
)
from std.collections import List
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def assert_near(actual: Float64, expected: Float64, tolerance: Float64 = 1e-12) raises:
    assert_true(
        abs(actual - expected) <= tolerance,
        msg="window value differs from reference",
    )


def assert_values_near(actual: List[Float64], expected: List[Float64]) raises:
    assert_equal(len(actual), len(expected))
    for index in range(len(actual)):
        assert_near(actual[index], expected[index])


def test_hann_symmetric_reference() raises:
    assert_values_near(hann(5), [0.0, 0.5, 1.0, 0.5, 0.0])


def test_hamming_symmetric_reference() raises:
    assert_values_near(hamming(5), [0.08, 0.54, 1.0, 0.54, 0.08])


def test_blackman_symmetric_reference() raises:
    assert_values_near(blackman(5), [0.0, 0.34, 1.0, 0.34, 0.0])


def test_nuttall_scipy_references() raises:
    assert_values_near(
        nuttall(8),
        [
            0.0003628000000000381,
            0.03777576895352028,
            0.34272761996881956,
            0.8918518610776603,
            0.8918518610776603,
            0.34272761996881956,
            0.03777576895352028,
            0.0003628000000000381,
        ],
    )
    assert_values_near(
        nuttall(8, WindowSampling.PERIODIC),
        [
            0.0003628000000000381,
            0.025205566515401824,
            0.22698240000000006,
            0.7019582334845982,
            1.0,
            0.7019582334845982,
            0.22698240000000006,
            0.025205566515401824,
        ],
    )


def test_blackman_harris_scipy_references() raises:
    assert_values_near(
        blackman_harris(8),
        [
            6.0000000000001025e-05,
            0.0333917234781512,
            0.33283350429856506,
            0.8893697722232838,
            0.8893697722232838,
            0.33283350429856506,
            0.0333917234781512,
            6.0000000000001025e-05,
        ],
    )
    assert_values_near(
        blackman_harris(8, WindowSampling.PERIODIC),
        [
            6.0000000000001025e-05,
            0.021735837018679628,
            0.21747000000000008,
            0.6957641629813204,
            1.0,
            0.6957641629813204,
            0.21747000000000008,
            0.021735837018679628,
        ],
    )


def test_flattop_scipy_references() raises:
    assert_values_near(
        flattop(8),
        [
            -0.0004210510000000013,
            -0.03684078115492349,
            0.01070371671615349,
            0.78087391493877,
            0.78087391493877,
            0.01070371671615349,
            -0.03684078115492349,
            -0.0004210510000000013,
        ],
    )
    assert_values_near(
        flattop(8, WindowSampling.PERIODIC),
        [
            -0.0004210510000000013,
            -0.026872193286334545,
            -0.05473684,
            0.4441353572863345,
            1.000000003,
            0.4441353572863345,
            -0.05473684,
            -0.026872193286334545,
        ],
    )


def test_general_cosine_accepts_arbitrary_length_coefficients() raises:
    var nuttall: List[Float64] = [0.3635819, 0.4891775, 0.1365995, 0.0106411]
    assert_values_near(
        general_cosine(5, nuttall),
        [0.0003628, 0.2269824, 1.0, 0.2269824, 0.0003628],
    )


def test_blackman_matches_general_cosine() raises:
    var coefficients: List[Float64] = [0.42, 0.5, 0.08]
    assert_values_near(blackman(8), general_cosine(8, coefficients))


def test_new_wrappers_match_general_cosine() raises:
    var nuttall_coefficients: List[Float64] = [
        0.3635819,
        0.4891775,
        0.1365995,
        0.0106411,
    ]
    var blackman_harris_coefficients: List[Float64] = [
        0.35875,
        0.48829,
        0.14128,
        0.01168,
    ]
    var flattop_coefficients: List[Float64] = [
        0.21557895,
        0.41663158,
        0.277263158,
        0.083578947,
        0.006947368,
    ]
    assert_values_near(nuttall(8), general_cosine(8, nuttall_coefficients))
    assert_values_near(
        blackman_harris(8),
        general_cosine(8, blackman_harris_coefficients),
    )
    assert_values_near(flattop(8), general_cosine(8, flattop_coefficients))


def test_periodic_reference() raises:
    assert_values_near(
        hann(4, WindowSampling.PERIODIC),
        [0.0, 0.5, 1.0, 0.5],
    )
    assert_values_near(
        hamming(4, WindowSampling.PERIODIC),
        [0.08, 0.54, 1.0, 0.54],
    )
    assert_values_near(
        blackman(4, WindowSampling.PERIODIC),
        [0.0, 0.34, 1.0, 0.34],
    )


def test_periodic_matches_symmetric_extension() raises:
    for length in range(2, 17):
        var periodic = hann(length, WindowSampling.PERIODIC)
        var symmetric = hann(length + 1)
        for index in range(length):
            assert_near(periodic[index], symmetric[index])


def test_symmetric_windows_are_mirror_symmetric() raises:
    for length in range(2, 18):
        var values = blackman(length)
        for index in range(length):
            assert_near(values[index], values[length - index - 1])


def test_peak_normalization_rescales_even_symmetric_window() raises:
    var formula = hann(4)
    assert_values_near(formula, [0.0, 0.75, 0.75, 0.0])
    var normalized = hann(4, normalization=WindowNormalization.PEAK)
    assert_values_near(normalized, [0.0, 1.0, 1.0, 0.0])


def test_length_two_hann_rejects_peak_normalization() raises:
    assert_values_near(hann(2), [0.0, 0.0])
    with assert_raises(contains="cannot peak-normalize a numerically zero window"):
        _ = hann(2, normalization=WindowNormalization.PEAK)


def test_length_two_blackman_rejects_roundoff_amplification() raises:
    assert_values_near(blackman(2), [0.0, 0.0])
    with assert_raises(contains="cannot peak-normalize a numerically zero window"):
        _ = blackman(2, normalization=WindowNormalization.PEAK)


def test_empty_and_singleton_contract() raises:
    assert_equal(len(hann(0)), 0)
    assert_values_near(hann(1), [1.0])
    assert_values_near(hamming(1, WindowSampling.PERIODIC), [1.0])
    assert_values_near(blackman(1, normalization=WindowNormalization.PEAK), [1.0])
    assert_equal(len(nuttall(0)), 0)
    assert_equal(len(blackman_harris(0)), 0)
    assert_equal(len(flattop(0)), 0)
    assert_values_near(nuttall(1), [1.0])
    assert_values_near(blackman_harris(1, WindowSampling.PERIODIC), [1.0])
    assert_values_near(flattop(1, normalization=WindowNormalization.PEAK), [1.0])


def test_negative_length_rejected() raises:
    with assert_raises(contains="window length must be non-negative"):
        _ = hann(-1)


def test_window_mode_constants_are_distinct() raises:
    assert_true(WindowSampling.SYMMETRIC != WindowSampling.PERIODIC)
    assert_true(WindowNormalization.FORMULA != WindowNormalization.PEAK)


def test_window_modes_write_constant_names() raises:
    assert_equal(String(WindowSampling.SYMMETRIC), "SYMMETRIC")
    assert_equal(String(WindowSampling.PERIODIC), "PERIODIC")
    assert_equal(String(WindowNormalization.FORMULA), "FORMULA")
    assert_equal(String(WindowNormalization.PEAK), "PEAK")


def test_explicit_window_mode_validation_rejects_corrupted_storage() raises:
    var sampling = WindowSampling.SYMMETRIC
    sampling._value = 2
    with assert_raises(contains="invalid window sampling"):
        sampling.validate()

    var normalization = WindowNormalization.FORMULA
    normalization._value = 2
    with assert_raises(contains="invalid window normalization"):
        normalization.validate()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
