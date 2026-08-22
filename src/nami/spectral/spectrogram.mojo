"""Frame-major one-sided power spectrograms for uniformly sampled signals."""

from shuhafft import FFTNormalization, RealFFTPlan
from std.collections import List, Optional
from std.complex import ComplexSIMD
from std.io import Writable, Writer

from ..windows.general_cosine import WindowSampling, hann
from .psd import (
    _frequencies,
    _validate_fft_length,
    _validate_finite_signal,
    _validate_sample_rate,
)


def _spectrogram_power_length(frame_count: Int, bin_count: Int) raises -> Int:
    """Return the checked frame-major storage length."""
    if frame_count < 0 or bin_count < 0:
        raise Error(
            String(
                "Spectrogram dimensions must be non-negative; got frame_count=",
                frame_count,
                ", bin_count=",
                bin_count,
            )
        )
    if frame_count != 0 and bin_count > Int.MAX // frame_count:
        raise Error(
            String(
                "Spectrogram power dimensions overflow Int; got frame_count=",
                frame_count,
                ", bin_count=",
                bin_count,
            )
        )
    return frame_count * bin_count


struct Spectrogram(Copyable, Equatable, Movable, Writable):
    """Own time, frequency, and contiguous frame-major power storage.

    Power at frame `frame_index` and bin `bin_index` is stored at
    `frame_index * bin_count() + bin_index`. Direct mutation of underscore-
    prefixed fields is out of contract; call `validate()` for an explicit
    checkpoint after unusual mutation.
    """

    var _times: List[Float64]
    var _frequencies: List[Float64]
    var _power: List[Float64]
    var _frame_count: Int
    var _bin_count: Int

    def __init__(
        out self,
        *,
        var _times: List[Float64],
        var _frequencies: List[Float64],
        var _power: List[Float64],
        _frame_count: Int,
        _bin_count: Int,
    ) raises:
        self._times = _times^
        self._frequencies = _frequencies^
        self._power = _power^
        self._frame_count = _frame_count
        self._bin_count = _bin_count
        self.validate()

    def times(self) -> Span[Float64, origin_of(self._times)]:
        """Return a non-owning view of frame-center times in seconds."""
        return Span(self._times)

    def frequencies(self) -> Span[Float64, origin_of(self._frequencies)]:
        """Return a non-owning view of DC-first frequency bins in hertz."""
        return Span(self._frequencies)

    def power(self) -> Span[Float64, origin_of(self._power)]:
        """Return a non-owning view of contiguous frame-major power density."""
        return Span(self._power)

    def frame_count(self) -> Int:
        """Return the number of complete time frames."""
        return self._frame_count

    def bin_count(self) -> Int:
        """Return the number of one-sided frequency bins per frame."""
        return self._bin_count

    def validate(self) raises:
        """Raise if unusual direct mutation broke the storage shape."""
        var expected_power = _spectrogram_power_length(
            self._frame_count, self._bin_count
        )
        if len(self._times) != self._frame_count:
            raise Error(
                String(
                    "Spectrogram times length must equal frame_count; got times=",
                    len(self._times),
                    ", frame_count=",
                    self._frame_count,
                )
            )
        if len(self._frequencies) != self._bin_count:
            raise Error(
                String(
                    (
                        "Spectrogram frequencies length must equal bin_count; got "
                        "frequencies="
                    ),
                    len(self._frequencies),
                    ", bin_count=",
                    self._bin_count,
                )
            )
        if len(self._power) != expected_power:
            raise Error(
                String(
                    (
                        "Spectrogram power length must equal frame_count * bin_count; "
                        "got power="
                    ),
                    len(self._power),
                    ", frame_count=",
                    self._frame_count,
                    ", bin_count=",
                    self._bin_count,
                    ", expected_power=",
                    expected_power,
                )
            )

    def __eq__(self, other: Self) -> Bool:
        if (
            self._frame_count != other._frame_count
            or self._bin_count != other._bin_count
        ):
            return False
        for index in range(self._frame_count):
            if self._times[index] != other._times[index]:
                return False
        for index in range(self._bin_count):
            if self._frequencies[index] != other._frequencies[index]:
                return False
        for index in range(len(self._power)):
            if self._power[index] != other._power[index]:
                return False
        return True

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "Spectrogram(frames=",
            self._frame_count,
            ", bins=",
            self._bin_count,
            ", layout=frame-major, one_sided_density=True)",
        )


def spectrogram(
    signal: Span[Float64, _],
    sample_rate: Float64 = 1.0,
    *,
    segment_length: Int = 256,
    overlap: Optional[Int] = None,
) raises -> Spectrogram:
    """Return a contiguous one-sided power spectrogram.

    Complete frames use Welch's periodic Hann window, per-frame constant
    detrending, density scaling, and half overlap by default. Frame times are
    window centers: `(start + segment_length / 2) / sample_rate`. Power has
    units of signal squared per hertz and is stored frame-major.

    One real FFT plan, one real frame buffer, and one compact spectrum buffer
    are allocated once and reused across all frames. The result owns only its
    coordinate lists and contiguous power matrix; accessors borrow spans.
    """
    _validate_sample_rate(sample_rate)
    _validate_fft_length(segment_length, operation="spectrogram segment")
    if len(signal) < segment_length:
        raise Error(
            String(
                "spectrogram signal length must be >= segment_length; got ",
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
                (
                    "spectrogram overlap must satisfy 0 <= overlap < "
                    "segment_length; got overlap="
                ),
                actual_overlap,
                ", segment_length=",
                segment_length,
            )
        )
    _validate_finite_signal(signal, operation="spectrogram")

    var window = hann(segment_length, WindowSampling.PERIODIC)
    var window_energy = 0.0
    for index in range(segment_length):
        window_energy += window[index] * window[index]
    var scale = 1.0 / (sample_rate * window_energy)
    var step = segment_length - actual_overlap
    var frame_count = (len(signal) - segment_length) // step + 1
    var bin_count = segment_length // 2 + 1
    var power_length = _spectrogram_power_length(frame_count, bin_count)
    var times = List[Float64](capacity=frame_count)
    var frequencies = _frequencies(segment_length, sample_rate)
    var power = List[Float64](length=power_length, fill=0.0)
    var plan = RealFFTPlan[DType.float64](segment_length, FFTNormalization.BACKWARD)
    var frame = List[Float64](length=segment_length, fill=0.0)
    var spectrum = List[ComplexSIMD[DType.float64, 1]](
        length=bin_count, fill=ComplexSIMD[DType.float64, 1](0.0)
    )

    for frame_index in range(frame_count):
        var start = frame_index * step
        var mean = 0.0
        for index in range(segment_length):
            mean += signal[start + index]
        mean /= Float64(segment_length)
        for index in range(segment_length):
            frame[index] = (signal[start + index] - mean) * window[index]

        plan.forward_into(frame, spectrum)
        var power_offset = frame_index * bin_count
        for bin_index in range(bin_count):
            var value = spectrum[bin_index]
            var density = scale * (value.re * value.re + value.im * value.im)
            if bin_index != 0 and bin_index != bin_count - 1:
                density *= 2.0
            power[power_offset + bin_index] = density

        times.append((Float64(start) + Float64(segment_length) / 2.0) / sample_rate)

    return Spectrogram(
        _times=times^,
        _frequencies=frequencies^,
        _power=power^,
        _frame_count=frame_count,
        _bin_count=bin_count,
    )
