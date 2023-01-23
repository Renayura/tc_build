#!/usr/bin/env bash

# Function to show an informational message
msg() {
	echo -e "\e[1;32m$*\e[0m"
}

# Set a directory
DIR="$(pwd)"

# Telegram Setup
git clone --depth=1 https://github.com/fabianonline/telegram.sh Telegram

TELEGRAM="$(pwd)/Telegram/telegram"
tgm() {
	"${TELEGRAM}" -H -D \
		"$(
			for POST in "${@}"; do
				echo "${POST}"
			done
		)"
}

tgf() {
	"${TELEGRAM}" -H \
		-f "$1" \
		"$2"
}

# Build Info
rel_date="$(date "+%Y%m%d")"              # ISO 8601 format
rel_friendly_date="$(date "+%B %-d, %Y")" # "Month day, year" format
builder_commit="$(git rev-parse HEAD)"

# Send a notificaton to TG
tgm "<b>🔨 Fortune ToolChain Compilation Started</b>
<b>Date : </b><code>$rel_friendly_date</code>
<b>Toolchain Script Commit : </b><a href='https://github.com/Renayura/tc_build/commit/$builder_commit'> Check Here </a>"

# Build LLVM
msg "Building LLVM..."
tgm "<b>🔨 Progress Building LLVM. . .</b>
<b>Linker Used : </b><code>lld</code>"

BUILD_START=$(date +"%s")
LLVM_START=$(date +"%s")
./build-llvm.py \
	--clang-vendor "Fortune" \
	--defines "LLVM_PARALLEL_COMPILE_JOBS=$(nproc) LLVM_PARALLEL_LINK_JOBS=$(nproc) CMAKE_C_FLAGS=-O3 CMAKE_CXX_FLAGS=-O3" \
	--projects "clang;compiler-rt;lld;polly" \
	--targets "ARM;AArch64;X86" \
	--no-ccache \
	--quiet-cmake \
	--shallow-clone 2>&1 | tee "build.loog"

LLVM_END=$(date +"%s")
LLVM_DIFF=$(($LLVM_END - $LLVM_START))
tgm "<b> Building LLVM Successfully Completed </b>
<b>LLVM Build Time: </b><code>$((LLVM_DIFF / 60)) minute(s) $((LLVM_DIFF % 60)) second(s)</code>"

# Check if the final clang binary exists or not.
[ ! -f install/bin/clang-1* ] && {
	err "Building LLVM failed ! Kindly check errors !!"
	tgm "<b> LLVM Failed To Build </b>
<b>LLVM Build Error Time: </b><code>$((LLVM_DIFF / 60)) minute(s) $((LLVM_DIFF % 60)) second(s)</code>"
}

# Build binutils
msg "Building binutils..."
BIN_START=$(date +"%s")
tgm "<b>🔨 Progress Building Binutils. . .</b>"
./build-binutils.py --targets arm aarch64 x86_64
BIN_END=$(date +"%s")
BIN_DIFF=$(($BIN_END - $BIN_START))

tgm "<b> Building Binutils Successfully Completed </b>
<b>Binutils Build Time: </b><code>$((BIN_DIFF / 60)) minute(s) $((BIN_DIFF % 60)) second(s)</code>"

# Remove unused products
rm -fr install/include
rm -f install/lib/*.a install/lib/*.la

# Strip remaining products
for f in $(find install -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
	strip -s "${f::-1}"
done

# Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
for bin in $(find install -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
	# Remove last character from file output (':')
	bin="${bin::-1}"

	echo "$bin"
	patchelf --set-rpath "$DIR/install/lib" "$bin"
done

# Release Info
pushd llvm-project || exit
llvm_commit="$(git rev-parse HEAD)"
short_llvm_commit="$(cut -c-8 <<<"$llvm_commit")"
popd || exit

llvm_commit_url="https://github.com/llvm/llvm-project/commit/$short_llvm_commit"
binutils_ver="$(ls | grep "^binutils-" | sed "s/binutils-//g")"
clang_version="$(install/bin/clang --version | head -n1 | cut -d' ' -f4)"
BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))

tgm "✅ <b>The Fortune ToolChain Compilation Finished</b>
<b>Clang Version : </b><code>$clang_version</code>
<b>LLVM Commit : </b><a href='$llvm_commit_url'> Check Here </a>
<b>Binutils Version : </b><code>$binutils_ver</code>
<b>Fortune Build Time : </b><code>$((DIFF / 60)) minute(s) $((DIFF % 60)) second(s)</code>"

bash tc_push.sh
