#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
# - env TARGET: path to target work dir
# - env MAGMA: path to Magma support files
# - env OUT: path to directory where artifacts are stored
# - env CFLAGS and CXXFLAGS must be set to link against Magma instrumentation
##

aflgo_patch_file="$FUZZER/src/aflgo.patch"

# preprocess
(
    echo "TARGET $(basename $TARGET)"

    case "$(basename $TARGET)" in
    # openssl https://github.com/aflgo/aflgo/issues/12
    "openssl")  
        if [ -f "$aflgo_patch_file" ]; then
            patch -p1 -d "$FUZZER/repo" <"$aflgo_patch_file"
            echo "Fuzzing patch file $aflgo_patch_file applied."
            "$FUZZER/build.sh"
        fi
    ;;
    # sqlite3 fix a bug in clang 4
    "sqlite3")
        sed -i -e '/".\/sqlite3.o"/s|"./sqlite3.o"||' -e '/\$LDFLAGS/s|\$LDFLAGS|& .libs\/libsqlite3.a|' "$TARGET/build.sh"
    ;;
    # php ignore build error for the first round since clang/llvm 4 not compatible
    "php")  
        sed -i '/^popd$/{n;n;s/make -j$(nproc)/make -i -j$(nproc)/}' "$TARGET/build.sh"
        sed -i 's|cp sapi/fuzzer/\$fuzzerName "\$OUT/\${fuzzerName/php-fuzz-/}"|cp -f sapi/fuzzer/"\$fuzzerName" "\$OUT/\${fuzzerName/php-fuzz-/}" 2>/dev/null \|\| true|' "$TARGET/build.sh"
    ;;

    esac
)

export AFLGO=$FUZZER/repo

mkdir -p $OUT/temp
export TMP_DIR=$OUT/temp

export CC=$AFLGO/afl-clang-fast
export CXX=$AFLGO/afl-clang-fast++

(
    echo "## Set Target"
    pushd $TARGET/repo
    echo "## Get Target"
    echo "targets"

    # Need starting position
    grep -nr MAGMA_LOG | cut -f1,2 -d':' | grep -v ".orig:" | grep -v "Binary file" >$TMP_DIR/real.txt

    cat $TMP_DIR/real.txt
    popd
)

export LDFLAGS="$LDFLAGS -lpthread"
export ADDITIONAL="-targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
# BBtargets
# real

export LIBS="$LIBS -l:afl_driver.o -lstdc++"

"$MAGMA/build.sh"

echo "## Build Target"
TEMP_CFLAGS=$CFLAGS
TEMP_CXXFLAGS=$CXXFLAGS

# set flags
case "$(basename $TARGET)" in
"openssl")
    export CONFIGURE_FLAGS="$ADDITIONAL"
    ;;
"lua")
    LDFLAGS="$LDFLAGS -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
    CFLAGS="$TEMP_CFLAGS $ADDITIONAL"
    CXXFLAGS="$TEMP_CXXFLAGS $ADDITIONAL"
    ;;
*)
    CFLAGS="$TEMP_CFLAGS $ADDITIONAL"
    CXXFLAGS="$TEMP_CXXFLAGS $ADDITIONAL"
    ;;
esac

"$TARGET/build.sh"

(
    pushd $TARGET/repo

    case "$(basename $TARGET)" in
    "libsndfile")
        cp ossfuzz/sndfile_fuzzer* $OUT/
        ;;
    "libtiff")
        cp tools/tiffcp* $OUT/
        ;;
    "libxml2")
        cp xmllint* $OUT/
        ;;
        "lua")
        cp lua* $OUT/
        ;;
    "openssl")
        fuzzers=$(find fuzz -executable -type f '!' -name \*.py '!' -name \*-test '!' -name \*.pl \( -name "asn1" -o -name "asn1parse" -o -name "bignum" -o -name "server" -o -name "client" -o -name "x509" \))
        for f in $fuzzers; do
            cp $f* $OUT/
        done
        ;;
    "php")
        # fuzzers="php-fuzz-exif php-fuzz-mbstring php-fuzz-unserialize php-fuzz-parser"
        fuzzers="php-fuzz-exif"  # Since our experiments only use exif. Feel free to set for different programs
        for f in $fuzzers; do
            for file in sapi/fuzzer/"$f"*; do
                dest_filename="${file##*/}"            # Remove directory path
                dest_filename="${dest_filename#php-fuzz-}"  # Remove prefix
                cp "$file" "$OUT/$dest_filename"
            done
        done
        ;;
    "poppler")
        cp "$TARGET/work/poppler/utils/"{pdfimages*,pdftoppm*} $OUT/
        ;;
    *)
        echo "$(basename $TARGET)"
        ;;
    esac
    popd
)

echo "## Generate Distance"
cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq >$TMP_DIR/BBnames2.txt && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
cat $TMP_DIR/BBcalls.txt | sort | uniq >$TMP_DIR/BBcalls2.txt && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt

$AFLGO/scripts/genDistance.sh $OUT $TMP_DIR

if [ "$(basename $TARGET)" == "openssl" ]; then
    echo "clean CONFIGURE_FLAGS"
    CONFIGURE_FLAGS="-distance=$TMP_DIR/distance.cfg.txt"
    CFLAGS="$TEMP_CFLAGS" CXXFLAGS="$TEMP_CXXFLAGS"
else
    CFLAGS="$TEMP_CFLAGS -distance=$TMP_DIR/distance.cfg.txt" CXXFLAGS="$TEMP_CXXFLAGS -distance=$TMP_DIR/distance.cfg.txt"
fi

"$TARGET/build.sh"

# NOTE: We pass $OUT directly to the target build.sh script, since the artifact
#       itself is the fuzz target. In the case of Angora, we might need to
#       replace $OUT by $OUT/fast and $OUT/track, for instance.
