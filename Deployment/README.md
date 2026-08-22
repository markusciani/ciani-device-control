# Supervised Apple TV deployment

The tvOS app uses the bundle identifier `org.ciani01.cdctv`. The included
`Ciani Device Control App Lock.mobileconfig` profile uses Apple's supervised
App Lock payload to keep the Apple TV inside that app at the operating-system
level.

## Install order

1. Supervise the Apple TV with Apple Configurator or enroll it in MDM.
2. Install Ciani Device Control on the Apple TV.
3. Install `Ciani Device Control App Lock.mobileconfig` using Apple
   Configurator or assign it to the Apple TV from MDM.
4. Restart the Apple TV and verify that Ciani Device Control opens again and
   that the Home button cannot leave the app.

The App Lock payload requires supervision. An unsupervised Apple TV cannot use
this deployment profile.

## Unlocking the Apple TV

Remove or unassign the App Lock profile to release the Apple TV from
system-level Single App Mode. The profile deliberately permits removal so an
administrator cannot permanently strand the device.

The app countdown controls the app's locked interface. tvOS does not let the
app remove its own configuration profile, so automatically leaving system-level
Single App Mode at the end of the countdown requires the MDM server to remove
or unassign this profile.
