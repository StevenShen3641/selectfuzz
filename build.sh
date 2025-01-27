#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

if [ ! -d "$FUZZER/repo" ]; then
    echo "fetch.sh must be executed first."
    exit 1
fi

aflgo_patch_file="$FUZZER/src/aflgo.patch"

# openssl
if [ "$(basename $TARGET)" == "openssl" ]; then
    echo "TARGET openssl"
    if [ -f "$aflgo_patch_file" ]; then
        patch -p1 -d "$FUZZER/repo" < "$aflgo_patch_file"
        echo "Fuzzing patch file $aflgo_patch_file applied."
    fi
	
fi

cd "$FUZZER/repo"
CC=clang make clean all -j $(nproc)
# error message "recipe for target 'test_build' failed" can be ignored.
CC=clang make clean all -j $(nproc) -i -C llvm_mode 

# compile afl_driver.cpp
"./afl-clang-fast++" $CXXFLAGS -std=c++11 -c "afl_driver.cpp" -fPIC -o "$OUT/afl_driver.o"
