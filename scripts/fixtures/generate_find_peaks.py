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
    indices, properties = find_peaks(x, **kwargs)
    prominences = peak_prominences(x, indices)[0]
    print(f"{label} indices: {mojo_int_list(indices)}")
    print(f"{label} prominences: {mojo_list(prominences)}")
    if "width" in kwargs:
        print(f"{label} widths: {mojo_list(properties['widths'])}")
        for name in (
            "peak_heights",
            "left_bases",
            "right_bases",
            "width_heights",
            "left_ips",
            "right_ips",
        ):
            if name in properties:
                values = properties[name]
                formatter = mojo_int_list if name.endswith("bases") else mojo_list
                print(f"{label} {name}: {formatter(values)}")


def main() -> None:
    print("# scipy.signal.find_peaks / peak_prominences, scipy 1.16.1")
    report("baseline", width=(None, None))
    report("height1.5", height=1.5)
    report("distance3", distance=3)
    report("prominence1.0", prominence=1.0)
    report("combined", height=1.0, distance=4, prominence=0.8)
    report("width2.0", width=2.0)
    report("max_width2.5", width=(None, 2.5))
    report("width1.5_to_3.0", width=(1.5, 3.0))
    report("max_height3.0", height=(None, 3.0))
    report("height1.0_to_3.0", height=(1.0, 3.0))
    report("max_prominence2.0", prominence=(None, 2.0))
    report(
        "combined_all",
        height=1.0,
        distance=3,
        prominence=(0.5, 4.0),
        width=(1.0, 4.0),
    )
    report("width2.0_rel_height1.0", width=(2.0, None), rel_height=1.0)
    report("width_all_rel_height0.0", width=(None, None), rel_height=0.0)


if __name__ == "__main__":
    main()
