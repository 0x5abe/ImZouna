import argparse
from collections import Counter
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
statistics = {}
STAT_PREFIX = "IMZOUNA_STAT "


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


def collect_statistics(path, stdout, stderr):
    path_statistics = {}
    for output in (stdout, stderr):
        for line in decode_process_output(output).splitlines():
            marker_position = line.find(STAT_PREFIX)
            if marker_position == -1:
                continue

            fields = line[marker_position + len(STAT_PREFIX):].strip().split()
            if len(fields) == 4 and fields[0] == "block_compression":
                block = int(fields[1])
                path_statistics.setdefault(block, {"block": block}).update(
                    {
                        "compressed": int(fields[2]),
                        "objects": int(fields[3]),
                    }
                )
            elif len(fields) == 8 and fields[0] == "block_working_offset":
                block = int(fields[1])
                path_statistics.setdefault(block, {"block": block}).update(
                    {
                        "working_offset": int(fields[2]),
                        "minimum_offset": int(fields[3]),
                        "trailing_space": int(fields[4]),
                        "link_headers": int(fields[5]),
                        "compressed_link_headers": int(fields[6]),
                        "link_headers_through_last_compressed": int(fields[7]),
                    }
                )

    if path_statistics:
        statistics[path.absolute()] = sorted(
            path_statistics.values(), key=lambda statistic: statistic["block"]
        )


def print_statistics():
    print("Compression statistics:")
    total_compressed = 0
    total_objects = 0
    compressed_block_count = 0
    exact_minimum_offset_count = 0
    nonzero_minimum_offset_count = 0
    offset_slack_distribution = Counter()
    nonzero_minimum_slack_distribution = Counter()
    right_aligned_compressed_block_count = 0
    right_aligned_position_counts = Counter()
    right_aligned_compressed_position_counts = Counter()
    placement_and_slack_counts = Counter()
    left_placed_slack_distribution = Counter()
    right_placed_slack_distribution = Counter()
    link_header_difference_distribution = Counter()
    compressed_link_header_difference_distribution = Counter()
    compressed_link_header_differences_by_directory = {}
    last_compressed_link_header_difference_distribution = Counter()
    last_compressed_link_header_differences_by_directory = {}
    exact_aligned_total_link_headers = 0
    exact_aligned_compressed_link_headers = 0
    exact_floor_total_link_headers = 0
    exact_floor_compressed_link_headers = 0

    for path in sorted(statistics, key=lambda value: str(value).casefold()):
        print(f"  {path}:")
        file_compressed = 0
        file_objects = 0
        last_block = max(statistic["block"] for statistic in statistics[path])
        last_block_by_parity = {
            parity: max(
                statistic["block"]
                for statistic in statistics[path]
                if statistic["block"] % 2 == parity
            )
            for parity in (0, 1)
            if any(
                statistic["block"] % 2 == parity
                for statistic in statistics[path]
            )
        }
        compressed_blocks = [
            statistic["block"]
            for statistic in statistics[path]
            if statistic["compressed"] != 0
        ]
        last_compressed_block = max(compressed_blocks) if compressed_blocks else None
        last_compressed_block_by_parity = {
            parity: max(
                block for block in compressed_blocks if block % 2 == parity
            )
            for parity in (0, 1)
            if any(block % 2 == parity for block in compressed_blocks)
        }
        for statistic in statistics[path]:
            compressed = statistic["compressed"]
            objects = statistic["objects"]
            file_compressed += compressed
            file_objects += objects
            print(
                f"    Block {statistic['block']}: "
                f"{compressed}/{objects} compressed"
            )
            if "working_offset" in statistic:
                if compressed != 0:
                    compressed_block_count += 1
                    offset_slack = (
                        statistic["working_offset"] - statistic["minimum_offset"]
                    )
                    offset_slack_distribution[offset_slack] += 1
                    if offset_slack == 0:
                        exact_minimum_offset_count += 1
                    if statistic["minimum_offset"] != 0:
                        nonzero_minimum_offset_count += 1
                        nonzero_minimum_slack_distribution[offset_slack] += 1
                    if statistic["trailing_space"] == 0:
                        right_aligned_compressed_block_count += 1
                        right_placed_slack_distribution[offset_slack] += 1
                        placement = "Right-aligned"
                        block = statistic["block"]
                        if block == last_block:
                            position = "final block"
                        elif block == last_block_by_parity[block % 2]:
                            position = "last block of its parity"
                        else:
                            position = "earlier than last block of its parity"
                        right_aligned_position_counts[position] += 1
                        if block == last_compressed_block:
                            compressed_position = "final compressed block"
                        elif (
                            block
                            == last_compressed_block_by_parity[block % 2]
                        ):
                            compressed_position = (
                                "last compressed block of its parity"
                            )
                        else:
                            compressed_position = (
                                "earlier than last compressed block of its parity"
                            )
                        right_aligned_compressed_position_counts[
                            compressed_position
                        ] += 1
                    else:
                        left_placed_slack_distribution[offset_slack] += 1
                        placement = "Not right-aligned"
                    if offset_slack == 0:
                        slack_class = "minimum"
                    elif offset_slack == 0x800:
                        slack_class = "minimum + 0x800"
                    else:
                        slack_class = "other"
                    placement_and_slack_counts[(placement, slack_class)] += 1
                    aligned_link_headers = (
                        statistic["link_headers"] + 0x7FF
                    ) & ~0x7FF
                    aligned_compressed_link_headers = (
                        statistic["compressed_link_headers"] + 0x7FF
                    ) & ~0x7FF
                    link_header_difference_distribution[
                        statistic["working_offset"] - aligned_link_headers
                    ] += 1
                    if statistic["working_offset"] == aligned_link_headers:
                        exact_aligned_total_link_headers += 1
                    if (
                        statistic["working_offset"]
                        == aligned_compressed_link_headers
                    ):
                        exact_aligned_compressed_link_headers += 1
                    if statistic["working_offset"] == (
                        statistic["link_headers"] & ~0x7FF
                    ):
                        exact_floor_total_link_headers += 1
                    if statistic["working_offset"] == (
                        statistic["compressed_link_headers"] & ~0x7FF
                    ):
                        exact_floor_compressed_link_headers += 1
                    compressed_link_header_difference_distribution[
                        statistic["working_offset"]
                        - aligned_compressed_link_headers
                    ] += 1
                    aligned_link_headers_through_last_compressed = (
                        statistic["link_headers_through_last_compressed"] + 0x7FF
                    ) & ~0x7FF
                    last_compressed_difference = (
                        statistic["working_offset"]
                        - aligned_link_headers_through_last_compressed
                    )
                    last_compressed_link_header_difference_distribution[
                        last_compressed_difference
                    ] += 1
                    directory = path.parent.name.upper()
                    compressed_link_header_differences_by_directory.setdefault(
                        directory, Counter()
                    )[
                        statistic["working_offset"]
                        - aligned_compressed_link_headers
                    ] += 1
                    last_compressed_link_header_differences_by_directory.setdefault(
                        directory, Counter()
                    )[last_compressed_difference] += 1
                print(
                    f"      Working offset: {statistic['working_offset']} "
                    f"(minimum {statistic['minimum_offset']}, "
                    f"trailing space {statistic['trailing_space']})"
                )
        print(f"    Total: {file_compressed}/{file_objects} compressed")
        total_compressed += file_compressed
        total_objects += file_objects

    print(f"  Overall: {total_compressed}/{total_objects} compressed")
    print("Working offset statistics for blocks containing compressed objects:")
    print(f"  Blocks: {compressed_block_count}")
    print(f"  Equal to calculated minimum: {exact_minimum_offset_count}")
    print(f"  Nonzero calculated minimum: {nonzero_minimum_offset_count}")
    print(f"  Right-aligned: {right_aligned_compressed_block_count}")
    print("  Right-aligned block positions (mutually exclusive):")
    for position in (
        "final block",
        "last block of its parity",
        "earlier than last block of its parity",
    ):
        print(f"    {position}: {right_aligned_position_counts[position]}")
    print("  Right-aligned positions among compressed blocks:")
    for position in (
        "final compressed block",
        "last compressed block of its parity",
        "earlier than last compressed block of its parity",
    ):
        print(
            f"    {position}: "
            f"{right_aligned_compressed_position_counts[position]}"
        )
    print("  Placement/minimum overlap (mutually exclusive):")
    for placement in ("Right-aligned", "Not right-aligned"):
        for slack_class in ("minimum", "minimum + 0x800", "other"):
            print(
                f"    {placement}, {slack_class}: "
                f"{placement_and_slack_counts[(placement, slack_class)]}"
            )
    print(
        "    Partition total: "
        f"{sum(placement_and_slack_counts.values())}"
    )
    print("  Actual minus minimum distribution:")
    for slack, count in offset_slack_distribution.most_common():
        print(f"    {slack}: {count}")
    print("  Actual minus minimum where minimum is nonzero:")
    for slack, count in nonzero_minimum_slack_distribution.most_common():
        print(f"    {slack}: {count}")
    print("  Actual minus minimum for blocks with trailing space:")
    for slack, count in left_placed_slack_distribution.most_common():
        print(f"    {slack}: {count}")
    print("  Actual minus minimum for right-aligned blocks:")
    for slack, count in right_placed_slack_distribution.most_common():
        print(f"    {slack}: {count}")
    print("  Actual minus aligned total link-header size:")
    print(f"    Exact ceil(total): {exact_aligned_total_link_headers}")
    print(f"    Exact floor(total): {exact_floor_total_link_headers}")
    for difference, count in link_header_difference_distribution.most_common():
        print(f"    {difference}: {count}")
    print("  Actual minus aligned compressed-object link-header size:")
    print(
        "    Exact ceil(compressed total): "
        f"{exact_aligned_compressed_link_headers}"
    )
    print(
        "    Exact floor(compressed total): "
        f"{exact_floor_compressed_link_headers}"
    )
    for difference, count in compressed_link_header_difference_distribution.most_common():
        print(f"    {difference}: {count}")
    print("  By directory (actual minus aligned compressed link headers):")
    for directory in sorted(compressed_link_header_differences_by_directory):
        print(f"    {directory}:")
        for difference, count in compressed_link_header_differences_by_directory[
            directory
        ].most_common(12):
            print(f"      {difference}: {count}")
    print("  Actual minus aligned link headers through last compressed object:")
    for difference, count in last_compressed_link_header_difference_distribution.most_common():
        print(f"    {difference}: {count}")
    print("  Through-last-compressed difference by directory:")
    for directory in sorted(last_compressed_link_header_differences_by_directory):
        print(f"    {directory}:")
        for difference, count in last_compressed_link_header_differences_by_directory[
            directory
        ].most_common(12):
            print(f"      {difference}: {count}")


def worker():
    try:
        while True:
            path = q.get()
            print(path.absolute())
            path_parts = {part.casefold() for part in path.absolute().parts}
            input_path_define = (
                "INPUT_PATH_IS_RTC"
                if "rtc" in path_parts or "rte" in path_parts
                else "INPUT_PATH_IS_NOT_RTC"
            )
            defines = ["-D", input_path_define]
            if gather_statistics:
                defines.extend(["-D", "IMZOUNA_COLLECT_STATS"])
            pattern_name = pattern_override or os.path.splitext(path)[1][1:]
            process = subprocess.Popen(
                [
                    imhex_path,
                    "--pl",
                    "run",
                    "-v",
                    "-I",
                    str(IMZOUNA_DIR / "includes"),
                    *defines,
                    "--pattern",
                    str(IMZOUNA_DIR / f"patterns/{game}/{pattern_name}.hexpat"),
                    str(path.absolute()),
                ],
                stderr=subprocess.PIPE,
                stdout=subprocess.PIPE,
            )
            stdout, stderr = process.communicate()
            exit_code = process.wait()
            if gather_statistics:
                collect_statistics(path, stdout, stderr)
            if exit_code != 0:
                faileds.append((path.absolute(), get_last_error_occurrence(stdout, stderr)))
            q.task_done()
    except (KeyboardInterrupt, SystemExit):
        os._exit(0)


def main():
    global imhex_path
    global game
    global gather_statistics
    global pattern_override
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
    parser.add_argument(
        "--stats",
        help="Collect and print statistics emitted by patterns",
        action="store_true",
    )
    parser.add_argument(
        "--pattern",
        help="Pattern name to use instead of deriving it from each file extension",
        type=str,
    )
    args = parser.parse_args()
    imhex_path = args.imhex
    game = args.game
    gather_statistics = args.stats
    pattern_override = args.pattern
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
    if gather_statistics:
        print_statistics()


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, SystemExit):
        os._exit(0)
