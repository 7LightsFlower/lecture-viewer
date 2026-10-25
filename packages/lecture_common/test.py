#!/usr/bin/env python3
"""
Parse a JSON file containing base64-encoded PCM S16LE audio data
and count the number of audio frames (samples per channel).

Usage:
    python count_pcm_frames.py <input.json> [--channels N] [--sample-rate N]

The JSON is expected to have the key "b64_enc_pcm_s16le" with the
base64-encoded raw PCM data as its value.
"""

import argparse
import base64
import json
import sys


def count_pcm_frames(
    json_path: str,
    channels: int = 1,
    sample_rate: int | None = None,
) -> dict:
    # ── 1. Load JSON ──────────────────────────────────────────────────────────
    with open(json_path, "r") as f:
        payload = json.load(f)

    b64_data = payload.get("b64_enc_pcm_s16le")
    if b64_data is None:
        raise KeyError("Key 'b64_enc_pcm_s16le' not found in the JSON.")

    # ── 2. Decode base64 → raw bytes ─────────────────────────────────────────
    raw_bytes = base64.b64decode(b64_data)

    # ── 3. Calculate frame count ──────────────────────────────────────────────
    # PCM S16LE: each sample = 2 bytes (signed 16-bit little-endian)
    BYTES_PER_SAMPLE = 2
    total_samples = len(raw_bytes) // BYTES_PER_SAMPLE

    if len(raw_bytes) % BYTES_PER_SAMPLE != 0:
        print(
            f"Warning: byte count ({len(raw_bytes)}) is not a multiple of "
            f"{BYTES_PER_SAMPLE}. The last {len(raw_bytes) % BYTES_PER_SAMPLE} "
            "byte(s) will be ignored.",
            file=sys.stderr,
        )

    # A "frame" = one sample per channel (the standard audio definition)
    frames = total_samples // channels

    result = {
        "raw_bytes": len(raw_bytes),
        "bytes_per_sample": BYTES_PER_SAMPLE,
        "channels": channels,
        "total_samples": total_samples,
        "frames": frames,
    }

    if sample_rate:
        duration_sec = frames / sample_rate
        result["sample_rate"] = sample_rate
        result["duration_seconds"] = round(duration_sec, 6)

    return result


def main():
    parser = argparse.ArgumentParser(
        description="Count PCM S16LE frames from a base64-encoded JSON payload."
    )
    parser.add_argument("json_file", help="Path to the JSON file")
    parser.add_argument(
        "--channels",
        type=int,
        default=1,
        help="Number of audio channels (default: 1 = mono)",
    )
    parser.add_argument(
        "--sample-rate",
        type=int,
        default=None,
        help="Sample rate in Hz (optional, used to compute duration)",
    )
    args = parser.parse_args()

    result = count_pcm_frames(args.json_file, args.channels, args.sample_rate)

    print(f"Raw bytes decoded : {result['raw_bytes']}")
    print(f"Bytes per sample  : {result['bytes_per_sample']}  (S16LE)")
    print(f"Channels          : {result['channels']}")
    print(f"Total samples     : {result['total_samples']}")
    print(f"Frames            : {result['frames']}")
    if "duration_seconds" in result:
        print(f"Sample rate       : {result['sample_rate']} Hz")
        print(f"Duration          : {result['duration_seconds']:.6f} s")


if __name__ == "__main__":
    main()