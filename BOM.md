# Bill of materials (Stage 1, prototyping)

| Item | Purpose | ~Cost | Notes |
|---|---|---|---|
| ESP32-S3 dev board (e.g. DevKitC-1 N16R8) | MCU | $15 | PSRAM helps LVGL |
| L9637D K-line transceiver (SOIC-8) + breakout | Safe 12 V K-line interface | $5 | datasheet in `docs/datasheets/` |
| SN65HVD230 or MCP2515 module | CAN (only if diag port has CAN) | $5–10 | datasheets in `docs/datasheets/` |
| USB logic analyzer (8ch, 24 MHz) | Sniff serial line | $15 | Use with PulseView / sigrok |
| Multimeter + back-probe pins | Identify wires without cutting | $25 | |
| Yamaha diagnostic connector pigtail | Non-invasive tap | $10 | Match the bike's 3- or 4-pin connector |
| Round IPS display 2.1–2.8" (high-nit) | UI | $20–40 | Sun test before committing |
| Automotive buck converter 12→5 V | Power | $8 | Wide input, load-dump tolerant |
| Neo-6M/M10 GPS module | Speed validation | $12 | |
| Service manual (2022+ XSR700) | Wiring diagrams | $60–120 | Buy from a Yamaha dealer |
