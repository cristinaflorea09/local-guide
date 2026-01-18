# Localization setup (EN + RO)

This project includes:
- `Resources/en.lproj/Localizable.strings`
- `Resources/ro.lproj/Localizable.strings`

If Xcode does not automatically include them in the target:
1. Drag `Resources` folder into Xcode (Copy items if needed)
2. Ensure "Create folder references" is selected OR add files individually
3. In File Inspector, check Target Membership for the app target

The app already stores `preferredLanguageCode` on the user and applies it through the environment locale.
