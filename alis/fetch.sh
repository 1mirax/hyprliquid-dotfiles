#!/usr/bin/env bash
# Fetch alis and drop this repository's configuration on top of it.
#
#   cd alis && ./fetch.sh && ./alis.sh
#
# alis is not a single file: alis.sh sources alis-commons.sh and calls into
# alis-packages.sh, configs/ and files/. Downloading alis.sh alone gets you
# "no such file: alis-commons.sh" one line into the run, which is what
# happened before this script existed.
#
# Upstream's own download.sh pulls the whole tree - and brings its own
# alis.conf and alis-packages.conf with it, which would quietly replace ours.
# So the order matters: fetch first, copy ours over second, and say which
# files were replaced.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRANCH="${1:-main}"

for cmd in curl bsdtar; do
    command -v "$cmd" >/dev/null || {
        echo "missing: $cmd  (the Arch live image has both)" >&2; exit 1; }
done

echo "==> Downloading alis ($BRANCH)"
cd "$HERE"
curl -sL -o "alis-$BRANCH.zip" \
     "https://github.com/picodotdev/alis/archive/refs/heads/$BRANCH.zip"
bsdtar -x -f "alis-$BRANCH.zip"
cp -R "alis-$BRANCH"/*.sh "alis-$BRANCH"/files/ "alis-$BRANCH"/configs/ ./
# alis-commons.conf is machinery, not configuration to edit - alis-commons.sh
# sources it by name and stops without it, the same way it stops without
# alis-commons.sh. Every upstream .conf comes across EXCEPT the two this
# repository owns, which is the whole point of not running upstream's
# download.sh.
for f in "alis-$BRANCH"/*.conf; do
    case "${f##*/}" in
        alis.conf|alis-packages.conf) continue ;;
        *) cp "$f" ./ ;;
    esac
done
rm -rf "alis-$BRANCH" "alis-$BRANCH.zip"
chmod +x ./*.sh configs/*.sh

echo "==> Keeping this repository's configuration"
git -C "$HERE" checkout -- alis.conf alis-packages.conf 2>/dev/null || true
echo "    alis.conf             $(grep -c . alis.conf) lines"
echo "    alis-packages.conf    $(grep -c . alis-packages.conf) lines"

echo
echo "Check the target disk before running anything:"
echo
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS 2>/dev/null || lsblk
echo
grep -n '^DEVICE=' alis.conf
echo
echo "If that is the disk you mean:  ./alis.sh"
