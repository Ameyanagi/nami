# /// script
# requires-python = ">=3.11"
# dependencies = ["scipy==1.16.1", "numpy==2.3.2"]
# ///
"""Generate SciPy reference fixtures for nami find_peaks tests.

Run with `uv run scripts/fixtures/generate_find_peaks.py` and paste the
printed Mojo literals into `tests/test_find_peaks.mojo`. Provenance is
recorded in docs/data-provenance.md.
"""

import numpy as np
from scipy.signal import find_peaks, peak_prominences

SIGNAL = [
    0.1, 1.2, 0.4, 0.3, 2.5, 2.5, 0.8, 0.5, 3.1, 0.9,
    1.7, 1.6, 1.8, 0.2, 4.0, 3.9, 4.0, 0.6, 1.1, 1.0,
    1.05, 0.95, 2.2, 2.2, 2.2, 0.7, 5.0, 0.3, 0.8, 0.4,
]  # fmt: skip


def mojo_int_list(values) -> str:
    return "[" + ", ".join(str(int(v)) for v in values) + "]"


def mojo_list(values) -> str:
    return "[" + ", ".join(repr(float(v)) for v in values) + "]"


def report(label: str, **kwargs) -> None:
    x = np.asarray(SIGNAL)
    indices, _ = find_peaks(x, **kwargs)
    prominences = peak_prominences(x, indices)[0]
    print(f"{label} indices: {mojo_int_list(indices)}")
    print(f"{label} prominences: {mojo_list(prominences)}")


def main() -> None:
    print("# scipy.signal.find_peaks / peak_prominences, scipy 1.16.1")
    report("baseline")
    report("height1.5", height=1.5)
    report("distance3", distance=3)
    report("prominence1.0", prominence=1.0)
    report("combined", height=1.0, distance=4, prominence=0.8)


if __name__ == "__main__":
    main()
