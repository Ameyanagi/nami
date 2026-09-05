"""Construction versus steady-state fixed-size spectral analysis, compiled -O3."""

from nami.spectral import SpectralWorkspace, periodogram, welch
from shuhafft import RealFFTPlan
from std.benchmark import keep
from std.collections import List
from std.math import pi, sin
from std.time import perf_counter_ns


comptime SAMPLES = 31
comptime BATCH = 32


def _report(label: StringLiteral, size: Int, mut timings: List[Int]):
    for index in range(1, len(timings)):
        var value = timings[index]
        var position = index
        while position > 0 and timings[position - 1] > value:
            timings[position] = timings[position - 1]
            position -= 1
        timings[position] = value
    print(
        "case=",
        label,
        " fft_size=",
        size,
        " p50_ns=",
        timings[15] // BATCH,
        " p95_ns=",
        timings[29] // BATCH,
        sep="",
    )


def _run(size: Int) raises:
    var signal = List[Float64](capacity=size)
    for index in range(size):
        signal.append(
            sin(2.0 * pi * 7.0 * Float64(index) / Float64(size))
            + 0.25 * sin(2.0 * pi * 11.0 * Float64(index) / Float64(size))
        )
    var long_signal = List[Float64](capacity=4 * size)
    for _ in range(4):
        for value in signal:
            long_signal.append(value)
    var workspace = SpectralWorkspace(size)
    var output = List[Float64](length=workspace.bin_count(), fill=0.0)
    for _ in range(3):
        workspace.periodogram_into(signal, output, 4096.0)
        workspace.welch_into(long_signal, output, 4096.0)
        keep(periodogram(signal, 4096.0))
        keep(welch(long_signal, 4096.0, segment_length=size))

    var plans = List[Int](capacity=SAMPLES)
    var workspaces = List[Int](capacity=SAMPLES)
    var oneshot = List[Int](capacity=SAMPLES)
    var reused = List[Int](capacity=SAMPLES)
    var welch_oneshot = List[Int](capacity=SAMPLES)
    var welch_reused = List[Int](capacity=SAMPLES)
    for _ in range(SAMPLES):
        var started = perf_counter_ns()
        for _ in range(BATCH):
            keep(RealFFTPlan[DType.float64](size))
        plans.append(perf_counter_ns() - started)
        started = perf_counter_ns()
        for _ in range(BATCH):
            keep(SpectralWorkspace(size))
        workspaces.append(perf_counter_ns() - started)
        started = perf_counter_ns()
        for _ in range(BATCH):
            keep(periodogram(signal, 4096.0))
        oneshot.append(perf_counter_ns() - started)
        started = perf_counter_ns()
        for _ in range(BATCH):
            workspace.periodogram_into(signal, output, 4096.0)
            keep(output)
        reused.append(perf_counter_ns() - started)
        started = perf_counter_ns()
        for _ in range(BATCH):
            keep(welch(long_signal, 4096.0, segment_length=size))
        welch_oneshot.append(perf_counter_ns() - started)
        started = perf_counter_ns()
        for _ in range(BATCH):
            workspace.welch_into(long_signal, output, 4096.0)
            keep(output)
        welch_reused.append(perf_counter_ns() - started)
    _report("fft_plan_construction", size, plans)
    _report("workspace_construction", size, workspaces)
    _report("periodogram_oneshot", size, oneshot)
    _report("periodogram_reused", size, reused)
    _report("welch_oneshot_7_frames", size, welch_oneshot)
    _report("welch_reused_7_frames", size, welch_reused)
    print("checksum=", output[7], sep="")


def main() raises:
    print(
        "schema=nami-spectral-workspace-v1 mojo=1.0.0 compiler=-O3 warmups=3 samples=31"
        " batch=32 units=ns_per_operation"
    )
    _run(64)
    _run(4096)
