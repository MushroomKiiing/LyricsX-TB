# 构建 LyricsX TB

需要 macOS 26 SDK、Swift 6.2 或兼容版本、Command Line Tools / Xcode、Python 3。测试中的 Flexbar 互操作用例还需要 Node.js（本项目不打包 Node）。依赖版本由 Package.resolved 固定。

```sh
git clone https://github.com/MushroomKiiing/LyricsX-TB.git
cd LyricsX-TB/app
python3 scripts/update-settings-search.py --check
swift test --no-parallel
LYRICSX_ARCHS=arm64 scripts/build.sh release
```

如需指定 SDK，可设置 `LYRICSX_SDK=/absolute/path/MacOSX26.5.sdk`。新工具链运行 Swift Testing 时如提示找不到宏插件，可参照该工具链的 Testing 插件路径传入 `-Xswiftc -load-plugin-library -Xswiftc /absolute/path/libTestingMacros.dylib`；不要把某台机器的路径当成所有环境通用值。

从仓库根目录看，产物为 `app/build/LyricsX TB.app`。旧的发布标签保留当时的目录布局。`LYRICSX_BUILD_PATH` 可指定独立 scratch 路径，`LYRICSX_SIGN_IDENTITY` 指定签名身份；本次发布使用 ad-hoc，未公证。当前安装包面向 macOS 26 或更新系统的 Apple 芯片 Mac。

图标保留上游的 Resources/Icon.iconset 音符资源，由构建脚本打包。Touch Bar 使用系统非公开桥接，网易云读取也依赖系统/客户端实现，因此系统升级可能影响兼容性。请阅读对应 Release 的测试记录和已知限制。
