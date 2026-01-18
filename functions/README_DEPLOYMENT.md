# LocalGuide Backend Deployment (EU)

This folder deploys Firebase **Cloud Functions v2** to **`europe-west1`**.

## Prerequisites
- Node.js **20**
- Firebase CLI
- Stripe account

## 1) Install dependencies
From the `functions/` folder:

```bash
npm install
```

## 2) Set Stripe secrets (Secret Manager)
Set these once per Firebase project:

```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
```

## 3) Set non-secret parameters (params)

```bash
firebase functions:params:set APP_BASE_URL="https://yourdomain.com"

# Subscription Price IDs (Stripe "Price" objects)
firebase functions:params:set PRICE_GUIDE_PRO_EUR="price_..."
firebase functions:params:set PRICE_GUIDE_ELITE_EUR="price_..."
firebase functions:params:set PRICE_HOST_PRO_EUR="price_..."
firebase functions:params:set PRICE_HOST_ELITE_EUR="price_..."

firebase functions:params:set PRICE_GUIDE_PRO_RON="price_..."
firebase functions:params:set PRICE_GUIDE_ELITE_RON="price_..."
firebase functions:params:set PRICE_HOST_PRO_RON="price_..."
firebase functions:params:set PRICE_HOST_ELITE_RON="price_..."

# Optional: buffer minutes after listing end time before payout runs
firebase functions:params:set PAYOUT_BUFFER_MINUTES="60"
```

## 4) Deploy functions

```bash
firebase deploy --only functions
```

## 5) Stripe webhook
In Stripe Dashboard:
- Developers -> Webhooks -> Add endpoint
- URL: the deployed `stripeWebhook` HTTPS function URL
- Events:
  - `payment_intent.succeeded`
  - `payment_intent.payment_failed`
  - `customer.subscription.created`
  - `customer.subscription.updated`
  - `customer.subscription.deleted`

Then set `STRIPE_WEBHOOK_SECRET` to the webhook signing secret.

## 6) Remove old US functions (optional but recommended)
If you previously deployed to `us-central1`, delete them so the app can’t call the wrong region:

```bash
firebase functions:delete createBillingPortal --region us-central1
firebase functions:delete createSellerSubscriptionCheckout --region us-central1
firebase functions:delete reserveSlotAndCreateBooking --region us-central1
firebase functions:delete stripeWebhook --region us-central1
```

## 7) Client-side (iOS) note
Make sure your app uses the EU region:

```swift
Functions.functions(region: "europe-west1")
```

## Payout model (after tour end)
This backend uses **separate charges and transfers**:
- The customer is charged on the platform.
- After the listing end time, a scheduled job creates a Stripe **Transfer** to the seller’s Connect account.
- Platform commission depends on seller tier: Free 15% / Pro 10% / Elite 5%.

See `STRIPE_DASHBOARD_CHECKLIST.md` for required Stripe settings.
