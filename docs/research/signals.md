# Signal map (fill in during Phase 1)

| Signal | Source (ECU serial / CAN / meter pin / own sensor) | Type | Connector & pin | Wire colour | Decode / scaling | Verified? |
|---|---|---|---|---|---|---|
| Speed | | | | | | |
| RPM | | | | | | |
| Gear | **unknown:** gear position sensor or calculated (see `data-sources.md` §5) | | | | fallback: RPM/speed ratio (`gear.zig`) | |
| Coolant temp | | | | | | |
| Ambient temp | | | | | | |
| Fuel level | | | | | | |
| Neutral | neutral switch (exists per owner's manual; wired to ECU and/or meter?) | switch | | | | partially |
| Turn L / R | | | | | | |
| High beam | | | | | | |
| ABS warning | | | | | | |
| Engine trouble | | | | | | |
| Immobilizer lamp | immobilizer unit | lamp drive | | Green/Black (MT-07 2017) | | |
| Switched 12 V | | | | | | |
| Constant 12 V | | | | | | |
| Ground | | | | | | |
| Select/Reset switches | | | | | | |

## Open questions with a test attached

| Question | Test | Result |
|---|---|---|
| Is the XT660X 5-byte frame layout used on the XSR700? | Logic analyzer capture of the K-line (`data-sources.md` Phase 1 checklist) | |
| Gear position sensor or calculated gear? | Garage test, rolling test, shift-and-compare capture (`data-sources.md` §5) | |
| Is there a quiet gap between K-line frames? | Logic analyzer timing view | |
| Does the bike start with the meter unplugged? | Unplug meter, try to start | |
