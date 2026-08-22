# Ciani Device Control

Ciani Device Control is a dual-target SwiftUI project. The iOS and Mac Catalyst app is the administrator console; the tvOS app is the managed display.

## Run

1. Open `Ciani Device Control.xcodeproj` in Xcode.
2. Select **Ciani Device Control iOS** or **Ciani Device Control tvOS**.
3. Choose a simulator or a device signed by your Personal Team.
4. Run both apps on devices on the same local network. Approve the local-network prompt.
5. On iPhone, enter the administrator PIN, tap **+**, select the Apple TV, and enter its six-digit pairing code.

## Updates

Every app launch checks `update.json` on the public GitHub repository. Increase
`latestVersion` when publishing an administrator-approved release. The apps
notify users when that version is newer than the installed version; installation
still occurs through Xcode, TestFlight, the App Store, or the administrator's
deployment workflow.

## Supervised Apple TV locking

The Mac Catalyst controller can use the bundled App Lock profile and Apple
Configurator's `cfgutil` tool to start and stop Single App Mode on a paired,
supervised Apple TV. See `Deployment/README.md` for setup and recovery details.
