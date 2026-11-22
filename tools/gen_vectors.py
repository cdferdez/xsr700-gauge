"""Generate K-line frame test vectors for the Zig decoder.

The reference decoder here is written from the protocol notes in
docs/research/data-sources.md (UNVERIFIED), independently of kline.zig.
"""

from __future__ import annotations

import argparse
import json
import random
from collections.abc import Sequence
from pathlib import Path
from typing import Literal, TypedDict, TypeAlias

FRAME_LEN = 5
DEFAULT_OUT = Path(__file__).resolve().parent.parent / "firmware" / "testdata" / "kline_vectors.json"

Frame: TypeAlias = list[int]
ErrorName: TypeAlias = Literal["BadChecksum", "EmptyFrame"]


class Decoded(TypedDict):
    rpm: int
    speed_raw: int
    error_code: int
    coolant_c: int


class _CaseRequired(TypedDict):
    kind: str
    bytes: Frame


class Case(_CaseRequired, total=False):
    ok: Decoded
    err: ErrorName


def checksum(data: Sequence[int]) -> int:
    return sum(data) % 256


def frame(rpm_byte: int, speed: int, err: int, coolant_byte: int) -> Frame:
    data = [rpm_byte, speed, err, coolant_byte]
    return data + [checksum(data)]


def reference_decode(b: Frame) -> Decoded | ErrorName:
    if all(x == 0 for x in b):
        return "EmptyFrame"
    if checksum(b[:4]) != b[4]:
        return "BadChecksum"
    return {
        "rpm": b[0] * 50,
        "speed_raw": b[1],
        "error_code": b[2],
        "coolant_c": b[3] - 30,
    }


def flip_bit(b: Frame, rng: random.Random) -> Frame:
    out = list(b)
    out[rng.randrange(FRAME_LEN)] ^= 1 << rng.randrange(8)
    return out


def compensating_pair(b: Frame, rng: random.Random) -> Frame:
    out = list(b)
    i, j = rng.sample(range(4), 2)
    delta = rng.randrange(1, 256)
    out[i] = (out[i] + delta) % 256
    out[j] = (out[j] - delta) % 256
    return out


def build(seed: int) -> list[Case]:
    rng = random.Random(seed)
    cases: list[Case] = []

    def add(kind: str, b: Frame) -> None:
        result = reference_decode(b)
        if isinstance(result, str):
            cases.append({"kind": kind, "bytes": b, "err": result})
        else:
            cases.append({"kind": kind, "bytes": b, "ok": result})

    add("example_cruise", [136, 68, 0, 122, 0x46])
    add("empty", [0, 0, 0, 0, 0])
    add("all_ff", [0xFF] * FRAME_LEN)
    add("checksum_wrap", frame(0xFF, 0x01, 0, 0))
    add("idle_98c", frame(26, 0, 0, 128))

    for v in range(256):
        add("sweep_rpm", frame(v, 40, 0, 120))
    for v in range(256):
        add("sweep_coolant", frame(30, 40, 0, v))
    for v in (0, 1, 127, 128, 254, 255):
        add("edge_speed", frame(60, v, 0, 120))
        add("edge_error", frame(60, 40, v, 120))

    valid = [frame(rng.randrange(256), rng.randrange(256), rng.randrange(256), rng.randrange(256)) for _ in range(200)]
    for b in valid:
        add("random_valid", b)
    for b in valid:
        add("single_bit_flip", flip_bit(b, rng))
    for b in valid[:50]:
        add("compensating_pair", compensating_pair(b, rng))
    for _ in range(200):
        add("random_bytes", [rng.randrange(256) for _ in range(FRAME_LEN)])

    return cases


def write(cases: list[Case], path: Path, seed: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [json.dumps(c, separators=(",", ":"), sort_keys=True) for c in cases]
    with path.open("w") as f:
        f.write('{"generator":"tools/gen_vectors.py","seed":%d,"count":%d,"vectors":[\n' % (seed, len(cases)))
        f.write(",\n".join(lines))
        f.write("\n]}\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=(__doc__ or "").splitlines()[0])
    parser.add_argument("out", nargs="?", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--seed", type=int, default=700)
    args = parser.parse_args()

    cases = build(args.seed)
    write(cases, args.out, args.seed)

    kinds: dict[str, int] = {}
    for c in cases:
        kinds[c["kind"]] = kinds.get(c["kind"], 0) + 1
    print(f"wrote {len(cases)} vectors to {args.out}")
    for k, n in kinds.items():
        print(f"  {k:<18} {n}")


if __name__ == "__main__":
    main()
