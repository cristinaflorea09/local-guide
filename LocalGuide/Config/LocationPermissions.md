## Location permissions required

For Maps live location to work, ensure your app target Info.plist contains:

- `NSLocationWhenInUseUsageDescription` = "We use your location to show nearby tours and experiences on the map."

(Optional)
- `NSLocationAlwaysAndWhenInUseUsageDescription` (only if you ever request Always)

If you are running in the iOS Simulator, set a simulated location in Xcode:
`Debug` -> `Location` -> choose a location.
