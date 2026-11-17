# LyricsX TB

面向 MacBook Pro Touch Bar 的非官方歌词定制版，基于 [LyricsX Next](https://github.com/wzk112/LyricsX-Next) 继续开发。与原作者、网易云音乐及 Apple 无隶属或背书关系。

当前预览版：**2.0.43-TB.5-preview.1 / build 279.8**。最低 macOS 26；本次安装包仅 Apple Silicon（arm64）。本机 M1 Touch Bar 已验证基本显示与切换，其他机器及最低系统尚待验证。安装包采用 ad-hoc 签名，未经 Apple 公证。

[下载预览版](https://github.com/MushroomKiiing/LyricsX-TB/releases/tag/v2.0.43-tb.5-preview.1) · [功能对比](docs/TB-COMPARISON.md) · [隐私说明](PRIVACY.md) · [许可与署名](COPYRIGHT.md) · [构建说明](docs/BUILD-TB.md)

## 功能

- 主程序统一控制后台 Touch Bar 歌词，无需独立助手或聊天软件。
- 普通模式保留左侧歌词和右侧系统控制条；全宽模式使用可用宽度。轻触歌词或两侧空白返回普通模式，可设置闲置 1–15 秒后恢复全宽。
- Touch Bar 使用白色常规字体；双语左右分栏，长句分别滚动。译文还受歌词总开关控制。
- 网易云专用播放状态读取，减少浏览器媒体抢占造成的误判和时间漂移。
- 可选高清封面匹配、可选随网易云启动，均需主动开启；设置写明各自的数据使用方式。
- 设置支持本地搜索，按常用设置、播放与显示、外观、其他分组，翻译与字体样式的作用范围明确。
- 保留上游主窗口、悬浮歌词、歌词搜索与同步等功能；歌词提供商可与当前播放器不同。

## 安装与使用

退出已有 LyricsX / LyricsX Next / 旧版 Touch Bar 助手，再将下载的 LyricsX TB.app 放入“应用程序”运行。沿用 `com.lyricsx.modern` 标识，因此会继续使用原有设置；请勿与同标识版本同时运行。

在“设置 → Touch Bar”开启歌词及所需后台/全宽选项，再在网易云播放歌曲。通常无需修改网易云设置。播放器识别失败时先检查“设置 → 播放器”的来源与连接状态；不要为此授予无关的屏幕录制权限。波形等上游可选功能另有其自身权限要求。

未公证的预览包可能被 macOS 阻止，请自行核对来源与校验值，并通过系统提供的正常安全确认流程处理；也可以从对应标签自行构建。

## 开源与来源

代码按 [MPL-2.0](LICENSE) 分发；依赖遵循各自许可。修改文件的对应源码在本仓库和各发布标签中提供。最初 LyricsX、MxIris 维护分支、LyricsX Next 及依赖作者的权利与署名保留，详见 [COPYRIGHT.md](COPYRIGHT.md) 与 [第三方许可](Resources/THIRD-PARTY-NOTICES.txt)。

基线提交：[`54561db8c06e1abfefbe7aa0f0c2bc26cff94eeb`](https://github.com/wzk112/LyricsX-Next/commit/54561db8c06e1abfefbe7aa0f0c2bc26cff94eeb)，属于上游 2.0.43 开发线，并非声称与 v2.0.43 标签完全相同。保留上游 Git 历史；原 README 另存于 [docs/UPSTREAM-README.md](docs/UPSTREAM-README.md)，其中下载链接和兼容性声明仅指上游。

本项目不附带商业歌曲音频、个人歌词缓存或用户截图。歌词及译文权利属于各自权利人，软件开源不代表获得这些内容的再分发许可。
