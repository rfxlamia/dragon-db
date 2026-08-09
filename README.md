# DragonDB - A native PostgreSQL client for macOS

[![Platform](https://img.shields.io/badge/platform-macOS%2026-lightgrey.svg)](https://www.apple.com/macos)

DragonDB is a focused, native PostgreSQL GUI for Mac.
It connects to local and hosted PostgreSQL databases without sending connection
details, queries, or results through a DragonDB server.

## Getting started

1. Clone the repository:
   ```bash
   git clone https://github.com/rfxlamia/dragon-db.git
   cd dragon-db
   ```

2. Open the project in Xcode:
   ```bash
   open DragonDB.xcodeproj
   ```

3. IMPORTANT: Configure code signing:
   - Select the **DragonDB** target in the project navigator
   - Go to **Signing & Capabilities** tab
   - Select your **Team** from the dropdown (use your Apple ID's "Personal Team" if you don't have a paid developer account)

4. Build and run with `Cmd+R`

### Automated Local Build

If you don't want to open Xcode to configure code signing manually, you can use the provided script to set your Apple Developer Team ID and run the build directly from the terminal:

1. Apply your Team ID and a custom Bundle Identifier prefix:
   ```bash
   ./clean_pbxproj.sh YOUR_TEAM_ID com.yourname
   ```
   *(You can find your 10-character Team ID in your Apple Developer account)*

2. Build the app and generate the DMG:
   ```bash
   ./build_dmg.sh
   ```
### Submitting Pull Requests

When you select your team in step 3, Xcode modifies `project.pbxproj` with your team ID. **Do not include this change in your pull request.**

### Why Code Signing is Required

This app uses macOS Keychain to securely store database passwords. Keychain access requires a valid code signature, so even local development builds need to be signed with your team ID.

## Support

- Report bugs on [GitHub Issues](https://github.com/rfxlamia/dragon-db/issues)

## Acknowledgments

DragonDB is a fork of [O'Saasy](https://github.com/PostgresGUI) by Fikri Ghazi, built on the shoulders of giants. Special thanks to:

- The [PostgresNIO](https://github.com/vapor/postgres-nio) team for the excellent PostgreSQL client library
- The [Swift NIO](https://github.com/apple/swift-nio) project for the networking foundation
