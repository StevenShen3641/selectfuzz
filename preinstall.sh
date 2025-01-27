#!/bin/bash
set -ex

apt-get update &&
    apt-get install -y sudo autoconf automake build-essential libtool cmake git software-properties-common gperf libselinux1-dev bison texinfo flex \
    zlib1g-dev libexpat1-dev libmpg123-dev python3-pip unzip pkg-config clang llvm-dev curl wget make ninja-build subversion binutils-gold binutils-dev \
    python3 python3-dev python3-pip libtool-bin python-bs4 libclang-4.0-dev gawk

python3 -m pip install --upgrade pip

python3 -m pip install networkx pydot pydotplus

# llvm 4.0
mkdir -p /build 
cd /build 
wget http://releases.llvm.org/4.0.0/llvm-4.0.0.src.tar.xz \
    http://releases.llvm.org/4.0.0/cfe-4.0.0.src.tar.xz \
    http://releases.llvm.org/4.0.0/compiler-rt-4.0.0.src.tar.xz \
    http://releases.llvm.org/4.0.0/libcxx-4.0.0.src.tar.xz \
    http://releases.llvm.org/4.0.0/libcxxabi-4.0.0.src.tar.xz 
tar xf llvm-4.0.0.src.tar.xz 
tar xf cfe-4.0.0.src.tar.xz 
tar xf compiler-rt-4.0.0.src.tar.xz 
tar xf libcxx-4.0.0.src.tar.xz 
tar xf libcxxabi-4.0.0.src.tar.xz 
rm *.tar.xz 
mv cfe-4.0.0.src /build/llvm-4.0.0.src/tools/clang 
mv compiler-rt-4.0.0.src /build/llvm-4.0.0.src/projects/compiler-rt 
mv libcxx-4.0.0.src /build/llvm-4.0.0.src/projects/libcxx 
mv libcxxabi-4.0.0.src /build/llvm-4.0.0.src/projects/libcxxabi 

# link xlocale
ln -s /usr/include/locale.h /usr/include/xlocale.h

sed -i '/struct sigaltstack;/d' /build/llvm-4.0.0.src/projects/compiler-rt/lib/sanitizer_common/sanitizer_linux.h
sed -i 's/uptr internal_sigaltstack(const struct sigaltstack\* ss,/uptr internal_sigaltstack(const void\* ss,/' /build/llvm-4.0.0.src/projects/compiler-rt/lib/sanitizer_common/sanitizer_linux.h
sed -i 's/struct sigaltstack\* oss);/void\* oss);/' /build/llvm-4.0.0.src/projects/compiler-rt/lib/sanitizer_common/sanitizer_linux.h
sed -i 's/uptr internal_sigaltstack(const struct sigaltstack \*ss,/uptr internal_sigaltstack(const void \*ss,/' /build/llvm-4.0.0.src/projects/compiler-rt/lib/sanitizer_common/sanitizer_linux.cc
sed -i 's/struct sigaltstack \*oss) {/void \*oss) {/' /build/llvm-4.0.0.src/projects/compiler-rt/lib/sanitizer_common/sanitizer_linux.cc
sed -i 's/struct sigaltstack handler_stack;/stack_t handler_stack;/' /build/llvm-4.0.0.src/projects/compiler-rt/lib/sanitizer_common/sanitizer_stoptheworld_linux_libcdep.cc
sed -i 's/struct sigaltstack handler_stack;/stack_t handler_stack;/' /build/llvm-4.0.0.src/projects/compiler-rt/lib/sanitizer_common/sanitizer_stoptheworld_linux_libcdep.cc
sed -i 's/__res_state \*statp = (__res_state\*)state;/struct __res_state \*statp = (struct __res_state\*)state;/' /build/llvm-4.0.0.src/projects/compiler-rt/lib/tsan/rtl/tsan_platform_linux.cc
sed -i 's/struct sigaltstack SigAltStack;/stack_t SigAltStack;/' /build/llvm-4.0.0.src/projects/compiler-rt/lib/esan/esan_sideline_linux.cpp

mkdir -p build-llvm/llvm; cd build-llvm/llvm 
cmake -G "Ninja" \
      -DLIBCXX_ENABLE_SHARED=OFF \
      -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLVM_TARGETS_TO_BUILD="X86" \
      -DLLVM_BINUTILS_INCDIR=/usr/include \
      /build/llvm-4.0.0.src

ninja 
ninja install 
mkdir -p /usr/lib/bfd-plugins 
cp /usr/local/lib/libLTO.so /usr/lib/bfd-plugins 
cp /usr/local/lib/LLVMgold.so /usr/lib/bfd-plugins

mkdir -p /build/build-llvm/msan 
cd /build/build-llvm/msan 
cmake -G "Ninja" -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++  \
     -DLLVM_USE_SANITIZER=Memory -DCMAKE_INSTALL_PREFIX=/usr/msan/ \
           -DLIBCXX_ENABLE_SHARED=OFF -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON  \
                -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD="X86"  \
           /build/llvm-4.0.0.src 
ninja cxx
ninja install-cxx    
