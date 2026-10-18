# libheif emscripten

[![Build Status](https://img.shields.io/github/actions/workflow/status/catdad-experiments/libheif-emscripten/emscripten.yml?branch=master&logo=github)](https://github.com/catdad-experiments/libheif-emscripten/actions/workflows/emscripten.yml)

This repo provides a JavaScript compiled (emscripten) version of [libheif](https://github.com/strukturag/libheif). The library is pinned as a submodule; the build applies the narrow recipe patch in `patches/libde265-cmake.patch` before running its original CI scripts. The patch updates the HEVC dependency build without changing the JavaScript decoder wrapper. You can get the compiled version from the [releases](https://github.com/catdad-experiments/libheif-emscripten/releases) page.

If you have found your way here while looking for a `libheif` version that you can install from `npm`, you are in the wrong place. Take a look at [`libheif-js`](https://github.com/catdad-experiments/libheif-js) instead.

Refer to the [original license](https://github.com/strukturag/libheif#license) for licensing information.

## HEVC dependency maintenance

This candidate advances the source to libheif1.23.6 and libde2651.1.3. The codec removed autotools; its static library and generated version header must be built and installed with CMake before libheif discovers them. The recipe verifies the codec release archive, disables decoder executables/encoder/SIMD tools, and retains the existing unthreaded HEVC build and fixed-RGBA `HeifDecoder`/`HeifImage.display` API. Optional codecs are not part of this candidate.

The producer's Emscripten3.1.61 toolchain and JS/WASM packaging remain unchanged. On a clean Linux checkout, initialize the submodule and apply the build patch once before following the workflow's existing build steps:

```sh
git submodule update --init
git -C libheif apply --check ../patches/libde265-cmake.patch
git -C libheif apply ../patches/libde265-cmake.patch
```

Qualification is pending a bounded Linux/Emscripten build: both library banners, actual fixed-RGBA pixel decode of the existing public sample, decoder-only/static/unthreaded build profile, and hashes of the complete generated JS/WASM assets. This source candidate is not a published replacement for `libheif-js` until a maintained release and consuming-wrapper validation exist.
