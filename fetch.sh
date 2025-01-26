#!/bin/bash
set -e

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

git clone --no-checkout https://github.com/cuhk-seclab/SelectFuzz.git "$FUZZER/repo"
git -C "$FUZZER/repo" checkout 1f1b5c53de6e85400c5317ac2c1984aea7d20f65
#wget -O "$FUZZER/repo/afl_driver.cpp" \
#    "https://cs.chromium.org/codesearch/f/chromium/src/third_party/libFuzzer/src/afl/afl_driver.cpp"
cp "$FUZZER/src/afl_driver.cpp" "$FUZZER/repo/afl_driver.cpp"
cp "$FUZZER/src/genDistance.sh" "$FUZZER/repo/scripts/genDistance.sh"

