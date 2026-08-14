<p align="center">
  <img src="BoxHelper/Assets.xcassets/AppLogo.imageset/AppIcon-iOS-Default-1024x1024@2x_4.png" alt="BoxHelper app icon" width="140">
</p>

<h1 align="center">BoxHelper</h1>

<p align="center">
  Organize boxes, items and storage locations with photos, QR codes, backups, CSV import/export and Shortcuts automation.
</p>

<p align="center">

  <a href="https://apps.apple.com/us/app/boxhelper/id6737223705?itscg=30200&itsct=apps_box_badge&mttnsubad=6737223705">
    <img
      src="https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-app-store/black/en-us?releaseDate=1729641600"
      alt="Download on the App Store"
      width="246"
      height="82"
    />
  </a>

  <br/>
  <br/>
  <a href="https://developer.apple.com/swift/">
    <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="Swift 6">
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/SwiftUI-Framework-007AFF?logo=swift&logoColor=white" alt="SwiftUI">
  </a>
  <a href="https://github.com/HOCKULUS/BoxHelper/blob/main/LICENSE">
    <img
      src="https://img.shields.io/badge/License-AGPLv3-blue.svg"
      alt="AGPLv3 License"
    />
  </a>
  <a href="https://github.com/HOCKULUS/BoxHelper">
    <img
      src="https://img.shields.io/badge/Open%20Source-Yes-brightgreen.svg"
      alt="Open Source"
    />
  </a>
  <a href="#">
  <img src="https://img.shields.io/badge/AI-Supported-8A2BE2?logo=openai&logoColor=white" alt="AI Supported">
 </a>

</p>

<p align="center">
  <img src="https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/4b/1d/ff/4b1dffea-e377-7498-77fc-75b51194b487/Mockup_BoxHelper_DE5_6.png/460x996bb.webp" alt="BoxHelper screenshot showing organized boxes" width="220">
  <img src="https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/55/a0/37/55a037b0-c84c-b2f7-0041-78aed9518ee8/Mockup_BoxHelper_DE1_2.png/460x996bb.webp" alt="BoxHelper screenshot showing inventory management" width="220">
  <img src="https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/ca/af/83/caaf8345-8fd0-eede-ca66-911489831946/Mockup_BoxHelper_EN2.png/460x996bb.webp" alt="BoxHelper screenshot showing QR code organization" width="220">
</p>

## Overview



BoxHelper is a SwiftUI app for keeping track of boxes, items and storage locations. It is built for moving, home storage, basement shelves, office inventory, storage units, or any setup where you want to know what you own, where it is and how to find it again without opening every box.

Each box can get its own QR code. Scan the code later to jump directly to the box and see what is inside. BoxHelper also supports photos, tags, deeper search, backups, CSV import/export and automation through Siri Shortcuts and App Intents.

I no longer want to hide this app away. I want everyone to have the chance to become part of BoxHelper, whether that means actively contributing to this repository, learning from the code, or building their own version from it.

AI has made it easier than ever to create copycats of management and organization apps. Instead of spreading effort across a thousand half-finished clones, I believe it is better to combine resources, ideas and real-world feedback into one strong app that can become genuinely useful for more people.

## Features

- Manage boxes, items and locations
- Generate, customize, print and scan QR codes for boxes
- Add photos to boxes, items and locations
- Search across boxes, items, locations, tags and linked content
- Create, export, share, import, merge and restore ZIP backups
- Import and export CSV files for boxes, items and locations
- Use Siri Shortcuts and App Intents for recurring workflows
- Customize QR code labels and app appearance
- Keep inventory data under user control on device

## App Icons

<p>
  <img src="BoxHelper/Assets.xcassets/AppIcons/Preview/AppLogoClassicPreview.imageset/AppIconClassicPreview.png" alt="Classic BoxHelper app icon" width="72">
  <img src="BoxHelper/Assets.xcassets/AppIcons/Preview/AppLogoFirstPreview.imageset/AppIconPreview.png" alt="First BoxHelper app icon" width="72">
  <img src="BoxHelper/Assets.xcassets/AppIcons/Preview/AppLogoRealPreview.imageset/AppIconRealPreview.png" alt="Real BoxHelper app icon" width="72">
  <img src="BoxHelper/Assets.xcassets/AppIcons/Preview/AppLogoSkeuomorphPreview.imageset/AppIconSkeuomorph3Preview.png" alt="Skeuomorph BoxHelper app icon" width="72">
  <img src="BoxHelper/Assets.xcassets/AppIcons/Preview/AppLogoPridePreview.imageset/AppIconPridePreview.png" alt="Pride BoxHelper app icon" width="72">
</p>

## Platform Support

BoxHelper is built for:

- iPhone with iOS 18.0 or later
- iPad with iPadOS 18.0 or later
- Mac with macOS 15.0 or later and an Apple M1 chip or later
- Apple Vision with visionOS 2.0 or later

## Development

### Requirements

- Xcode
- iOS/iPadOS simulator or a compatible test device
- Local Swift package `Zip`, because the Xcode project references `../../Zip-Dependency`

### Open the Project

1. Clone the repository.
2. Make sure the local `Zip` dependency is available at the expected relative path.
3. Open `BoxHelper.xcodeproj` in Xcode.
4. Select a scheme, for example `en-US`, `de-DE`, or `BoxHelperRelase`.
5. Build and run the app on a simulator or device.

## Privacy

BoxHelper is designed around local organization and user-controlled exports. The app does not collect user data. Backups and CSV files are created, shared, imported, or restored by the user.

## App Store

BoxHelper is available for free in the Productivity category on the App Store. Current public version: `2.0.1`.

[Open BoxHelper on the App Store](https://apps.apple.com/us/app/boxhelper/id6737223705)

## License

BoxHelper is licensed under the GNU Affero General Public License v3.0 (`AGPL-3.0`).

If you build on this project, modify it, or create your own version from it, please make your derived work available to others under the same license. This keeps improvements open, supports the project and helps the community build one better app together instead of many closed or unfinished copies.
