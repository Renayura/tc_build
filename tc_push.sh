#!/usr/bin/env bash

# Function to show an informational message
msg() {
	echo -e "\e[1;32m$*\e[0m"
}

tgm "🚀 <b>Prepare to push clang to github release</b>"

# Set a directory
DIR="$(pwd)"

# Build Info
rel_date="$(date "+%Y%m%d")"              # ISO 8601 format
rel_friendly_date="$(date "+%B %-d, %Y")" # "Month day, year" format

# Release Info
pushd llvm-project || exit
llvm_commit="$(git rev-parse HEAD)"
short_llvm_commit="$(cut -c-8 <<<"$llvm_commit")"
popd || exit

llvm_commit_url="https://github.com/llvm/llvm-project/commit/$short_llvm_commit"
binutils_ver="$(ls | grep "^binutils-" | sed "s/binutils-//g")"
clang_version="$(install/bin/clang --version | head -n1 | cut -d' ' -f4)"
tags_date="$(TZ=Asia/Jakarta date +"%Y%m%d")"
build_date="$(TZ=Asia/Jakarta date +"%Y-%m-%d")"
build_hours="$(TZ=Asia/Jakarta date +"%H%M")"
zip_name="fortune-clang-$clang_version-$tags_date-$build_hours.tar.gz"
tags="fortune-clang-$clang_version-$tags_date-release"
clang_link="https://github.com/Renayura/fortune-clang/releases/download/${tags}/${zip_name}"

# Git Config
git config --global user.name "Renayura"
git config --global user.email "renayura@proton.me"

pushd install || exit
{
	echo "# Quick Info
* Build completed on: $build_date
* LLVM commit: $llvm_commit_url
* Clang Version: $clang_version
* Binutils Version: $binutils_ver
* Builder at commit: https://github.com/Renayura/tc_build/commit/$builder_commit
* Release: https://github.com/Renayura/fortune-clang/releases/tag/${tags}"
} >>README.md
tar -czvf ../"$zip_name" .
popd || exit

# Clone Repo
git clone "https://Renayura:$GH_TOKEN@github.com/Renayura/fortune-clang.git" rel_repo
pushd rel_repo || exit
echo "${clang_link}" >"$clang_version"/clang-link.txt
echo "${build_date}" >"$clang_version"/build-date.txt
git add .
git commit -asm "fortune-clang: Add Fortune Clang build ${tags_date}

* Build completed on: $build_date
* LLVM commit: $llvm_commit_url
* Clang Version: $clang_version
* Binutils Version: $binutils_ver
* Builder at commit: https://github.com/Renayura/tc_build/commit/$builder_commit
* Release: https://github.com/Renayura/fortune-clang/releases/tag/${tags}"
git tag "${tags}" -m "${tags}"
git push -f origin main
git push -f origin "${tags}"
popd || exit

chmod +x github-release
./github-release release \
	--security-token "$GH_TOKEN" \
	--user Renayura \
	--repo fortune-clang \
	--tag "${tags}" \
	--name "${tags}" \
	--description "$(cat install/README.md)"

fail="n"
./github-release upload \
	--security-token "$GH_TOKEN" \
	--user Renayura \
	--repo fortune-clang \
	--tag "${tags}" \
	--name "$zip_name" \
	--file "$zip_name" || fail="y"

TotalTry="0"
UploadAgain() {
	GetRelease="$(./github-release upload \
		--security-token "$GH_TOKEN" \
		--user Renayura \
		--repo fortune-clang \
		--tag "${tags}" \
		--name "$zip_name" \
		--file "$zip_name")"
	[[ -z "$GetRelease" ]] && fail="n"
	[[ "$GetRelease" == *"already_exists"* ]] && fail="n"
	TotalTry=$((TotalTry + 1))
	if [ "$fail" == "y" ]; then
		if [ "$TotalTry" != "5" ]; then
			sleep 10s
			UploadAgain
		fi
	fi
}
if [ "$fail" == "y" ]; then
	sleep 10s
	UploadAgain
fi

if [ "$fail" == "y" ]; then
	pushd rel_repo || exit
	git push -d origin "${tags}"
	git reset --hard HEAD~1
	git push -f origin main
	popd || exit
fi

# Send message to telegram
tgf "build.log" "<b>🚀 Fortune Toochain Have Been Successfully..."
tgm "
<b>--------------------------------------------------</b>
<b>Build Date : </b>
* <code>$build_date</code>
<b>Clang Version : </b>
* <code>$clang_version</code>
<b>Binutils Version : </b>
* <code>$binutils_ver</code>
<b>Compile Based : </b>
* <a href='$llvm_commit_url'>$llvm_commit_url</a>
<b>Push Repository : </b>
* <a href='https://github.com/Renayura/fortune-clang.git'>fortune-clang</a>
<b>--------------------------------------------------</b>
"
