# XSR700 Custom Gauge

Custom instrument display for a **2025 Yamaha XSR700** (US).

- **Stage 1:** add-on gauge mounted next to the stock meter. It is read-only and fully reversible.
- **Stage 2 (end goal):** full replacement of the stock round LCD meter.

## Bike facts (verify against service manual)

- The 2025 XSR700 carries over the 2022 spec with new colours. It is the CP2 platform shared with the 2021–2024 MT-07, **not** the new 2025 MT-07 (TFT, Y-AMT).
- Stock meter: round negative LCD showing speed, tach, gear, coolant temp, ambient temp, fuel gauge, clock, trips, fuel consumption and the ECO indicator.
- ABS is standard. Ignition is TCI. The immobilizer uses a MORIC/immobilizer unit that talks to the ECU over K-line.

See `docs/research/` for details and open questions.

## Layout

```
docs/
  research/     findings, data-source notes, open questions
  datasheets/   transceiver / controller datasheets
  manuals/      owner's manual(s); service manual goes here once purchased
reference/      cloned open-source projects (read-only reference, check licenses)
firmware/       Zig firmware + desktop simulator (chip TBD: RP2350 or ESP32-P4)
tools/          Python dev tooling (test-vector generation, ride synthesis)
hardware/       KiCad schematics/PCB
enclosure/      CAD + STL files
ui/             UI mockups (Paper / SVG concepts), LVGL assets
captures/       logic-analyzer / serial captures from the bike (.sal, .csv, .bin)
ROADMAP.md      phases, tasks, exit criteria
BOM.md          parts list
LEARNING_PLAN.md  step-by-step build plan for the simulator
```

## Development setup

### Python tooling (conda)

Uses miniconda for setting up the environment.

```sh
conda create -n xsr700-gauge python=3.14
conda activate xsr700-gauge
pip install --group dev
mypy                    # type-checks tools/ (config in pyproject.toml)
```

To add a package, list it under `[dependency-groups]` in `pyproject.toml` and rerun `pip install --group dev`.

### Zig firmware

Zig version is pinned in `firmware/.zigversion` (0.17.1).

```sh
cd firmware
zig build test          # all unit tests, including generated vectors
zig build run           # desktop simulator
zig build vectors       # regenerate testdata/ (run inside the conda env)
```
