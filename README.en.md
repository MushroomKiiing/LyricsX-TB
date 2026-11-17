# LyricsX TB

[简体中文](README.md) · **English**

<img src="Resources/Icon.iconset/icon_128x128.png" width="96" alt="Original LyricsX music-note icon">

An unofficial Touch Bar edition based on [LyricsX Next](https://github.com/wzk112/LyricsX-Next), retaining the original music-note icon.

[Download TB.5](https://github.com/MushroomKiiing/LyricsX-TB/releases/tag/v2.0.43-tb.5)

## Improvements over LyricsX Next

### Touch Bar

- **Full-width lyrics:** fixed or automatic full-width display. Tap the lyrics or blank space to return to lyrics on the left and system controls on the right; return to full width after an adjustable 1–15 seconds.
- **Background display:** the former standalone helper is integrated into the main app. Settings directly control the displayed lyrics, including when another app is active.
- **Text and translation:** white, regular-weight text; original lyrics on the left and translation on the right, with independent scrolling. Full-width mode uses the available bar width.
- **Stability:** fixes from local iterations address a blank bar, narrow lyric area, unresponsive blank space, and repeated mode switching.

### NetEase playback and artwork

- **Playback sync:** a dedicated NetEase reader reduces interference from browser media, incorrect stopped states, and position drift. Pause, seeking, and lyric offsets follow the main app.
- **Optional high-resolution artwork:** matches artwork through NetEase, with query details explained in settings and no additional disk image cache. This extra matching supports NetEase only; other players can still display the artwork they provide.

### Startup and privacy

- **Launch with NetEase:** an independent option alongside launch at login. It listens to local app lifecycle events, without network requests or startup history.
- **Optional features:** high-resolution artwork matching and launch with NetEase require opt-in. Privacy explanations appear beside their settings.

### Cache and library

- **Automatic caching:** disable automatic lyric and per-track offset writes while continuing to fetch and display lyrics. Existing files remain readable.
- **Cache cleanup:** confirm before moving lyric files to Trash, where they can be restored. The library remains available.

### Settings and interface

- **Settings search:** local search with links to the matching controls.
- **Navigation:** groups for common settings, playback and display, appearance, and other options. Player, floating lyrics, and Touch Bar settings sit together.
- **Translation controls:** explains the main-window master switch, five floating-window content policies, and the Touch Bar translation switch.
- **Fonts and colors:** clarifies shared styling for the main and floating windows and fixed white Touch Bar text; removes duplicate controls and uses vector sidebar icons.
- **Copy and naming:** corrects misleading descriptions, uses the name LyricsX TB, and preserves the original icon and upstream credits.

## Use

Download the arm64 app ZIP, move LyricsX TB.app to Applications, quit the previous version, and open the app. Enable the desired features in Settings → Touch Bar.

TB.5 supports Apple Silicon and requires macOS 26 or later. It is not notarized by Apple.

## Credits and license

Built on [ddddxxx/LyricsX](https://github.com/ddddxxx/LyricsX), the [MxIris maintenance branch](https://github.com/MxIris-LyricsX-Project/LyricsX), and [wzk112/LyricsX Next](https://github.com/wzk112/LyricsX-Next), preserving their history and author credits. Lyric parsing and media components build on LyricsKit and mediaremote-adapter. Code remains under [MPL-2.0](LICENSE); dependencies retain their own licenses. Lyrics belong to their respective rights holders.

[Full credits](COPYRIGHT.md) · [Privacy](PRIVACY.md) · [Detailed comparison](docs/TB-COMPARISON.md) · [Build and verification](docs/BUILD-TB.md)
