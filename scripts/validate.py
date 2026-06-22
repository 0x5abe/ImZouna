import argparse
from pathlib import Path
import subprocess
import os
from queue import Queue
from threading import Thread
import time
from config import IMZOUNA_DIR


extensions = [
    "Animation_Z",
    "Binary_Z",
    "Bitmap_Z",
    "Camera_Z",
    "CollisionVol_Z",
    "DPC",
    "Fonts_Z",
    "GameObj_Z",
    "GenWorld_Z",
    "GwRoad_Z",
    "Light_Z",
    "LightData_Z",
    "Lod_Z",
    "LodData_Z",
    "Material_Z",
    "MaterialAnim_Z",
    "MaterialObj_Z",
    "Mesh_Z",
    "MeshData_Z",
    "Node_Z",
    "Omni_Z",
    "Particles_Z",
    "ParticlesData_Z",
    "RotShape_Z",
    "RotShapeData_Z",
    "Rtc_Z",
    "Skel_Z",
    "Skin_Z",
    "Sound_Z",
    "Spline_Z",
    "SplineGraph_Z",
    "Surface_Z",
    "SurfaceDatas_Z",
    "UserDefine_Z",
    "Warp_Z",
    "World_Z",
    "WorldRef_Z",
]


def get_paths_with_extension(working_directory, extension):
    return Path(working_directory).rglob(f"*.{extension}")


q = Queue()
faileds = []


def decode_process_output(output):
    return output.decode("utf-8", errors="replace")


def sanitize_error_line(line):
    return (
        line.replace("\r", "")
        .replace("\n", "")
        .replace("\\r", "")
        .replace("\\n", "")
        .strip()
    )


def get_last_error_occurrence(stdout, stderr):
    lines = []
    for output in (stdout, stderr):
        lines.extend(decode_process_output(output).splitlines())
    for line in reversed(lines):
        stripped = sanitize_error_line(line)
        lowered = stripped.lower()
        if "[error]" in lowered and lowered != "[error]":
            return stripped
    return "No [ERROR] occurrence found"


def worker():
    try:
        while True:
            path = q.get()
            print(path.absolute())
            process = subprocess.Popen(
                [
                    imhex_path,
                    "--pl",
                    "run",
                    "-v",
                    "-I",
                    str(IMZOUNA_DIR / "includes"),
                    "--pattern",
                    str(IMZOUNA_DIR / f"patterns/{game}/{os.path.splitext(path)[1][1:]}.hexpat"),
                    str(path.absolute()),
                ],
                stderr=subprocess.PIPE,
                stdout=subprocess.PIPE,
            )
            stdout, stderr = process.communicate()
            exit_code = process.wait()
            if exit_code != 0:
                faileds.append((path.absolute(), get_last_error_occurrence(stdout, stderr)))
            q.task_done()
    except (KeyboardInterrupt, SystemExit):
        os._exit(0)


def main():
    global imhex_path
    global game
    total = 0
    parser = argparse.ArgumentParser()
    parser.add_argument("-C", help="Working directory", type=str, default=".")
    parser.add_argument("-j", help="Number of parallel tests", type=int, default=1)
    parser.add_argument(
        "--tests", help="Names of tests to run", type=str, nargs="+", default=extensions
    )
    parser.add_argument(
        "--imhex", help="Path to ImHex executable", type=str, default="imhex"
    )
    parser.add_argument(
        "--game", help="Game to test", type=str, default="fuel"
    )
    args = parser.parse_args()
    imhex_path = args.imhex
    game = args.game
    t0 = time.time()
    for i in range(args.j):
        Thread(target=worker, daemon=True).start()
    for extension in args.tests:
        for path in get_paths_with_extension(args.C, extension):
            q.put(path)
            total += 1
    q.join()
    t1 = time.time()
    print(f"Completed in {t1-t0:.2f}s")
    print(f"{total} tests, {len(faileds)} failed, {total-len(faileds)} passed")
    if len(faileds) != 0:
        print("Failing tests:")
        for path, error in faileds:
            print(f"  {path}: {error}")


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, SystemExit):
        os._exit(0)
