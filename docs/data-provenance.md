# Data provenance

No generated lookup data is currently committed.

The window reference fixtures are independently derived from the analytic
formulas documented in `docs/windows.md`; they are not copied from a third-party
dataset or implementation.

The convolution fixtures are independently calculated from the discrete linear
convolution sum documented in `docs/convolution.md`; no third-party output
dataset is committed.

Every future generated artifact must record:

- upstream project and canonical URL;
- upstream version and retrieval date;
- exact file checksums and licenses;
- generator source and command;
- deterministic output checks;
- review notes for semantic or licensing changes.

Generation tools are development dependencies. Consumers install the generated
Mojo data and do not require Python, Rust, C, or another runtime.
