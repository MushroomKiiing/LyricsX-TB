# 构建 LyricsX TB

需要 macOS 26 SDK、Swift 6.2 或兼容版本、Command Line Tools / Xcode、Python 3。测试中的 Flexbar 互操作用例还需要 Node.js（本项目不打包 Node）。依赖版本由 Package.resolved 固定。

```sh
git clone https://github.com/MushroomKiiing/LyricsX-TB.git
cd LyricsX-TB/app
python3 scripts/update-settings-search.py --check
swift test --no-parallel
LYRICSX_ARCHS=universal scripts/build.sh release
```

如需指定 SDK，可设置 `LYRICSX_SDK=/absolute/path/MacOSX26.5.sdk`。新工具链运行 Swift Testing 时如提示找不到宏插件，可参照该工具链的 Testing 插件路径传入 `-Xswiftc -load-plugin-library -Xswiftc /absolute/path/libTestingMacros.dylib`；不要把某台机器的路径当成所有环境通用值。

从仓库根目录看，产物为 `app/build/LyricsX TB.app`。旧的发布标签保留当时的目录布局。`LYRICSX_BUILD_PATH` 可指定独立 scratch 路径，`LYRICSX_SIGN_IDENTITY` 指定签名身份；本次发布使用 ad-hoc，未公证。通用包包含 arm64 和 x86_64；Intel 实机验证另计。

图标保留上游的 Resources/Icon.iconset 音符资源，由构建脚本打包。Touch Bar 使用系统非公开桥接，网易云读取也依赖系统/客户端实现，因此系统升级可能影响兼容性。请阅读对应 Release 的测试记录和已知限制。

## TB.6 兼容试用包

在 TB.6 源码上运行 `LYRICSX_ARCHS=universal scripts/build.sh release` 可构建面向 macOS 15 及更新系统的通用包。建议使用保留 Intel Swift 支持的工具链。如果较新的 Apple 芯片工具链缺少旧版 Intel Swift 兼容库，可在构建 TB.6 时加上 `LYRICSX_SKIP_PRE_SEQUOIA_RUNTIME_SHIMS=1`，改用系统自带的 Swift 运行时。此选项必须配合 macOS 15 或更新的最低目标使用；不能据此将最低系统继续下调。通过签名和架构检查之后，仍要在 macOS 15 的实体 MacBook Pro 上验证 Touch Bar。
