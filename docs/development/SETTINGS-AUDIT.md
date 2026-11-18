# LyricsX TB 设置文案与实现核对（TB.5）

本次检查范围是设置的 12 个页面、其子视图、搜索结果、关于链接及更新菜单。逐项核对 UI 绑定、持久化和实际消费者；主窗口、悬浮窗翻译策略与 Touch Bar 的组合另外做自动化测试及本机界面检查。下表“代码接通”不代表每种硬件、账号和联网来源都做过实机测试。

## 修正清单

| 原问题 | 本次处理 |
|---|---|
| “各位置可单独关闭”包括了没有独立开关的主窗口 | 删除该承诺；明确主窗口跟随总开关，悬浮窗使用内容选择，Touch Bar 另有开关 |
| 悬浮窗翻译入口叫“辅助内容”且埋在字号设置中 | 改名“翻译与下一句”，移到悬浮窗页面靠前位置；保留五种策略 |
| 内容模式“关闭”不清楚关什么 | 改为“都不显示”；只关闭原文下方翻译/下一句，不关闭原文 |
| 隐藏 Dock 后承诺固定快捷键可用 | 改为菜单栏、已配置快捷键或重新打开应用；不再假定默认快捷键未被改动 |
| 高清封面说明像是支持所有播放器 | 明确仅用于网易云；实际 resolver 也只接受网易云 track |
| 暂停时隐藏的说明省略手动显示例外 | 补充暂停时手动显示会暂时保留 |
| 下一句字号附带无条件动画承诺 | 删除动画承诺，只说明字号作用；动画仍受减少动态效果限制 |
| 段间距滑块禁用原因不明确 | 写明关闭“段间距跟随字号”后才能手动调节 |
| 恢复搜索只说清空排除记录 | 补充清空相关例外；不删除歌词文件 |
| 关于/菜单入口容易被误认成本地版发布、下载、反馈 | 明确上游项目；上游更新入口仍明确标记；公开预览新增本分支项目链接 |
| 本地版本行附上游作者名，容易混淆修改者 | 作者保留在上游署名行，版本行只列当前版本 |
| 搜索残留旧翻译文案、遗漏样式/HDR/恢复按钮、偏移单位过时 | 从公开 UI 文案生成索引并在构建时检查一致；补齐入口和条件跳转；通用偏移以秒输入、支持毫秒精度 |
| 教程还指向旧的悬浮窗间距页面 | 同步到“设置 → 悬浮窗”及新内容选择名称 |

本次没有删除可用功能。没有额外增加与内容选择重复的悬浮窗翻译开关。

## 逐组实现核对

| 页面/条目 | 实际控制链与限制 |
|---|---|
| 外观：界面主题 | Preferences.appTheme → LyricsXApp/MainWindowController 的界面颜色方案 |
| 通用：Dock | showDockIcon → AppModel/DockVisibilityController；应用可重开，不依赖固定快捷键 |
| 通用：菜单栏图标、歌词、合并 | LyricsXApp 的独立 MenuBarExtra 插入条件；AppModel.menubarText 截断长句 |
| 通用：登录启动、随网易云启动 | 分别由 SMAppService.mainApp / bundled agent 注册；两个独立服务；需要系统允许时显示状态 |
| 通用：全局快捷键、清除、恢复 | HotkeyPreferences/GlobalHotkeys；清除即不再占用组合；⌘F 是应用内命令 |
| 播放器：来源、重连 | PlayerBridge.mode/restart；自动模式过滤浏览器，指定来源跟随所选播放器 |
| 播放器：高清封面 | AppModel.updateArtwork 只对 com.netease.163music 调用 NetEaseArtworkResolver；匹配不成功保留系统封面；内存当前项、临时会话 |
| 悬浮窗：显示、锁定、穿透 | AppModel.setOverlay* → OverlayController；穿透使内容忽略鼠标，控制条分离；锁定/穿透联动 |
| 悬浮窗：经过隐藏、暂停隐藏 | OverlayController 的实际鼠标范围、锁定状态和暂停策略；手动暂停显示例外已写清 |
| 悬浮窗：翻译与下一句 | OverlaySecondaryMode 五种策略 → OverlayLyricsContent/OverlayTextMeasure；总开关只阻止译文，不抹掉选择，不影响原文 |
| 悬浮窗：歌曲信息 | overlayShowSongInfo → 固定头部与测量；歌词模式隐藏信息，无歌词歌曲卡片仍显示 |
| 外观：悬浮窗样式、深浅、透明度、磨砂 | OverlayAppearance + OverlayController/OverlayGlassBackground；Glass 固定外观，磨砂可选深浅；降低透明度时使用实色 |
| 悬浮窗：自动高度、宽度 | OverlaySizing/OverlayController；自动高度固定宽度，按可见文本测量；手动宽度在自动模式下禁用 |
| 悬浮窗：字号、下一句字号、翻译字号 | OverlayLyricsContent/OverlayTextMeasure；译文与下一句的选择决定显示；译文最多两行 |
| 悬浮窗：行距、段距、恢复 | OverlayTextSpacing normalized 值参与渲染及测量；自动段距有明确前提；恢复不改字号/位置 |
| 悬浮窗：实时波形、颜色、重试 | OverlayAudioWaveform/OverlayController；只在主动开启后尝试音频读取；受系统权限、音频可用性限制 |
| 歌词：翻译总开关 | 主窗口 NowPlayingView、OverlayLyricsContent/OverlaySizing、IntegratedTouchBarController、Flexbar 均读取 showTranslation；主窗口没有额外独立 gate |
| 歌词：简繁显示 | Preferences.text + Conversion；渲染前转换，不改写源文件 |
| 歌词：主窗口原文/翻译字号 | NowPlayingView 使用 mainLyricFontSize/mainTranslationFontSize |
| 歌词：当前歌词位置/自定义百分比 | MainLyricPosition/MainLyricScrollMotion/NowPlayingView 共用 placement；5–95% 归一化，切换预设不丢自定义值 |
| 字体与颜色：字体、当前色、辅助色 | Preferences.typography/mainTypography/overlayTypography → 实际渲染；浅色界面做对比度适配；Touch Bar 不跟随 |
| 字体与颜色：封面主题色 | AppModel 封面主题 → Preferences.typography 优先使用；无封面使用 neutral；自动模式禁用手动颜色编辑 |
| 字体与颜色：逐字独立配色 | Preferences.typography.wordColors → WordHighlight/Overlay 原文；只影响逐字时间歌词；已唱/未唱按钮有前提 |
| 字体与颜色：预览、恢复 | 真实 OverlayLyricsContent/WordHighlight 的固定演示；恢复实际重置字体、颜色与跟随/独立配色标志 |
| 歌词同步：通用、单曲 | GlobalLyricOffsetSettings → LyricsSession 有效偏移；通用保存在偏好，单曲保存到歌词文档；正值提前 |
| Touch Bar：开关、后台、全宽、等待时间 | IntegratedTouchBarController 直接观察主软件偏好；固定/自动互斥选用；1–15 秒；底层系统兼容性限制仍存在 |
| Touch Bar：翻译、固定字体、预览 | 原文/译文左右布局；总开关与独立 gate 同时满足才显示；白色常规 15 pt；预览使用同一 LyricView |
| 动效：减少动态、轻微放大、长音辉光 | Preferences.lyricEmphasis → WordHighlight/Overlay 原文；系统 reduceMotion 与应用标志共同限制；需要逐字时间 |
| 动效：HDR 开关、亮度倍数 | HDRBrightnessControl + HDRDisplaySupport；目标 1–4 倍、受当前屏幕余量限制，不修改系统亮度 |
| 动效：预览 | LyricsPreviewView 使用演示文档，不切歌、不写用户歌词缓存 |
| 搜索：双语、逐字、严格匹配 | Preferences → SourceConfigurationSnapshot → LyricsStore/CandidateRanker；偏好是排名加权，不越过曲目匹配门槛 |
| 搜索：完整搜索、来源开关/顺序/恢复 | LyricsSearchController/LyricsStore 的预算与别名查询；来源选择写入 config；恢复顺序不重置启用状态 |
| 搜索：Apple Music 内嵌/云端 | SourceConfiguration 合并同一来源；云端有独立 opt-in 与本地登录会话；格式由服务实际返回决定 |
| 搜索：按偏好重新搜索 | AppModel.refreshLyrics → session.reload(forceRefresh:true)；现有手动选择/缓存策略由 repository 执行 |
| 开发者：帧率 | LyricFrameSource/OverlayWindowMotion；智能节能在低电量/serious/critical 热状态限制帧率；实际显示由系统决定 |
| 开发者：Flexbar | FlexbarController/FlexbarServer；需要外部 FlexDesigner 插件，不是 Mac 内置 Touch Bar 开关 |
| 开发者：文件夹、导入、导出、写入 Music | AppModel.chooseCacheDirectory/importLyrics/exportLyrics/writeLyricsToMusic；执行前有曲目/文档状态检查与文件选择；导入会改当前缓存，写入 Music 会改音乐资料库 |
| 开发者：Musixmatch 令牌 | TokenStore 钥匙串；来源配置读取令牌；保存空值移除；未读取用户令牌做本次验证 |
| 开发者：显示诊断 | DisplayController/HDRDisplayCapability 读取系统报告，不声称尼特或认证 |
| 开发者：恢复排除 | blockedTracks/blockedAlbums/manualLyricOverrides 清空，再重载 session；本次不执行破坏用户记录的操作 |
| 关于：版本、指南、许可、上游链接 | 本地 Info.plist/GuideContent；Link 目标仍为已署名的上游仓库，现明确范围 |
| 搜索栏：条目、说明、跳转 | scripts/update-settings-search.py 从公开静态 UI 文本生成；SettingsSearchIndex 不读取实时状态、歌曲或文件；条件项跳到实际可用的前提控件 |

## 验证边界

本次不会为了“测试”而登录其他音乐账号、开启音频录制、写入 Apple Music、覆盖歌词文件、清空排除记录、修改钥匙串或启用额外网络查询。上述部分核对实现及既有测试，不能据此承诺所有来源/设备都可用。真实 Touch Bar 触感与歌词时序仍需物理硬件使用验证，屏幕预览不能代替。

## TB.5 设置整理

左侧分为常用设置、播放与显示、外观、其他。新的“外观”页包含应用主题及悬浮窗背景、材质、透明度；悬浮窗页保留内容、字号、尺寸、行为与波形。

字体与颜色页集中列明主窗口与悬浮窗共用样式、Touch Bar 固定白色常规字体。Touch Bar 页已移除重复的字体颜色说明；没有新增未接通的样式开关，也没有改动用户现有样式值。

## 搜索目录覆盖

以下为当前公开目录（包括分组标题与说明入口，并非每条都是独立开关）。

### 通用

应用入口、在 Dock 中显示、菜单栏图标、菜单栏歌词、合并图标与歌词、启动、登录时启动、随网易云启动、快捷键、恢复默认、搜索歌词、悬浮歌词、主窗口。

### 歌词

文字、显示翻译、中文显示、主窗口歌词字号、主窗口翻译字号、主窗口当前歌词位置、距歌词区域顶部。

### 歌词同步

同步、单曲歌词偏移、通用歌词偏移。

### 搜索

选择版本、双语优先、逐字优先、严格匹配、完整搜索、来源顺序、恢复默认顺序、当前歌曲、按当前偏好重新搜索、Apple Music 云端歌词、启用云端歌词。

### 播放器

连接播放器、读取来源、重新连接、专辑封面、补充高清封面。

### 悬浮窗

操作、显示悬浮窗、锁定位置、点击穿透、鼠标经过时隐藏、暂停时隐藏、悬浮窗内容、显示顶部歌曲信息、翻译与下一句、尺寸、自动调整高度、窗口宽度、悬浮窗文字、当前句字号、翻译字号、下一句字号、悬浮窗文字间距、音频波形、显示实时波形、波形颜色、原文换行行距、翻译换行行距、段间距跟随字号、原文与辅助行间距、翻译与下一句间距、恢复默认间距。

### Touch Bar

Touch Bar 歌词、在 Touch Bar 上显示歌词、后台显示、全宽与普通模式、闲置后自动全宽、恢复全宽的等待时间、固定全宽显示、文字与翻译、显示歌词翻译、当前歌曲预览。

### 外观

界面主题、应用界面、悬浮窗背景、悬浮窗颜色、歌词配色、磨砂程度、底色透明度、透明度、悬浮窗样式。

### 字体与颜色

适用范围、主窗口与悬浮窗、Touch Bar、主窗口与悬浮窗 · 字体与颜色、歌词字体、跟随封面主题色、当前歌词颜色、翻译与下一句颜色、逐字独立配色、已唱到的颜色、未唱到的颜色、恢复字体与颜色。

### 动效

动态效果、减少动态效果、逐字轻微放大、预览动效、长音辉光、HDR / EDR 辉光、HDR 辉光增强、HDR 亮度倍数。

### 开发者选项

渲染与功耗、悬浮窗帧率、Flexbar、在 Flexbar 上显示歌词、歌词文件夹、更换缓存文件夹、在 Finder 中打开、导入与导出、导入当前歌曲歌词、导出歌词、导出纯文本、写入 Apple Music、Musixmatch 访问令牌、显示诊断、搜索排除记录、恢复全部歌词搜索。

### 关于

LyricsX TB、Touch Bar 非官方定制版、项目与署名、使用指南、本次更新、上游项目主页、上游版本与下载、上游问题记录、上游项目、开源许可。

## TB.4 验证记录

TB.4 的 48 项相关测试（7 个测试组）通过，包括五种悬浮窗策略、翻译总开关与 Touch Bar 独立 gate、设置搜索、更新介绍、搜索控制和控制条生命周期。实际设置页已确认新入口、五个下拉选项与改写后的总开关说明；临时选择“仅下一句”时译文字号消失、下一句字号出现，随后恢复原来的“仅翻译”。搜索“悬浮窗 关闭翻译”能定位并高亮该控件。

没有开启原本关闭的悬浮窗、音频波形、高清封面或启动监听器。已备份 TB.3 并验证安装包签名及二进制哈希。


TB.5 验证：32 项相关测试（4 个测试组）通过；本机界面确认四组侧栏顺序、字体适用范围集中说明、Touch Bar 页字体条目已删除、主题和背景出现在外观页。搜索“悬浮窗样式”打开外观页并定位控件。本地验证保留原有字号、颜色、全宽等待及启动隐私选项。公开预览的最终验证以 Release 说明为准。

## 译文修复复查

重新打开全部 12 个设置页，逐组核对控件是否可见、禁用条件与实际处理方法。跳过登录时启动和随网易云启动。实机翻译开关切换后，Touch Bar 控制器诊断的 `showsTranslation` 同步变化；主开关关闭会停止显示并禁用从属选项；自动全宽关闭时固定全宽入口出现。测试后恢复用户原设置。异常是来源把译文编码为单独的逐字行，两个已发布版本共用这一读取路径；修复在读取时配对特征明确的酷狗歌词，保留已有文件不变。测试覆盖配对、时间轴、字级时间、不误配其他来源与缓存再读。搜索定位使用实时波形的有效可用状态，macOS 15 不会尝试跳到隐藏的波形颜色或采集项。

其余设置通过控件绑定、禁用条件和已有回归用例复查。涉及缓存清除、写入 Apple Music、钥匙串、网络登录、音频权限或外接硬件的操作不在真实用户数据上触发。
