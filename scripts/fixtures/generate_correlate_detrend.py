# /// script
# requires-python = ">=3.11"
# dependencies = ["scipy==1.16.1", "numpy==2.3.2"]
# ///
"""Generate SciPy reference fixtures for nami correlate and detrend tests.

Run with `uv run scripts/fixtures/generate_correlate_detrend.py` and paste the
printed Mojo literals into `tests/test_correlate.mojo` and
`tests/test_detrend.mojo`. Provenance is recorded in docs/data-provenance.md.
"""

import numpy as np
from scipy.signal import correlate, detrend

SIGNAL = [0.5, -1.25, 2.0, 3.5, -0.75, 1.5]
KERNEL_ODD = [1.0, -2.0, 0.5]
KERNEL_EVEN = [0.25, -1.0, 2.0, 0.5]

DETREND_INPUT = [1.2, 3.4, 2.8, 5.9, 4.1, 6.3, 8.0, 7.2]


def mojo_list(values) -> str:
    return "[" + ", ".join(repr(float(v)) for v in values) + "]"


def main() -> None:
    a = np.asarray(SIGNAL)
    print("# scipy.signal.correlate(method='direct'), scipy 1.16.1")
    for name, kernel in (("odd", KERNEL_ODD), ("even", KERNEL_EVEN)):
        k = np.asarray(kernel)
        for mode in ("full", "same", "valid"):
            result = correlate(a, k, mode=mode, method="direct")
            print(f"correlate {name} {mode}: {mojo_list(result)}")

    x = np.asarray(DETREND_INPUT)
    print("# scipy.signal.detrend, scipy 1.16.1")
    print("detrend constant:", mojo_list(detrend(x, type="constant")))
    print("detrend linear:", mojo_list(detrend(x, type="linear")))


if __name__ == "__main__":
    main()
