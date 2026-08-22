"""Scientific signal-processing algorithms for Mojo."""

from .convolution import ConvolutionMode, convolve, correlate
from .detrend import DetrendKind, detrend
from .peaks import PeakWorkspace, Peaks, find_peaks, find_peaks_into
from .savgol import savgol_coefficients, savgol_filter
from .windows import (
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
