#!/usr/bin/env bash
# PREPARED ONLY: fixed pure producer compilation; no decoder, --emit-tsd or tests.
set -euo pipefail
umask 077
[[ $# == 1 && ( "$1" == wasm || "$1" == js ) ]]
HEVC_TARGET="$1"
: "${GITHUB_WORKSPACE:?}" "${GITHUB_SHA:?}" "${GITHUB_RUN_ID:?}" "${GITHUB_RUN_ATTEMPT:?}"
[[ "$GITHUB_RUN_ATTEMPT" == 1 && "$GITHUB_SHA" =~ ^[0-9a-f]{40}$ && "$GITHUB_RUN_ID" =~ ^[0-9]+$ ]]
[[ "${GITHUB_REPOSITORY:-}" == dakshbhatia/libheif-emscripten ]]
[[ "${GITHUB_REF:-}" == refs/heads/codex/hevc-hosted-compile-once-20261018 ]]
[[ "$(uname -m)" == x86_64 && "${EMSDK:-}" == /emsdk ]]
HEVC_SOURCE="$GITHUB_WORKSPACE/producer/libheif"
HEVC_BUILD="$GITHUB_WORKSPACE/hevc-private-build"
HEVC_OUT="$GITHUB_WORKSPACE/hevc-compile-out"
mkdir -p "$HEVC_OUT/logs"
hevc_status() {
  local code=$?
  trap - EXIT
  printf '{"target":"%s","exitCode":%s,"terminal":true,"compiledOnly":true,"qualified":false,"finishedAt":"%s"}\n' \
    "$HEVC_TARGET" "$code" "$(date -u +%FT%TZ)" > "$HEVC_OUT/logs/status-$HEVC_TARGET.json"
  (cd "$HEVC_OUT/logs" && find . -maxdepth 1 -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
  exit "$code"
}
trap hevc_status EXIT
exec > >(tee "$HEVC_OUT/logs/build-$HEVC_TARGET.log") 2>&1
[[ "$(git -C "$GITHUB_WORKSPACE/workflow-source" rev-parse HEAD)" == "$GITHUB_SHA" ]]
# Execution ref must not carry the release-capable historical workflow or extra workflows.
[[ ! -e "$GITHUB_WORKSPACE/workflow-source/.github/workflows/emscripten.yml" ]]
[[ "$(find "$GITHUB_WORKSPACE/workflow-source/.github/workflows" -maxdepth 1 -type f | wc -l)" -eq 1 ]]
[[ "$(git -C "$GITHUB_WORKSPACE/producer" rev-parse HEAD)" == ace8640ccf02de95ec4998d591b78649278d99b0 ]]
[[ "$(git -C "$HEVC_SOURCE" rev-parse HEAD)" == f81f28ac014b1c28dee483ac45b72c6b05bc421a ]]
printf '%s  %s\n' b6a06802e78cc885b249febb46622efae4e381a2f5a229743e26157d3bc87c4c \
  "$GITHUB_WORKSPACE/producer/patches/libde265-cmake.patch" | sha256sum --check --strict -
if [[ "$HEVC_TARGET" == wasm ]]; then
  [[ ! -e "$HEVC_BUILD" && ! -e "$HEVC_OUT/wasm" && ! -e "$HEVC_OUT/js" ]]
  git -C "$HEVC_SOURCE" apply --check ../patches/libde265-cmake.patch
  git -C "$HEVC_SOURCE" apply ../patches/libde265-cmake.patch
  mkdir "$HEVC_BUILD"
else
  [[ -d "$HEVC_BUILD" && -f "$HEVC_OUT/wasm/target.json" && ! -e "$HEVC_OUT/js" ]]
fi
printf '%s  %s\n' 9384ec1ac7b7bc36fca8d32cf5b16e648bf39453435fa28b42ff63ce21d05446 \
  "$HEVC_SOURCE/build-emscripten.sh" 67b6f172bae9e4aebdae6de6409aede29fbeb829acfd656670e8ddd22d577c5d \
  "$HEVC_SOURCE/post.js" | sha256sum --check --strict -
export CORES=4 EMCC_CORES=4 CMAKE_BUILD_PARALLEL_LEVEL=4 CMAKE_GENERATOR='Unix Makefiles'
export ENABLE_LIBDE265=1 LIBDE265_VERSION=1.1.3
export LIBDE265_SHA256=554228bd17788c99a7e63b37ab5634722190e6e2bf60c1dcb01cef328e133905
export ENABLE_AOM=0 ENABLE_WEBCODECS=0 ENABLE_UNCOMPRESSED=0 ENABLE_OPENJPEG=0
export STANDALONE=0 DEBUG=0 USE_ES6=0 USE_TYPESCRIPT=0 USE_UNSAFE_EVAL=0
export USE_WASM=1
[[ "$HEVC_TARGET" == wasm ]] || export USE_WASM=0
cd "$HEVC_BUILD"
# CMake/static inputs are identical between calls. Only the maintained final link reads USE_WASM.
bash "$HEVC_SOURCE/build-emscripten.sh" "$HEVC_SOURCE" 2>&1 | tee "$HEVC_OUT/logs/leaf-$HEVC_TARGET.log"
[[ ! -e libheif.d.ts ]]
HEVC_PAYLOAD="$HEVC_OUT/$HEVC_TARGET"
mkdir "$HEVC_PAYLOAD"
cp libheif.js libheif/libheif.a "$HEVC_PAYLOAD/"
[[ "$HEVC_TARGET" != wasm ]] || cp libheif.wasm "$HEVC_PAYLOAD/"
cp libde265-1.1.3/build-emscripten/install/lib/libde265.a "$HEVC_PAYLOAD/"
cp "$HEVC_SOURCE/post.js" "$HEVC_PAYLOAD/"
cp "$HEVC_SOURCE/COPYING" "$HEVC_PAYLOAD/LICENSE"
cp libde265-1.1.3/COPYING "$HEVC_PAYLOAD/libde265.COPYING"
cp CMakeCache.txt "$HEVC_PAYLOAD/heif-CMakeCache.txt"
cp libde265-1.1.3/build-emscripten/CMakeCache.txt "$HEVC_PAYLOAD/de265-CMakeCache.txt"
cp libde265-1.1.3/build-emscripten/libde265/CMakeFiles/de265.dir/flags.make "$HEVC_PAYLOAD/de265-flags.make"
cp libde265-1.1.3/build-emscripten/install/include/libde265/de265-version.h "$HEVC_PAYLOAD/"
"$EMSDK/upstream/bin/llvm-nm" libheif/libheif.a --format=just-symbols | grep '^heif_\|^de265_\|^aom_' \
  | grep '[^:]$' | sed 's/^/_/' | paste -sd ',' - > "$HEVC_PAYLOAD/exported-functions.txt"
(cd "$EMSDK" && sha256sum upstream/bin/clang upstream/bin/llvm-nm upstream/bin/wasm-ld \
  upstream/bin/wasm-opt upstream/emscripten/emcc.py upstream/emscripten/tools/link.py) > "$HEVC_PAYLOAD/sdk-link-tools.sha256"
for HEVC_TOOL in clang llvm-nm wasm-ld wasm-opt; do
  "$EMSDK/upstream/bin/$HEVC_TOOL" --version | sed '/^InstalledDir: /d'
done > "$HEVC_PAYLOAD/native-tool-versions.txt"
emcc --version > "$HEVC_PAYLOAD/emcc-version.txt"
grep -F '3.1.61' "$HEVC_PAYLOAD/emcc-version.txt" >/dev/null
cmake --version > "$HEVC_PAYLOAD/cmake-version.txt"
make --version > "$HEVC_PAYLOAD/make-version.txt"
# This is the SDK image's actual CMake, NOT the earlier CMake3.31.12 bootstrap.
python3 - "$HEVC_PAYLOAD" "$HEVC_TARGET" <<'PY'
import hashlib, json, os, pathlib, sys
p, target = pathlib.Path(sys.argv[1]), sys.argv[2]
hashfile = lambda name: hashlib.sha256((p / name).read_bytes()).hexdigest()
archives = {n: hashfile(n) for n in ('libheif.a', 'libde265.a')}
reuse = None
if target == 'js':
    first = json.loads((p.parent / 'wasm/target.json').read_text())
    reuse = archives == first['staticArchives']
    # Different archives are retained honestly, not silently substituted or called reused.
meta = dict(target=target, stage='raw_compiled_no_declarations', completed=True,
            terminal=False, qualified=False, fullPackageQualified=False, installedAlfredQualified=False,
            producerHead='ace8640ccf02de95ec4998d591b78649278d99b0',
            libheifHead='f81f28ac014b1c28dee483ac45b72c6b05bc421a',
            patchSha256='b6a06802e78cc885b249febb46622efae4e381a2f5a229743e26157d3bc87c4c',
            patchedLeafSha256='9384ec1ac7b7bc36fca8d32cf5b16e648bf39453435fa28b42ff63ce21d05446',
            image='emscripten/emsdk:3.1.61@sha256:30aa9fed39cc7810cc4338c77828bd513a6ee6b60c6b141bc6d9760aea5791e3',
            workflowCommit=os.environ['GITHUB_SHA'], runId=os.environ['GITHUB_RUN_ID'], runAttempt=1,
            staticArchives=archives, archiveHashesEqualFirstTarget=reuse,
            profile=dict(HEIF='1.23.6', libde265='1.1.3', HEVCOnly=True, unthreaded=True,
                         shared=False, buildTesting=False, unsafeEval=False, typescript=False),
            actualCmake=(p/'cmake-version.txt').read_text().splitlines()[0],
            actualMake=(p/'make-version.txt').read_text().splitlines()[0])
(p/'target.json').write_text(json.dumps(meta, indent=2)+'\n')
PY
cp "$HEVC_OUT/logs/leaf-$HEVC_TARGET.log" "$HEVC_PAYLOAD/build.log"
(cd "$HEVC_PAYLOAD" && find . -maxdepth 1 -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
printf 'HEVC_RAW_TARGET_COMPLETED target=%s qualified=false\n' "$HEVC_TARGET"
