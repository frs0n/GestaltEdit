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
  <a href="LICENSE"><img src="https://img.shields.io/github/license/frs0n/GestaltEdit?style=flat-square&color=6E56CF" alt="MIT License"></a>
</p>

<a href="https://github.com/frs0n/GestaltEdit/releases/latest"><b>Download IPA</b></a> ·
<a href="#requirements-and-signing">Requirements</a> ·
<a href="#installing-with-iloader">Installing</a> ·
<a href="#usage">Usage</a> ·
<a href="README.zh-CN.md">简体中文</a>

</div>

GestaltEdit is a MobileGestalt utility that runs directly on iPhone and iPad — no computer, no sideload host, no tethering. It reads the device's `com.apple.MobileGestalt.plist` and provides common capability presets, a complete field editor, and backup/import/restore workflows.

> [!WARNING]
> This project uses private APIs and modifies system cache data. Incorrect MobileGestalt values can break system features or UI behavior and may require restoring the device. Use it only on devices you own or are authorized to manage.

> [!IMPORTANT]
> GestaltEdit is completely free and open source. Selling this app or any repackaged/modified version of it, in any form, is strictly prohibited. If you find someone selling it, please report them.

## Features

### MobileGestalt presets

- Dynamic Island device subtypes and the alternate support flag
- Device model name shown in About
- Boot/shutdown chime, charge limit, tap to wake, and Camera Control settings
- Apple Pencil, Action Button, and Collision SOS settings
- Always-On Display, AOD vibrancy, wallpaper parallax, and Liquid Glass low-performance mode
- Stage Manager, iPad app compatibility, and Nugget's iPadOS `CacheData` patch
- Siri AI US region, Apple internal install, internal storage, and Security Research Device mode

Presets follow Nugget's staged-apply model: toggles represent changes for the next write, and all selected changes are committed with the bottom Apply button. Selections are cleared after a successful write. Options that write conflicting values are mutually exclusive.

### Field editor

- Search keys and values in `CacheExtra` and at the plist top level
- Edit String, Integer, Float, Boolean, Data, Array, and Dictionary values
- Add or remove `CacheExtra` fields
- Read the file back after saving to verify the write
- Automatically respring after a verified write so changes take effect without a manual restart

### Backups

- Manually back up the current MobileGestalt file
- Automatically preserve the original plist before every write
- Import `.plist` files through the system file picker
- Validate the top-level dictionary and `CacheExtra` before importing
- Export, restore, and delete local backups

Importing only copies a file into GestaltEdit's backup library; it does not immediately modify the system file. Restoring first backs up the current file and then writes the selected backup.

## Requirements and signing

- Supported system versions: iOS and iPadOS 18, and 27 beta 1 through beta 4
- A way to sign and install the IPA, such as [iLoader](https://github.com/nab138/iloader)
- Developer Mode enabled on the device
- Bundle identifier: `me.ssus.gestaltedit`

GestaltEdit checks the running system build before accessing MobileGestalt. The current release accepts iOS and iPadOS 18 (any build; bad_query support is unverified upstream, "ymmv") and 27 beta 1–4 (24A5355q, 24A5370h, 24A5380h, 24A5380i, 24A5380l, 24A5390f). Apple may change these private behaviors at any time.

## Installing with iLoader

GestaltEdit ships as a ready-to-install IPA on the [Releases](https://github.com/frs0n/GestaltEdit/releases/latest) page. [iLoader](https://github.com/nab138/iloader) can sign and install it directly using your own Apple ID.

1. Download the latest `GestaltEdit.ipa` from [Releases](https://github.com/frs0n/GestaltEdit/releases/latest).
2. Install iLoader from [iloader.app](https://iloader.app/) or its [GitHub releases](https://github.com/nab138/iloader/releases) (Windows, Linux, and macOS are supported).
3. Connect your iPhone or iPad to your computer with a cable, then open iLoader and sign in with your Apple ID (used only for local code signing).
4. Import the downloaded IPA into iLoader and let it sign and install the app to your device.
5. On the device, trust the developer certificate under Settings → General → VPN & Device Management if prompted.

## Usage

1. Install and open GestaltEdit, then wait for it to read MobileGestalt.
2. Select the desired changes on the Tools tab and tap Apply.
3. Use the Fields tab when you need precise plist editing.
4. Create, import, export, or restore backups from the Backups tab.
5. After a successful write or restore, GestaltEdit automatically refreshes SpringBoard so the changes take effect.

## Credits

- [Nugget](https://github.com/leminlimez/Nugget) — MobileGestalt presets and the iPadOS `CacheData` approach
- [FilzaSlop](https://github.com/0xjohnnydev/FilzaSlop) — ContainerManager file-access research
- [bad_query](https://github.com/forcequitOS/bad_query) — path-based ContainerManager sandbox escape
- [0xJohnny](https://x.com/0xjohnny) — MobileHouseArrest / ContainerManager proof of concept
- [neospring](https://github.com/rooootdev/neospring) — WebKit respring implementation

GestaltEdit is an independent implementation and is not affiliated with Apple or the projects listed above.

## License

[MIT License](LICENSE)
