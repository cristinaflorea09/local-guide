# Stripe Dashboard Setup Checklist

This project uses:

- **Stripe Checkout** for seller subscriptions (Pro/Elite)
- **Stripe Connect Express** for marketplace payouts (guides/hosts)
- **Destination charges + application fee** for commission-based bookings

## 1) Connect settings
1. Stripe Dashboard → Connect → Settings
2. Choose **Express** accounts.
3. Set your platform branding (name, icon, support email).

## 2) Webhook
1. Create a webhook endpoint pointing to your deployed function:
   - `stripeWebhook` (europe-west1)
2. Subscribe to events:
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
   - `checkout.session.completed`
   - `customer.subscription.created|updated|deleted`

## 3) Products & Prices
Create Stripe Prices for seller tiers:

- Guide Pro (EUR)
- Guide Elite (EUR)
- Host Pro (EUR)
- Host Elite (EUR)
- Guide Pro (RON)
- Guide Elite (RON)
- Host Pro (RON)
- Host Elite (RON)

Then set env parameters in Firebase Functions:

- `PRICE_GUIDE_PRO_EUR`, ...

## 4) Apple Pay / Payment Methods
Enable the payment methods you want (cards, Apple Pay where supported).

## 5) Tax / VAT (optional)
If you want Stripe to help compute VAT:

- Enable **Stripe Tax**
- Enable `automatic_tax` (already used in subscription checkout)

## 6) Test mode
Run everything in Test mode first:

- Use test API keys
- Use Stripe test cards
- Complete Connect Express onboarding in test mode