#!/bin/sh
# Generate divvun-runtime.pc with an absolute prefix pointing at ../
# (where libdivvun_runtime.a and divvun_runtime.h live).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
PREFIX="$(cd "$HERE/.." && pwd)"
sed "s|@PREFIX@|$PREFIX|g" "$HERE/divvun-runtime.pc.in" > "$HERE/divvun-runtime.pc"
