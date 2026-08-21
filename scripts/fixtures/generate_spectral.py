# /// script
# requires-python = ">=3.11"
# dependencies = ["scipy==1.16.1", "numpy==2.3.2"]
# ///
"""Generate SciPy reference fixtures for nami periodogram and welch tests.

The test signal is synthesized from the exact closed form below (mirrored in
`tests/test_spectral.mojo`), so no sample arrays are committed. Run with
`uv run scripts/fixtures/generate_spectral.py` and paste the printed Mojo
literals into `tests/test_spectral.mojo`. Provenance is recorded in
docs/data-provenance.md.
"""

import numpy as np
from scipy.signal import find_peaks, periodogram, welch

SAMPLE_RATE = 800.0


def synthesize(length: int) -> np.ndarray:
    i = np.arange(length, dtype=np.float64)
    t = i / SAMPLE_RATE
    return (
        np.sin(2.0 * np.pi * 50.0 * t)
        + 0.5 * np.sin(2.0 * np.pi * 120.0 * t + 0.7)
        + 0.01 * i
    )


def mojo_list(values) -> str:
    return "[" + ", ".join(repr(float(v)) for v in values) + "]"


def main() -> None:
    print("# scipy.signal.periodogram / welch, scipy 1.16.1")
    x256 = synthesize(256)
    freq, power = periodogram(x256, fs=SAMPLE_RATE)
    print("periodogram n=256 fs=800 frequencies[0:4]:", mojo_list(freq[:4]))
    print("periodogram n=256 fs=800 power:")
    print(mojo_list(power))

    x512 = synthesize(512)
    freq, power = welch(x512, fs=SAMPLE_RATE, nperseg=256)
    print("welch n=512 nperseg=256 fs=800 power:")
    print(mojo_list(power))

    # README workflow: detrend -> welch -> find_peaks on a drifting signal.
    i = np.arange(2048, dtype=np.float64)
    t = i / SAMPLE_RATE
    workflow = (
        np.sin(2.0 * np.pi * 50.0 * t)
        + 0.3 * np.sin(2.0 * np.pi * 175.0 * t)
        + 0.002 * i
    )
    from scipy.signal import detrend

    freq, power = welch(detrend(workflow), fs=SAMPLE_RATE, nperseg=256)
    peaks, _ = find_peaks(power, prominence=0.001)
    print("workflow peak frequencies:", mojo_list(freq[peaks]))
    print("workflow peak powers:", mojo_list(power[peaks]))


if __name__ == "__main__":
    main()
