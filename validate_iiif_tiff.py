#!/usr/bin/python3

import argparse
import subprocess
import sys
import json
import os


# =========================================================
# system
# =========================================================
def run(cmd):
    return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)


# =========================================================
# parsing
# =========================================================
def parse_levels(tiffinfo_text):
    levels = []

    for line in tiffinfo_text.splitlines():
        if "Image Width:" in line:
            parts = line.split()
            try:
                w = int(parts[2])
                h = int(parts[5])
                levels.append((w, h))
            except Exception:
                pass

    return levels


def analyze_file(path):
    try:
        info = run(["tiffinfo", path])
    except Exception as e:
        return {
            "file": path,
            "ok": False,
            "error": str(e),
        }

    levels = parse_levels(info)

    result = {
        "file": path,
        # core properties
        "tiled": "Tile Width" in info,
        "jpeg": "Compression Scheme: JPEG" in info,
        # pyramid
        "levels": levels,
        "level_count": len(levels),
        "pyramid": False,
        "monotonic": False,
        "scale_ok": False,
        # final
        "ok": False,
        "error": None,
    }

    # insufficient levels
    if len(levels) < 2:
        result["error"] = "Not pyramidal (single level)"
        return result

    # monotonic check
    monotonic = True
    for i in range(1, len(levels)):
        w0, h0 = levels[i - 1]
        w1, h1 = levels[i]

        if w1 >= w0 or h1 >= h0:
            monotonic = False
            break

    result["monotonic"] = monotonic

    # scale check (~2x)
    ratios = [levels[i - 1][0] / levels[i][0] for i in range(1, len(levels))]
    result["scale_ok"] = all(1.8 <= r <= 2.2 for r in ratios)

    result["pyramid"] = monotonic and len(levels) > 1

    # final decision
    result["ok"] = (
        result["tiled"]
        and result["jpeg"]
        and result["pyramid"]
        and result["monotonic"]
    )

    return result


# =========================================================
# renderers
# =========================================================
def render_cli(result):
    print(f"\nFILE: {result['file']}")

    if "error" in result and result["error"]:
        print(f"ERROR: {result['error']}")
        return

    print("\n=== SUMMARY ===")
    print(f"tiled      = {result['tiled']}")
    print(f"jpeg       = {result['jpeg']}")
    print(f"levels     = {result['level_count']}")
    print(f"pyramid    = {result['pyramid']}")
    print(f"monotonic  = {result['monotonic']}")
    print(f"scale_ok   = {result['scale_ok']}")
    print(f"OK         = {result['ok']}")

    print("\n=== LEVELS ===")
    for i, (w, h) in enumerate(result["levels"]):
        print(f"Level {i}: {w} x {h}")


def render_json(results):
    print(json.dumps(results, indent=2))


# =========================================================
# file expansion
# =========================================================
def collect_inputs(inputs):
    files = []

    for item in inputs:
        if os.path.isdir(item):
            for root, _, names in os.walk(item):
                for n in names:
                    if n.lower().endswith((".tif", ".tiff")):
                        files.append(os.path.join(root, n))
        else:
            files.append(item)

    return files


# =========================================================
# main
# =========================================================
def main():
    parser = argparse.ArgumentParser(
        description="IIIF / Cantaloupe TIFF validator"
    )

    parser.add_argument("inputs", nargs="+")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--fail-fast", action="store_true")

    args = parser.parse_args()

    files = collect_inputs(args.inputs)
    results = []

    exit_code = 0

    for f in files:
        r = analyze_file(f)
        results.append(r)

        if not r.get("ok", False):
            exit_code = 1
            if args.fail_fast:
                break

    # render
    if args.json:
        render_json(results)
    else:
        for r in results:
            render_cli(r)

    sys.exit(exit_code)


if __name__ == "__main__":
    main()
