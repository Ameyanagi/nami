"""Scientific signal-processing algorithms for Mojo."""

from .convolution import ConvolutionMode, convolve, correlate
from .detrend import DetrendKind, detrend
from .windows import (
    WindowNormalization,
    WindowSampling,
    blackman,
    general_cosine,
    hamming,
    hann,
)
