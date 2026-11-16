<div align="center">

<img src="docs/icon.png" alt="GestaltEdit app icon" width="128" height="128">

# GestaltEdit

**A MobileGestalt utility that runs directly on iPhone and iPad**

<a href="https://trendshift.io/repositories/128548?utm_source=trendshift-badge&amp;utm_medium=badge&amp;utm_campaign=badge-trendshift-128548" target="_blank" rel="noopener noreferrer"><img src="https://trendshift.io/api/badge/trendshift/repositories/128548/daily?language=Swift" alt="frs0n%2FGestaltEdit | Trendshift" width="250" height="55"/></a>
<a href="https://trendshift.io/repositories/128548?utm_source=trendshift-badge&amp;utm_medium=badge&amp;utm_campaign=badge-trendshift-128548" target="_blank" rel="noopener noreferrer"><img src="https://trendshift.io/api/badge/trendshift/repositories/128548/weekly?language=Swift" alt="frs0n%2FGestaltEdit | Trendshift" width="250" height="55"/></a>

<p>
  <a href="https://github.com/frs0n/GestaltEdit/releases/latest"><img src="https://img.shields.io/github/v/release/frs0n/GestaltEdit?style=flat-square&label=release&color=6E56CF" alt="Latest release"></a>
  <a href="https://github.com/frs0n/GestaltEdit/releases"><img src="https://img.shields.io/github/downloads/frs0n/GestaltEdit/total?style=flat-square&label=downloads&color=6E56CF" alt="Downloads"></a>
  <a href="https://github.com/frs0n/GestaltEdit/stargazers"><img src="https://img.shields.io/github/stars/frs0n/GestaltEdit?style=flat-square&color=6E56CF" alt="Stars"></a>
  <img src="https://img.shields.io/badge/iOS%20%7C%20iPadOS-27-000000?style=flat-square&logo=apple&logoColor=white" alt="Platform">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0--or--later-6E56CF?style=flat-square" alt="GPL-3.0-or-later"></a>
</p>

<a href="https://github.com/frs0n/GestaltEdit/releases/latest"><b>Download IPA</b></a> ·
<a href="#requirements">Requirements</a> ·
<a href="#install">Install</a> ·
<a href="README.zh-CN.md">简体中文</a>

</div>

Edit `com.apple.MobileGestalt.plist` on-device. Capability presets, a full field editor, and backup/restore.

> [!WARNING]
> This app uses private APIs and modifies system cache data. Bad MobileGestalt values can break system features and may require restoring the device. Use only on devices you own.

> [!IMPORTANT]
> GestaltEdit is free and its source is public. Without authorization, you may not sell it.

## Features

**Presets** — Organized by purpose: Siri AI, Dynamic Island, display, iPad features and everyday device features. iPadOS Mode includes multitasking, Stage Manager and iPad app support in one selection. Liquid Glass uses a single effects selector. Extended presets include HDR photos, AOD widgets/brightness, Audio Mix, FaceTime spatial audio, seven device regions. Options are filtered by system version. Siri AI retains supported device regions and adjusts known restricted device regions when needed; it does not change Apple Account region. Settings-page options and internal experiments are collapsed under Advanced; tap ⓘ for limitations where available. Capability overrides do not guarantee hardware or service support. Selections stage changes until Apply; removing a selection does not undo an already applied preset. Use Backups to restore prior values.

On unsupported iOS 27 devices, Siri AI setup temporarily spoofs an eligible model. Face ID and dictation may be unavailable while spoofed. Finish downloading Siri AI models in Settings, then use **After Model Download · Remove Device Spoof** in Restore. After removing the spoof and restarting, Face ID and dictation work again; SiriMode = 2 and AI settings are retained. The ordinary pre-write backup keeps its original timestamp-based name and performs a full restore.

**Field editor** — Search and edit any MobileGestalt key by hand when a preset doesn't cover it.

**Backups** — Every write is backed up automatically. Back up, import, export, and restore at any time.

## Requirements

- iOS / iPadOS 27.0 or later (iOS / iPadOS 26 is not supported for on-device MobileGestalt access)
- Developer Mode enabled
- A signing tool such as [iLoader](https://github.com/nab138/iloader)

## Install

1. Download `GestaltEdit.ipa` from [Releases](https://github.com/frs0n/GestaltEdit/releases/latest).
2. Install [iLoader](https://iloader.app/), connect your device, and sign in with your Apple ID (used only for local signing).
3. Import the IPA to sign and install it, then trust the certificate under Settings → General → VPN & Device Management.

## Apple Watch

watchOS 26 is not supported.

Expand the device connection row at the top of Tools and select the active Apple Watch paired with your iPhone.

For Apple Watch support, we recommend signing with [WatchBridge](https://github.com/AdminZachary/WatchBridge). This community tool can enable Developer Mode and install an IPA containing both the iPhone app and the Watch app. It is not affiliated with this project.

## Credits

- [Nugget](https://github.com/leminlimez/Nugget) — presets and iPadOS support
- [FilzaSlop](https://github.com/0xjohnnydev/FilzaSlop), [worse_query](https://github.com/forcequitOS/worse_query), [0xJohnny](https://x.com/0xjohnny) — file access research
- [neospring](https://github.com/rooootdev/neospring) — respring implementation

Not affiliated with Apple or the projects above.

## License

[GNU General Public License v3.0 or later](LICENSE).
