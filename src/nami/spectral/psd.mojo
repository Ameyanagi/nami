"""One-sided periodogram and Welch power spectral density estimators."""

from shuhafft import FFTNormalization, RealFFTPlan
from std.collections import List, Optional
from std.complex import ComplexSIMD
from std.io import Writable, Writer
from std.math import isfinite

from ..detrend import DetrendKind, detrend
from ..windows.general_cosine import WindowSampling, hann


struct PowerSpectrum(Copyable, Equatable, Movable, Sized, Writable):
    """Own parallel frequency and one-sided power-density bins.

    Direct mutation of `_frequencies` or `_power` is out of contract; use
    `validate()` for an explicit checkpoint after unusual mutation.
    """

    var _frequencies: List[Float64]
    var _power: List[Float64]

    def __init__(
        out self,
        *,
        var _frequencies: List[Float64],
        var _power: List[Float64],
    ) raises:
        self._frequencies = _frequencies^
        self._power = _power^
        self.validate()

    def frequencies(self) -> Span[Float64, origin_of(self._frequencies)]:
        """Return a non-owning view of the DC-first frequency bins."""
        return Span(self._frequencies)

    def power(self) -> Span[Float64, origin_of(self._power)]:
        """Return a non-owning view of the parallel density values."""
        return Span(self._power)

    def __len__(self) -> Int:
        return len(self._frequencies)

    def validate(self) raises:
        """Raise if unusual direct mutation broke parallel storage."""
        if len(self._frequencies) != len(self._power):
            raise Error(
                String(
                    "PowerSpectrum parallel lengths must match; got frequencies=",
                    len(self._frequencies),
                    ", power=",
                    len(self._power),
                )
            )

    def __eq__(self, other: Self) -> Bool:
        if len(self) != len(other):
            return False
        for index in range(len(self)):
            if self._frequencies[index] != other._frequencies[index]:
                return False
            if self._power[index] != other._power[index]:
                return False
        return True

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write("PowerSpectrum(bins=", len(self), ", one_sided_density=True)")


def _validate_sample_rate(sample_rate: Float64) raises:
    if not isfinite(sample_rate) or sample_rate <= 0.0:
        raise Error(
            String(
                "spectral sample_rate must be positive and finite; got ",
                sample_rate,
            )
        )


def _validate_fft_length(length: Int, *, operation: StringLiteral) raises:
    if length < 2:
        raise Error(
            String(
                operation,
                " length must be a power of two >= 2; got ",
                length,
                "; the smallest valid length is 2",
            )
        )
    if (length & (length - 1)) != 0:
        var lower = 1
        while lower * 2 < length:
            lower *= 2
        raise Error(
            String(
                operation,
                " length must be a power of two >= 2; got ",
                length,
                " (nearest are ",
                lower,
                " and ",
                lower * 2,
                ")",
            )
        )


def _validate_finite_signal(
    signal: Span[Float64, _], *, operation: StringLiteral
) raises:
    for index in range(len(signal)):
        if not isfinite(signal[index]):
            raise Error(
                String(
                    operation,
                    " signal must contain only finite values; got signal[",
                    index,
                    "]=",
                    signal[index],
                )
            )


def _frequencies(n_fft: Int, sample_rate: Float64) -> List[Float64]:
    var result = List[Float64](capacity=n_fft // 2 + 1)
    for index in range(n_fft // 2 + 1):
        result.append(Float64(index) * sample_rate / Float64(n_fft))
    return result^


def periodogram(
    signal: Span[Float64, _],
    sample_rate: Float64 = 1.0,
) raises -> PowerSpectrum:
    """Return a SciPy-default one-sided density periodogram.

    The complete signal is constant-detrended and transformed with a
    rectangular window. The signal length must be a power of two at least 2.
    This preserves the input and allocates a real FFT plan and tables, a
    detrended list, a compact complex FFT result, and the two result lists.
    Committed SciPy fixtures use mixed absolute/relative tolerance
    `max(1e-9, 1e-9 * abs(expected))`.
    """
    _validate_sample_rate(sample_rate)
    _validate_fft_length(len(signal), operation="periodogram signal")
    _validate_finite_signal(signal, operation="periodogram")

    var centered = detrend(signal, DetrendKind.CONSTANT)
    var plan = RealFFTPlan[DType.float64](len(signal), FFTNormalization.BACKWARD)
    var transformed = plan.forward(centered)
    var scale = 1.0 / (sample_rate * Float64(len(signal)))
    var power = List[Float64](capacity=len(transformed))
    for index in range(len(transformed)):
        var value = transformed[index]
        var density = scale * (value.re * value.re + value.im * value.im)
        if index != 0 and index != len(transformed) - 1:
            density *= 2.0
        power.append(density)

    var frequencies = _frequencies(len(signal), sample_rate)
    return PowerSpectrum(_frequencies=frequencies^, _power=power^)


def welch(
    signal: Span[Float64, _],
    sample_rate: Float64 = 1.0,
    *,
    segment_length: Int = 256,
    overlap: Optional[Int] = None,
) raises -> PowerSpectrum:
    """Return a SciPy-default one-sided Welch density estimate.

    Complete segments use a periodic Hann window, per-segment constant
    detrending, mean averaging, and half overlap by default. One real FFT plan
    and its tables are allocated once and reused. The operation preserves the
    input and allocates the window, accumulated result, real frame, and compact
    spectrum lists once. The frame and spectrum buffers are reused for every
    segment. Committed SciPy fixtures use mixed absolute/relative tolerance
    `max(1e-9, 1e-9 * abs(expected))`.
    """
    _validate_sample_rate(sample_rate)
    _validate_fft_length(segment_length, operation="welch segment")
    if len(signal) < segment_length:
        raise Error(
            String(
                "welch signal length must be >= segment_length; got ",
                "signal_length=",
                len(signal),
                ", segment_length=",
                segment_length,
            )
        )

    var actual_overlap = overlap.value() if overlap else segment_length // 2
    if actual_overlap < 0 or actual_overlap >= segment_length:
        raise Error(
            String(
                "welch overlap must satisfy 0 <= overlap < segment_length; got ",
                "overlap=",
                actual_overlap,
                ", segment_length=",
                segment_length,
            )
        )
    _validate_finite_signal(signal, operation="welch")

    var window = hann(segment_length, WindowSampling.PERIODIC)
    var window_energy = 0.0
    for index in range(len(window)):
        window_energy += window[index] * window[index]
    var scale = 1.0 / (sample_rate * window_energy)
    var step = segment_length - actual_overlap
    var segment_count = (len(signal) - segment_length) // step + 1
    var bin_count = segment_length // 2 + 1
    var accumulated = List[Float64](length=bin_count, fill=0.0)
    var plan = RealFFTPlan[DType.float64](segment_length, FFTNormalization.BACKWARD)
    var frame = List[Float64](length=segment_length, fill=0.0)
    var spectrum = List[ComplexSIMD[DType.float64, 1]](
        length=bin_count, fill=ComplexSIMD[DType.float64, 1](0.0)
    )

    for segment_index in range(segment_count):
        var start = segment_index * step
        var mean = 0.0
        for index in range(segment_length):
            mean += signal[start + index]
        mean /= Float64(segment_length)
        for index in range(segment_length):
            frame[index] = (signal[start + index] - mean) * window[index]
        plan.forward_into(frame, spectrum)
        for index in range(bin_count):
            var value = spectrum[index]
            accumulated[index] += scale * (value.re * value.re + value.im * value.im)

    var inverse_segment_count = 1.0 / Float64(segment_count)
    for index in range(bin_count):
        accumulated[index] *= inverse_segment_count
        if index != 0 and index != bin_count - 1:
            accumulated[index] *= 2.0

    var frequencies = _frequencies(segment_length, sample_rate)
    return PowerSpectrum(_frequencies=frequencies^, _power=accumulated^)
