from nami import ConvolutionMode, WindowSampling, convolve, hann


def main() raises:
    var analysis_window = hann(8, WindowSampling.PERIODIC)
    print("periodic Hann window:", analysis_window)
    var filtered = convolve(
        [1.0, 2.0, 3.0],
        [0.25, 0.5, 0.25],
        ConvolutionMode.same(),
    )
    print("same-length direct convolution:", filtered)
