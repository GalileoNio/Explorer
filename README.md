# Explorer

Explorer is a SwiftUI file manager for macOS and iPadOS with a Nautilus-inspired layout and a Liquid Glass-first interface.

## Requirements

- Xcode 26 or newer
- macOS 26 / iPadOS 26 deployment targets

The project is intentionally configured for the new design system so it can use SwiftUI Liquid Glass APIs such as `glassEffect`, `GlassEffectContainer`, glass button styles, and updated toolbar/search behavior directly.

## Targets

- `ExplorerCore`: file models, navigation state, directory scanning, sorting, search, and file operations.
- `ExplorerUI`: shared SwiftUI interface for macOS and iPadOS.
- `Explorer`: the app target.
- `ExplorerCoreTests`: unit and temporary-directory integration tests for the core filesystem layer.

`ExplorerCore` and `ExplorerUI` are built as static frameworks. This keeps the project modular while avoiding local run-time dyld failures from mismatched ad-hoc framework signatures.

## Running

Open `Explorer.xcodeproj`, choose the shared `Explorer` scheme, and run it on `My Mac`.

For iPadOS devices, select your Apple Development Team in Signing & Capabilities for the `Explorer` app target before running on-device.

## Notes

On macOS, Explorer is designed as a developer-style local file browser. If protected folders fail to load, grant the app Full Disk Access in System Settings.

On iPadOS, the system does not expose a whole-device filesystem. Explorer uses folder selection and security-scoped bookmarks for user-authorized locations.
