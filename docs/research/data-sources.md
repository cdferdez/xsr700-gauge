# Data sources: how to get data off the bike

> Status: **unverified on a 2025 XSR700.** Everything below comes from community
> reverse engineering on *other* Yamahas: the K-line frame layout probably comes
> from an **XT660X**, the CAN claims from a 2014 MT-07, and the immobilizer notes
> from a 2017 MT-07. Phase 1 is about confirming or refuting it with a logic
> analyzer on *this* bike.

## 1. Yamaha K-line / single-wire serial (most promising)

### a) ECU → meter broadcast stream (passive listen)
Source: [terrafirma2021/Yamaha-DataLogger](https://github.com/terrafirma2021/Yamaha-DataLogger) (cloned in `reference/`, **no license file, so treat it as all rights reserved and use it only for reference**)

**Source bike: probably an XT660X, not a CP2 twin.** The README names no model, but
`yamaha/include/gear.h` has `MAX_GEARS = 5; // Set 5 for xt660x`. The XT660X is a
mid-2000s 5-speed single with no gear display. Yamaha may share this diagnostic stream
across models, but **treat the whole frame layout below as a hypothesis for the XSR700**:
frame length, byte order, scaling, offsets and baud rate are all open.
`firmware/src/core/protocols/yamaha5.zig` implements this hypothesis. If real captures
show a different frame, `FrameReader` never locks (`bytes_skipped` keeps climbing).
The fix is a new protocol file plus a one-line change in `firmware/src/core/profile.zig`,
which also holds every other unverified constant (speed scale, drivetrain, tire).

- UART, **~16040 baud** (code uses `Serial1.begin(16040, SERIAL_8N1, ...)`), 8N1, 12 V single wire.
- The logger only listens and sends no init. It waits for a `0x3E` byte, then a 61-byte block.
  If the block ends in `0xCD` the stream is in diag mode; otherwise it is normal mode.
- Normal frames are **5 bytes**: `[RPM, Speed, Error, Coolant, Checksum]`
  - checksum = (b0+b1+b2+b3) & 0xFF; all-zero frames are discarded
  - RPM = b0 × 50
  - Coolant °C = b3 − 30
  - Speed: raw byte; the logger sums 8 samples (scaling unclear, so verify against GPS)
  - Error: raw error code byte
- Frames arrive about every 7 ms (based on the emulator).
- Interface: **L9637D** K-line transceiver, 510 Ω pull-up on the TX side. The ESP32 must boot before the ECU (the author uses an external power switch).
- The logger calculates gear itself from RPM/speed ratios (a GIpro-style learn mode: cycle through the gears on the centre stand). On the source bike that was the only option. **This says nothing about whether the XSR700 has a gear position sensor**; see §5.

On the source bike, the stream contains only RPM, speed, coolant and an error code. On the XSR700, fuel level, neutral, turn signals and the other lamps are probably hard-wired to the meter (confirm with the wiring diagram).

### b) Immobilizer K-line (do not interfere)
Source: [vik0t0r: Demystifying Yamaha immobilisers](https://vik0t0r.github.io/posts/demystifying-yamaha-immobilisers) (MT-07 2017)

- The immobilizer unit and ECU talk over a **Yellow/Blue** wire: half-duplex UART, 12 V logic, **15625 baud**, no parity, 1 stop bit.
- The immobilizer unit has 5 wires: Black = GND, Yellow/Blue = K-line, Red/White = switched 12 V,
  **Green/Black = immobilizer indicator lamp on the meter**, Red/Green = constant 12 V.
- The meter's only known link to the immobilizer is the indicator lamp. Nobody has said the meter takes part in the handshake.
  **Open question:** does the bike start and run with the meter unplugged? (Test this early, before Stage 2 design.)
- The baud rate (15625) is close to the DataLogger's 16040. It is likely the same physical line or the same family of line. Confirm whether the ECU→meter stream and the immobilizer share the Yellow/Blue wire.

## 2. CAN bus (doubtful; verify)
Source: [JackHat1/MT07_CAN_Project](https://github.com/JackHat1/MT07_CAN_Project) (MIT, cloned in `reference/`)

Claims for a "2014 MT-07" at 500 kbps via the diagnostic port:

| ID | Byte(s) | Decode |
|---|---|---|
| 0x20A | b2,b3 | RPM = b2×100 + b3 ; speed ≈ b2×0.75 (dubious) |
| 0x216 | b0 | TPS % = b0/255×100 |
| 0x236 | b0 | Gear: 0x00 N, 0x20 1st … 0xC0 6th |
| 0x23E | b0 | Coolant °C = (b0−0x70)×0.625+40 |
| 0x23E | b1 | Air °C = (b1−0x30)×0.625 |

⚠️ This conflicts with the K-line findings above. These IDs also look like the format
used by newer Yamahas. There is no wiring or validation, and the speed decode has bugs.
**Check whether the 2025 XSR700 diagnostic connector even has CAN_H/CAN_L pins** before
buying CAN hardware. If it does, CAN would give gear and TPS directly, which makes it the better source.

## 3. Hard-wired meter inputs (needed for full replacement)
Expected per typical Yamaha meters; **confirm in the service manual wiring diagram**:
- Fuel level sender (resistive, or a thermistor-type warning)
- Neutral switch
- Turn signal L/R, high beam
- ABS warning (from the ABS ECU, possibly a serial/lamp line)
- Oil pressure (if fitted) / engine trouble warning
- Ambient air temp sensor (the meter shows it, so the sensor may be wired to the meter)
- Ignition switched 12 V, constant 12 V (clock/odo memory), ground
- Mode/select switches on the handlebar

## 4. Own sensors (fallback / extras)
- GPS (speed fallback, clock, trip logging)
- IMU (lean angle)
- Hall sensor on the front wheel (independent speed)

## 5. Gear: sensor or calculated? (open question)

**Known (owner's manual, MTM660N):**
- The stock display shows the selected gear, and neutral as "–" plus the neutral indicator light (§ "Transmission gear display", p. 4-7).
- A **neutral switch** exists. It is part of the ignition circuit cut-off check (shift into gear with the sidestand down and the engine should stall).

**Unknown:** whether gears 1–6 come from a **gear position sensor** on the shift drum or are **calculated** from RPM/speed (by the ECU or the meter).

**Where a sensed gear could appear:**

| Path | What a capture would show |
|---|---|
| Longer or different K-line frame on the 2025 bike | More than 5 bytes per frame; one byte steps with each shift |
| Another message on the same wire (e.g. the 61-byte `0x3E` block, diag mode) | A byte that tracks gear inside that block |
| CAN (if the diagnostic connector has CAN pins) | A gear field, e.g. the claimed `0x236` |
| Direct wire from the sensor to the meter | Nothing in any data stream; a per-gear voltage on a meter pin |

**Tests:**
1. **Garage test (free):** engine running, bike stopped, clutch pulled, shift into 1st. If the display shows "1" at 0 mph, it must come from a sensor (no RPM/speed ratio exists at standstill). If it shows "–" or nothing until rolling, it is almost certainly calculated.
2. **Rolling test:** steady speed in 3rd, pull the clutch, blip the throttle. A sensor keeps showing "3"; a calculation drops out or changes.
3. **Shift-and-compare capture:** logic analyzer on the K-line, engine running at steady RPM, bike stationary, clutch pulled. Shift N → 1 → 2 → 3 with a pause in each gear. Look for a byte that changes at each shift while everything else holds steady.
4. **Wiring diagram:** look for a gear position sensor on the engine harness, and note whether it goes to the ECU or to the meter.

**Impact:**
- **No sensor:** `firmware/src/core/gear.zig` is what the stock meter does too, and the only option.
- **Sensor → ECU, gear in a data stream:** read it directly; keep `gear.zig` as a cross-check.
- **Sensor → ECU only, not in any stream we can read:** Stage 1 keeps using `gear.zig`.
- **Sensor → meter:** Stage 2 must read that wire (likely an analog voltage per gear); Stage 1 could tap it.

## Phase 1 checklist
- [ ] Buy the service manual (2022+ XSR700 / MTM690-U family). Copy the wiring diagram + meter connector pinout into this folder.
- [ ] Identify the meter connector and wire colours on the bike; photograph them into `captures/`.
- [ ] Back-probe with a multimeter (key ON, engine OFF/ON) to label 12 V, GND, serial and lamp lines.
- [ ] Logic analyzer (via a resistor divider/L9637D!) on the serial line: confirm baud, frame length, byte layout, checksum and the 0x3E header. Assume nothing from the XT660X layout.
- [ ] Note whether there is a quiet gap between frames (if so, `FrameReader.gap()` can use UART idle detection).
- [ ] Gear: run the garage test, rolling test and shift-and-compare capture (§5). Check the wiring diagram for a gear position sensor.
- [ ] Check the diagnostic connector pins: K-line only, or CAN as well?
- [ ] Test: unplug the meter, try to start the bike. Note immobilizer/ABS behaviour.
- [ ] Fill in `signals.md` with one row per signal: name, source, type, pin, wire colour, decode.
