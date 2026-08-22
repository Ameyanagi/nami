from nami import detrend, find_peaks
from nami.spectral import (
    PowerSpectrum,
    Spectrogram,
    periodogram,
    spectrogram,
    welch,
)
from std.collections import List
from std.math import pi, sin
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def assert_power_value_near(actual: Float64, expected: Float64) raises:
    var tolerance = 1e-9 * max(1.0, abs(expected))
    assert_true(
        abs(actual - expected) <= tolerance,
        msg="spectral power differs from SciPy reference",
    )


def assert_power_near(actual: Span[Float64, _], expected: Span[Float64, _]) raises:
    assert_equal(len(actual), len(expected))
    for index in range(len(actual)):
        assert_power_value_near(actual[index], expected[index])


def synthesize(length: Int) -> List[Float64]:
    var signal = List[Float64](capacity=length)
    for index in range(length):
        var t = Float64(index) / 800.0
        signal.append(
            sin(2.0 * pi * 50.0 * t)
            + 0.5 * sin(2.0 * pi * 120.0 * t + 0.7)
            + 0.01 * Float64(index)
        )
    return signal^


def periodogram_fixture() -> List[Float64]:
    return [
        1.9567749161528127e-33,
        0.10625455845486512,
        0.026572370372936513,
        0.011816459005743268,
        0.006651949330299029,
        0.004261585714219089,
        0.002963189351350521,
        0.0021803759229233302,
        0.0016723845265862352,
        0.001324198380438897,
        0.0010752411421213843,
        0.0008911473717851613,
        0.0007512448263597725,
        0.0006424946398814387,
        0.0005563446016405567,
        0.00048699855138951357,
        0.1438335148413177,
        0.00038372185353874707,
        0.0003448143022791584,
        0.0003121451811885598,
        0.00028455383765746504,
        0.0002611645327226205,
        0.00024131606718434277,
        0.00022451480026186127,
        0.00021040478510104955,
        0.00019875185778915857,
        0.00018944118054466143,
        0.00018249083408469652,
        0.0001780889000339607,
        0.00017667077563399095,
        0.00017907373894814825,
        0.00018685457040243416,
        0.00020298581718020126,
        0.00023353510405518945,
        0.00029228851960550525,
        0.00041610755344338794,
        0.0007329420748901401,
        0.0019679912125334393,
        0.02303829978027045,
        0.010228506447805097,
        0.00149351336748279,
        0.0006050969027097144,
        0.00034468213542077606,
        0.0002334214206791407,
        0.00017521300800173672,
        0.00014056620710600393,
        0.00011799351921828238,
        0.00010226581964855211,
        9.072385442146832e-05,
        8.189768970139615e-05,
        7.491997075720584e-05,
        6.925118268015111e-05,
        6.45407615419306e-05,
        6.055237154627462e-05,
        5.71215706887757e-05,
        5.4130755049448825e-05,
        5.149376339957813e-05,
        4.914610482588162e-05,
        4.703857603325263e-05,
        4.513298584935683e-05,
        4.3399225867756867e-05,
        4.181322222582863e-05,
        4.035547690198069e-05,
        3.9010011315064304e-05,
        3.776358945491712e-05,
        3.6605138465712914e-05,
        3.55253108316701e-05,
        3.451614954063535e-05,
        3.357082911181847e-05,
        3.268345318916005e-05,
        3.184889478685402e-05,
        3.1062669035020074e-05,
        3.0320830934917072e-05,
        2.9619892538348726e-05,
        2.895675534545651e-05,
        2.8328654724410603e-05,
        2.7733113902051535e-05,
        2.7167905630799146e-05,
        2.6631020055430047e-05,
        2.6120637620783494e-05,
        2.5635106104109485e-05,
        2.517292104277504e-05,
        2.473270897309024e-05,
        2.431321300938099e-05,
        2.3913280381540254e-05,
        2.3531851619777758e-05,
        2.316795113148493e-05,
        2.2820678959926965e-05,
        2.248920355079337e-05,
        2.217275538174246e-05,
        2.1870621334005648e-05,
        2.1582139704426868e-05,
        2.130669577237761e-05,
        2.1043717849100575e-05,
        2.0792673747930988e-05,
        2.055306762296488e-05,
        2.032443713123616e-05,
        2.010635087990908e-05,
        1.98984061252184e-05,
        1.9700226694546013e-05,
        1.9511461106713267e-05,
        1.933178086889817e-05,
        1.9160878931373005e-05,
        1.899846828356822e-05,
        1.884428067707628e-05,
        1.8698065462951875e-05,
        1.8559588532162393e-05,
        1.8428631349392315e-05,
        1.8304990071533414e-05,
        1.818847474319183e-05,
        1.8078908562452793e-05,
        1.7976127210837498e-05,
        1.7879978242150546e-05,
        1.7790320525417447e-05,
        1.7707023737754192e-05,
        1.762996790333897e-05,
        1.7559042975232042e-05,
        1.7494148456991636e-05,
        1.743519306154254e-05,
        1.738209440488979e-05,
        1.7334778732690254e-05,
        1.7293180677838852e-05,
        1.725724304753218e-05,
        1.7226916638359184e-05,
        1.720216007837179e-05,
        1.7182939695025778e-05,
        1.7169229408234154e-05,
        1.7161010647882455e-05,
        8.57913614761138e-06,
    ]


def welch_fixture() -> List[Float64]:
    return [
        5.546941657281157e-06,
        0.03984385061352736,
        0.0019674753512779575,
        0.00012297136150989614,
        1.9677317586329818e-05,
        4.920376323489761e-06,
        1.6073029936557915e-06,
        6.282910885263701e-07,
        2.7955597452836603e-07,
        1.3722151512194474e-07,
        7.276915491445699e-08,
        4.10880445938845e-08,
        2.444443870562554e-08,
        1.520631500461787e-08,
        9.836326543696517e-09,
        0.026640183698027012,
        0.10671071649809172,
        0.026648081296865966,
        2.40348277487229e-09,
        1.8334810765841624e-09,
        1.4526351538451393e-09,
        1.2031524021470996e-09,
        1.0515057066556926e-09,
        9.812224170069879e-10,
        9.905308787130003e-10,
        1.0946839998588545e-09,
        1.335206815342698e-09,
        1.8030224829651082e-09,
        2.694286565238636e-09,
        4.451960492574226e-09,
        8.155893657604042e-09,
        1.672117781896163e-08,
        3.9128650721864414e-08,
        1.083471469238518e-07,
        3.790097609285623e-07,
        1.9050990955125369e-06,
        1.8752745969136478e-05,
        0.0013531633077714415,
        0.021646495592567205,
        0.016574313883726297,
        0.000392187615750022,
        1.0882806193970238e-05,
        1.313853944995555e-06,
        2.822566807825219e-07,
        8.357561561042296e-08,
        3.0426541847422894e-08,
        1.2802028566546932e-08,
        5.995797733878223e-09,
        3.049913588831672e-09,
        1.6566585981251744e-09,
        9.492569919821412e-10,
        5.685961077527794e-10,
        3.535851996331671e-10,
        2.2704955983209576e-10,
        1.4991180698745683e-10,
        1.0142732761936248e-10,
        7.012459038805767e-11,
        4.94297925667198e-11,
        3.545569774704732e-11,
        2.5838790542313346e-11,
        1.910580757883403e-11,
        1.4317641622894897e-11,
        1.086344868341599e-11,
        8.338537910667339e-12,
        6.4702631742241035e-12,
        5.07209278632101e-12,
        4.0145914276888445e-12,
        3.206760832612952e-12,
        2.5838448479723267e-12,
        2.0992386816554628e-12,
        1.719045739200266e-12,
        1.4183679059217042e-12,
        1.1787464743679777e-12,
        9.863767494274204e-13,
        8.308491723769006e-13,
        7.042527989651917e-13,
        6.005308310514969e-13,
        5.150132172064768e-13,
        4.4407483342587857e-13,
        3.8488350985989543e-13,
        3.3521289146247215e-13,
        2.9330245736745333e-13,
        2.5775208924446215e-13,
        2.27442161969258e-13,
        2.0147257933855862e-13,
        1.791160138678785e-13,
        1.597818076169308e-13,
        1.4298797615736557e-13,
        1.283393629313822e-13,
        1.155105220779969e-13,
        1.0423222732972588e-13,
        9.42807987452393e-14,
        8.546961612748868e-14,
        7.764233750813488e-14,
        7.066746859668375e-14,
        6.443397826094705e-14,
        5.88477649004695e-14,
        5.382877917534843e-14,
        4.930868376207872e-14,
        4.522893760780617e-14,
        4.153922531677517e-14,
        3.8196161724789604e-14,
        3.516222106380591e-14,
        3.2404849866314176e-14,
        2.9895729638294416e-14,
        2.7610158405148657e-14,
        2.5526536939062027e-14,
        2.3625933944358052e-14,
        2.1891722340203407e-14,
        2.0309270688492463e-14,
        1.886568261972169e-14,
        1.754957593943439e-14,
        1.635089400579811e-14,
        1.5260745443585282e-14,
        1.4271267791528335e-14,
        1.3375510259876055e-14,
        1.2567332691070675e-14,
        1.1841321728934992e-14,
        1.1192715540868649e-14,
        1.061734192302917e-14,
        1.0111565015612299e-14,
        9.672238932466824e-15,
        9.296669546298919e-15,
        8.982582353647471e-15,
        8.728095171567301e-15,
        8.531696362793901e-15,
        8.392227969680062e-15,
        8.308871556389653e-15,
        4.14056995533325e-15,
    ]


def test_periodogram_matches_scipy_fixture() raises:
    var signal = synthesize(256)
    var spectrum = periodogram(signal, 800.0)
    var frequencies = spectrum.frequencies()
    assert_equal(len(spectrum), 129)
    assert_equal(frequencies[0], 0.0)
    assert_equal(frequencies[1], 3.125)
    assert_equal(frequencies[2], 6.25)
    assert_equal(frequencies[3], 9.375)
    var expected = periodogram_fixture()
    assert_power_near(spectrum.power(), expected)


def test_welch_matches_scipy_fixture_and_exact_frequencies() raises:
    var signal = synthesize(512)
    var spectrum = welch(signal, 800.0, segment_length=256)
    var expected = welch_fixture()
    assert_power_near(spectrum.power(), expected)
    var frequencies = spectrum.frequencies()
    assert_equal(frequencies[0], 0.0)
    assert_equal(frequencies[16], 50.0)
    assert_equal(frequencies[128], 400.0)


def test_periodogram_parseval_for_exact_bin_sinusoid() raises:
    var signal = List[Float64](capacity=256)
    for index in range(256):
        signal.append(sin(2.0 * pi * 16.0 * Float64(index) / 256.0))
    var spectrum = periodogram(signal)
    var power = spectrum.power()
    var density_sum = 0.0
    var dominant_count = 0
    for index in range(len(power)):
        density_sum += power[index]
        if power[index] > 1e-6:
            dominant_count += 1
    assert_equal(dominant_count, 1)
    assert_true(power[16] > 127.999)
    assert_true(abs(density_sum / 256.0 - 0.5) <= 1e-6)


def test_welch_three_segment_arithmetic_and_short_signal_error() raises:
    var constant = List[Float64](length=512, fill=3.25)
    var spectrum = welch(
        constant,
        800.0,
        segment_length=256,
        overlap=128,
    )
    for value in spectrum.power():
        assert_true(abs(value) <= 1e-15)

    var short = List[Float64](length=128, fill=0.0)
    with assert_raises(contains="signal_length=128, segment_length=256"):
        _ = welch(short, 800.0, segment_length=256)


def test_power_of_two_errors_suggest_nearest_values() raises:
    var signal = List[Float64](length=100, fill=0.0)
    with assert_raises(contains="nearest are 64 and 128"):
        _ = periodogram(signal)

    var longer = List[Float64](length=200, fill=0.0)
    with assert_raises(contains="nearest are 64 and 128"):
        _ = welch(longer, segment_length=100)


def test_sample_rate_overlap_and_finite_input_errors() raises:
    var signal = List[Float64](length=256, fill=0.0)
    with assert_raises(contains="sample_rate must be positive and finite"):
        _ = periodogram(signal, 0.0)
    with assert_raises(contains="overlap=256, segment_length=256"):
        _ = welch(signal, overlap=256)
    signal[4] = Float64("nan")
    with assert_raises(contains="got signal[4]=nan"):
        _ = welch(signal)


def test_readme_detrend_welch_find_peaks_workflow() raises:
    var samples = List[Float64](capacity=2048)
    for index in range(2048):
        var t = Float64(index) / 800.0
        samples.append(
            sin(2.0 * pi * 50.0 * t)
            + 0.3 * sin(2.0 * pi * 175.0 * t)
            + 0.002 * Float64(index)
        )

    var stationary = detrend(samples)
    var spectrum = welch(stationary, 800.0, segment_length=256)
    var peaks = find_peaks(spectrum.power(), min_prominence=0.001)
    var indices = peaks.indices()
    var frequencies = spectrum.frequencies()
    var power = spectrum.power()
    assert_equal(len(peaks), 2)
    assert_equal(frequencies[indices[0]], 50.0)
    assert_equal(frequencies[indices[1]], 175.0)
    assert_power_value_near(power[indices[0]], 0.10666669953353614)
    assert_power_value_near(power[indices[1]], 0.00960000022519727)


def test_power_spectrum_value_contract() raises:
    var frequencies: List[Float64] = [0.0, 1.0]
    var power: List[Float64] = [0.25, 0.5]
    var spectrum = PowerSpectrum(
        _frequencies=frequencies^,
        _power=power^,
    )
    assert_equal(len(spectrum), 2)
    assert_equal(spectrum.frequencies()[1], 1.0)
    assert_equal(spectrum.power()[0], 0.25)

    var equal_frequencies: List[Float64] = [0.0, 1.0]
    var equal_power: List[Float64] = [0.25, 0.5]
    var equal = PowerSpectrum(
        _frequencies=equal_frequencies^,
        _power=equal_power^,
    )
    assert_true(spectrum == equal)
    assert_equal(
        String(spectrum),
        "PowerSpectrum(bins=2, one_sided_density=True)",
    )

    spectrum._power.append(0.75)
    with assert_raises(contains="got frequencies=2, power=3"):
        spectrum.validate()


def test_power_spectrum_constructor_rejects_parallel_length_mismatch() raises:
    var frequencies: List[Float64] = [0.0, 1.0]
    var power: List[Float64] = [0.25]
    with assert_raises(contains="got frequencies=2, power=1"):
        _ = PowerSpectrum(_frequencies=frequencies^, _power=power^)


def test_spectrogram_matches_direct_dft_oracle_and_frame_coordinates() raises:
    var signal: List[Float64] = [
        0.0,
        1.0,
        0.0,
        -1.0,
        1.0,
        0.0,
        -1.0,
        0.0,
        0.5,
        -0.5,
        0.5,
        -0.5,
    ]
    var result = spectrogram(
        signal,
        8.0,
        segment_length=8,
        overlap=4,
    )
    assert_equal(result.frame_count(), 2)
    assert_equal(result.bin_count(), 5)

    var times = result.times()
    assert_equal(len(times), 2)
    assert_equal(times[0], 0.5)
    assert_equal(times[1], 1.0)

    var frequencies = result.frequencies()
    assert_equal(len(frequencies), 5)
    for index in range(5):
        assert_equal(frequencies[index], Float64(index))

    # Independent periodic-Hann, constant-detrended direct-DFT oracle. Rows
    # are frames and columns are DC through Nyquist.
    var expected: List[Float64] = [
        0.0017872174505605205,
        0.007148869802242077,
        0.27083333333333337,
        0.3261844635310912,
        0.06071278254943947,
        0.002604166666666666,
        0.018305826175840773,
        0.057291666666666644,
        0.1483608404908259,
        0.023437500000000007,
    ]
    assert_power_near(result.power(), expected)


def test_spectrogram_frame_mean_matches_welch_policy() raises:
    var signal = synthesize(512)
    var frames = spectrogram(signal, 800.0, segment_length=256)
    var averaged = welch(signal, 800.0, segment_length=256)
    assert_equal(frames.frame_count(), 3)
    assert_equal(frames.bin_count(), len(averaged))

    var frame_power = frames.power()
    var averaged_power = averaged.power()
    for bin_index in range(frames.bin_count()):
        var total = 0.0
        for frame_index in range(frames.frame_count()):
            total += frame_power[frame_index * frames.bin_count() + bin_index]
        assert_power_value_near(
            total / Float64(frames.frame_count()), averaged_power[bin_index]
        )


def test_spectrogram_errors_name_invalid_configuration() raises:
    var short = List[Float64](length=7, fill=0.0)
    with assert_raises(contains="signal_length=7, segment_length=8"):
        _ = spectrogram(short, segment_length=8)

    var signal = List[Float64](length=8, fill=0.0)
    with assert_raises(contains="overlap=8, segment_length=8"):
        _ = spectrogram(signal, segment_length=8, overlap=8)
    with assert_raises(contains="nearest are 4 and 8"):
        _ = spectrogram(signal, segment_length=6)
    signal[3] = Float64("nan")
    with assert_raises(contains="got signal[3]=nan"):
        _ = spectrogram(signal, segment_length=8)


def test_spectrogram_value_contract() raises:
    var times: List[Float64] = [0.5]
    var frequencies: List[Float64] = [0.0, 1.0]
    var power: List[Float64] = [0.25, 0.5]
    var result = Spectrogram(
        _times=times^,
        _frequencies=frequencies^,
        _power=power^,
        _frame_count=1,
        _bin_count=2,
    )
    assert_equal(result.frame_count(), 1)
    assert_equal(result.bin_count(), 2)
    assert_equal(result.power()[1], 0.5)
    assert_equal(
        String(result),
        "Spectrogram(frames=1, bins=2, layout=frame-major, one_sided_density=True)",
    )

    var equal_times: List[Float64] = [0.5]
    var equal_frequencies: List[Float64] = [0.0, 1.0]
    var equal_power: List[Float64] = [0.25, 0.5]
    var equal = Spectrogram(
        _times=equal_times^,
        _frequencies=equal_frequencies^,
        _power=equal_power^,
        _frame_count=1,
        _bin_count=2,
    )
    assert_true(result == equal)

    result._power.append(0.75)
    with assert_raises(contains="power=3"):
        result.validate()


def test_spectrogram_constructor_rejects_shape_mismatch() raises:
    var times: List[Float64] = [0.5]
    var frequencies: List[Float64] = [0.0, 1.0]
    var power: List[Float64] = [0.25]
    with assert_raises(contains="expected_power=2"):
        _ = Spectrogram(
            _times=times^,
            _frequencies=frequencies^,
            _power=power^,
            _frame_count=1,
            _bin_count=2,
        )


def test_spectrogram_validation_rejects_dimension_product_overflow() raises:
    var times: List[Float64] = [0.5]
    var frequencies: List[Float64] = [0.0]
    var power: List[Float64] = [0.25]
    var result = Spectrogram(
        _times=times^,
        _frequencies=frequencies^,
        _power=power^,
        _frame_count=1,
        _bin_count=1,
    )
    result._frame_count = Int.MAX
    result._bin_count = 2
    with assert_raises(
        contains=(
            "Spectrogram power dimensions overflow Int; got "
            "frame_count=9223372036854775807, bin_count=2"
        )
    ):
        result.validate()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
