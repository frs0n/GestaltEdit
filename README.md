# GestaltEdit

GestaltEdit is a native SwiftUI MobileGestalt utility that runs directly on iPhone and Apple Vision Pro. It reads the device's `com.apple.MobileGestalt.plist` and provides common capability presets, a complete field editor, and backup/import/restore workflows.

> [!WARNING]
> This project uses private APIs and modifies system cache data. Incorrect MobileGestalt values can break system features or UI behavior and may require restoring the device. Use it only on devices you own or are authorized to manage.

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

- Supported system versions: iOS/iPadOS and visionOS 27 beta 1 through beta 4 only
- Xcode and a signing method that can install apps on the target device
- Developer Mode enabled on the device
- Bundle identifier: `me.ssus.gestaltedit`

GestaltEdit checks the running system build before accessing MobileGestalt. The current release accepts iOS 27 beta 1–4 (24A5355q, 24A5370h, 24A5380h, and 24A5390f) and visionOS 27 beta 1–4 (24M5291p, 24M5306i, 24M5316k, and 24M5326g). Apple may change these private behaviors at any time.

## Building

Open `GestaltEdit.xcodeproj` in Xcode, select your own development team for the target, and build. You can also build from the command line:

```sh
xcodebuild \
  -project GestaltEdit.xcodeproj \
  -scheme GestaltEdit \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  build
```

To validate the source without signing:

```sh
xcodebuild \
  -project GestaltEdit.xcodeproj \
  -scheme GestaltEdit \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build
```

IPA files, certificates, provisioning profiles, development team identifiers, and local Xcode user data are intentionally excluded from the repository.

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
