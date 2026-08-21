# Data provenance

No generated lookup tables are currently committed.

The original Hann, Hamming, and Blackman reference fixtures are independently
derived from the analytic formulas documented in `docs/windows.md`; they are
not copied from a third-party dataset or implementation.

The convolution fixtures are independently calculated from the discrete linear
convolution sum documented in `docs/convolution.md`; no third-party output
dataset is committed.

## SciPy reference fixtures

### Correlation and detrend

The correlation and detrend reference values embedded in
`tests/test_correlate.mojo` and `tests/test_detrend.mojo` were generated on
2026-08-21 from [SciPy 1.16.1](https://github.com/scipy/scipy/tree/v1.16.1) and
[NumPy 2.3.2](https://github.com/numpy/numpy/tree/v2.3.2) with:

```text
uv run scripts/fixtures/generate_correlate_detrend.py
```

The generator records exact inputs and calls `scipy.signal.correlate` with
`method="direct"` and `scipy.signal.detrend` for the constant and linear cases.
The committed values are computed numerical outputs, not copied SciPy or NumPy
source code. SciPy and NumPy are BSD-3-Clause licensed; their code is not
redistributed by these fixtures.

### Additional windows and Savitzky-Golay

The Nuttall, Blackman-Harris, flat-top, and Savitzky-Golay reference values
embedded in `tests/test_windows.mojo` and `tests/test_savgol.mojo` were generated
on 2026-08-21 from
[SciPy 1.16.1](https://github.com/scipy/scipy/tree/v1.16.1) and
[NumPy 2.3.2](https://github.com/numpy/numpy/tree/v2.3.2) with:

```text
uv run scripts/fixtures/generate_windows_savgol.py
```

The generator calls the corresponding `scipy.signal.windows` functions with
both symmetric and periodic sampling, `scipy.signal.savgol_coeffs`, and
`scipy.signal.savgol_filter`. Inputs and parameter sets are fixed in the
generator. The committed values are computed numerical outputs; SciPy or NumPy
source code is not redistributed.

Every future generated artifact must record:

- upstream project and canonical URL;
- upstream version and retrieval date;
- exact file checksums and licenses;
- generator source and command;
- deterministic output checks;
- review notes for semantic or licensing changes.

Generation tools are development dependencies. Consumers install the generated
Mojo data and do not require Python, Rust, C, or another runtime.
