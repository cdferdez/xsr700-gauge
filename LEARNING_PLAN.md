# Plan: Learn-as-you-build desktop emulator for the XSR700 gauge

## Context
`~/Workspace/xsr700-gauge` has research, a roadmap, and four UI concepts in Paper, but no code. The user wants a **Mac-only environment** for developing and testing the display software. The user's main goal is to **understand what they're building**, so the work is split into small steps. Each step teaches one bounded set of concepts and ends with something that runs.

**Decisions made:**
- Zig on the Mac (0.17.1 already installed). The chip is decided later.
- The first screen is Concept 01 "Redline", 960×320.
- Desktop only.

**Already installed:** zig 0.17.1, SDL2 (brew), pkg-config, python 3.13, VS Code.

## How each step works
- **Learn:** the few concepts the step introduces. Claude explains them first, with short readings.
- **Build:** one small piece of the code. **You write the logic; Claude reviews it and explains.** Claude writes the boilerplate (e.g. the LVGL build wiring) and walks you through it line by line.
- **Done when:** something you can run or test.
- **Explain it back:** one question you should be able to answer before moving on.

Each step is sized for one sitting of about 1–3 hours. Stages A and B need no graphics at all, so you learn Zig and the data side first.

---

## Stage A: Zig foundations and the bike's data (terminal only)

**A1. Project skeleton**
- Learn: `zig init`, what `build.zig` is (a Zig program that describes the build), steps (`run`, `test`), and pinning a Zig version.
- Build: `firmware/` with `.zigversion` = 0.17.1; `zig build run` prints "XSR700 gauge".
- Done when: both `zig build run` and `zig build test` work.
- Explain it back: what happens, in order, when you type `zig build run`?

**A2. The telemetry state**
- Learn: structs, sized integers (`u8`, `u16`), floats vs integers, `?T` optionals, `test` blocks.
- Build: `src/core/telemetry.zig` with State{rpm, speed_mph, gear (?u3, null = neutral), coolant_f, fuel_pct, trip_mi}, plus °C→°F and km/h→mph helpers and tests.
- Done when: the tests pass.
- Explain it back: why is gear optional and not just `0`?

**A3. Decoding a K-line frame**
- Learn: bytes and slices, checksums, error unions (`!T`), and what the ECU stream looks like (`docs/research/data-sources.md`).
- Build: `src/core/kline.zig` with `decodeFrame([5]u8) !Frame`: checksum = sum of bytes 0–3 & 0xFF, RPM = b0×50, coolant = b3−30. Mark it UNVERIFIED in comments. Write the tests with hand-crafted bytes.
- Done when: a good frame decodes and a bad checksum returns an error.
- Explain it back: what does the checksum protect against on a noisy 12 V wire?

**A4. Finding frames in a byte stream**
- Learn: streams vs messages, sliding windows / ring buffers, resynchronizing after garbage.
- Build: `FrameReader` that takes bytes one at a time and yields valid frames.
- Done when: a test feeding garbage + frames + a corrupted frame yields exactly the good ones.
- Explain it back: why can't you just read 5 bytes at a time?

**A5. Test vectors from Python**
- Learn: generating fixtures in a language you know, JSON, `@embedFile` + `std.json`.
- Build: `tools/gen_vectors.py` (stdlib only) writes `firmware/testdata/kline_vectors.json`; a Zig test decodes every vector.
- Done when: `zig build test` runs the Python-generated cases.
- Explain it back: why generate tests in Python rather than hand-write them all in Zig?

**A6. Calculating the gear**
- Learn: the drivetrain ratio chain (engine → primary 1.925 → gear ratio → final drive 43/16 → rear tire), and tolerance for noisy data.
- Build: `src/core/gear.zig` with `gearFrom(rpm, mph) ?u3`. Use the CP2 ratios 2.846/2.125/1.632/1.300/1.091/0.964, flagged "verify against the service manual". Return null when the clutch is pulled or the bike is stopped.
- Done when: tests cover all 6 gears, a mid-shift case, and a stopped case.
- Explain it back: why is gear ambiguous at low speed?

**A7. Smoothing**
- Learn: exponential moving average, rate limiting, time-step independence (dt), and why a raw signal makes a jittery gauge.
- Build: `src/core/smoothing.zig` with tests.
- Done when: a noisy input test produces a smooth output that still reaches its target within N ms.
- Explain it back: what's the trade-off between smoothness and lag?

## Stage B: A simulated bike (still terminal only)

**B1. A synthetic ride (Python)**
- Learn: a simple vehicle model: throttle → RPM → shift points → speed through the gear ratios.
- Build: `tools/make_ride.py` writes `captures/synthetic/ride_01.csv` (t_ms, rpm, mph, gear, coolant_f, fuel_pct). Optionally plot it with matplotlib.
- Done when: the plot looks like a believable ride (sawtooth RPM, rising speed).
- Explain it back: why does RPM drop on each upshift?

**B2. Data sources behind one interface**
- Learn: tagged unions and `switch`, the "interface" pattern in Zig, reading files and parsing CSV.
- Build: `src/sources/` with `sweep.zig` and `replay.zig` behind a single `Source` union, selected by `--source=sweep|replay:<file>`.
- Done when: the terminal prints a live text dashboard at 10 Hz from either source, passed through gear.zig and smoothing.zig.
- Explain it back: what would you add to support real bike data later?

## Stage C: Graphics with LVGL

**C1. First window (toolchain risk gate)**
- Learn: how Zig compiles a C library (LVGL), `lv_conf.h`, linking a system library (SDL2), translating C headers into Zig (`b.addTranslateC`), and why a C shim is sometimes needed.
- Build: `zig fetch --save` LVGL v9 (pinned). Claude writes the build wiring and walks you through it. Result: a 960×320 window with a label.
- Done when: `zig build run` opens the window.
- Explain it back: where does LVGL draw, and how do the pixels reach the window?

**C2. LVGL basics: a static Redline layout**
- Learn: objects and the parent/child tree, styles, flex layout, and how LVGL redraws only changed areas.
- Build: `src/ui/theme.zig` (the Redline palette, with exact values pulled from the Paper file) and `src/ui/redline.zig` with static speed, gear box, and TEMP/FUEL bars.
- Done when: the window resembles the Paper artboard with fixed numbers.
- Explain it back: why does changing one label not redraw the whole screen?

**C3. The bar tach**
- Learn: generating UI from math (port the segment math from `ui/concepts/gen.py`), and updating only segments whose state changed.
- Build: 30 rising segments, a 0–10 scale, and a red zone; `setRpm(rpm)` lights the right segments.
- Done when: a test hook steps RPM and the bars respond.
- Explain it back: how many segments change when RPM goes from 6,000 to 6,400?

**C4. Fonts**
- Learn: TTF vs bitmap fonts on microcontrollers, and why size and glyph count cost memory.
- Build: load Saira Condensed and Share Tech Mono (Google Fonts, OFL) with LVGL's tiny_ttf.
- Done when: the typography matches the Paper design.
- Explain it back: why will the real device probably use pre-rendered bitmap fonts instead?

**C5. Wiring it all together**
- Learn: the main loop (tick, poll source, update state, LVGL timer handler) and frame pacing.
- Build: source → smoothing → State → `redline.update(State)` at 30 Hz. Add the keyboard source: ↑ held to rev, 1–6/N for gear, T/H/A to toggle lamps.
- Done when: sweep, keys, and replay of `ride_01.csv` all drive the screen.
- Explain it back: what's the only file that would change when this runs on the real chip?

## Stage D: Dev-loop tools

**D1. Seeing it like the real thing**
- Learn: physical size and PPI (4.58″ 960×320 ≈ 221 ppi), and measuring render time with LVGL's sysmon.
- Build: `--zoom` and a sysmon overlay.
- Done when: the window matches the panel's real size when measured with a ruler, and render times are visible.
- Explain it back: why are render times on the Mac misleading?

**D2. Screenshots for review**
- Learn: frame buffers, RGB565, and snapshotting.
- Build: `--frames=N --screenshot=out.png` (lv_snapshot → BMP → PNG via `sips`). Claude can then view and critique real renders.
- Done when: the PNG matches what's on screen.

**D3. Night mode, debugger, docs**
- Build: a `--night` palette, a VS Code CodeLLDB `launch.json` with ZLS, `firmware/README.md`, a "Software stack" section in `README.md`, and the simulator stage added to `ROADMAP.md`.
- Done when: you can set a breakpoint in `gear.zig` while the sim runs.

---

## Rules that keep it portable
`core/` and `sources/` never import LVGL or SDL. `ui/` only reads `State`. Only `platform/sim.zig` knows it's running on a Mac.

## Risks
- **C1 (translate-c on LVGL headers) is the biggest unknown.** The fallback is a small C shim.
- **Check Zig 0.17 APIs** against `zig init` output and the std docs, not old blog posts.
- **Use SDL2** (installed), not SDL3.

## Verification (end of Stage D)
1. `cd firmware && zig build test` passes, including the Python-generated vectors.
2. `zig build run -- --source=sweep`: bars sweep into red, gears cycle, and temp and fuel move.
3. `zig build run -- --source=keys` responds smoothly to held ↑ and the gear keys.
4. `zig build run -- --source=replay:../captures/synthetic/ride_01.csv` plays end to end.
5. `--screenshot` output compared against the Paper "01 Redline" artboard.
