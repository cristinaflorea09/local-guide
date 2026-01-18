# LocalGuide Cloud Functions (EU) — Stripe Connect Express Marketplace

This folder contains the Firebase Cloud Functions backend for **LocalGuide**, deployed to **`europe-west1`**.

Included features:
- **Stripe Connect Express** onboarding for Guides/Hosts (seller payouts)
- **Tier-based platform commission** (Free 15% / Pro 10% / Elite 5%)
- **Separate charges and transfers** for delayed payouts (payout **after tour end**)
- Booking flow: reserve slot → create booking → create PaymentIntent → webhook marks paid → scheduled payout
- **Per-listing custom cancellation policy** → refunds + slot release
- **Admin override** cancel/refund
- Seller subscriptions (Pro/Elite) via Stripe Checkout + Billing Portal

Docs:
- `README_DEPLOYMENT.md` — deployment steps end-to-end
- `STRIPE_DASHBOARD_CHECKLIST.md` — exact Stripe setup checklist
- `LEGAL_COMPLIANCE_CHECKLIST_RO_EU.md` — Romania + EU marketplace compliance checklist

> Note: This backend intentionally avoids `functions.config()` (removed in newer versions) and uses
> `firebase-functions/params` + Secret Manager.
