# Building for HarmonyOS

## Prerequisites

- [Qt for HarmonyOS](https://doc.qt.io/qt-6/harmonyos.html) 6.12.1 or newer
- CMake 3.25 or newer
- Either of these, both including the HarmonyOS SDK (API 23 or newer):
  - DevEco Studio
  - [Command Line Tools](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-commandline-get), plus a JDK

Only tested on a Windows host so far.

With the Command Line Tools, set `OHOS_SDK_ROOT` to the HarmonyOS SDK's
`default/openharmony` directory.

## Build

```sh
cmake --preset ohos
cmake --build --preset ohos
```

Output: unsigned HAP `entry-default-unsigned.hap`, in `build-ohos/harmonyos-build/entry/build/default/outputs/default/`.

## Signing

Recommended: open `build-ohos/harmonyos-build/` in DevEco Studio, then Signing Configs → Automatically generate signature. A Huawei developer account is required.

Alternatively sign the HAP with `hap-sign-tool.jar` from the SDK's `toolchains/lib`.

Every build regenerates `build-profile.json5`, which clears the signing configuration.
