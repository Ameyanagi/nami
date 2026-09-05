"""One-sided periodogram and Welch power spectral density estimators."""

from shuhafft import FFTNormalization, RealFFTPlan
from std.collections import List, Optional
from std.complex import ComplexSIMD
from std.io import Writable, Writer
from std.math import frexp, inf, isfinite, ldexp

from ..detrend import _Expansion, _power_of_two_scale
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
        while lower <= (length - 1) // 2:
            lower *= 2
        if lower > Int.MAX // 2:
            raise Error(
                String(
                    operation,
                    " length must be a power of two >= 2; got ",
                    length,
                    "; nearest lower valid length is ",
                    lower,
                    "; no larger valid length fits Int",
                )
            )
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


def _validate_welch_segments(
    signal: Span[Float64, _], segment_length: Int, overlap: Optional[Int]
) raises -> Int:
    if len(signal) < segment_length:
        raise Error(
            String(
                "welch signal length must be >= segment_length; got signal_length=",
                len(signal),
                ", segment_length=",
                segment_length,
            )
        )
    var actual_overlap = overlap.value() if overlap else segment_length // 2
    if actual_overlap < 0 or actual_overlap >= segment_length:
        raise Error(
            String(
                (
                    "welch overlap must satisfy 0 <= overlap < segment_length; got"
                    " overlap="
                ),
                actual_overlap,
                ", segment_length=",
                segment_length,
            )
        )
    return actual_overlap


def _frequencies(n_fft: Int, sample_rate: Float64) -> List[Float64]:
    var result = List[Float64](capacity=n_fft // 2 + 1)
    for index in range(n_fft // 2 + 1):
        result.append((Float64(index) / Float64(n_fft)) * sample_rate)
    return result^


def _center_frame(signal: Span[Float64, _], mut frame: List[Float64]) -> Float64:
    """Center a validated frame in normalized units without allocating."""
    var maximum = 0.0
    for value in signal:
        maximum = max(maximum, abs(value))
    if maximum == 0.0:
        for index in range(len(signal)):
            frame[index] = 0.0
        return 1.0
    var amplitude = _power_of_two_scale(maximum)
    var total = _Expansion()
    for value in signal:
        total.add(value / amplitude)
    var length = Float64(len(signal))
    for index in range(len(signal)):
        var residual = _Expansion()
        residual.add_product(length, signal[index] / amplitude)
        for part in range(total.count):
            residual.add(-total.partials[part])
        frame[index] = residual.value() / length
    return amplitude


def _binary_parts(value: Float64) -> Tuple[Float64, Int]:
    """Normalize subnormals before Mojo 1.0's frexp exponent-bit operation."""
    if value < 2.2250738585072014e-308:
        var parts = frexp(value * 18014398509481984.0)
        return (parts[0], Int(parts[1]) - 54)
    var parts = frexp(value)
    return (parts[0], Int(parts[1]))


def _restore_exponent(mantissa: Float64, exponent: Int) -> Float64:
    """Round once at underflow, and keep ldexp's exponent in [-1022, 1023]."""
    if mantissa == 0.0:
        return 0.0
    var parts = _binary_parts(mantissa)
    var normalized = parts[0]
    var total_exponent = exponent + parts[1]
    if total_exponent > 1024:
        return inf[DType.float64]()
    if total_exponent < -1074:
        return 0.0
    if total_exponent == 1024:
        return ldexp(normalized, Int32(1023)) * 2.0
    if total_exponent < -1022:
        return ldexp(normalized, Int32(total_exponent + 1022)) * 2.2250738585072014e-308
    return ldexp(normalized, Int32(total_exponent))


def _density_parts(
    value: ComplexSIMD[DType.float64, 1],
    amplitude: Float64,
    sample_rate: Float64,
    energy: Float64,
    factor: Float64,
) -> Tuple[Float64, Int]:
    """Evaluate squared amplitude / (rate * energy) using bounded mantissas."""
    var component = max(abs(value.re), abs(value.im))
    if component == 0.0:
        return (0.0, 0)
    var fft_parts = _binary_parts(component)
    var amplitude_parts = _binary_parts(amplitude)
    var rate_parts = _binary_parts(sample_rate)
    var energy_parts = _binary_parts(energy)
    var re = value.re / component
    var im = value.im / component
    var magnitude = fft_parts[0] * amplitude_parts[0]
    var mantissa = (
        magnitude
        * magnitude
        * (re * re + im * im)
        / (rate_parts[0] * energy_parts[0])
        * factor
    )
    var exponent = (
        2 * (fft_parts[1] + amplitude_parts[1]) - rate_parts[1] - energy_parts[1]
    )
    return (mantissa, exponent)


def _checked_density(
    mantissa: Float64, exponent: Int, sample_rate: Float64
) raises -> Float64:
    var density = _restore_exponent(mantissa, exponent)
    if not isfinite(density):
        raise Error(
            String(
                "spectral density is outside finite Float64; got ",
                density,
                "; rescale the signal or increase sample_rate=",
                sample_rate,
            )
        )
    return density


def _density(
    value: ComplexSIMD[DType.float64, 1],
    amplitude: Float64,
    sample_rate: Float64,
    energy: Float64,
    factor: Float64,
) raises -> Float64:
    var parts = _density_parts(value, amplitude, sample_rate, energy, factor)
    return _checked_density(parts[0], parts[1], sample_rate)


struct SpectralWorkspace(Equatable, Movable, Writable):
    """Reusable fixed-size FFT plan, Hann window, and bounded analysis scratch.

    Execution overwrites caller-owned output without allocating. Equality
    compares FFT size: scratch history does not affect subsequent results.
    Direct underscore-field mutation is out of contract; validate() provides
    an explicit checkpoint. Methods are mutating and require exclusive access.
    """

    var _size: Int
    var _plan: RealFFTPlan[DType.float64]
    var _window: List[Float64]
    var _energy: Float64
    var _frame: List[Float64]
    var _spectrum: List[ComplexSIMD[DType.float64, 1]]
    var _exponents: List[Int]

    def __init__(out self, fft_size: Int) raises:
        _validate_fft_length(fft_size, operation="SpectralWorkspace fft_size")
        self._size = fft_size
        self._plan = RealFFTPlan[DType.float64](fft_size, FFTNormalization.BACKWARD)
        self._window = hann(fft_size, WindowSampling.PERIODIC)
        self._energy = 0.0
        for value in self._window:
            self._energy += value * value
        self._frame = List[Float64](length=fft_size, fill=0.0)
        self._spectrum = List[ComplexSIMD[DType.float64, 1]](
            length=fft_size // 2 + 1, fill=ComplexSIMD[DType.float64, 1](0.0)
        )
        self._exponents = List[Int](length=fft_size // 2 + 1, fill=0)

    def size(self) -> Int:
        """Return the immutable FFT/segment length."""
        return self._size

    def bin_count(self) -> Int:
        """Return the required length of caller-owned output lists."""
        return self._size // 2 + 1

    def validate(self) raises:
        """Check plan and scratch invariants after unusual direct mutation."""
        _validate_fft_length(self._size, operation="SpectralWorkspace fft_size")
        self._plan.validate()
        if (
            self._plan.size() != self._size
            or self._plan.normalization() != FFTNormalization.BACKWARD
            or len(self._window) != self._size
            or len(self._frame) != self._size
            or len(self._spectrum) != self.bin_count()
            or len(self._exponents) != self.bin_count()
        ):
            raise Error(
                String(
                    "SpectralWorkspace storage must match fft_size=",
                    self._size,
                    "; got plan_size=",
                    self._plan.size(),
                    ", frame_length=",
                    len(self._frame),
                    ", window_length=",
                    len(self._window),
                    ", spectrum_length=",
                    len(self._spectrum),
                    ", exponent_length=",
                    len(self._exponents),
                    "; reconstruct the workspace",
                )
            )
        var expected = hann(self._size, WindowSampling.PERIODIC)
        var energy = 0.0
        for index in range(self._size):
            if self._window[index] != expected[index]:
                raise Error(
                    String(
                        "SpectralWorkspace window[",
                        index,
                        "] must be periodic Hann value=",
                        expected[index],
                        "; got ",
                        self._window[index],
                        "; reconstruct the workspace",
                    )
                )
            energy += expected[index] * expected[index]
        if self._energy != energy:
            raise Error(
                String(
                    "SpectralWorkspace window energy must be ",
                    energy,
                    "; got ",
                    self._energy,
                    "; reconstruct the workspace",
                )
            )

    def __eq__(self, other: Self) -> Bool:
        return self._size == other._size

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "SpectralWorkspace(fft_size=", self._size, ", bins=", self.bin_count(), ")"
        )

    def _validate_output(self, length: Int) raises:
        if length != self.bin_count():
            raise Error(
                String(
                    "spectral output length must equal bin_count=",
                    self.bin_count(),
                    "; got ",
                    length,
                    "; preallocate the output list",
                )
            )

    def frequencies_into(
        self, mut output: List[Float64], sample_rate: Float64 = 1.0
    ) raises:
        """Write frequencies for this FFT size into an exactly sized list."""
        _validate_sample_rate(sample_rate)
        self._validate_output(len(output))
        for index in range(self.bin_count()):
            output[index] = (Float64(index) / Float64(self._size)) * sample_rate

    def periodogram_into(
        mut self,
        signal: Span[Float64, _],
        mut output: List[Float64],
        sample_rate: Float64 = 1.0,
    ) raises:
        """Overwrite density bins using a rectangular, constant-centered frame.

        Input and output must have size() and bin_count() entries respectively.
        Configuration and samples are checked before output mutation. A numeric
        overflow may leave partially overwritten output; the workspace remains
        reusable after any error. No buffer is resized or allocated.
        """
        _validate_sample_rate(sample_rate)
        if len(signal) != self._size:
            raise Error(
                String(
                    "periodogram signal length must equal fft_size=",
                    self._size,
                    "; got ",
                    len(signal),
                )
            )
        self._validate_output(len(output))
        _validate_finite_signal(signal, operation="periodogram")
        var amplitude = _center_frame(signal, self._frame)
        self._plan.forward_into(self._frame, self._spectrum)
        for index in range(self.bin_count()):
            var factor = 1.0 if index == 0 or index == self.bin_count() - 1 else 2.0
            output[index] = _density(
                self._spectrum[index],
                amplitude,
                sample_rate,
                Float64(self._size),
                factor,
            )

    def welch_into(
        mut self,
        signal: Span[Float64, _],
        mut output: List[Float64],
        sample_rate: Float64 = 1.0,
        *,
        overlap: Optional[Int] = None,
    ) raises:
        """Overwrite Welch bins, reusing all scratch for every complete frame.

        The segment size is size(); overlap accepts every integer in [0, size()).
        The default is half overlap. Trailing incomplete samples are ignored.
        Error/output behavior matches periodogram_into().
        """
        _validate_sample_rate(sample_rate)
        var actual_overlap = _validate_welch_segments(signal, self._size, overlap)
        self._validate_output(len(output))
        _validate_finite_signal(signal, operation="welch")
        for index in range(self.bin_count()):
            output[index] = 0.0
            self._exponents[index] = 0
        var step = self._size - actual_overlap
        var count = (len(signal) - self._size) // step + 1
        for segment in range(count):
            var start = segment * step
            var amplitude = _center_frame(
                signal[start : start + self._size], self._frame
            )
            for index in range(self._size):
                self._frame[index] *= self._window[index]
            self._plan.forward_into(self._frame, self._spectrum)
            for index in range(self.bin_count()):
                var factor = 1.0 if index == 0 or index == self.bin_count() - 1 else 2.0
                var parts = _density_parts(
                    self._spectrum[index], amplitude, sample_rate, self._energy, factor
                )
                if parts[0] == 0.0:
                    continue
                if output[index] == 0.0:
                    output[index] = parts[0]
                    self._exponents[index] = parts[1]
                elif parts[1] > self._exponents[index]:
                    output[index] = (
                        _restore_exponent(
                            output[index], self._exponents[index] - parts[1]
                        )
                        + parts[0]
                    )
                    self._exponents[index] = parts[1]
                else:
                    output[index] += _restore_exponent(
                        parts[0], parts[1] - self._exponents[index]
                    )
        for index in range(self.bin_count()):
            output[index] = _checked_density(
                output[index] / Float64(count), self._exponents[index], sample_rate
            )


def periodogram(
    signal: Span[Float64, _],
    sample_rate: Float64 = 1.0,
) raises -> PowerSpectrum:
    """Allocate a workspace and return a one-sided rectangular-window density.

    For repeated frames use SpectralWorkspace.periodogram_into() to reuse the
    plan, centering scratch, compact FFT storage, and caller-owned output.
    """
    _validate_sample_rate(sample_rate)
    _validate_fft_length(len(signal), operation="periodogram signal")
    _validate_finite_signal(signal, operation="periodogram")
    var workspace = SpectralWorkspace(len(signal))
    var power = List[Float64](length=workspace.bin_count(), fill=0.0)
    workspace.periodogram_into(signal, power, sample_rate)
    var frequencies = _frequencies(len(signal), sample_rate)
    return PowerSpectrum(_frequencies=frequencies^, _power=power^)


def welch(
    signal: Span[Float64, _],
    sample_rate: Float64 = 1.0,
    *,
    segment_length: Int = 256,
    overlap: Optional[Int] = None,
) raises -> PowerSpectrum:
    """Allocate a workspace and return mean periodic-Hann one-sided density.

    For repeated analyses use SpectralWorkspace.welch_into(). Defaults and
    normalization match scipy.signal.welch with complete frames only.
    """
    _validate_sample_rate(sample_rate)
    _validate_fft_length(segment_length, operation="welch segment")
    _ = _validate_welch_segments(signal, segment_length, overlap)
    _validate_finite_signal(signal, operation="welch")
    var workspace = SpectralWorkspace(segment_length)
    var power = List[Float64](length=workspace.bin_count(), fill=0.0)
    workspace.welch_into(signal, power, sample_rate, overlap=overlap)
    var frequencies = _frequencies(segment_length, sample_rate)
    return PowerSpectrum(_frequencies=frequencies^, _power=power^)
