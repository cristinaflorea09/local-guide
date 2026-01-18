# LocalGuide Deployment (RO + EU)

This repo contains:

- **iOS app (SwiftUI)**
- **Firebase**: Auth, Firestore, Storage, Cloud Functions
- **Stripe**: subscriptions + **Connect Express** marketplace payments

Target backend region: **europe-west1**.

## Firebase setup

1. Create a Firebase project.
2. Enable products:
   - Authentication (Email/Password, Apple)
   - Firestore
   - Storage
   - Cloud Functions
3. Download `GoogleService-Info.plist` and add it to the iOS target.

## Cloud Functions deployment

> You must deploy the Functions zip you received (Stage 1).

1. Install Firebase CLI.
2. In `functions/`:
   ```bash
   npm i
   firebase deploy --only functions
   ```
3. Confirm functions exist in **europe-west1**:
   ```bash
   firebase functions:list
   ```

## Firestore rules

Update rules to:
- restrict writes to owners
- restrict admin-only operations
- enforce seller onboarding (business fields) for guide/host

This project includes baseline rules in `storage.rules` and `firestore.rules` (adjust to your needs).

## iOS build

1. Open the Xcode project.
2. Set Bundle ID to your Apple Developer App ID.
3. Ensure capabilities:
   - Sign In with Apple
4. Add Google Maps key to `AppConfig.swift` (see checklist).

## Test payment end-to-end

1. Create guide/host account.
2. Connect Stripe Express.
3. Create tour/experience + availability.
4. Traveler books and pays.
5. After end time, seller requests payout (backend validates completion).
