from nami import WindowSampling, hann


def main() raises:
    var analysis_window = hann(8, WindowSampling.PERIODIC)
    print("periodic Hann window:", analysis_window)
