"""Analyze successive fixed-size frames without reconstructing FFT storage."""

from nami.spectral import SpectralWorkspace
from std.collections import List
from std.math import pi, sin


def main() raises:
    var workspace = SpectralWorkspace(256)
    var frequencies = List[Float64](length=workspace.bin_count(), fill=0.0)
    var power = List[Float64](length=workspace.bin_count(), fill=0.0)
    var frame = List[Float64](length=workspace.size(), fill=0.0)
    workspace.frequencies_into(frequencies, 800.0)
    for frame_index in range(3):
        for index in range(len(frame)):
            var t = Float64(frame_index * len(frame) + index) / 800.0
            frame[index] = sin(2.0 * pi * 50.0 * t)
        workspace.periodogram_into(frame, power, 800.0)
        print("frame", frame_index, "50 Hz density", power[16])
    workspace.welch_into(frame, power, 800.0, overlap=0)
    print("Hann density at", frequencies[16], "Hz:", power[16])
