## Google Maps
This build uses a `GoogleMapToursView` that will render Google Maps if you add the Google Maps iOS SDK.
Steps:
1) Add the GoogleMaps SDK (SPM or CocoaPods)
2) Provide your API key in App start (e.g., `GMSServices.provideAPIKey(...)`)
If the SDK isn't added, the app falls back to Apple Maps.

## Country & City dropdowns
- Country list uses `Locale.isoRegionCodes`.
- City list is a starter dataset in `Core/CountryCityData.swift` (extend as needed).
