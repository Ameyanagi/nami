"""Compiled p50/p95 benchmark for representative analysis workloads."""

from nami import (
    ConvolutionMode,
    PeakWorkspace,
    Peaks,
    find_peaks,
    find_peaks_into,
    savgol_filter,
)
from nami.convolution import _convolve_core, _convolve_core_scalar
from nami.spectral import welch
from std.benchmark import keep
from std.collections import List
from std.math import pi, sin
from std.sys import simd_width_of
from std.time import perf_counter_ns


comptime WARMUPS = 3
comptime SAMPLES = 31


def _sort(mut values: List[Int]):
    # Thirty-one samples keep this benchmark-only insertion sort negligible.
    for index in range(1, len(values)):
        var value = values[index]
        var position = index
        while position > 0 and values[position - 1] > value:
            values[position] = values[position - 1]
            position -= 1
        values[position] = value


def _report(label: StringLiteral, mut elapsed: List[Int], checksum: Float64):
    _sort(elapsed)
    print(
        "case=",
        label,
        " p50_ns=",
        elapsed[SAMPLES // 2],
        " p95_ns=",
        elapsed[(SAMPLES * 95 + 99) // 100 - 1],
        " checksum=",
        checksum,
        sep="",
    )


def _smooth_signal(length: Int) -> List[Float64]:
    var signal = List[Float64](capacity=length)
    for index in range(length):
        var x = 2.0 * pi * Float64(index) / Float64(length)
        signal.append(sin(37.0 * x) + 0.35 * sin(173.0 * x) + 0.08 * sin(997.0 * x))
    return signal^


def _dense_peak_signal(length: Int) -> List[Float64]:
    var signal = List[Float64](length=length, fill=0.0)
    for index in range(1, length - 1, 2):
        # Deterministic unequal heights exercise distance priority and metadata.
        signal[index] = 1.0 + Float64((index * 48271) % 1021) / 1021.0
    return signal^


def _convolution_kernel(length: Int) -> List[Float64]:
    var kernel = List[Float64](capacity=length)
    for index in range(length):
        kernel.append(Float64((index * 17) % 23 - 11) / 16.0)
    return kernel^


def _bench_convolution_simd(signal: List[Float64], kernel: List[Float64]) raises:
    for _ in range(WARMUPS):
        keep(_convolve_core(signal, kernel, ConvolutionMode.SAME))
    var elapsed = List[Int](capacity=SAMPLES)
    var checksum = 0.0
    for _ in range(SAMPLES):
        var started = perf_counter_ns()
        var result = _convolve_core(signal, kernel, ConvolutionMode.SAME)
        elapsed.append(perf_counter_ns() - started)
        checksum += result[len(result) // 2]
        keep(result)
    _report("convolve_core_simd_n65536_k31_same", elapsed, checksum)


def _bench_convolution_scalar(signal: List[Float64], kernel: List[Float64]) raises:
    for _ in range(WARMUPS):
        keep(_convolve_core_scalar(signal, kernel, ConvolutionMode.SAME))
    var elapsed = List[Int](capacity=SAMPLES)
    var checksum = 0.0
    for _ in range(SAMPLES):
        var started = perf_counter_ns()
        var result = _convolve_core_scalar(signal, kernel, ConvolutionMode.SAME)
        elapsed.append(perf_counter_ns() - started)
        checksum += result[len(result) // 2]
        keep(result)
    _report("convolve_core_scalar_n65536_k31_same", elapsed, checksum)


def _bench_savgol(signal: List[Float64]) raises:
    for _ in range(WARMUPS):
        keep(savgol_filter(signal, 31, 3))
    var elapsed = List[Int](capacity=SAMPLES)
    var checksum = 0.0
    for _ in range(SAMPLES):
        var started = perf_counter_ns()
        var result = savgol_filter(signal, 31, 3)
        elapsed.append(perf_counter_ns() - started)
        checksum += result[len(result) // 2]
        keep(result)
    _report("savgol_n65536_w31", elapsed, checksum)


def _bench_welch(signal: List[Float64]) raises:
    for _ in range(WARMUPS):
        keep(welch(signal, 4096.0, segment_length=256))
    var elapsed = List[Int](capacity=SAMPLES)
    var checksum = 0.0
    for _ in range(SAMPLES):
        var started = perf_counter_ns()
        var result = welch(signal, 4096.0, segment_length=256)
        elapsed.append(perf_counter_ns() - started)
        checksum += result.power()[37]
        keep(result)
    _report("welch_n65536_segment256", elapsed, checksum)


def _bench_peaks(signal: List[Float64]) raises:
    for _ in range(WARMUPS):
        keep(find_peaks(signal, min_distance=4, min_prominence=0.25, min_width=0.5))
    var elapsed = List[Int](capacity=SAMPLES)
    var checksum = 0.0
    for _ in range(SAMPLES):
        var started = perf_counter_ns()
        var result = find_peaks(
            signal, min_distance=4, min_prominence=0.25, min_width=0.5
        )
        elapsed.append(perf_counter_ns() - started)
        checksum += Float64(len(result)) + result.prominences()[0]
        keep(result)
    _report("find_peaks_n8192_dense_distance4", elapsed, checksum)


def _bench_peaks_reused(signal: List[Float64]) raises:
    var output = Peaks()
    var workspace = PeakWorkspace()
    for _ in range(WARMUPS):
        find_peaks_into(
            signal,
            output,
            workspace,
            min_distance=4,
            min_prominence=0.25,
            min_width=0.5,
        )
        keep(output)
    var elapsed = List[Int](capacity=SAMPLES)
    var checksum = 0.0
    for _ in range(SAMPLES):
        var started = perf_counter_ns()
        find_peaks_into(
            signal,
            output,
            workspace,
            min_distance=4,
            min_prominence=0.25,
            min_width=0.5,
        )
        elapsed.append(perf_counter_ns() - started)
        checksum += Float64(len(output)) + output.prominences()[0]
        keep(output)
    _report("find_peaks_into_n8192_reused", elapsed, checksum)


def main() raises:
    print(
        "schema=nami-analysis-benchmark-v3 mojo=1.0.0 compiler=mojo-build-O3 "
        "timer=perf_counter_ns samples=31 warmups=3 fixture=deterministic "
        "allocation=case-specific"
    )
    print(
        (
            "provenance_required=cpu,os,architecture,utc,thermal_state,system_load,"
            "exact_command native_float64_simd_width="
        ),
        simd_width_of[DType.float64](),
        sep="",
    )
    var smooth_signal = _smooth_signal(65_536)
    var peak_signal = _dense_peak_signal(8_192)
    var kernel = _convolution_kernel(31)
    _bench_convolution_simd(smooth_signal, kernel)
    _bench_convolution_scalar(smooth_signal, kernel)
    _bench_savgol(smooth_signal)
    _bench_welch(smooth_signal)
    _bench_peaks(peak_signal)
    _bench_peaks_reused(peak_signal)
