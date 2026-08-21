from nami import ConvolutionMode, WindowSampling, convolve, hann


def main() raises:
    var analysis_window = hann(8, WindowSampling.PERIODIC)
    print("periodic Hann window:", analysis_window)
    var samples: List[Float64] = [1.0, 2.0, 3.0]
    var kernel: List[Float64] = [0.25, 0.5, 0.25]
    var filtered = convolve(samples, kernel, ConvolutionMode.SAME)
    print("same-length direct convolution:", filtered)
