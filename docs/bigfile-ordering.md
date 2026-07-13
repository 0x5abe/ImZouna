# Bigfile block ordering and working-buffer layout

This document records what is currently known about block construction in the
Garfield 2, Ratatouille, and Wall-E PC/PSP bigfile builders. Its purpose is to
support future tooling that reproduces the original layout as closely as the
available artifacts permit.

The document distinguishes three confidence levels:

- **Confirmed** means the rule matches every applicable file or block in the
  current corpus.
- **Supported** means the rule is a necessary bound or explains a large part of
  the corpus, but does not uniquely reconstruct the stored value.
- **Hypothesis** means the rule is consistent with the evidence but cannot be
  verified from the surviving files.

## Corpus and terminology

All sizes below exclude sector padding unless explicitly described as padded.
The sector size is `0x800` bytes.

```text
align_sector(n) = (n + 0x7ff) & ~0x7ff
```

The following terms are used throughout:

- **Stored size**, `D`: the number of bytes occupied by a serialized object in
  a block, including its per-object header.
- **Ordering key**, `K`: the value used to order objects in a block and select
  the next block's anchor.
- **Anchor**: the largest remaining `K` object. It is the last object serialized
  in a block.
- **Parity**: even and odd block indices have separate reusable working-buffer
  capacities.
- **Capacity**, `C`: `block_working_buffer_capacity_even` or
  `block_working_buffer_capacity_odd`.
- **Padded block size**, `B`: the block description's `padded_size`.
- **Working offset**, `W`: the block description's
  `working_buffer_offset`.
- **Trailing space**, `T = C - W - B`.

The measured corpora are:

- Garfield 2: 138 DPCs and 462 blocks.
- Ratatouille: 322 DPCs and 2,154 blocks.
- Wall-E PC: 418 DPCs, 2,070 blocks, and 101,320 objects. Of these,
  114 files actually contain compressed objects; those files contain 671
  blocks in total, 651 blocks containing compression, and 55,965 compressed
  objects.
- Wall-E PSP: 397 DPPs with NPP and DPP.LAYOUT sidecars.

## The common high-level model

The three builders share the following high-level behavior.

1. Objects have a scalar ordering/workspace key `K`.
2. Every block is serialized in nondecreasing `K` order.
3. The last object in every block is the globally largest `K` object that had
   not already been assigned to an earlier block.
4. Blocks reuse an even or odd working-buffer capacity according to their
   index.
5. The first block of a parity establishes at least the capacity required by
   its anchor.
6. Objects chosen as fillers are sorted only after block membership has been
   decided.

Steps 2 and 3 are confirmed for all 462 Garfield blocks, all 2,154 Rat blocks,
and all 671 blocks belonging to the 114 actually compressed Wall-E PC files.
Wall-E PSP's stronger additive packing rule is confirmed for all 397 PSP
bigfiles.

The unresolved part for compressed Garfield and Rat bigfiles is step 6: the
surviving files do not expose the builder's pre-sort resource-vector order, so
they do not reveal exactly which eligible smaller objects were visited first.

## Per-format object measurements

### Garfield 2

The old layout reports, for each resource:

- `S`: decompressed resource size.
- `P`: compressed resource size, or zero when stored uncompressed.

The resource header is `0x10` bytes.

```text
stored_payload = P if P != 0 else S
D = 0x10 + stored_payload
K = S + P
```

`P = 0` deliberately makes an uncompressed object's key equal to `S`; its
decompressed representation must not be counted twice.

`K = S + P` is confirmed as the exact ordering key:

- 462/462 blocks are nondecreasing by `K` with zero descents.
- 462/462 blocks end with the largest `K` remaining at that point.

This single key explains the apparent interleaving of compressed and
uncompressed resources. There are not two independently sorted streams.

### Ratatouille

Rat separates the link header from the compressible body:

```text
L = link_header_size
U = decompressed_size
P = compressed_size, or zero when the body is uncompressed
D = 0x18 + data_size
K = L + U + P
```

The link header is counted once in `K` because it is not duplicated by body
compression. This is the newer-format equivalent of Garfield's `S + P` key.

`K = L + U + P` is confirmed as the exact ordering key:

- 2,154/2,154 blocks are nondecreasing by `K` with zero descents.
- 2,154/2,154 blocks end with the largest `K` remaining at that point.

### Wall-E PC

Wall-E PC uses the same newer object header as Rat:

```text
L = link_header_size
U = decompressed_size
P = compressed_size, or zero when the body is uncompressed
D = 0x18 + data_size
K = L + U + P
```

The Rat key is also exact for every file that actually uses compression:

- 671/671 blocks are nondecreasing by `K`.
- 671/671 blocks end with the largest `K` remaining at that point.

This includes blocks with no compressed objects when another block in the same
file is compressed. It is therefore a file-level builder mode, not merely a
per-object comparison.

`WORLD/PZ_CHARM.DPC` is a deliberate exception that must not be folded into
the compressed result. Its normal-file flag is set, but all of its objects have
`P = 0`; 19 of its 21 blocks are not sorted by `K`, and 10 do not have the
usual largest-remaining anchor. No other Wall-E PC file has either exception.

### Wall-E PSP

The inspected PSP corpus contains no compressed block resources. The layout's
disk-space value is the complete serialized size:

```text
D = 0x18 + data_size
```

Because every object is uncompressed, sorting by the uncompressed payload or
by `D` differs only by the constant object-header size. Packing must use `D`.

## Capacity selection

### Garfield 2: exact

For the first block of each existing parity, let `K_anchor` be the block's last
and largest object key.

```text
C = align_sector(K_anchor) + 0x800
```

This matches all 241 applicable Garfield parity cases exactly.

There is no separate minimum-capacity floor in the current corpus. The four
cases that originally appeared to require one were caused by considering only
compressed objects. Their capacity anchors are large uncompressed resources:

- `G_STD`: `G_STD_RTC.TRTC`, `K = 16,117`, gives `C = 0x4800`.
- `CASTLE` even: `_L_CA_BIBLIO.WAV`, `K = 782,350`, gives
  `C = 0xC0000`.
- `CASTLE` odd: `_L_CA_CORRIDOR.WAV`, `K = 778,254`, gives
  `C = 0xBF000`.
- `EGOUT` even: `_L_SE_SEWER2.WAV`, `K = 914,826`, gives
  `C = 0xE0000`.

### Wall-E PSP and uncompressed Rat RTC: exact

For uncompressed files, capacity is based on the anchor's complete serialized
disk size:

```text
C = align_sector(D_anchor) + 0x800
```

This matches:

- 783/783 Wall-E PSP parity cases.
- 296/296 Rat RTC parity cases.

### Compressed Rat: capacity algorithm unknown

`K = L + U + P` still works exactly for Rat ordering and anchor selection. The
builder's rule for converting the completed blocks into the final parity
capacity is not known. In particular, the Garfield equality is false for
compressed Rat:

```text
C != necessarily align_sector(K_anchor) + 0x800
```

The `K`-based value is useful only as an observed validation bound, not as a
Rat capacity algorithm.

For every Rat parity containing a compressed object, the capacity satisfies:

```text
C >= align_sector(max K in that parity) + 0x800
```

This inequality holds in all 256 applicable parity cases and happens to be an
equality in 121. The other 135 cases prove that it is insufficient for
constructing a compressed Rat header.

The stored header always satisfies the independently confirmed identity:

```text
C = max(B_i + W_i) for blocks i of that parity
```

Consequently, a later block with a large padded disk footprint `B_i`, a large
working offset `W_i`, or both can determine `C`. Predicting those blocks and
offsets requires the compressed filler-membership and working-offset policies,
which remain unresolved, especially in WORLD DPCs. Tooling must therefore treat
compressed Rat capacity as unknown rather than copying Garfield's equality.

### Compressed Wall-E PC: the same capacity ambiguity

Wall-E PC supplies an independent later corpus with the same symptom. Across
the 180 parity cases containing compression:

```text
C >= align_sector(K_anchor) + 0x800
```

holds in 180/180 cases, but equality holds in only 85. As with Rat, this is a
confirmed lower bound and not a construction algorithm. WORLD files account
for most of the excess: only 1/70 compressed WORLD parity cases is equal,
compared with 84/110 DATAS parity cases.

The retrospective header identity still holds in all 777 Wall-E PC parity
cases, compressed or not:

```text
C = max(B_i + W_i) for blocks i of that parity
```

Uncompressed PC also adds a small caveat to the usual extra-sector rule. RTE
matches `C = align_sector(D_anchor) + 0x800` in 115/115 parity cases, while RTC
matches in 475/480. In the other five odd-parity cases, the parity has only one
block and stores `C = align_sector(D_anchor)` with no extra sector.

## Confirmed uncompressed block membership

For Wall-E PSP, Rat RTC, and Wall-E PC RTC/RTE, block membership is reproduced
by a two-ceiling largest-fitting algorithm using serialized size `D`.

1. Keep all remaining object sizes sorted.
2. For block 0, take the largest remaining object and set the even disk ceiling
   to `align_sector(D_anchor)`.
3. Repeatedly take the largest remaining object whose `D` fits in the block's
   remaining disk space.
4. Store the selected objects in reverse selection order, producing
   nondecreasing `D` order with the anchor last.
5. Block 1 establishes the odd disk ceiling in the same way.
6. Later blocks reuse their parity's ceiling.
7. The final block shrinks to the aligned size actually used.

`scripts/validate_dpc_object_order.py` reconstructs this algorithm and passes
all 397 Wall-E PSP DPP/NPP/DPP.LAYOUT triplets. The same stored-size mode passes
all 156 Rat RTC DPCs without sidecars. It also passes all 242 Wall-E PC RTC DPCs
and all 61 Wall-E PC RTE DPCs without sidecars.

## Compressed filler membership: unresolved

Garfield and compressed Rat block anchors and final within-block order are
known, but their filler membership is not fully reconstructable yet. The same
is true for compressed Wall-E PC.

The following candidate rules have been tested and rejected as complete
solutions:

- largest `K` filler that fits;
- largest stored-size filler that fits;
- smallest-first variants;
- mathematically fullest subset/knapsack selection;
- NPC name-table order;
- class-size order;
- simple dependency-report line order.

The failure of these rules does not affect the confirmed `K` sort or anchor
rule. It means only that another input determines which smaller candidate is
examined first.

### Unknown pre-sort candidate order

One possible explanation is that fillers are accepted during a pass over the
builder's original resource vector, after which the selected block is sorted
by `K`. This is an unverified possibility, not a confirmed explanation or even
a demonstrated difference between the compressed and uncompressed builders.

Conceptually:

```text
remaining = resources in builder discovery/memory order

while remaining is not empty:
    anchor = object with maximum K
    establish parity capacity if this is its first block
    selected = [anchor]

    for candidate in remaining, preserving discovery order:
        if candidate can be added safely:
            selected.append(candidate)
            remove candidate from remaining

    sort selected by K ascending
    serialize selected
```

Adding a smaller object before a compressed source trades stored block bytes
against decompression offset: the source moves forward, so `R_min` can shrink
while `B` grows. Before rounding this is usually neutral or worse. Because `B`
and `R_min` are rounded independently, however, their sum can occasionally
drop by one sector at a boundary. A strict one-pass implementation therefore
can differ from one that revisits an earlier rejected candidate. The artifacts
do not reveal whether the builder revisited candidates.

Memory order can still change which of several individually eligible fillers
wins the remaining space. However, it would affect uncompressed packing too
unless the uncompressed resource vector had already been sorted by disk size.
The exact Wall-E result therefore shows either that its candidate vector is
disk-size ordered or that its builder explicitly searches by disk size. No
surviving artifact shows that the compressed path intentionally changes this
behavior.

Compression does make a hidden rule more visible because three measurements
that collapse to essentially one value in an uncompressed file become
different:

```text
ordering/anchor priority: K
stored block occupancy:   D
decompression workspace:  R_min
```

Thus a rule that is indistinguishable from largest-fitting in an uncompressed
corpus may diverge once compression is enabled. The current evidence does not
identify whether that divergence comes from input-vector order, another sorted
candidate list, container erase behavior, compression staging, or an
additional eligibility rule.

Because many possible hidden orders can generate a given final membership, a
memory-order hypothesis is not independently provable without the original
vector order or builder.

### Wall-E PC and the matching PSP reports

Wall-E PC has no native DPC.LAYOUT reports. Its extracted `manifest.json` files
do not replace them: in all 418 files, manifest block counts, object counts,
compression flags, and `offset` values reproduce the final DPC header. In
particular, manifest `offset` is exactly `working_buffer_offset`. The manifests
are post-build descriptions, not pre-packing resource vectors.

There are nevertheless same-name PSP reports for many files:

- 91/114 compressed PC files have a matching PSP DPP.LAYOUT.
- 56 of those pairs have exactly the same resource-name set.
- 29 exact-set pairs have more than one block and can exercise filler choice.

Using the PSP reports as proxy candidate orders does not identify a winner. A
single-pass simulation using the current `B + R_min <= C` feasibility model
reconstructs 19 or 20 of those 29 multi-block PC files whether the proxy order
is PSP disk size, reversed disk size, class order, dependency appearance,
alphabetical order, or final PC order. The near-identical results from mutually
incompatible orders show that those successes are forced by the size geometry;
they are not evidence for a particular discovery order. The same nine or ten
files remain unexplained.

Large WORLD files also show why “keep taking any safe filler until none fits”
is incomplete. Of their 388 nonfinal blocks, 373 leave at least one later
object that could be added under the current `B + R_min <= C` test after
resorting by `K`; 361 still have such a candidate when an extra `0x800` margin
is required. This does not prove the builder considered those candidates--an
unknown eligibility rule may reject them--but it rules out exhaustive filling
under the presently known size and decompression constraints.

### Why NPC order is not the missing order

NPC/NPP files are name dictionaries, not resource-vector dumps.

For Garfield equal-`K` groups, where a stable final sort might retain fragments
of the input order:

- only 1,492/4,972 groups match NPC order exactly;
- pairwise agreement is 50.17%, effectively random.

Thus an NPC-ordered scan failing to reproduce membership does not disprove a
memory-order scan.

### Class, info, and dependency reports

New Wall-E layouts contain four parallel reports:

- `SortByDiskSpace`;
- `SortByClassSize`;
- `SortByInfos`;
- `SortDependencies`.

These sections enumerate the same database for diagnostics; their presence
does not prove that each one is a packing pass.

Evidence against using them as the primary filler order:

- Mixed classes are perfectly ordered by `K`, so class is not the final sort
  key.
- A class-total candidate scan reconstructs at most about 40/138 Garfield
  files, mostly trivial one-block files.
- `SortByInfos` covers only resource types with reportable metadata and cannot
  define a total order.
- Wall-E's dependency section contains, on average, 81.4% of packed object
  names, but contains every object in only 1/397 files.
- Scanning dependency-report order and then appending missing objects in disk
  order reproduces only 167/397 Wall-E memberships. Disk-size order reproduces
  397/397.

Dependencies may still affect the discovery order that originally populated
the builder's vector. They just do not provide a complete surviving vector
order.

### Recovering dependency evidence

The supplied LZRS decoder successfully decompresses Garfield resources. An
aligned 32-bit name-hash scan over Wall-E object payloads recovers 100% of the
printed dependency edges in the sampled files. It also finds extra references,
so it is a dependency/reference superset rather than a precise strong-link
parser.

Applying the same technique to Garfield shows that direct references between
packed top-level resources are sparse in the character DPCs:

- P_MOUSE: 1 direct packed-resource edge;
- P_GOOSE: 1;
- P_GARFLD: 3;
- no block anchor in those files has a direct outgoing packed-resource edge.

Matching old internal `link_name` hashes produces more relationships and some
above-chance co-location, but not an anchor-expansion rule. Exact dependency
reconstruction would require version- and class-aware parsing of resource
payloads and still might not recover the original vector insertion order.

## In-place decompression feasibility

A compressed object's stored bytes can fit on disk while its decompressed
output overlaps the unread compressed source. Candidate selection must account
for this working-space geometry.

For a tentative block already sorted by `K`, let `O_i` be the stored offset of
object `i`'s resource header from the start of the block.

### Garfield minimum

For compressed objects (`P_i != 0`), the compressed source begins after the
`0x10`-byte resource header:

```text
source_i = O_i + 0x10
required_i = align_sector(max(S_i - source_i, 0))
R_min = max(required_i)
```

### Rat minimum

For compressed Rat objects, the source begins after the `0x18`-byte object
header and `U_i` is the decompressible body size used by the current pattern:

```text
source_i = O_i + 0x18
required_i = align_sector(max(U_i - source_i, 0))
R_min = max(required_i)
```

The current Rat pattern asserts that the stored working offset is never less
than this value.

A conservative candidate feasibility check is:

```text
align_sector(sum(D_i)) + R_min <= C
```

This is a necessary safe bound. It is not a complete model of the builder's
chosen offset because the stored offset is frequently larger than `R_min`.

## Working-buffer offset and placement policy

The minimal decompression requirement and the stored placement offset are
different concepts.

The common placement behavior is to right-align a padded block in its parity
buffer:

```text
W_right = C - B
T = 0
```

Measured right-alignment counts are:

- Garfield: 449/462 blocks. The other 13 leave exactly `0x800` trailing.
- Wall-E PSP: 2,042/2,168 blocks. The other 126 leave exactly `0x800`.
- Rat RTC: 1,255/1,285 blocks. The other 30 leave exactly `0x800`.
- Wall-E PC RTC/RTE: 1,341/1,378 blocks. The other 37 leave exactly
  `0x800`.

This explains why uncompressed RTC and Wall-E files still store nonzero and
sometimes very large offsets: most of those offsets are ordinary right-aligned
placement in a reused parity buffer. Earlier hypothetical compression is not
required to explain them.

### Garfield offset evidence

Against the simple overlap minimum above:

- 203/462 offsets equal `R_min`;
- 138/462 equal `R_min + 0x800`;
- 449/462 are right-aligned;
- the 13 non-right-aligned blocks have `W = 0` and `T = 0x800`.

Most excess values are therefore exactly the unused leading space created by
right alignment, not additional decompression necessity. The rule choosing the
13 left placements instead of `W = 0x800` remains unknown.

### Compressed Rat offset evidence

There are 818 Rat blocks containing compressed objects:

- 207 offsets equal the calculated minimum;
- 475 equal minimum plus `0x800`;
- 372 are right-aligned;
- 446 retain trailing space.

These counts overlap: right alignment and equality to a minimum are independent
properties. The remaining 136 blocks have other positive differences from the
calculated minimum.

Compressed Rat therefore still has an unresolved offset policy. Neither the
minimum decompression bound nor right alignment alone reproduces every stored
offset, especially in WORLD DPCs.

### Compressed Wall-E PC offset evidence

The 651 Wall-E PC blocks containing compressed objects show the same mixed
policy:

- 183 offsets equal `R_min`;
- 378 equal `R_min + 0x800`;
- 90 have another positive excess;
- 246 are right-aligned;
- 82 leave exactly `0x800` trailing.

As in the Rat counts, these categories overlap. This larger later corpus makes
the common `0`/`0x800` excess especially clear, but it still does not explain
the 90 other values or the rule choosing placement per block.

## Best-attempt construction of a new bigfile from serialized resources

The goal here is not to recreate the unavailable builder exactly. It is to
create a deterministic, self-consistent best attempt that satisfies every
known loader and in-place decompression invariant. Unknown historical choices
prevent byte-identical reproduction of a compressed original, but do not
prevent a tool from choosing and documenting its own safe policies. This
section assumes that every resource has already been serialized into the exact
per-object binary representation expected by the target game, including its
object header and any per-resource compression.

The writer should separate two layers:

1. A **layout builder** assigns serialized resources to blocks and calculates
   block sizes, working offsets, and parity capacities.
2. A **format profile** emits the game/platform-specific file header,
   descriptors, checksums, flags, and optional sidecars.

Resources alone cannot determine a version string/triple, platform constants,
an unknown mandatory checksum, or optional pool/manifest data. Those values
must come from an explicit target profile, not be inferred from resource
ordering. A profile should refuse to write a variant whose mandatory fields
are not understood.

### Normalize the resource input

Parse or retain the following metadata beside each serialized byte string:

```text
bytes          complete serialized object, including its object header
D              len(bytes)
K              game-specific ordering key
name           object name hash
class          class name hash
input_ordinal  stable caller/database discovery index
compression fields needed to calculate R_min
```

Use the format-specific definitions already established above:

```text
Garfield:       D = 0x10 + (P != 0 ? P : S), K = S + P
Rat/Wall-E PC: D = 0x18 + data_size,        K = L + U + P
Wall-E PSP:    D = 0x18 + data_size,        K = D for packing purposes
```

Validate before packing that the serialized length agrees with its embedded
size fields, name/class hashes agree with the supplied metadata, and compressed
sizes are legal for the target profile. If the output is an RTC file, require
`P = 0` for every resource and write the RTC flag accordingly. Do not silently
decompress a resource merely to satisfy this rule.

Use `input_ordinal` as the deterministic secondary key whenever two resources
have equal `K` or `D`. Historical tie order is not known, but deterministic
output is much easier to test and reproduce.

### Exact uncompressed block construction

For Wall-E PSP, Rat RTC, and Wall-E PC RTC/RTE, use the confirmed algorithm.
The two parity packing ceilings below exclude the extra working-buffer sector:

```text
remaining = resources sorted by (D, input_ordinal)
disk_ceiling[0] = unset
disk_ceiling[1] = unset
blocks = []

while remaining is not empty:
    block_index = len(blocks)
    parity = block_index % 2
    anchor = largest remaining resource

    if disk_ceiling[parity] is unset:
        disk_ceiling[parity] = align_sector(anchor.D)

    free = disk_ceiling[parity]
    selected = []

    while a remaining resource has D <= free:
        candidate = largest remaining resource whose D <= free
        remove candidate from remaining
        selected.append(candidate)
        free -= candidate.D

    sort selected by (D, input_ordinal) ascending
    blocks.append(selected)
```

The block's actual padded disk size is always derived from what was selected;
it is not forced to occupy the full parity ceiling:

```text
data_size = sum(resource.D for resource in block)
B = align_sector(data_size)
```

This naturally produces the smaller final block seen in the corpus. If the
result exceeds the format's 64 block descriptors, fail clearly, split the
resource set into multiple bigfiles, or retry with deliberately larger packing
ceilings. Never overwrite the fixed descriptor area.

### Deterministic compressed block construction

Compressed Garfield, Rat, and Wall-E PC require a declared heuristic policy.
The following produces deterministic blocks that obey the known ordering and
in-place decompression constraints without claiming historical authenticity:

```text
remaining = resources in caller/database discovery order
capacity[0] = unset
capacity[1] = unset
blocks = []

while remaining is not empty:
    block_index = len(blocks)
    parity = block_index % 2
    anchor = maximum remaining resource by (K, input_ordinal)

    if capacity[parity] is unset:
        capacity[parity] = align_sector(anchor.K) + 0x800

    selected = [anchor]
    remove anchor from remaining

    for candidate in a snapshot of remaining discovery order:
        tentative = sort(selected + [candidate], by K ascending)
        B_test = align_sector(sum(resource.D for resource in tentative))
        R_test = calculate_R_min(tentative)

        if candidate is still remaining and B_test + R_test <= capacity[parity]:
            selected.append(candidate)
            remove candidate from remaining

    sort selected by (K, input_ordinal) ascending
    blocks.append(selected)
```

`align_sector(anchor.K) + 0x800` is Garfield's confirmed capacity rule. For
compressed Rat and Wall-E PC it is only a safe starting policy based on the
confirmed lower bound; it is not their recovered builder rule. A writer may
instead accept an explicit per-parity capacity budget.

Before accepting the block, verify that its anchor alone fits. If a later
anchor of an already-established parity does not satisfy
`B_anchor + R_anchor <= capacity[parity]`, grow that parity capacity by sectors
until it does and finalize all offsets only after every block is known. Earlier
blocks remain valid when their capacity grows. Do not silently drop an anchor.

The discovery-order scan is likewise a writer policy. Implementations should
make filler order selectable--for example discovery order, descending `K`, or
descending `D`--and record the chosen mode in build diagnostics. Changing this
mode changes membership but must not change the final ascending-`K` order
inside a selected block.

### Finalize working-buffer placement

Once every block is known, recalculate its minimal decompression offset from
the final ascending order. Let this be `R_min`. A simple self-consistent writer
policy is to right-align every block:

```text
B_i = align_sector(sum(resource.D for resource in block_i))
W_i = C_parity(i) - B_i
assert W_i >= R_min_i
```

If the assertion fails, increase that parity capacity to at least
`B_i + R_min_i`, sector-align it, and recompute the offsets of every block of
that parity. Repeat until no capacity changes. This guarantees:

```text
C_parity = max(B_i + W_i)
T_i = C_parity - W_i - B_i = 0
W_i >= R_min_i
```

This right-aligned policy is common in the originals and is safe according to
the known model. It will not reproduce blocks for which the original builder
left `0x800` trailing or selected another unexplained excess offset. Such
compatibility choices should be optional policies, not hidden adjustments.

For exact uncompressed mode, initialize:

```text
C_parity = disk_ceiling[parity] + 0x800
```

and apply the same right-alignment calculation. The five Wall-E PC odd-parity
exceptions that omit the extra sector matter only when matching those original
headers; a newly built self-consistent file need not imitate them.

### Emit blocks and the file header

For each block, concatenate the already-serialized resource bytes in their
final order, then append zero bytes up to `B`. Populate its description from
the result:

```text
object_count          number of selected resources
data_size             unpadded concatenated byte count
padded_size           B
working_buffer_offset W
first_object_name     name hash of the first serialized resource, where used
checksum              supplied/calculated by the target format profile
```

Then emit the fixed-size header and block data:

1. Write the target version string/triple and RTC/normal flags from the profile.
2. Write `block_count`, even/odd capacities, and
   `total_padded_block_size = sum(B_i)`.
3. Write the used block descriptions and zero the unused descriptor slots.
4. Populate any remaining known profile fields, including final file size.
5. Pad the header to `0x800`, append every padded block, and emit any
   format-specific pool/manifest area only when that variant requires it.
6. Optionally emit NPC/NPP name dictionaries from the resource hash/name map.
   A diagnostic LAYOUT report is not required for block loading.

For an empty resource set, use the target profile's explicit empty-file rule;
do not manufacture an empty block just to enter the normal packing loop.

### Required post-build validation

A new writer should parse its own output again and reject it unless all of the
following hold:

- every serialized object is present exactly once and its bytes round-trip;
- each `data_size` equals the sum of its objects and each `padded_size` is its
  sector alignment;
- every block is nondecreasing by the selected format's `K`;
- every block anchor was the largest `K` remaining when that block was made;
- `C = max(B + W)` independently for even and odd blocks;
- every compressed block has `W >= R_min`;
- RTC files contain no compressed resources and the path/type flag agrees;
- block count, total padded size, final file size, and end-of-file position
  agree with the emitted bytes;
- all profile-specific checksum, pool, and sidecar invariants pass.

Build diagnostics should state whether the file used **exact uncompressed** or
**heuristic compressed** layout. A structurally valid heuristic file should
never be reported as an exact reproduction of the unavailable builder.

### Mapping the construction process onto bff

For the Garfield/Rat/Wall-E formats in scope, the bff repository already
contains most of the binary-format machinery needed by this design. Their
missing piece is a planner that creates a suitable `Manifest` from a resource
collection. This does not imply that every later bff backend has a complete
writer or that the current shared manifest preserves every later format's
layout metadata.

#### What bff currently does

`bff-cli/src/create.rs` currently performs these operations in this order:

1. Open `manifest.json` and probe its `version` to choose a `NameType`.
2. Deserialize the complete manifest into a `NameContext`.
3. Read every entry in `resources/` into a `HashMap<Name, Resource>`.
4. Construct `BigFile::new(manifest, resources)`.
5. Dispatch to the writer selected by manifest version/platform.

The manifest is not merely descriptive in this path. Its block list is the
write plan. The Rat/Wall-E-style writers iterate `manifest.blocks` and then
each block's `resources` in exactly the stored order. A resource present in the
folder but absent from the manifest is not written. A manifest entry whose
resource is absent reaches an `unwrap`, and duplicate manifest references can
write the same map entry more than once. Manifestless support should add
explicit set validation instead of preserving these failure modes.

The writer also gives omitted optional values behavior that is unsuitable for
an intentional best-attempt layout:

- missing `ManifestResource.compress` becomes `false`;
- missing `ManifestBlock.offset` uses bff's local calculated fallback;
- missing block checksum is written as zero;
- missing `version_xple` becomes zeroes;
- missing `bigfile_type` generally becomes `Normal`.

In particular, the current Rat/Wall-E offset fallback is not the right-aligned
policy described above. It tracks a padded maximum based on the full body size
when the body is larger than the resource's block offset. It neither calculates
the documented `R_min` difference nor finalizes offsets against the maximum
capacity of the parity. A synthesized manifest should therefore contain an
explicit offset for every block rather than rely on this fallback.

#### What survives in a folder without a manifest

Binary resources produced by bff extraction are not raw DPC object bytes. They
are `BFF0` wrapper files. Each wrapper preserves:

- platform;
- engine version;
- resource class and name hashes;
- link header and decompressed body, where that format separates them.

Rich resource directories preserve the same platform/version in
`resource.json` through `BffClass.header`. Both forms therefore contain enough
information to select a backend and serialize an uncompressed resource.

They do **not** preserve the original resource compression flag or compressed
byte stream. bff decompresses a DPC resource while reading it and the `BFF0`
header contains only platform/version metadata. They also do not preserve
block membership, block order, working offsets, checksums, XPLE version, or
pool topology. Once `manifest.json` has been removed, those values must be
synthesized or supplied; there is no exact “preserve” compression mode.

The current `Source` extraction directories contain `source.json`, whereas
`create` expects `resource.json` in every resource directory. `source.json` is
intended to describe an editable, game/platform/version-independent asset, not
one already-cooked bigfile resource. A Node source asset is also allowed to
represent several cooked resources, such as the Node itself, its UserDefine,
and its AnimFrames.

Source extraction can consequently produce a **hybrid project**: supported
resource groups become `source.json` assets, while resources not represented
by a source asset remain as rich or binary cooked fallbacks. bff extraction
always writes `manifest.json`, including for a Source export, so an ordinary
extracted hybrid project already has its original write plan. Its rebuild path
should materialize every input kind and validate the resulting resource set
against that manifest; it should not synthesize a replacement merely because
the folder mixes representations.

A manifestless hybrid is still a valid input model for a manually assembled
project or one whose manifest was deliberately removed. Only that case needs
best-attempt synthesis. The architecture must therefore accept any mixture of
`source.json`, `resource.json`, and `BFF0` without assuming that one directory
entry always becomes exactly one resource.

The common layout planner should consume a target-specific collection of
cooked `Resource` values. A separate front end should eventually turn source
assets into that same collection. This keeps source cooking independent from
block packing and allows source-only, cooked-only, and hybrid projects to share
all compression and layout code.

#### Manifest field synthesis

The following table separates values obtainable from resources from actual
builder policy.

| Manifest field | Available from project entries | Recommended generated value |
| --- | --- | --- |
| `version` | Every `BFF0`/`resource.json` header; absent from source assets | Require all cooked resources to agree. A manifestless source-only project requires an explicit target profile, CLI value, or template. |
| `platform` | Every cooked-resource header; absent from source assets | Require cooked inputs to agree. Resolve it from the selected target for source-only input and store it in the manifest. |
| `version_xple` | Not present | Target-profile default, explicit CLI value, or template manifest. Warn before using zeroes. |
| `bigfile_type` | Not present | Explicit `Rtc`/`Normal`; path-based `RTC`/`RTE` inference may be an opt-in convenience. |
| `blocks[].resources[].name` | Resource object | Generated block membership and final serialization order. |
| `blocks[].resources[].compress` | Not present | `false` for RTC; otherwise an explicit none/all/auto/per-resource policy. |
| `blocks[].offset` | Not present | Calculate all `R_min`, parity capacities, and right-aligned offsets after membership is final. |
| `blocks[].checksum` | Not present | Calculate from the final unpadded serialized block when the profile uses one. |
| `blocks[].compress` | Not present | Format-specific block-compression policy; leave absent for Rat/Wall-E resource-level LZRS profiles. |
| `pool` | Not present | Omit only for a profile known to permit no pool; otherwise require a template or reject manifestless creation. |
| `pool_manifest_unused` | Not present | Profile/template value only. |
| `incredi_builder_string` | Not present | Empty, a user tag, or a profile value; never use it as layout input. |

For the scoped Asobo block checksum, bff already contains
`asobo_alternate32`, and its writer TODO identifies that algorithm over the
unpadded block. Direct checks against Rat and Garfield blocks reproduce their
stored checksum. The writer should calculate it while it already has the final
serialized block bytes instead of requiring it in user-authored JSON. Profiles
whose corpus stores zero should continue to emit zero.

#### Version-specific planners and manifest fidelity

There should not be one universal `synthesize_manifest(resources)` algorithm.
The JSON type called `Manifest` is shared today, but the policy that creates it
depends on the game/build lineage, platform, and binary version. Even two
versions that can reuse a resource serializer may have different block
membership, ordering, capacity, offset, compression, pool, or checksum rules.

For the currently studied generations, planner support has these different
confidence levels:

| Build profile | What a generated manifest may claim |
| --- | --- |
| Garfield 2 | Exact scalar ordering, anchors, and capacity; filler membership and some offset choices remain heuristic. |
| Rat | Exact uncompressed packing; compressed membership, capacity excess, and offset choices remain heuristic. |
| Wall-E PSP/PC | Exact for the documented uncompressed profiles; compressed PC packing remains heuristic. |
| APTR `v2_128_52_19` | No synthesis claim yet. Its layout representation and construction policy require separate analysis. |

APTR demonstrates why this is more than selecting a different sort function.
Its current bff reader exposes a block-level `Resources` map containing two
separate resource lists plus a fixed table of as many as 52 `DataDescription`
groups. It also distinguishes locally stored resources from references whose
data must be found elsewhere, and stores map/data offsets and working-buffer
values using a different layout. Resources may use None, LZ4, or Zlib body
compression rather than the older resource-level policy modeled above.

The current `v2_128_52_19_pc` reader appends all those categories to one
`ManifestBlock.resources` vector. That is useful for inventory/extraction, but
it discards the subgroup and local/external placement information needed to
write the original structure. Its `write` implementation is also currently
`todo!()`. Therefore an APTR `manifest.json` emitted by the present reader
must not be treated as a proven complete rebuild recipe, and the legacy block
planner must never be selected for it as a fallback.

The build system should describe these distinctions as capabilities of each
target profile:

```text
can_read
can_write_existing_manifest
manifest_is_lossless
can_synthesize_from_cooked
can_cook_source
layout_confidence = exact | heuristic | unsupported
```

`auto` may use only a profile that explicitly declares the required
capability. It should reject an unsupported version with a precise diagnostic
instead of choosing the nearest older planner. This is especially important
for source-only input: successfully cooking an APTR resource does not imply
that bff knows how to group those resources into an APTR bigfile.

The long-term internal boundary should consequently be a version-specific
`BuildPlan`, not necessarily today's lowest-common-denominator `Manifest`:

```text
cooked resources
       |
       v
LayoutProfile::plan(...) -> BuildPlan::<target>
                                  |
                                  +--> complete JSON manifest for that target
                                  |
                                  +--> target writer
```

Legacy profiles can convert their plan directly into the existing `Manifest`.
Later profiles can extend the manifest with a tagged, version-specific layout
payload, or use a versioned manifest enum, without adding unrelated optional
fields to every legacy block. The important requirement is losslessness: a
writer must receive every grouping and placement decision required by its
binary format.

#### Recommended command behavior

When a manifest exists, keep it as the authoritative write plan. Cooked-only
projects retain the current behavior; source or hybrid projects must first
materialize the cooked resources referenced by that plan. Add a shared
synthesis path for projects without a manifest, exposed in two ways:

```text
bff manifest <directory> --output <manifest.json> [build policy options]
bff create <directory> <bigfile> --manifest-mode auto [build policy options]
```

Useful manifest modes are:

- `require`: current behavior; absence is an error.
- `auto`: use an existing manifest, otherwise synthesize one and continue.
- `generate`: require that no manifest exists, synthesize it, and optionally
  stop before writing the bigfile.
- `regenerate`: use an existing manifest only as an explicit metadata template
  and replace its layout through the selected planner.

These modes remain capability-gated by the selected target profile. Finding a
JSON file named `manifest.json` is not sufficient if that version's current
schema is lossy or its writer is unimplemented. In that case `require` and
`auto` must explain which layout information or writer capability is missing.
They must not reinterpret the manifest using a legacy profile.

`auto` should save the generated `manifest.json` by default. The saved file is
the build lock: it freezes resource order, tie decisions, compression choices,
blocks, offsets, and checksums. Rebuilding the same folder afterward then uses
the ordinary deterministic manifest path instead of rerunning heuristics.

For `require` and the existing-manifest branch of `auto`, input representation
does not affect ordering. After source cooking and rich/binary import, validate
that the manifest references every emitted resource exactly once and no unknown
resource. Recompute the sizes and decompression-safety requirements implied by
the newly materialized bytes. If an edited asset no longer fits the stored
block/offset plan, fail and suggest explicit `regenerate`; never silently move
objects or change their compression flags under an existing manifest.

Do not add a separate incremental manifest-update algorithm initially. If a new
source asset emits names absent from the manifest, an old asset stops emitting
a referenced resource, or an edit makes the stored plan invalid, `require` and
the existing-manifest branch of `auto` should report the exact added/missing or
unsafe resources and stop. The user can then select `regenerate` explicitly.

`regenerate` materializes the **entire** mixed project--all `source.json`,
`resource.json`, and `BFF0` entries--and runs the selected best-attempt planner
over the resulting cooked resource collection. It may reuse target identity and
other safe top-level values from the old manifest, but it discards the old
blocks, ordering, compression flags, offsets, and checksums. Resource-dependent
pool, common-reference, or later version-specific grouping data must be rebuilt
by that target profile rather than copied from the old manifest. If the profile
cannot rebuild those structures, regeneration is unsupported and must fail.

This full regeneration is more invasive than an append-only updater, but its
behavior is much easier to define and validate. It also avoids preserving a
partly historical layout while applying invented placement rules only to new
resources. The generated manifest becomes the new build lock after a successful
write and read-back validation.

The build-policy options should include at least:

```text
--bigfile-type rtc|normal
--input-mode auto|cooked|source|hybrid
--target-profile <game-platform-version-profile>
--version <version>                 # required if it cannot be inferred
--platform <platform>               # required if it cannot be inferred
--version-xple <a,b,c>
--compression none|all|auto
--compression-threshold <ratio>     # profile default for auto mode
--packing auto|exact-uncompressed|heuristic-compressed
--filler-order discovery|k-desc|d-desc
--template-manifest <path>          # top-level/pool metadata, not block layout
--write-generated-manifest <path>
```

`--target-profile` is more than shorthand for version and platform. For source
input it selects the source-to-cooked conversions, resource class variants,
name hashing, binary serialization, compression policy, and layout profile.
Raw `--version` and `--platform` remain useful low-level overrides, but they are
not sufficient when two games share those values and require different cooking
rules.

Existing `platform_override`/`version_override` options can be reused as the
explicit target only if their semantics are made clear. `version_to_write`
changes the version string written to the file; it must not be treated as the
backend/resource-layout version.

An RTC build should force `compression = none` and reject a conflicting flag.
For `Normal`, `auto` should precompress each eligible body with the same LZRS
implementation used by the final writer and retain compression only when the
target profile's ratio threshold is met. For the Rat/Wall-E policy currently
being modeled, a reasonable default is:

```text
compressed_size <= decompressed_size * 0.80
```

`all` should remain an explicit diagnostic option because the current bff
writer will otherwise compress even when the result is poor or larger. The
chosen compressed size is needed before packing because it contributes to both
`D` and `K`.

#### Source-resource cooking before layout

A source project changes where target selection occurs. `BFF0` and
`resource.json` carry a target and can be measured immediately. `source.json`
does not. The builder must resolve the target first, cook the source project
into target-specific resources, and only then validate an existing manifest or
run the manifestless synthesis pipeline.

The boundary should look conceptually like this:

```text
project entries
    cooked BFF0/resource.json ----------+
                                        +--> cooked Resource collection
    source.json --> target cooker -------+              |
                                                       v
                                manifest validation or layout planning
                                                       |
                                                       v
                                                Manifest + bigfile
```

Source cooking must be a project operation rather than a per-file conversion:

- one source asset can emit zero, one, or several cooked resources;
- resource names and classes emitted for its component parts must be stable;
- source assets can refer to other source assets or cooked fallback resources;
- cooking may require a dependency graph and more than one pass;
- two source assets, or a source asset and a cooked fallback, must not emit the
  same resource name silently;
- unsupported source classes should produce a capability error listing the
  missing cookers, not disappear from the output;
- source-side artifacts should be loaded before cooking just as rich-resource
  artifacts are loaded before importing;
- any target-specific preserved fragment must either declare compatibility
  with the selected target or fail explicitly. It must not be copied blindly
  into a different target.

For a source-only directory without a manifest, `auto` cannot infer
version/platform from the resources. It must require `--target-profile` or
equivalent explicit target configuration. An existing or template manifest can
also supply the target. For a hybrid directory, the existing manifest and
cooked fallback headers must agree, and the selected source cooker must support
that target. The resolved target is immutable for the rest of the build.

Names require the same early decision. The builder selects the target's
`NameType`, creates its `NameContext`, and then reads the source project. Source
JSON should prefer symbolic names. A numeric-only hash cannot in general be
translated to another hash scheme and should require a name mapping or be
rejected when the target name type differs.

An existing manifest can still be used with source input, but only after
cooking. Its resource list must be checked against the **emitted cooked
resources**, not against the number or names of `source.json` files. With no
manifest, the emitted resource collection becomes the input to the ordinary
best-attempt planner. Even the manifest-only command therefore has to run the
source cooker in memory: block membership depends on the final serialized and
possibly compressed sizes.

The source build path should have these stages:

1. Classify every resource entry as binary cooked, rich cooked, or source.
2. Resolve one target build profile before parsing target-dependent names.
3. Load all source assets and artifacts into a `SourceProject` and validate its
   identity/reference graph.
4. Cook the entire project through a target-specific `CookProfile`, producing
   named `BffClass`/`Resource` values and diagnostics about represented source
   assets.
5. Import binary/rich fallbacks for the same target and merge both collections,
   rejecting name collisions and incompatible embedded targets.
6. Assert that every source asset was either cooked successfully or rejected;
   partial silent builds are never valid.
7. Pass only the completed cooked collection to serialization, compression,
   existing-manifest validation or manifestless packing, and final writing.

This also provides a useful implementation order. Manifestless cooked-folder
support can be delivered first, using an `InputProject` abstraction whose
source branch initially returns a precise “cooker unavailable for target”
error. Adding source cookers later then changes the input front end without
changing the layout algorithm or manifest schema.

#### Synthesis pipeline

The manifest generator should execute these phases only when no authoritative
manifest exists or `regenerate` was explicitly selected. The discovery,
target-resolution, name-context, and cook/merge phases are shared with an
existing-manifest build; that path then validates its stored plan against the
prepared resources instead of executing membership selection.

1. **Discover and classify deterministically.** Resolve `directory/resources`
   when it exists, otherwise use an explicitly supplied resource root. Sort
   entry paths and classify `BFF0`, `resource.json`, and `source.json` inputs.
   `std::fs::read_dir` order and `HashMap` iteration must never become
   `input_ordinal`.
2. **Resolve the target before cooking.** Probe every cooked `BFF0` header or
   `header` object in `resource.json`, combine that evidence with the selected
   target profile/template/CLI values, and verify compatibility. A source-only
   or empty folder requires explicit target information.
3. **Create the `NameContext`.** Derive `NameType` from the resolved target,
   validate overrides, then deserialize cooked resources and source assets.
   JSON string names will populate the context; unresolved binary hashes remain
   numeric.
4. **Cook and merge the project.** Compile source assets for the resolved
   target, import cooked fallbacks, reject duplicate emitted resource names and
   incompatible embedded targets, and require an explicit error for every
   unsupported source asset.
5. **Prepare both storage variants.** Serialize each resource uncompressed. If
   compression is allowed, LZRS-compress its body into a scratch buffer. Cache
   or record `D`, `K`, decompressed size, compressed size, and the final
   compression choice.
6. **Build membership.** Invoke the exact uncompressed or declared heuristic
   compressed algorithm from this document. Keep resources in an ordered
   vector during planning; create the final `ResourceMap` only after order is
   no longer needed.
7. **Finalize each block.** Serialize its prepared resources in final order,
   calculate `data_size`, `B`, `R_min`, and any block checksum from those exact
   bytes.
8. **Finalize each parity.** Choose/grow `C`, then write
   `offset = C - B` for every block. Assert `offset >= R_min` and
   `C = max(B + offset)`.
9. **Construct `Manifest`.** Fill top-level profile metadata, generated blocks,
   per-resource compression flags, offsets, and checksums. Ensure every loaded
   resource appears exactly once unless a format-specific pool model explicitly
   permits another relationship.
10. **Persist and build.** Write the generated manifest using the populated
    `NameContext`, construct `BigFile::new`, and call the existing backend
    writer.
11. **Read back.** Parse the emitted bigfile and verify the post-build
    invariants listed above before reporting success.

The scratch serialization in steps 5 and 7 is important. Calculating sizes
from Rust structures separately from the backend writer risks disagreement due
to headers, endian handling, alignment, or compression headers. A first
implementation may compress twice--once for planning and once in the existing
writer--because bff's compressor is deterministic. A later refactor should pass
prepared compressed bytes into the writer so compression occurs once and the
planned bytes are exactly the emitted bytes.

#### Suggested bff code organization

Do not put the packing algorithm directly into the CLI command. A reusable
library API makes it testable and allows other tools to request a plan without
writing a file. One possible split is:

```text
bff/src/bigfile/layout.rs
    BuildOptions
    CompressionPolicy
    PackingPolicy
    FillerOrder
    DiscoveredResource / PreparedResource
    LayoutProfile
    BuildPlan
    common packing/measurement helpers

bff/src/bigfile/layout/profiles/
    garfield.rs
    rat.rs
    walle.rs
    aptr.rs                       # unsupported until its layout is modeled

bff/src/source/cook.rs
    InputProject / ProjectEntry
    CookOptions / CookContext
    CookProfile
    CompiledProject
    cook_project(...)

bff/src/bigfile/manifest.rs
    legacy serialized manifest schema
    tagged/version-specific layout payloads when required

bff-cli/src/create.rs
    discover/classify project entries
    resolve target and cook source assets when present
    load a lossless existing plan or call the selected LayoutProfile
    save generated manifest
    invoke the matching target writer

bff-cli/src/manifest.rs
    manifest-only command using the same selected LayoutProfile
```

The source cooker and layout code need related but distinct profile interfaces.
`CookProfile` owns semantic source-to-resource conversion. The layout profile
operates only on the resulting target-specific resources and must answer:

- how to serialize and measure this version's resource variants;
- how to calculate `D`, `K`, and `R_min`;
- whether compression is per resource and which threshold applies;
- which checksum algorithm/default is required;
- default XPLE/type/tag values, if safely known;
- whether a pool may be omitted;
- maximum block count and sector size.

The existing `BigFileIo` trait only exposes read/write and a resource type. A
`BuildProfile` can aggregate `CookProfile` and `LayoutProfile`, while keeping
both separate from `BigFileIo`. That is less invasive than forcing source and
planning state into the binary reader/writer. The cooked resource collection
is the boundary between cooking and layout. A target-specific `BuildPlan` is
the boundary between planning and writing; a JSON manifest is its persistent
representation only when that profile can serialize the plan losslessly.

#### Manifest generator validation and tests

At minimum, add tests for:

- binary `BFF0`, rich `resource.json`, source-only `source.json`, and hybrid
  folders;
- extracted hybrid projects preserving their existing manifest membership,
  order, compression flags, and offsets regardless of input representation;
- edited source that violates an existing plan failing until `regenerate` is
  explicitly requested;
- a new source asset emitting one or several unlisted resources causing strict
  modes to fail, then appearing exactly once after full regeneration;
- manifestless source-only builds requiring a target profile before cooking;
- one source asset producing several cooked resources with deterministic names;
- source/cooked collision detection, missing cookers, unresolved references,
  and incompatible preserved fragments;
- the same source project cooked for each supported target and then round-tripped
  through that target's resource reader;
- selecting the correct game/build-lineage planner when versions share binary
  machinery;
- unsupported profiles being rejected instead of falling back to a legacy
  planner;
- backward-compatible legacy manifests and lossless round trips for every new
  version-specific manifest payload;
- APTR subgroup/local-reference information surviving manifest round trips
  before APTR synthesis or writing is advertised;
- stable output when directory enumeration order changes;
- mixed platform/version rejection and explicit conversion overrides;
- duplicate names, missing resource roots, and empty folders;
- RTC forcing every `compress` flag to false;
- auto-compression decisions using the actual emitted LZRS size;
- exact uncompressed packing on the known Rat RTC and Wall-E corpora;
- heuristic compressed output satisfying `K`, anchor, capacity, and `R_min`
  invariants;
- correct Asobo Alternate block checksums where required;
- more than 64 generated blocks producing an error/repack instead of header
  corruption;
- generated-manifest create, extract, and resource-byte round trips;
- extra or omitted resources being rejected before writing;
- a second build using the saved manifest producing the same output.

Corpus tests for compressed files should not compare generated membership with
the original manifest. They should compare resource identity and validate the
known structural invariants. Original equality is an appropriate test only
when the original manifest itself is supplied.

## Recommended best-effort writer strategy

Tooling should offer exact and heuristic modes instead of claiming one rule for
all games.

### Exact uncompressed mode

Use for Wall-E PSP, Rat RTC, and Wall-E PC RTC/RTE:

1. Compute serialized `D`.
2. Apply the confirmed two-parity largest-fitting algorithm.
3. Sort each block by `D` ascending.
4. Set capacity from the first anchor's aligned `D` plus `0x800`. For Wall-E
   PC, preserve the five observed single-block odd-parity exceptions that omit
   this extra sector if byte-identical reconstruction is required.
5. Preserve tie order when possible, but treat equal sizes as interchangeable.

### Best-effort compressed mode

Use for Garfield, compressed Rat, and compressed Wall-E PC until the original
discovery order or builder is recovered:

1. Preserve the caller/database resource discovery order as one explicit
   heuristic. Do not substitute NPC/NPP order, which is known not to represent
   it.
2. Compute the game-specific `K` exactly.
3. Select the largest remaining `K` object as the next anchor.
4. Establish capacity with the exact game rule when known.
5. Make the filler strategy selectable. Useful experiments include preserved
   discovery order, descending `K`, descending stored `D`, and class/dependency
   traversal, but none is currently authentic for all compressed files.
6. For each candidate, sort the tentative set by `K` and apply the in-place
   feasibility bound before accepting it.
7. Sort accepted objects by `K` ascending before serialization.
8. Prefer right alignment for `W`, while exposing an override or compatibility
   mode because the exact left/right and excess-offset policies are unresolved.

When no meaningful discovery order exists, descending `K` is a deterministic
fallback, not an authentic reconstruction. A writer should report that the
result is structurally valid but not expected to be byte-identical to the
original builder.

## Open questions

1. What resource-vector discovery order did the old Garfield and compressed Rat
   builders use?
2. Was filler selection a scan, a sorted search, or another container traversal
   whose order changed during removal or compression staging?
3. Which strong/weak dependency classes, if any, influenced resource insertion
   order?
4. Why do a minority of otherwise right-alignable blocks leave one `0x800`
   sector trailing?
5. What produces compressed Rat's capacity and offset excesses, particularly in
   WORLD files?
6. Was the final `K` sort stable, and which input order breaks equal-key ties?

Until those questions are answered, block ordering and anchor selection are
exactly known, uncompressed membership is exactly known, and compressed filler
membership plus some working-buffer placement decisions remain best-effort.
