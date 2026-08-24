# Supervised Apple TV deployment

The tvOS app uses the bundle identifier `org.ciani01.cdctv`. The included
`Ciani Device Control App Lock.mobileconfig` profile uses Apple's supervised
App Lock payload to keep the Apple TV inside that app at the operating-system
level.

## Install order

1. Supervise the Apple TV with Apple Configurator or enroll it in MDM.
2. Install Ciani Device Control on the Apple TV.
3. On the Mac controller, press **Lock Now**. The Mac app uses Apple
   Configurator's **Actions > Advanced > Start Single App Mode** workflow and
   selects Ciani Device Control. Grant Accessibility and Automation permission
   to the Mac app when macOS asks.
4. Restart the Apple TV and verify that Ciani Device Control opens again and
   that the Home button cannot leave the app.

The App Lock payload requires supervision. An unsupervised Apple TV cannot use
this deployment profile.

## Unlocking the Apple TV

Press **Unlock Now** on the Mac controller to run Apple Configurator's
**Stop Single App Mode** action. A timed lock runs the same action when its
countdown ends, provided the Mac is awake and Configurator can reach the TV.

The app countdown controls the app's locked interface. tvOS cannot remove
Single App Mode itself, so the Mac must remain available for automatic unlock.
