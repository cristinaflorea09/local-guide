# Stripe Dashboard Setup Checklist (LocalGuide)

1) Developers -> API keys
- Store Secret key in Firebase Secret Manager as `STRIPE_SECRET_KEY`.
- Use Publishable key in the iOS app.

2) Connect
- Enable Stripe Connect.
- Use account type: **Express**.

3) Developers -> Webhooks
- Add endpoint: your deployed `stripeWebhook` HTTPS function URL.
- Events: `payment_intent.succeeded`, `payment_intent.payment_failed`, `customer.subscription.created`, `customer.subscription.updated`, `customer.subscription.deleted`.
- Store the webhook signing secret in Firebase Secret Manager as `STRIPE_WEBHOOK_SECRET`.

4) Products
- Create recurring Prices for seller tiers (Pro/Elite) in EUR and RON.
- Set the Price IDs into Firebase params: `PRICE_GUIDE_PRO_EUR`, etc.

5) Tax
- If you plan to use VAT automation, enable Stripe Tax and configure your business details and registrations.
