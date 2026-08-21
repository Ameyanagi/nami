"""Dependency-free direct convolution and correlation for `Float64` sequences."""

from std.collections import List
from std.io import Writable, Writer
from std.math import isfinite


struct ConvolutionMode(Copyable, Equatable, ImplicitlyCopyable, Writable):
    """Select the returned portion of a full discrete linear convolution.

    `SAME` returns the first input's length and uses the left-centered slice for
    an even-length kernel. Direct mutation of `_value` is out of contract; use
    `validate()` for an explicit checkpoint after unusual mutation.
    """

    comptime FULL = ConvolutionMode(0)
    comptime SAME = ConvolutionMode(1)
    comptime VALID = ConvolutionMode(2)

    var _value: Int

    def __init__(out self, _value: Int):
        self._value = _value

    def validate(self) raises:
        """Raise if unusual direct field mutation broke the mode invariant."""
        if self != Self.FULL and self != Self.SAME and self != Self.VALID:
            raise Error(
                String(
                    (
                        "ConvolutionMode _value must be 0 (FULL), 1 (SAME), or 2 "
                        "(VALID); got _value="
                    ),
                    self._value,
                )
            )

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        if self == Self.FULL:
            writer.write("FULL")
        elif self == Self.SAME:
            writer.write("SAME")
        else:
            writer.write("VALID")


def _full_output_length(signal_length: Int, kernel_length: Int) raises -> Int:
    if signal_length <= 0:
        raise Error(
            String(
                "convolution signal must be non-empty; got signal_length=",
                signal_length,
            )
        )
    if kernel_length <= 0:
        raise Error(
            String(
                "convolution kernel must be non-empty; got kernel_length=",
                kernel_length,
            )
        )
    if signal_length > Int.MAX - (kernel_length - 1):
        raise Error(
            String(
                "convolution output length overflows Int; got signal_length=",
                signal_length,
                ", kernel_length=",
                kernel_length,
            )
        )
    return signal_length + kernel_length - 1


def _output_length(
    signal_length: Int, kernel_length: Int, mode: ConvolutionMode
) raises -> Int:
    """Return a validated output length for internal tests and allocation."""
    var full_length = _full_output_length(signal_length, kernel_length)
    if mode == ConvolutionMode.SAME:
        return signal_length
    if mode == ConvolutionMode.VALID:
        if kernel_length > signal_length:
            raise Error(
                String(
                    (
                        "valid convolution requires kernel length <= signal length; got"
                        " kernel="
                    ),
                    kernel_length,
                    ", signal=",
                    signal_length,
                )
            )
        return signal_length - kernel_length + 1
    return full_length


def _output_start(kernel_length: Int, mode: ConvolutionMode) -> Int:
    if mode == ConvolutionMode.SAME:
        return (kernel_length - 1) // 2
    if mode == ConvolutionMode.VALID:
        return kernel_length - 1
    return 0


def _validate_finite(values: Span[Float64, _], *, argument: StringLiteral) raises:
    for index in range(len(values)):
        if not isfinite(values[index]):
            raise Error(
                String(
                    "convolution ",
                    argument,
                    " must contain only finite values; got ",
                    argument,
                    "[",
                    index,
                    "]=",
                    values[index],
                )
            )


def _convolve_core(
    signal: Span[Float64, _],
    kernel: Span[Float64, _],
    mode: ConvolutionMode,
) raises -> List[Float64]:
    """Run validated direct convolution for the public entry points."""
    var output_length = _output_length(len(signal), len(kernel), mode)
    var full_length = _full_output_length(len(signal), len(kernel))
    var full = List[Float64](length=full_length, fill=0.0)
    for signal_index in range(len(signal)):
        for kernel_index in range(len(kernel)):
            var output_index = signal_index + kernel_index
            var updated = (
                full[output_index] + signal[signal_index] * kernel[kernel_index]
            )
            if not isfinite(updated):
                raise Error(
                    String(
                        (
                            "convolution result must contain only finite values; "
                            "got output["
                        ),
                        output_index,
                        "]=",
                        updated,
                    )
                )
            full[output_index] = updated

    var start = _output_start(len(kernel), mode)
    if start == 0 and output_length == full_length:
        return full^
    var output = List[Float64](capacity=output_length)
    for index in range(output_length):
        output.append(full[start + index])
    return output^


def convolve(
    signal: Span[Float64, _],
    kernel: Span[Float64, _],
    mode: ConvolutionMode = ConvolutionMode.FULL,
) raises -> List[Float64]:
    """Return the direct discrete linear convolution of two finite sequences.

    Both inputs must be non-empty and contain only finite values. `SAME` length
    is controlled by `signal`, the first input; for an even kernel it starts at
    `floor((kernel_length - 1) / 2)` in the full result. `VALID` requires the
    kernel to be no longer than the signal. Arithmetic overflow raises instead
    of returning a non-finite sample. Inputs are preserved.
    """
    _validate_finite(signal, argument="signal")
    _validate_finite(kernel, argument="kernel")
    return _convolve_core(signal, kernel, mode)


def correlate(
    signal: Span[Float64, _],
    kernel: Span[Float64, _],
    mode: ConvolutionMode = ConvolutionMode.FULL,
) raises -> List[Float64]:
    """Return direct cross-correlation without complex conjugation.

    For every mode, `correlate(a, b, mode)` equals
    `convolve(a, reversed(b), mode)`. In the `FULL` output, index `m`
    corresponds to lag `m - (len(kernel) - 1)`, and the value at lag `k` is
    `sum_n signal[n + k] * kernel[n]`; zero lag is therefore at index
    `len(kernel) - 1`. Output mode and validation behavior match `convolve`:
    inputs must be non-empty and finite, `VALID` requires the kernel to be no
    longer than the signal, and output-length or arithmetic overflow raises.
    Inputs are preserved.
    """
    _validate_finite(signal, argument="signal")
    _validate_finite(kernel, argument="kernel")
    var reversed_kernel = List[Float64](capacity=len(kernel))
    for index in range(len(kernel)):
        reversed_kernel.append(kernel[len(kernel) - index - 1])
    return _convolve_core(signal, reversed_kernel, mode)
