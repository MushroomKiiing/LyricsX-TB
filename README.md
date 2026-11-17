# LyricsX TB

<img src="Resources/Icon.iconset/icon_128x128.png" width="96" alt="LyricsX 音符图标">

基于 [LyricsX Next](https://github.com/wzk112/LyricsX-Next) 的非官方 Touch Bar 定制版，保留原音符图标。

[下载 TB.5](https://github.com/MushroomKiiing/LyricsX-TB/releases/tag/v2.0.43-tb.5)

## 相比 LyricsX Next 的改进

### Touch Bar

- **全宽显示**：增加固定全宽和闲置自动全宽；点歌词或两侧空白切回“左侧歌词＋右侧系统控制条”，等待时间可调 1–15 秒。
- **后台歌词**：将此前的独立助手整合进主程序，设置开关直接控制实际显示；切换其他应用仍可查看。
- **文字与翻译**：改为白色常规字体，原文与译文左右并列，长句独立滚动；全宽时利用完整可用区域。
- **显示稳定性**：修复试验中的黑条、显示区域过窄、空白无法点按和反复切换问题。

### 网易云与封面

- **播放同步**：增加网易云专用状态读取，减少浏览器媒体源干扰、误报“未播放”和进度漂移；暂停、跳转及歌词偏移跟随主程序。
- **高清封面**：增加可选的网易云高清封面匹配，不为此建立磁盘图片缓存；设置中说明查询数据与用途。

### 启动与隐私

- **随网易云启动**：增加独立开关，与登录启动分别控制；采用本机应用事件监听，不联网、不记录启动历史。
- **可选功能**：高清封面与随网易云启动均需主动开启，隐私说明统一呈现在对应设置中。

### 设置与界面

- **设置搜索**：增加本地搜索，结果可跳转并定位对应选项。
- **导航整理**：按常用、播放与显示、外观、其他分组；播放器、悬浮窗与 Touch Bar 放在一起，外观独立成页。
- **翻译控制**：明确主窗口总开关、悬浮窗“翻译与下一句”五种策略及 Touch Bar 译文开关的实际作用。
- **字体与颜色**：集中说明主窗口/悬浮窗的共用样式与 Touch Bar 固定白色样式，移除重复条目，栏目使用矢量图标。
- **文案与命名**：修正未落实或容易误解的说明，统一名称 LyricsX TB，保留原音符图标和上游署名。

## 使用

下载后将 LyricsX TB.app 放入“应用程序”，退出旧版后打开。在“设置 → Touch Bar”启用所需功能即可。

TB.5 支持 Apple Silicon，最低 macOS 26，尚未经过 Apple 公证。

## 致谢与许可证

基于 [ddddxxx/LyricsX](https://github.com/ddddxxx/LyricsX)、[MxIris 维护分支](https://github.com/MxIris-LyricsX-Project/LyricsX) 和 [wzk112/LyricsX Next](https://github.com/wzk112/LyricsX-Next) 继续开发，保留原项目历史与作者署名。歌词解析和媒体组件基于 LyricsKit 与 mediaremote-adapter，代码沿用 [MPL-2.0](LICENSE)，依赖遵循各自许可。歌词内容版权归其权利人所有。

[完整署名](COPYRIGHT.md) · [隐私说明](PRIVACY.md) · [详细功能对比](docs/TB-COMPARISON.md) · [构建与验证](docs/BUILD-TB.md)
