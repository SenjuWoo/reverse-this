"""ipc_seqlock.py — reader/writer for ipc_seqlock.h on Windows x64.

Run:
    python ipc_seqlock.py            # create a demo mapping and round-trip 10 frames
    python ipc_seqlock.py --open     # read the newest frame from the demo mapping

Layout is asserted against the C++ header (Frame 160 bytes, Slot 168, Shared 520).
Python's standard library exposes no CPU fence intrinsic; on x86-64 the store order is preserved (TSO), which
is the supported target. Port the fences before using this on ARM64.
"""

from __future__ import annotations

import argparse
import ctypes
import mmap
import time

MAGIC = 0x50544652  # 'RTFP'
VERSION = 1
SLOTS = 3
NAME = r"Local\ReverseThisIpcDemo"


class Frame(ctypes.Structure):
    _fields_ = [
        ("rgba", ctypes.c_uint32),
        ("linear_depth", ctypes.c_float),
        ("near_z", ctypes.c_float),
        ("far_z", ctypes.c_float),
        ("view_proj", ctypes.c_float * 16),
        ("camera_world", ctypes.c_float * 16),
        ("frame_id", ctypes.c_uint64),
        ("timestamp_ns", ctypes.c_uint64),
    ]


class Slot(ctypes.Structure):
    _fields_ = [
        ("seq", ctypes.c_uint32),
        ("pad", ctypes.c_uint32),
        ("frame", Frame),
    ]


class Shared(ctypes.Structure):
    _fields_ = [
        ("magic", ctypes.c_uint32),
        ("version", ctypes.c_uint32),
        ("slot_count", ctypes.c_uint32),
        ("reserved", ctypes.c_uint32),
        ("slots", Slot * SLOTS),
    ]


assert ctypes.sizeof(Frame) == 160, ctypes.sizeof(Frame)
assert ctypes.sizeof(Slot) == 168, ctypes.sizeof(Slot)
assert ctypes.sizeof(Shared) == 520, ctypes.sizeof(Shared)


def open_mapping(name: str = NAME, create: bool = True):
    """Return (mmap, Shared). create=True initializes a new mapping."""
    mm = mmap.mmap(-1, ctypes.sizeof(Shared), tagname=name)
    shared = Shared.from_buffer(mm)
    if create and shared.magic == 0:
        shared.magic = MAGIC
        shared.version = VERSION
        shared.slot_count = SLOTS
    if shared.magic != MAGIC or shared.version != VERSION or shared.slot_count != SLOTS:
        raise RuntimeError(f"{name} is not a compatible Reverse THIS! frame mapping")
    return mm, shared


def write_frame(shared: Shared, frame: Frame) -> None:
    """Seqlock write: odd sequence, payload, even sequence."""
    slot = shared.slots[frame.frame_id % shared.slot_count]
    seq = slot.seq
    slot.seq = seq + 1
    slot.frame = frame
    slot.seq = seq + 2


def read_latest(shared: Shared, retries: int = 8) -> Frame | None:
    """Return the newest clean snapshot, or None if every attempt was torn."""
    best: Frame | None = None
    for index in range(shared.slot_count):
        slot = shared.slots[index]
        for _ in range(retries):
            seq1 = slot.seq
            if seq1 & 1:
                continue
            raw = ctypes.string_at(ctypes.addressof(slot.frame), ctypes.sizeof(Frame))
            frame = Frame.from_buffer_copy(raw)
            if slot.seq == seq1:
                if best is None or frame.frame_id > best.frame_id:
                    best = frame
                break
    return best


def _demo() -> int:
    mm, shared = open_mapping()
    try:
        for frame_id in range(1, 11):
            frame = Frame()
            frame.frame_id = frame_id
            frame.rgba = 0xFF000000 | frame_id
            frame.linear_depth = frame_id * 0.5
            frame.near_z = 0.1
            frame.far_z = 1000.0
            frame.view_proj[0] = float(frame_id)
            frame.timestamp_ns = time.time_ns()
            write_frame(shared, frame)
        latest = read_latest(shared)
        if latest is None:
            print("FAIL no clean frame")
            return 1
        print(
            "PASS frame_id=%d rgba=0x%08X depth=%.1f vp0=%.1f"
            % (latest.frame_id, latest.rgba, latest.linear_depth, latest.view_proj[0])
        )
        return 0 if latest.frame_id == 10 else 1
    finally:
        del shared
        mm.close()


def _open_only() -> int:
    mm, shared = open_mapping(create=False)
    try:
        latest = read_latest(shared)
        if latest is None:
            print("FAIL no clean frame")
            return 1
        print(
            "frame_id=%d rgba=0x%08X depth=%.1f vp0=%.1f"
            % (latest.frame_id, latest.rgba, latest.linear_depth, latest.view_proj[0])
        )
        return 0
    finally:
        del shared
        mm.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--open", action="store_true", help="read an existing demo mapping")
    args = parser.parse_args()
    raise SystemExit(_open_only() if args.open else _demo())
