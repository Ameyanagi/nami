# /// script
# requires-python = ">=3.11"
# dependencies = ["scipy==1.16.1", "numpy==2.3.2"]
# ///
"""Generate SciPy reference fixtures for nami window and Savitzky-Golay tests.

Run with `uv run scripts/fixtures/generate_windows_savgol.py` and paste the
printed Mojo literals into `tests/test_windows.mojo` and
`tests/test_savgol.mojo`. Provenance is recorded in docs/data-provenance.md.
"""

import numpy as np
from scipy.signal import savgol_coeffs, savgol_filter
from scipy.signal.windows import blackmanharris, flattop, nuttall

SAVGOL_INPUT = [2.0, 1.5, 3.2, 4.8, 4.1, 5.5, 7.0, 6.2, 8.1, 9.4, 8.8, 10.5]


def mojo_list(values) -> str:
    return "[" + ", ".join(repr(float(v)) for v in values) + "]"


def main() -> None:
    print("# scipy.signal.windows, scipy 1.16.1")
    for name, fn in (
        ("nuttall", nuttall),
        ("blackman_harris", blackmanharris),
        ("flattop", flattop),
    ):
        print(f"{name} sym 8: {mojo_list(fn(8, sym=True))}")
        print(f"{name} periodic 8: {mojo_list(fn(8, sym=False))}")

    print("# scipy.signal.savgol_coeffs / savgol_filter, scipy 1.16.1")
    print("coeffs w5 p2:", mojo_list(savgol_coeffs(5, 2)))
    print("coeffs w7 p3:", mojo_list(savgol_coeffs(7, 3)))
    print(
        "coeffs w5 p2 d1 delta0.5:",
        mojo_list(savgol_coeffs(5, 2, deriv=1, delta=0.5)),
    )
    print("coeffs w9 p4 d2:", mojo_list(savgol_coeffs(9, 4, deriv=2)))
    x = np.asarray(SAVGOL_INPUT)
    print("filter w5 p2:", mojo_list(savgol_filter(x, 5, 2)))
    print("filter w7 p3:", mojo_list(savgol_filter(x, 7, 3)))


if __name__ == "__main__":
    main()
