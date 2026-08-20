"""Dependency-free direct convolution for finite `Float64` sequences."""

from std.collections import List


def _is_finite(value: Float64) -> Bool:
    return value == value and value - value == 0.0


struct ConvolutionMode(Copyable, Equatable, ImplicitlyCopyable):
    """Select the returned portion of a full discrete linear convolution.

    Use `full()`, `same()`, or `valid()`. `same()` returns the first input's
    length and uses the left-centered slice for an even-length kernel.
    """

    var _is_same: Bool
    var _is_valid: Bool

    def __init__(out self):
        """Construct full-output mode."""
        self._is_same = False
        self._is_valid = False

    @staticmethod
    def full() -> Self:
        """Return all `signal_length + kernel_length - 1` samples."""
        return Self()

    @staticmethod
    def same() -> Self:
        """Return a centered slice whose length equals the first input."""
        var result = Self()
        result._is_same = True
        return result

    @staticmethod
    def valid() -> Self:
        """Return samples where the kernel lies entirely within the signal."""
        var result = Self()
        result._is_valid = True
        return result

    def _validate(self) raises:
        # Mojo 1.0 fields remain externally mutable. The fourth Bool pair has no
        # convolution meaning, so every semantic operation rejects it.
        if self._is_same and self._is_valid:
            raise Error("invalid convolution mode")

    def __eq__(self, other: Self) -> Bool:
        return self._is_same == other._is_same and self._is_valid == other._is_valid


def _full_output_length(signal_length: Int, kernel_length: Int) raises -> Int:
    if signal_length <= 0 or kernel_length <= 0:
        raise Error("convolution inputs must be non-empty")
    if signal_length > Int.MAX - (kernel_length - 1):
        raise Error("convolution output length overflows Int")
    return signal_length + kernel_length - 1


def _output_length(
    signal_length: Int, kernel_length: Int, mode: ConvolutionMode
) raises -> Int:
    """Return a validated output length for internal tests and allocation."""
    mode._validate()
    var full_length = _full_output_length(signal_length, kernel_length)
    if mode._is_same:
        return signal_length
    if mode._is_valid:
        if kernel_length > signal_length:
            raise Error(
                "valid convolution requires signal length at least kernel length"
            )
        return signal_length - kernel_length + 1
    return full_length


def _output_start(kernel_length: Int, mode: ConvolutionMode) -> Int:
    if mode._is_same:
        return (kernel_length - 1) // 2
    if mode._is_valid:
        return kernel_length - 1
    return 0


def convolve(
    signal: List[Float64],
    kernel: List[Float64],
    mode: ConvolutionMode = ConvolutionMode.full(),
) raises -> List[Float64]:
    """Return the direct discrete linear convolution of two finite sequences.

    Both inputs must be non-empty and contain only finite values. `SAME` length
    is controlled by `signal`, the first input; for an even kernel it starts at
    `floor((kernel_length - 1) / 2)` in the full result. `VALID` requires the
    kernel to be no longer than the signal. Arithmetic overflow raises instead
    of returning a non-finite sample. Inputs are preserved.
    """
    var output_length = _output_length(len(signal), len(kernel), mode)
    for index in range(len(signal)):
        if not _is_finite(signal[index]):
            raise Error("convolution inputs must contain only finite values")
    for index in range(len(kernel)):
        if not _is_finite(kernel[index]):
            raise Error("convolution inputs must contain only finite values")

    var full_length = _full_output_length(len(signal), len(kernel))
    var full = List[Float64](length=full_length, fill=0.0)
    for signal_index in range(len(signal)):
        for kernel_index in range(len(kernel)):
            var output_index = signal_index + kernel_index
            var updated = (
                full[output_index] + signal[signal_index] * kernel[kernel_index]
            )
            if not _is_finite(updated):
                raise Error("convolution result must contain only finite values")
            full[output_index] = updated

    var start = _output_start(len(kernel), mode)
    if start == 0 and output_length == full_length:
        return full^
    var output = List[Float64](capacity=output_length)
    for index in range(output_length):
        output.append(full[start + index])
    return output^
