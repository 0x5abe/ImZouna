import argparse
from bisect import bisect_right
from dataclasses import dataclass
from pathlib import Path
import re
import struct

from config import IMZOUNA_DIR


SECTOR_SIZE = 0x800
HEADER_SIZE = 0x800
BLOCK_DESCRIPTION_OFFSET = 0x120
BLOCK_DESCRIPTION_SIZE = 0x18
OBJECT_HEADER_SIZE = 0x18
NAME_LINE = re.compile(r'^(-?\d+)\s+"(.*)"$')
LAYOUT_SIZE_LINE = re.compile(r'^\s*(\d+)\s+"(.*)"$')


@dataclass(frozen=True)
class ObjectInfo:
    block_index: int
    object_index: int
    stored_disk_size: int
    uncompressed_disk_size: int
    name_hash: int


@dataclass(frozen=True)
class BlockInfo:
    index: int
    described_data_size: int
    padded_size: int
    objects: tuple[ObjectInfo, ...]


def align_to_sector(size):
    return (size + SECTOR_SIZE - 1) & ~(SECTOR_SIZE - 1)


def read_u32(data, offset):
    return struct.unpack_from("<I", data, offset)[0]


def read_i32(data, offset):
    return struct.unpack_from("<i", data, offset)[0]


def parse_dpp(path):
    data = path.read_bytes()
    if len(data) < HEADER_SIZE:
        raise ValueError("file is smaller than the 0x800-byte DPP header")

    block_count = read_u32(data, 0x104)
    if block_count == 0 or block_count > 64:
        raise ValueError(f"invalid block count {block_count}")

    blocks = []
    position = HEADER_SIZE
    for block_index in range(block_count):
        description_offset = (
            BLOCK_DESCRIPTION_OFFSET
            + block_index * BLOCK_DESCRIPTION_SIZE
        )
        object_count = read_u32(data, description_offset)
        padded_size = read_u32(data, description_offset + 0x04)
        described_data_size = read_u32(data, description_offset + 0x08)
        block_start = position
        objects = []

        for object_index in range(object_count):
            if position + OBJECT_HEADER_SIZE > len(data):
                raise ValueError(
                    f"block {block_index} object {object_index} header exceeds EOF"
                )

            data_size = read_u32(data, position)
            link_header_size = read_u32(data, position + 0x04)
            decompressed_size = read_u32(data, position + 0x08)
            object_end = position + OBJECT_HEADER_SIZE + data_size
            if object_end > len(data):
                raise ValueError(
                    f"block {block_index} object {object_index} data exceeds EOF"
                )

            objects.append(
                ObjectInfo(
                    block_index=block_index,
                    object_index=object_index,
                    stored_disk_size=OBJECT_HEADER_SIZE + data_size,
                    uncompressed_disk_size=(
                        OBJECT_HEADER_SIZE
                        + link_header_size
                        + decompressed_size
                    ),
                    name_hash=read_i32(data, position + 0x14),
                )
            )
            position = object_end

        consumed_size = position - block_start
        if consumed_size != described_data_size:
            raise ValueError(
                f"block {block_index} data size is {described_data_size}, "
                f"but its objects occupy {consumed_size}"
            )
        if align_to_sector(consumed_size) != padded_size:
            raise ValueError(
                f"block {block_index} padded size is {padded_size}, "
                f"expected {align_to_sector(consumed_size)}"
            )

        blocks.append(
            BlockInfo(
                index=block_index,
                described_data_size=described_data_size,
                padded_size=padded_size,
                objects=tuple(objects),
            )
        )
        position = align_to_sector(position)

    return tuple(blocks)


def parse_names(path):
    names = {}
    for line_number, line in enumerate(
        path.read_text(encoding="cp1252").splitlines(), start=1
    ):
        match = NAME_LINE.fullmatch(line)
        if match is None:
            raise ValueError(f"{path.name}:{line_number}: malformed name line")
        names[int(match.group(1))] = match.group(2)
    return names


def parse_layout_sizes(path):
    sizes = {}
    in_disk_space_section = False
    found_section = False

    for line_number, line in enumerate(
        path.read_text(encoding="cp1252").splitlines(), start=1
    ):
        if line == "SortByDiskSpace":
            in_disk_space_section = True
            found_section = True
            continue
        if line == "EndSortByDiskSpace":
            in_disk_space_section = False
            break
        if not in_disk_space_section:
            continue

        match = LAYOUT_SIZE_LINE.fullmatch(line)
        if match is None:
            raise ValueError(
                f"{path.name}:{line_number}: malformed SortByDiskSpace line"
            )
        size = int(match.group(1))
        name = match.group(2)
        if name in sizes:
            raise ValueError(f"{path.name}: duplicate layout object {name!r}")
        sizes[name] = size

    if not found_section or in_disk_space_section:
        raise ValueError(f"{path.name}: incomplete SortByDiskSpace section")
    return sizes


def object_packing_size(object_info, size_source):
    if size_source == "stored":
        return object_info.stored_disk_size
    if size_source == "uncompressed":
        return object_info.uncompressed_disk_size
    raise ValueError(f"unsupported size source {size_source!r}")


def validate_sidecars(path, blocks, size_source):
    names_path = path.with_suffix(".N" + path.suffix[2:])
    layout_path = path.with_suffix(path.suffix + ".LAYOUT")
    if not names_path.is_file():
        raise ValueError(f"missing name sidecar {names_path.name}")
    if not layout_path.is_file():
        raise ValueError(f"missing layout sidecar {layout_path.name}")

    names = parse_names(names_path)
    layout_sizes = parse_layout_sizes(layout_path)
    dpp_names = set()

    for block in blocks:
        for object_info in block.objects:
            if object_info.name_hash not in names:
                raise ValueError(
                    f"block {block.index} object {object_info.object_index}: "
                    f"name hash {object_info.name_hash} is absent from {names_path.name}"
                )
            name = names[object_info.name_hash]
            dpp_names.add(name)
            if name not in layout_sizes:
                raise ValueError(
                    f"block {block.index} object {object_info.object_index}: "
                    f"{name!r} is absent from {layout_path.name}"
                )
            packing_size = object_packing_size(object_info, size_source)
            if layout_sizes[name] != packing_size:
                raise ValueError(
                    f"block {block.index} object {object_info.object_index}: "
                    f"{size_source} packing size {packing_size} != layout size "
                    f"{layout_sizes[name]} for {name!r}"
                )

    extra_layout_names = set(layout_sizes) - dpp_names
    if extra_layout_names:
        example = min(extra_layout_names, key=str.casefold)
        raise ValueError(
            f"layout contains {len(extra_layout_names)} object(s) absent from "
            f"the DPP; for example {example!r}"
        )


def validate_greedy_order(blocks, size_source):
    remaining_sizes = sorted(
        object_packing_size(object_info, size_source)
        for block in blocks
        for object_info in block.objects
    )
    parity_ceilings = [None, None]

    for block in blocks:
        actual_ascending = [
            object_packing_size(object_info, size_source)
            for object_info in block.objects
        ]
        if actual_ascending != sorted(actual_ascending):
            raise ValueError(
                f"block {block.index} objects are not in nondecreasing disk-size order"
            )

        if not remaining_sizes:
            raise ValueError(f"block {block.index} has no remaining object to pack")

        parity = block.index % 2
        ceiling = parity_ceilings[parity]
        if ceiling is None:
            ceiling = align_to_sector(remaining_sizes[-1])
            parity_ceilings[parity] = ceiling
        if remaining_sizes[-1] > ceiling:
            raise ValueError(
                f"block {block.index} ceiling {ceiling} cannot hold largest "
                f"remaining object {remaining_sizes[-1]}"
            )

        selected_descending = []
        available_size = ceiling
        while remaining_sizes:
            selected_index = bisect_right(
                remaining_sizes, available_size
            ) - 1
            if selected_index < 0:
                break
            selected_size = remaining_sizes.pop(selected_index)
            selected_descending.append(selected_size)
            available_size -= selected_size

        actual_descending = list(reversed(actual_ascending))
        if actual_descending != selected_descending:
            raise ValueError(
                f"block {block.index} does not match greedy largest-fitting "
                f"selection: actual descending sizes {actual_descending}, "
                f"expected {selected_descending}"
            )

    if remaining_sizes:
        raise ValueError(
            f"{len(remaining_sizes)} object(s) remain after the final block"
        )


def validate_file(path, without_sidecars, size_source):
    blocks = parse_dpp(path)
    if not without_sidecars:
        validate_sidecars(path, blocks, size_source)
    validate_greedy_order(blocks, size_source)


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Validate RAT-format bigfile object ordering against the Wall-E PSP "
            "two-ceiling greedy size-packing hypothesis"
        )
    )
    parser.add_argument(
        "-C",
        "--directory",
        type=Path,
        default=IMZOUNA_DIR / "bigfiles" / "Wall-E" / "PSP",
        help="Directory containing the bigfiles to validate",
    )
    parser.add_argument(
        "--extension",
        default="DPP",
        help="Bigfile extension to scan (default: DPP)",
    )
    parser.add_argument(
        "--without-sidecars",
        action="store_true",
        help="Validate packing from object headers without name/layout sidecars",
    )
    parser.add_argument(
        "--size-source",
        choices=("stored", "uncompressed"),
        default="stored",
        help=(
            "Object size used to reconstruct packing: final stored size "
            "(default) or link header plus decompressed data"
        ),
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print every bigfile path as it is validated",
    )
    parser.add_argument(
        "--summary-only",
        action="store_true",
        help="Print only the pass/fail totals",
    )
    args = parser.parse_args()

    paths = sorted(
        args.directory.rglob(f"*.{args.extension.lstrip('.')}"),
        key=lambda path: str(path).casefold(),
    )
    failures = []
    for path in paths:
        if args.verbose:
            print(path.absolute())
        try:
            validate_file(path, args.without_sidecars, args.size_source)
        except (OSError, UnicodeError, ValueError, struct.error) as error:
            failures.append((path, str(error)))

    print(
        f"{len(paths)} tests, {len(failures)} failed, "
        f"{len(paths) - len(failures)} passed"
    )
    if failures and not args.summary_only:
        print("Failing tests:")
        for path, error in failures:
            print(f"  {path.absolute()}: {error}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
