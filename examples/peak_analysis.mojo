"""Reusable peak analysis with complete prominence and width metadata."""

from nami import PeakWorkspace, Peaks, find_peaks_into
from std.collections import List


def main() raises:
    var samples: List[Float64] = [0.0, 1.0, 0.2, 2.5, 0.1, 1.4, 0.0]
    var peaks = Peaks()
    var workspace = PeakWorkspace()
    find_peaks_into(samples, peaks, workspace, min_prominence=0.5)

    for position in range(len(peaks)):
        print(
            "peak=",
            peaks.indices()[position],
            " height=",
            peaks.heights()[position],
            " prominence=",
            peaks.prominences()[position],
            " width=",
            peaks.widths()[position],
            sep="",
        )
