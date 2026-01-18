# LocalGuide – Stage 2 (Source)

This stage updates the iOS source to:
- Create Stripe PaymentIntent **on Pay Now** using `createPaymentIntent(bookingId)` (callable).
- Add **Host Experiences** as a separate Firestore collection: `experiences`.
- Add per-listing **cancellation policy** fields (custom) for Tours/Experiences.
- Add Guides/Hosts business compliance fields (SRL/PFA) + certificate upload.
- Add Intermediary Agreement acceptance for Guides/Hosts.
- Provide RO/EN legal docs templates (Terms, Privacy, Cancellation, Intermediary, SRL/PFA guide).

## Firebase/Stripe quick checklist

### Firebase
- Firestore collections used: `users`, `guides`, `hosts`, `tours`, `experiences`, `bookings`, `availability`, `threads`.
- If you use composite queries (where + orderBy), create Firestore composite indexes as prompted in console.

### Stripe (required for payments)
- Stripe iOS SDK uses a publishable key loaded from Firestore: `config/stripe.publishableKey`.
- Cloud Functions should expose:
  - `createPaymentIntent` (callable) **expects** `{ bookingId }`.
  - `reserveSlotAndCreateBooking` (callable)

### Stripe Connect Express (provider payouts)
If you implement payouts:
- Use Connect Express accounts for guides/hosts.
- Collect required KYC via account onboarding links.
- Store `users/{uid}.stripeAccountId`.

## Legal compliance checklist (Romania + EU)
This repo includes templates only (review with a lawyer):
- Terms & Conditions (marketplace position)
- Privacy Policy (GDPR)
- Cancellation Policy (per listing, consumer rights)
- Intermediary Agreement (platform ↔ provider)

Providers (guides/hosts) should:
- Add SRL/PFA details
- Upload registration certificate
- Accept Intermediary Agreement

