# Roadmap

Each phase has exit criteria. Don't start the next phase until they are met.

## Stage 1: Add-on gauge

### Phase 1: Research & reverse engineering ⚠️ highest risk
- [ ] Service manual: wiring diagram, meter pinout, diagnostic connector pinout
- [ ] Probe meter connector + diagnostic port (see `docs/research/data-sources.md`)
- [ ] Capture the serial stream with a logic analyzer → `captures/`
- [ ] Decide on the primary data source (K-line passive listen vs. CAN)
- [ ] Unplugged-meter start test
**Exit:** `docs/research/signals.md` table complete for speed, RPM, coolant and gear.

### Phase 2: Data acquisition prototype
- [ ] ESP32-S3 dev board + L9637D (or CAN transceiver) on a breadboard
- [ ] Firmware prints live RPM/speed/coolant over USB serial
- [ ] Gear calculation from RPM/speed ratio (or read directly if CAN has it)
- [ ] Bench emulator: second board replaying captured frames (so most dev happens indoors)
**Exit:** live, correct values on your laptop from the bike, with speed checked against GPS.

### Phase 3: Display & UI
- [ ] Pick a display; test **outdoors at noon** (≥800 nit IPS or transflective)
- [ ] Mock up layouts in Figma → `ui/`
- [ ] LVGL UI running on hardware with emulator data
- [ ] Brightness control (ambient light sensor), boot time < 2 s
**Exit:** UI readable in direct sun, smooth at 30+ fps.

### Phase 4: Power & electronics hardening
- [ ] Automotive input protection: reverse polarity, TVS (load dump), 9–16 V buck
- [ ] Ignition-switched wake/sleep, < 1 mA key-off draw
- [ ] Perfboard → KiCad PCB → `hardware/`
**Exit:** survives a 9–16 V sweep, cranking dips and an hour of riding.

### Phase 5: Enclosure & mount
- [ ] Measure the bars/clamp area; CAD in Fusion 360/Onshape → `enclosure/`
- [ ] 3D print (PETG/ASA), gasket, sealed connector (Deutsch DT), conformal coat
**Exit:** hose test passes, no rattles at highway speed.

### Phase 6: Integration
- [ ] Non-invasive tap: plug-in T-harness at the diagnostic port or meter connector (no cut wires)
- [ ] Road test, rain test, heat test
**Exit:** 2 weeks of daily riding with no faults.

## Stage 2: Full replacement

- [ ] Map **every** meter input: lamps, fuel, neutral, switches, ambient temp (Phase 1 table, extended)
- [ ] Confirm bike runs/immobilizer OK with stock meter removed
- [ ] Odometer: FRAM storage, legal considerations
- [ ] All legally required indicators (check state rules: speedometer, high beam, turn signals, neutral, ABS)
- [ ] Round enclosure that uses the stock meter mount + plug-and-play harness adapter
- [ ] Keep stock meter so you can swap back in 5 min
