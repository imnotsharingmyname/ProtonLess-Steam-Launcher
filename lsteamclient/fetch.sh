#!/bin/sh
# Assemble a complete lsteamclient source tree: Valve's, at the pinned commit, with
# the files authored here laid over the top.
#
# Only the authored files are tracked in this repo. Valve's 3,133 are fetched, so
# their Steamworks SDK licensed sources and the LGPL cxx.h are never redistributed
# here.
#
# Usage:
#   ./fetch.sh            assemble if needed
#   ./fetch.sh --refetch  discard the cached tarball and assembled tree first
#
# Overridable: PROTON_COMMIT, BASELINE_DIGEST, WORK, TREE

set -eu

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)

PROTON_COMMIT=${PROTON_COMMIT:-164e0ccd2ea2b1ec2e5d08dc97f65b184c2539ca}

# sha256 over the extracted tree: for each path in sorted order, the sha256 of the
# path then the sha256 of the contents. This pins content, not the archive, because
# codeload regenerates the tarball and the gzip framing moves. It also means a
# force-push that orphans the commit is caught as a mismatch instead of silently
# building against whatever the branch holds now.
BASELINE_DIGEST=${BASELINE_DIGEST:-b286df1df46a70d9e2cc674676afcc6e08b1a56ce472e5add0932b86940657bf}

WORK=${WORK:-$repo/scratch/proton-lsc}
TREE=${TREE:-$repo/build/lsteamclient}

# Laid over Valve's tree, in this order, by the loop at the end.
authored="steamclient_main.c
unix_steam_input_manual.cpp
unixlib.cpp"

if [ "${1:-}" = "--refetch" ]; then
	rm -rf "$WORK" "$TREE"
elif [ $# -ne 0 ]; then
	echo "==> unknown argument $1" >&2
	exit 1
fi

tarball=$WORK/proton-$PROTON_COMMIT.tar.gz
base=$WORK/lsteamclient

if [ ! -d "$base" ]; then
	mkdir -p "$WORK"
	if [ ! -f "$tarball" ]; then
		echo "==> fetching Proton $PROTON_COMMIT"
		curl -fsSL -o "$tarball.part" \
			"https://codeload.github.com/ValveSoftware/Proton/tar.gz/$PROTON_COMMIT"
		mv "$tarball.part" "$tarball"
	fi
	echo "==> extracting lsteamclient"
	mkdir -p "$base.part"
	tar xzf "$tarball" -C "$base.part" --strip-components=2 "*/lsteamclient/"
	mv "$base.part" "$base"
fi

got=$(cd "$base" && python3 -c '
import hashlib, pathlib
root = pathlib.Path(".")
h = hashlib.sha256()
for p in sorted(q for q in root.rglob("*") if q.is_file()):
    h.update(hashlib.sha256(str(p.relative_to(root)).encode()).digest())
    h.update(hashlib.sha256(p.read_bytes()).digest())
print(h.hexdigest())
')

if [ "$got" != "$BASELINE_DIGEST" ]; then
	echo "==> baseline digest mismatch for Proton $PROTON_COMMIT" >&2
	echo "    expected $BASELINE_DIGEST" >&2
	echo "    got      $got" >&2
	echo "    the cached tree is not the pinned commit. ./fetch.sh --refetch to discard it." >&2
	exit 1
fi

count=$(find "$base" -type f | wc -l | tr -d ' ')
echo "==> baseline verified: Proton $PROTON_COMMIT, $count files"

# Rebuilt from the baseline each time so a removed authored file cannot leave a stale
# copy behind, and so the overlay below is always the only divergence.
rm -rf "$TREE"
mkdir -p "$(dirname "$TREE")"
cp -c -R "$base" "$TREE" 2>/dev/null || cp -R "$base" "$TREE"

echo "$authored" | while IFS= read -r f; do
	[ -n "$f" ] || continue
	[ -f "$here/$f" ] || { echo "==> authored file missing: $f" >&2; exit 1; }
	[ -f "$TREE/$f" ] || { echo "==> $f is not in Valve's tree, so it is not an overlay" >&2; exit 1; }
	cp -f "$here/$f" "$TREE/$f"
done

echo "==> assembled $TREE with $(echo "$authored" | LC_ALL=C grep -c .) authored files over it"
