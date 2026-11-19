# Building for HarmonyOS

## Prerequisites

- [Qt for HarmonyOS](https://doc.qt.io/qt-6/harmonyos.html) 6.12.1 or newer
- CMake 3.25 or newer
- Either of these, each including the HarmonyOS SDK (API 23 or newer):
  - [DevEco Studio](https://developer.huawei.com/consumer/en/deveco-studio/) (recommended)
  - [Command Line Tools](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-commandline-get), plus a JDK

Signing needs a Huawei developer account.

Only tested on a Windows host so far.

## Build

When building with the Command Line Tools rather than DevEco Studio, point
`OHOS_SDK_ROOT` at the SDK's `default/openharmony` directory, either in the
environment or with `-DOHOS_SDK_ROOT=<path>`.

```sh
cmake --preset ohos
cmake --build --preset ohos
```

Output: unsigned HAP `entry-default-unsigned.hap`, in `build-ohos/harmonyos-build/entry/build/default/outputs/default/`.

## Signing

Open `build-ohos/harmonyos-build/` in DevEco Studio, then Signing Configs →
Automatically generate signature. This writes `.sign/sign-config.json5` there.

Alternatively, sign with `hap-sign-tool` from the SDK's `toolchains/lib`.

With `.sign/sign-config.json5` in place, run

```sh
cmake --build --preset ohos
```

to get `entry-default-signed.hap`, next to the unsigned one.
