# tools/generate-rocky-sounds.ps1
# ============================================================
# Generates Rocky's voice samples for the clawd-pet-themes project.
#
# Two layers:
#   L1 — marimba-like tonal chord (Rocky's organic "voice")
#   L2 — Windows TTS English word (translator) with light mechanical effect
#
# Outputs WAV files into both rocky-domed/sounds/ and rocky-bare/sounds/
#
# Usage (from any shell):  pwsh tools/generate-rocky-sounds.ps1
#                          (or)  powershell -File tools/generate-rocky-sounds.ps1
#
# Zero external dependencies — uses only built-in .NET + Windows TTS.
# ============================================================

Add-Type -AssemblyName System.Speech

$ErrorActionPreference = "Stop"
$SampleRate = 44100

# ====== Synthesis Helpers ======

function New-StoneSamples {
    <#
    Synthesizes a stone-chime-like tone for one or more frequencies.
    Stone sound = strong fundamental + lightly detuned octave + small detuned 5th + tiny high partial,
    with crisp attack burst (initial noise) and slow exponential decay (like a chime stone).
    The slight inharmonicity (2.01x, 3.04x, 5.07x) is what makes it "stone" instead of "wood".
    #>
    param(
        [double[]]$Frequencies,
        [double]$DurationSec = 0.45,
        [double]$AttackSec = 0.005,
        [double]$DecayPow = 2.5
    )
    $totalSamples = [int]($DurationSec * $SampleRate)
    $samples = [double[]]::new($totalSamples)
    $attackSamples = [int]($AttackSec * $SampleRate)
    $noiseBurstSec = 0.008
    $rng = [Random]::new(42)

    foreach ($freq in $Frequencies) {
        for ($i = 0; $i -lt $totalSamples; $i++) {
            $t = $i / [double]$SampleRate

            if ($i -lt $attackSamples) {
                $envelope = $i / [double]$attackSamples
            } else {
                $envelope = [Math]::Exp(-$DecayPow * ($t - $AttackSec) / $DurationSec)
            }

            # Stone chime waveform: fundamental + slightly inharmonic partials (key to "stone" feel)
            $signal  = [Math]::Sin(2 * [Math]::PI * $freq * $t)
            $signal += 0.40 * [Math]::Sin(2 * [Math]::PI * (2.01 * $freq) * $t)   # octave + slight detune
            $signal += 0.12 * [Math]::Sin(2 * [Math]::PI * (3.04 * $freq) * $t)   # 5th + detune
            $signal += 0.04 * [Math]::Sin(2 * [Math]::PI * (5.07 * $freq) * $t)   # high sparkle

            # Initial "scrape" noise burst (sharp percussive attack of stone-on-stone)
            if ($t -lt $noiseBurstSec) {
                $noiseEnv = (1 - $t / $noiseBurstSec)
                $signal += ($rng.NextDouble() * 2 - 1) * 0.18 * $noiseEnv
            }

            $samples[$i] += $signal * $envelope
        }
    }

    # Normalize to 0.85 amplitude
    $max = 0.0
    foreach ($s in $samples) { if ([Math]::Abs($s) -gt $max) { $max = [Math]::Abs($s) } }
    if ($max -gt 0) {
        $scale = 0.85 / $max
        for ($i = 0; $i -lt $totalSamples; $i++) { $samples[$i] = $samples[$i] * $scale }
    }
    return ,$samples
}

function ConvertTo-Int16Array {
    param([double[]]$DoubleSamples)
    $int16 = [int16[]]::new($DoubleSamples.Length)
    for ($i = 0; $i -lt $DoubleSamples.Length; $i++) {
        $v = [int]($DoubleSamples[$i] * 32000)
        if ($v -gt 32767)  { $v = 32767 }
        if ($v -lt -32768) { $v = -32768 }
        $int16[$i] = [int16]$v
    }
    return ,$int16
}

function Concat-DoubleArrays {
    param([double[][]]$Arrays)
    $total = 0
    foreach ($a in $Arrays) { $total += $a.Length }
    $out = [double[]]::new($total)
    $offset = 0
    foreach ($a in $Arrays) {
        [Array]::Copy($a, 0, $out, $offset, $a.Length)
        $offset += $a.Length
    }
    return ,$out
}

# ====== WAV File I/O ======

function Write-WavFile {
    param([string]$Path, [int16[]]$Samples)

    $dataSize = $Samples.Length * 2
    $fileSize = 36 + $dataSize
    $byteRate = $SampleRate * 2

    $stream = [System.IO.File]::Create($Path)
    $writer = New-Object System.IO.BinaryWriter($stream)
    try {
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
        $writer.Write([int]$fileSize)
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
        $writer.Write([int]16)              # fmt chunk size
        $writer.Write([int16]1)             # PCM
        $writer.Write([int16]1)             # mono
        $writer.Write([int]$SampleRate)
        $writer.Write([int]$byteRate)
        $writer.Write([int16]2)             # block align
        $writer.Write([int16]16)            # bits per sample
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
        $writer.Write([int]$dataSize)
        foreach ($s in $Samples) { $writer.Write($s) }
    } finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

function Read-WavSamples {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    # Find "data" chunk
    $dataIdx = -1
    for ($i = 12; $i -le $bytes.Length - 8; $i++) {
        if ([System.Text.Encoding]::ASCII.GetString($bytes, $i, 4) -eq "data") {
            $dataIdx = $i + 8
            break
        }
    }
    if ($dataIdx -lt 0) { throw "data chunk not found in $Path" }
    # Find sample rate (offset 24-28 in fmt chunk)
    $sr = [BitConverter]::ToInt32($bytes, 24)
    $sampleCount = ($bytes.Length - $dataIdx) / 2
    $samples = [int16[]]::new($sampleCount)
    for ($i = 0; $i -lt $sampleCount; $i++) {
        $samples[$i] = [BitConverter]::ToInt16($bytes, $dataIdx + $i * 2)
    }
    return @{ Samples = $samples; SampleRate = $sr }
}

# ====== TTS + Light Robot Effect ======

function New-TtsSamples {
    param(
        [string]$Text,
        [string]$VoiceFilter = "David",   # 'David' (male) or 'Zira' (female) on Windows
        [int]$Rate = 0
    )
    $tmpFile = [System.IO.Path]::GetTempFileName() + ".wav"
    $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
    try {
        $voice = $synth.GetInstalledVoices() | Where-Object {
            $_.VoiceInfo.Name -like "*$VoiceFilter*"
        } | Select-Object -First 1
        if ($voice) { $synth.SelectVoice($voice.VoiceInfo.Name) }
        $synth.Rate = $Rate
        $synth.Volume = 100
        $synth.SetOutputToWaveFile($tmpFile)
        $synth.Speak($Text)
        $synth.SetOutputToNull()
    } finally {
        $synth.Dispose()
    }
    $wav = Read-WavSamples -Path $tmpFile
    Remove-Item $tmpFile -Force
    return $wav   # hashtable { Samples; SampleRate }
}

function Apply-LightRobotEffect {
    <#
    Light "translator radio" effect, tuned for "young / teen" vibe:
    - Speed-up via SlowFactor (raises pitch when < 1.0)
    - One-pole low-pass filter at ~5kHz (gentle high-frequency rolloff for telephone feel)
    - Configurable volume boost (TTS is often quiet)
    Inputs/outputs are int16 mono samples; resampled to $SampleRate.
    #>
    param(
        [int16[]]$Samples,
        [int]$SourceSampleRate,
        [double]$SlowFactor = 0.85,
        [double]$LowPassHz = 5000,
        [double]$VolumeBoost = 1.4
    )

    # Step 1: resample to $SampleRate AND apply slow factor
    $srcLen = $Samples.Length
    $outLen = [int]($srcLen * $SampleRate / $SourceSampleRate * $SlowFactor)
    $out = [double[]]::new($outLen)
    for ($i = 0; $i -lt $outLen; $i++) {
        $srcPos = $i * $SourceSampleRate / [double]$SampleRate / $SlowFactor
        $srcIdx = [int]$srcPos
        if ($srcIdx -lt $srcLen - 1) {
            $frac = $srcPos - $srcIdx
            $out[$i] = ($Samples[$srcIdx] * (1 - $frac) + $Samples[$srcIdx + 1] * $frac) / 32768.0
        } elseif ($srcIdx -lt $srcLen) {
            $out[$i] = $Samples[$srcIdx] / 32768.0
        }
    }

    # Step 2: one-pole low-pass filter
    $rc = 1.0 / (2 * [Math]::PI * $LowPassHz)
    $dt = 1.0 / $SampleRate
    $alpha = $dt / ($rc + $dt)
    $prev = 0.0
    for ($i = 0; $i -lt $outLen; $i++) {
        $prev = $prev + $alpha * ($out[$i] - $prev)
        $out[$i] = $prev
    }

    # Step 3: volume boost
    for ($i = 0; $i -lt $outLen; $i++) { $out[$i] = $out[$i] * $VolumeBoost }

    return ,(ConvertTo-Int16Array $out)
}

function Repeat-Int16 {
    <#
    Plays a single sample buffer N times with a small gap between repetitions.
    Identical reps. (Kept for reference — current pipeline uses Repeat-WithVariation
    which gives each rep slightly different pitch/speed/volume for a less-robotic feel.)
    #>
    param(
        [int16[]]$Sample,
        [int]$Reps = 3,
        [int]$GapMs = 60
    )
    $gap = [int]($GapMs * $SampleRate / 1000)
    $totalLen = ($Sample.Length + $gap) * $Reps - $gap
    $out = [int16[]]::new($totalLen)
    $offset = 0
    for ($r = 0; $r -lt $Reps; $r++) {
        [Array]::Copy($Sample, 0, $out, $offset, $Sample.Length)
        $offset += $Sample.Length + $gap
    }
    return ,$out
}

function Repeat-WithVariation {
    <#
    Generates N repetitions of a TTS source with per-rep variation in pitch/speed,
    volume, and inter-rep gap. Keeps Rocky's signature triple-rep cadence but adds
    natural-sounding micro-variation so it doesn't feel mechanical.

    SlowFactors:   one per rep. Smaller = faster + higher pitch.
    VolumeFactors: one per rep. Multiplied with the LightRobotEffect base boost.
    GapsMs:        gap[i] is the silence AFTER rep[i]. Length = (reps - 1).
    #>
    param(
        [int16[]]$Source,
        [int]$SourceSampleRate,
        [double[]]$SlowFactors,
        [double[]]$VolumeFactors,
        [int[]]$GapsMs
    )
    $reps = @()
    for ($i = 0; $i -lt $SlowFactors.Length; $i++) {
        $r = Apply-LightRobotEffect `
            -Samples $Source `
            -SourceSampleRate $SourceSampleRate `
            -SlowFactor $SlowFactors[$i] `
            -VolumeBoost $VolumeFactors[$i]
        $reps += ,$r
    }
    # Concatenate with gaps
    $totalLen = 0
    foreach ($r in $reps) { $totalLen += $r.Length }
    foreach ($g in $GapsMs) { $totalLen += [int]($g * $SampleRate / 1000) }

    $out = [int16[]]::new($totalLen)
    $offset = 0
    for ($i = 0; $i -lt $reps.Length; $i++) {
        [Array]::Copy($reps[$i], 0, $out, $offset, $reps[$i].Length)
        $offset += $reps[$i].Length
        if ($i -lt $reps.Length - 1) {
            $offset += [int]($GapsMs[$i] * $SampleRate / 1000)
        }
    }
    return ,$out
}

# ====== Combiners ======

function Concat-Int16WithGap {
    param(
        [int16[]]$First,
        [int16[]]$Second,
        [int]$GapMs = 40
    )
    $gap = [int]($GapMs * $SampleRate / 1000)
    $total = $First.Length + $gap + $Second.Length
    $out = [int16[]]::new($total)
    [Array]::Copy($First, 0, $out, 0, $First.Length)
    [Array]::Copy($Second, 0, $out, $First.Length + $gap, $Second.Length)
    return ,$out
}

function New-RockyOrganicSamples {
    <#
    Synthesizes Rocky's "jelly-squeeze + electric wave" original voice — the
    underlying sound the translator decodes from. Combines:
      - Low sine fundamental (body)
      - Optional ultra-slow base-frequency drift (UFO "tide" effect)
      - Pitch LFO (vibrato — the "wave" wobble)
      - Optional ring modulation (gives a metallic / "phasing" character)
      - Slow amplitude LFO (tremolo — the "jelly squeeze" squelch)
      - Small square-wave mix (synthy alien character)
      - Soft ADSR (slow attack + slow release for natural bed feel)
    Used as a bed underneath the translator voice — present throughout.
    #>
    param(
        [double]$Duration,
        [double]$BaseFreq = 180,
        [double]$WobbleHz = 2.5,
        [double]$WobbleDepth = 30,
        [double]$AmpModHz = 1.5,
        [double]$AmpModDepth = 0.50,
        [double]$SquareMix = 0.05,
        [double]$AttackSec = 0.06,
        [double]$ReleaseSec = 0.25,
        [double]$BaseDriftHz = 0,
        [double]$BaseDriftDepth = 0,
        [double]$RingModHz = 0,
        [double]$RingModMix = 0
    )
    $samples = [int]($Duration * $SampleRate)
    $audio = [double[]]::new($samples)
    $phase = 0.0

    for ($i = 0; $i -lt $samples; $i++) {
        $t = $i / [double]$SampleRate

        # Ultra-slow drift of the base frequency itself (UFO tide)
        $currentBase = $BaseFreq + $BaseDriftDepth * [Math]::Sin(2 * [Math]::PI * $BaseDriftHz * $t)
        # Faster wobble on top
        $instFreq = $currentBase + $WobbleDepth * [Math]::Sin(2 * [Math]::PI * $WobbleHz * $t)
        $phase += 2 * [Math]::PI * $instFreq / [double]$SampleRate

        # Carrier waveform
        $sine = [Math]::Sin($phase)
        $square = if ($sine -gt 0) { 1.0 } else { -1.0 }
        $waveform = $sine * (1 - $SquareMix) + $square * $SquareMix

        # Ring modulation: blend original with carrier × ring oscillator
        if ($RingModMix -gt 0) {
            $ringSig = $waveform * [Math]::Sin(2 * [Math]::PI * $RingModHz * $t)
            $waveform = $waveform * (1 - $RingModMix) + $ringSig * $RingModMix
        }

        # Amplitude LFO — the "jelly squeeze"
        $ampMod = (1 - $AmpModDepth) + $AmpModDepth * (0.5 + 0.5 * [Math]::Sin(2 * [Math]::PI * $AmpModHz * $t))
        $waveform = $waveform * $ampMod

        # ADSR
        $envelope = 1.0
        if ($t -lt $AttackSec) {
            $envelope = $t / $AttackSec
        } elseif ($t -gt $Duration - $ReleaseSec) {
            $envelope = [Math]::Max(0, ($Duration - $t) / $ReleaseSec)
        }

        $audio[$i] = $waveform * $envelope * 0.6
    }

    # Normalize to 0.85 amplitude
    $max = 0.0
    foreach ($s in $audio) { if ([Math]::Abs($s) -gt $max) { $max = [Math]::Abs($s) } }
    if ($max -gt 0) {
        $scale = 0.85 / $max
        for ($i = 0; $i -lt $samples; $i++) { $audio[$i] *= $scale }
    }
    return ,$audio
}

function Mix-Bed {
    <#
    Mixes a "bed" sound (Rocky's organic underlay) throughout a voice track,
    starting at t=0. Unlike Mix-Tail (which only appends at the end), this lets
    the bed sit UNDER the entire voice — so it feels like the translator voice
    is being decoded FROM the bed, rather than tacked onto it.
    #>
    param(
        [int16[]]$Voice,
        [int16[]]$Bed,
        [double]$BedAmplitude = 0.18
    )
    $outLen = [Math]::Max($Voice.Length, $Bed.Length)
    $out = [double[]]::new($outLen)
    for ($i = 0; $i -lt $Voice.Length; $i++) {
        $out[$i] = $Voice[$i] / 32768.0
    }
    for ($i = 0; $i -lt $Bed.Length; $i++) {
        if ($i -lt $outLen) {
            $out[$i] += ($Bed[$i] / 32768.0) * $BedAmplitude
        }
    }
    return ,(ConvertTo-Int16Array $out)
}

function Mix-Tail {
    <#
    Mixes a resonance "tail" sound into the end of a voice track.
    The tail starts $OverlapMs BEFORE the voice ends, so its onset blends with
    the voice's last syllable (feels integrated, not appended). The tail then
    continues to ring out after the voice finishes.

    Use case: subtle stone-cavity resonance after Rocky's translator voice — like
    his stone body cavity is naturally vibrating in sympathy with the words coming out.
    #>
    param(
        [int16[]]$Voice,
        [int16[]]$Tail,
        [double]$TailAmplitude = 0.22,
        [int]$OverlapMs = 100
    )
    $overlapSamples = [int]($OverlapMs * $SampleRate / 1000)
    $tailStart = $Voice.Length - $overlapSamples
    if ($tailStart -lt 0) { $tailStart = 0 }
    $tailEnd = $tailStart + $Tail.Length
    $outLen = [Math]::Max($Voice.Length, $tailEnd)

    $out = [double[]]::new($outLen)
    for ($i = 0; $i -lt $Voice.Length; $i++) {
        $out[$i] = $Voice[$i] / 32768.0
    }
    for ($i = 0; $i -lt $Tail.Length; $i++) {
        $idx = $tailStart + $i
        if ($idx -lt $outLen) {
            $out[$idx] += ($Tail[$i] / 32768.0) * $TailAmplitude
        }
    }
    return ,(ConvertTo-Int16Array $out)
}

# ====== Generate Sounds ======
#
# Each entry below is one Rocky utterance. The pipeline for each is:
#   1. Windows TTS speaks the English word once  (translator output)
#   2. Repeat-WithVariation copies it 3x with per-rep pitch/speed/volume changes
#      (Rocky's iconic 'Question Question Question' triple-rep cadence)
#   3. New-RockyOrganicSamples generates a low UFO 'jelly + electric wave' bed
#      that runs UNDERNEATH the entire voice (Rocky's actual organic voice;
#      the TTS is what the translator decoded from it)
#   4. Mix-Bed combines them; written to BOTH themes/rocky/sounds/ and
#      themes/rocky-domed/sounds/.
#
# To add a new sound, copy an entry and tune. Per-word tuning principles:
#   slower SlowFactor   = lower pitch  = sad / heavy
#   faster SlowFactor   = higher pitch = excited / young
#   wider WobbleDepth   = more dramatic UFO undulation
#   slower WobbleHz     = more 'tide-like' waves
#   higher BedAmp       = bed more present, voice more shrouded

Write-Host ""
Write-Host "Generating Rocky's voice ($($soundDefs.Count) sounds)..." -ForegroundColor Cyan
Write-Host ""

$soundDefs = @(
    @{
        Name = "confirm";  Word = "Good";       TtsRate = 3
        SlowFactors   = @(0.85, 0.81, 0.84);  VolumeFactors = @(1.40, 1.30, 1.55);  GapsMs = @(50, 70)
        BedFreq = 180;     BedWobbleHz = 0.9;    BedWobbleDepth = 55
        BedAmpHz = 0.6;    BedAmpDepth = 0.60
        BedDriftHz = 0.25; BedDriftDepth = 40
        BedRingHz = 70;    BedRingMix = 0.30;    BedAmp = 0.13
    },
    @{
        Name = "complete"; Word = "Amaze";      TtsRate = 3
        SlowFactors   = @(0.85, 0.80, 0.83);  VolumeFactors = @(1.40, 1.30, 1.60);  GapsMs = @(60, 85)
        BedFreq = 220;     BedWobbleHz = 1.035;  BedWobbleDepth = 60.5
        BedAmpHz = 0.69;   BedAmpDepth = 0.60
        BedDriftHz = 0.275; BedDriftDepth = 40
        BedRingHz = 77;    BedRingMix = 0.30;    BedAmp = 0.13
    },
    @{
        # ERROR — slower, lower pitched, melancholic 'Sad Sad Sad'
        Name = "error";    Word = "Sad";        TtsRate = 1
        SlowFactors   = @(0.92, 0.88, 0.94);  VolumeFactors = @(1.30, 1.25, 1.40);  GapsMs = @(80, 110)
        BedFreq = 160;     BedWobbleHz = 0.7;    BedWobbleDepth = 65
        BedAmpHz = 0.5;    BedAmpDepth = 0.65
        BedDriftHz = 0.20; BedDriftDepth = 45
        BedRingHz = 60;    BedRingMix = 0.35;    BedAmp = 0.16
    },
    @{
        # THINKING — third rep faster + higher (rising = question intonation)
        Name = "thinking"; Word = "Question";   TtsRate = 2
        SlowFactors   = @(0.86, 0.82, 0.78);  VolumeFactors = @(1.30, 1.30, 1.40);  GapsMs = @(60, 80)
        BedFreq = 200;     BedWobbleHz = 0.95;   BedWobbleDepth = 50
        BedAmpHz = 0.65;   BedAmpDepth = 0.55
        BedDriftHz = 0.28; BedDriftDepth = 38
        BedRingHz = 75;    BedRingMix = 0.28;    BedAmp = 0.13
    },
    @{
        # WAKING — snappy and bright 'Yes Yes Yes', third rep settles
        Name = "waking";   Word = "Yes";        TtsRate = 4
        SlowFactors   = @(0.83, 0.80, 0.86);  VolumeFactors = @(1.35, 1.30, 1.50);  GapsMs = @(40, 55)
        BedFreq = 210;     BedWobbleHz = 1.1;    BedWobbleDepth = 50
        BedAmpHz = 0.75;   BedAmpDepth = 0.55
        BedDriftHz = 0.30; BedDriftDepth = 35
        BedRingHz = 80;    BedRingMix = 0.28;    BedAmp = 0.13
    }
)

# Resolve theme paths (script lives in scripts/, themes/ is sibling)
$root = Split-Path $PSScriptRoot -Parent
$themeNames = @("rocky", "rocky-domed")
foreach ($t in $themeNames) {
    $d = Join-Path $root "themes/$t/sounds"
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
}

foreach ($s in $soundDefs) {
    Write-Host ("  [{0,-9}] '{1} x3'..." -f $s.Name, $s.Word) -NoNewline

    # 1. TTS source word
    $tts = New-TtsSamples -Text $s.Word -Rate $s.TtsRate

    # 2. Triple-rep with per-rep variation
    $voice = Repeat-WithVariation `
        -Source $tts.Samples -SourceSampleRate $tts.SampleRate `
        -SlowFactors $s.SlowFactors `
        -VolumeFactors $s.VolumeFactors `
        -GapsMs $s.GapsMs

    # 3. Organic UFO bed underlay matching voice duration
    $voiceDurSec = $voice.Length / [double]$SampleRate
    $bed = ConvertTo-Int16Array (New-RockyOrganicSamples `
        -Duration ($voiceDurSec + 0.3) -BaseFreq $s.BedFreq -SquareMix 0.0 `
        -WobbleHz $s.BedWobbleHz -WobbleDepth $s.BedWobbleDepth `
        -AmpModHz $s.BedAmpHz -AmpModDepth $s.BedAmpDepth `
        -BaseDriftHz $s.BedDriftHz -BaseDriftDepth $s.BedDriftDepth `
        -RingModHz $s.BedRingHz -RingModMix $s.BedRingMix)

    # 4. Mix
    $final = Mix-Bed -Voice $voice -Bed $bed -BedAmplitude $s.BedAmp

    # 5. Write to both themes
    foreach ($t in $themeNames) {
        $path = Join-Path $root "themes/$t/sounds/$($s.Name).wav"
        Write-WavFile -Path $path -Samples $final
    }

    $kb = [Math]::Round($final.Length * 2 / 1024, 1)
    Write-Host (" ok ({0}KB)" -f $kb)
}

Write-Host ""
Write-Host "Done. $($soundDefs.Count) sounds in themes/rocky/sounds/ and themes/rocky-domed/sounds/" -ForegroundColor Green
Write-Host ""
