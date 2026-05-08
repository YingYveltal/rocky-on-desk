# Rocky Sound Design Guide

How Rocky's voice works, how to generate new sounds, and how to tune parameters to get the right feel.

## Concept

Rocky's voice has two layers playing simultaneously:

| Layer | What | Source |
|-------|------|--------|
| **Translator voice** | English word spoken 3 times (Rocky's signature triple-rep cadence) | Windows TTS + light robot effect |
| **Organic bed** | Low, slow UFO-like "jelly-squeeze + electric wave" tone | Fully synthesized (sine + LFO modulation chain) |

The organic bed runs **underneath** the translator voice from t=0 — it's Rocky's actual organic voice. The TTS is what the translator decoded from it. This is how the movie (Project Hail Mary) presents Rocky's speech.

## Synthesis Pipeline

```
$Word (English text)
  │
  ├─► New-TtsSamples()           ← Windows TTS speaks the word once (16-bit mono WAV)
  │     │
  │     └─► Apply-LightRobotEffect() × 3   ← per-rep speed/pitch/volume variation + low-pass filter
  │           │
  │           └─► Repeat-WithVariation()    ← concatenate 3 reps with gaps, each rep slightly different
  │                 │
  │                 └─► Voice track (int16[])
  │
  └─► New-RockyOrganicSamples()  ← synthesize organic UFO bed for voice duration + 0.3s
        │                           (sine fundamental + base drift LFO + pitch wobble LFO
        │                            + amplitude LFO + ring modulation + square mix)
        │
        └─► Bed track (int16[])

  Voice track + Bed track
        │
        └─► Mix-Bed()            ← mix bed underneath voice at BedAmp volume
              │
              └─► Write-WavFile()   ← 16-bit PCM mono WAV, 44100Hz
                    │
                    └─► themes/{rocky,rocky-domed}/sounds/{Name}.wav
```

### Stage details

**1. TTS (New-TtsSamples)**
- Uses `System.Speech.Synthesis.SpeechSynthesizer` (built into Windows .NET, zero dependencies)
- Selects "David" (male) voice by default, falls back to any installed voice
- `TtsRate` controls base speaking speed (-10 to 10, adjusts in the TTS engine)
- Output: temporary WAV file (immediately cleaned up)

**2. Robot effect (Apply-LightRobotEffect)**
- Resamples TTS output to 44100Hz while applying `SlowFactor` (speed/pitch change)
- One-pole low-pass filter at 5kHz (gentle high-frequency rolloff — "translator radio" feel)
- Volume boost (TTS output is typically quiet; base VolumeFactor compensates)
- Per-rep SlowFactor variation gives each of the 3 repetitions a slightly different pitch/speed — this is what makes it feel natural instead of robotic

**3. Organic bed (New-RockyOrganicSamples)**
- Sine fundamental at `BedFreq` Hz
- Ultra-slow base frequency drift LFO at `BedDriftHz` — the "UFO tide" effect
- Pitch wobble LFO at `BedWobbleHz` — the "wave" undulation
- Amplitude LFO at `BedAmpHz` — the "jelly squeeze" squelch
- Ring modulation at `BedRingHz` — metallic "phasing" character
- Small square-wave mix for synth alien character
- Soft ADSR (6ms attack, 250ms release)

**4. Mix (Mix-Bed)**
- Both tracks normalized to 0.85 max amplitude before mixing
- Bed mixed at `BedAmp` volume (0.13–0.16 typical — present but not overpowering)

## Parameter Reference

### TTS parameters (per sound)

| Parameter | Range | Description |
|-----------|-------|-------------|
| `Word` | any English text | The word Rocky speaks. Keep it short (1-3 syllables). |
| `TtsRate` | -10 to 10 | Base TTS speaking speed. 0=normal, higher=faster. |

### Per-repetition parameters (arrays of 3)

| Parameter | Typical range | Description |
|-----------|---------------|-------------|
| `SlowFactors` | 0.78–0.94 | Speed/pitch for each rep. Smaller = faster + higher pitch. Lower values = "younger/brighter"; higher = "slower/deeper". |
| `VolumeFactors` | 1.25–1.60 | Volume multiplier for each rep. Compensates for TTS quietness. |
| `GapsMs` | 40–110 | Silence gap after each rep (milliseconds). 2 values (gap after rep 1, gap after rep 2). Longer gaps = heavier/sadder feel. |

**Rep 3 pattern**: The third rep typically uses a slightly different SlowFactor from reps 1-2 to create variation:
- **Rising** (question): rep 3 SlowFactor < rep 1-2 (third rep is faster/higher — "Question?")  
- **Falling** (statement): rep 3 SlowFactor > rep 1-2 (third rep is slower/lower — settles down)
- **Flat** (neutral): all 3 similar (boring — avoid)

### Organic bed parameters (per sound)

| Parameter | Typical range | What it does |
|-----------|---------------|--------------|
| `BedFreq` | 160–220 Hz | Base sine frequency. Lower = deeper/powerful; higher = lighter/brighter. |
| `BedWobbleHz` | 0.7–1.1 | Pitch wobble speed. Slower = UFO "tide" feel; faster = more electric/jittery. Rock's current range (0.7–1.1) is calibrated for "slow UFO." |
| `BedWobbleDepth` | 50–65 | How far pitch bends during wobble (Hz). Higher = more dramatic undulation. |
| `BedAmpHz` | 0.5–0.75 | Amplitude LFO speed — the "squeeze" rate. Slow = lazy jelly; fast = nervous twitch. |
| `BedAmpDepth` | 0.55–0.65 | How much volume fluctuates. 0.6 = 40%-100% swing. Higher = more dramatic squelch. |
| `BedDriftHz` | 0.20–0.30 | Ultra-slow base frequency drift — the "UFO tide" breathing. Very slow! |
| `BedDriftDepth` | 35–45 | How far base drifts. 40 = fundamental bends ±40Hz over the drift cycle. |
| `BedRingHz` | 60–80 | Ring modulation carrier frequency. Lower = more "growly"; higher = more "metallic ring." |
| `BedRingMix` | 0.28–0.35 | How much ring modulation. 0.30 = 30% ring, 70% original. |
| `BedAmp` | 0.13–0.16 | Bed volume in final mix. Higher = bed more present, voice more "shrouded." |

## How to Add a New Sound

### Step 1: Add a `$soundDefs` entry

In `scripts/generate-rocky-sounds.ps1`, copy an existing entry and tune:

```powershell
@{
    Name = "new-sound";     Word = "Hello";        TtsRate = 3
    SlowFactors   = @(0.85, 0.81, 0.84);  VolumeFactors = @(1.40, 1.30, 1.55);  GapsMs = @(50, 70)
    BedFreq = 180;          BedWobbleHz = 0.9;     BedWobbleDepth = 55
    BedAmpHz = 0.6;         BedAmpDepth = 0.60
    BedDriftHz = 0.25;      BedDriftDepth = 40
    BedRingHz = 70;         BedRingMix = 0.30;     BedAmp = 0.13
}
```

- `Name` becomes the WAV filename: `{Name}.wav`
- Start from an existing sound close to the emotion you want (see table below for baseline)

### Step 2: Add a playSound trigger (if new state)

If the sound maps to a new state (not reusing an existing trigger), add to `src/state.js` in the `updateSession()` function, around line 455:

```js
} else if (state === "your-new-state") {
  ctx.playSound("new-sound");
```

If reusing an existing state (e.g. a variation of "working"), no change needed.

### Step 3: Add to theme.json

In `themes/rocky/theme.json` (and `themes/rocky-domed/theme.json`), add to the `"sounds"` object:

```json
"sounds": {
  "new-sound": "new-sound.wav",
  ...
}
```

### Step 4: Generate and test

```powershell
pwsh scripts/generate-rocky-sounds.ps1
```

The script writes to both `themes/rocky/sounds/` and `themes/rocky-domed/sounds/`.

To test in the running app: trigger the state that plays your sound. The global 10-second cooldown (`SOUND_COOLDOWN_MS` in `src/main.js`) prevents sound spam.

## Tuning Quick Reference

### Starting point by emotion

| Emotion | Reference sound | Key knobs |
|---------|----------------|-----------|
| Happy / excited | `waking` ("Yes!") | TtsRate 4, SlowFactors fast, BedFreq 210, WobbleHz faster |
| Confident / warm | `confirm` ("Good") | TtsRate 3, moderate speed, BedFreq 180 |
| Amazed / impressed | `complete` ("Amaze!") | TtsRate 3, third rep rising, WobbleHz slightly faster for drama |
| Curious / rising | `thinking` ("Question?") | Rising SlowFactors (0.86→0.82→0.78), BedFreq 200 |
| Sad / heavy | `error` ("Sad...") | TtsRate 1, slow SlowFactors, large gaps, BedFreq 160, deep wobble |

### What to tweak if...

| Problem | Try |
|---------|-----|
| Voice sounds robotic/mechanical | Widen spread between SlowFactors (e.g. 0.86/0.80/0.84 instead of 0.84/0.83/0.85) |
| Voice too fast / chipmunk | Raise SlowFactors toward 0.90+ (slower = lower pitch) |
| Voice too slow / deep | Lower SlowFactors toward 0.80 (faster = higher pitch) |
| Bed too prominent / distracting | Lower BedAmp (0.10–0.12) |
| Bed not noticeable enough | Raise BedAmp (0.15–0.18) |
| UFO wobble too fast / electric | Lower BedWobbleHz (toward 0.7), raise BedWobbleDepth |
| Needs more "alien" feel | Raise BedRingMix (0.35+), try BedRingHz at 55-65 |
| Gaps feel unnatural | Adjust GapsMs — shorter for excited (40-60), longer for sad (80-120) |
| Third rep feels wrong | Check if SlowFactor[2] should be higher (settling/falling) or lower (rising/question) |

### One-knob sanity checks

After tuning, listen for these failure modes:
- **"Alvin and the Chipmunks"** — SlowFactors too low. Raise above 0.78.
- **"Darth Vader"** — SlowFactors too high. Lower below 0.95.
- **"Dial-up modem"** — WobbleHz too high. Lower below 1.5.
- **"Underwater gurgle"** — BedAmp too high + WobbleDepth too high. Lower both.

## How to Run

```powershell
# From the project root
pwsh scripts/generate-rocky-sounds.ps1

# Or with Windows PowerShell (not PowerShell Core)
powershell -File scripts/generate-rocky-sounds.ps1
```

Requirements:
- Windows 10/11 with .NET Framework (built-in)
- No external dependencies — uses only `System.Speech.Synthesis`

**Important**: Close any media players before running. Windows file locks from active playback will cause `IOException` on `Write-WavFile`.

## Technical Notes

### Sound file format
- 16-bit PCM mono WAV
- 44100Hz sample rate
- Output: ~20-50KB per file (3 reps of TTS word + bed)

### Sound resolution in the runtime
Each built-in theme ships its own sounds in `themes/<id>/sounds/`. The runtime (`src/theme-loader.js`) checks the theme-local path first, then falls back to `assets/sounds/`. This means different themes can have completely different sound sets.

### Cooldown
A global 10-second cooldown (`SOUND_COOLDOWN_MS` in `src/main.js`) prevents rapid-fire sound playback when multiple events fire in quick succession.

### The Organic Bed in Detail

The bed synthesis (`New-RockyOrganicSamples`) was iterated through 8+ versions. Key design decisions:

- **Base frequency drift** (0.20–0.30Hz): A very slow LFO that bends the fundamental. This is the "UFO tide" — it prevents the bed from sounding like a boring test tone.
- **Pitch wobble** (0.7–1.1Hz): Faster wobble on top of the drift. Together they create a complex, organic-sounding undulation.
- **Ring modulation at 60–80Hz**: Gives a metallic, "phasing" character without being harsh. At 70Hz with 30% mix, it adds texture without dominating.
- **Amplitude LFO**: The "jelly squeeze" — volume pulses that make the tone feel alive.
- **No square mix in final version**: The square wave was dialed to 0.0 after testing — it added an unwanted "8-bit video game" character.

The bed runs for `voiceDuration + 0.3s` so it extends slightly beyond the last word, giving a natural decay tail.
