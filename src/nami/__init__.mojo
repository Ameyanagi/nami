"""Scientific signal-processing algorithms for Mojo."""

from .convolution import ConvolutionMode, convolve, correlate
from .detrend import DetrendKind, detrend
from .peaks import Peaks, find_peaks
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
