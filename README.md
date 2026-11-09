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
firmware/       MCU firmware (PlatformIO, ESP32-S3 planned)
hardware/       KiCad schematics/PCB
enclosure/      CAD + STL files
ui/             UI mockups (Figma exports), LVGL assets
captures/       logic-analyzer / serial captures from the bike (.sal, .csv, .bin)
ROADMAP.md      phases, tasks, exit criteria
BOM.md          parts list
```
