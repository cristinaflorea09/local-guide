/**
 * LocalGuide Marketplace Cloud Functions (Stage 1 - Backend)
 *
 * Region: europe-west1
 * Runtime: Node 20
 *
 * Implemented:
 * - Seller subscriptions (Pro/Elite) for Guides/Hosts (Stripe Checkout)
 * - Stripe Connect Express onboarding for sellers
 * - Booking reservation (slot lock) + booking creation (pending_payment)
 * - PaymentIntent creation on "Pay now" (callable)
 * - Tier-based commission (Free=15%, Pro=10%, Elite=5%)
 * - Hold funds on platform; payout to seller AFTER tour completion via scheduled job
 * - Per-listing custom cancellation policy -> refund + slot release
 * - Admin override cancel/refund
 *
 * Notes:
 * - Uses Firebase Functions v2 + params/secrets (functions.config() is not used)
 * - For delayed payouts, we use "separate charges and transfers":
 *   - Charge customer on platform account (PaymentIntent)
 *   - After tour end, create Transfer to connected account
 */

const admin = require("firebase-admin");
const Stripe = require("stripe");

const { defineSecret, defineString } = require("firebase-functions/params");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions/logger");

admin.initializeApp();

const REGION = "europe-west1";

/* =======================
   SECRETS (Secret Manager)
======================= */
const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");
const STRIPE_WEBHOOK_SECRET = defineSecret("STRIPE_WEBHOOK_SECRET");
// OpenAI API key for AI Trip Designer (server-side only)
const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

/* =======================
   PARAMS (Env parameters)
======================= */
const APP_BASE_URL = defineString("APP_BASE_URL");

// Subscription price IDs
const PRICE_GUIDE_PRO_EUR = defineString("PRICE_GUIDE_PRO_EUR");
const PRICE_GUIDE_ELITE_EUR = defineString("PRICE_GUIDE_ELITE_EUR");
const PRICE_HOST_PRO_EUR = defineString("PRICE_HOST_PRO_EUR");
const PRICE_HOST_ELITE_EUR = defineString("PRICE_HOST_ELITE_EUR");

const PRICE_GUIDE_PRO_RON = defineString("PRICE_GUIDE_PRO_RON");
const PRICE_GUIDE_ELITE_RON = defineString("PRICE_GUIDE_ELITE_RON");
const PRICE_HOST_PRO_RON = defineString("PRICE_HOST_PRO_RON");
const PRICE_HOST_ELITE_RON = defineString("PRICE_HOST_ELITE_RON");

// Optional: how often to run payout job is set in schedule, but you can add a safety buffer.
// Example: don't pay out until N minutes after end time (to avoid time drift)
const PAYOUT_BUFFER_MINUTES = defineString("PAYOUT_BUFFER_MINUTES"); // e.g. "60"

/* =======================
   HELPERS
======================= */

function stripeClient() {
  const secret = STRIPE_SECRET_KEY.value();
  if (!secret) throw new Error("Missing secret STRIPE_SECRET_KEY");
  return new Stripe(secret, { apiVersion: "2023-10-16" });
}

function baseUrl() {
  const v = APP_BASE_URL.value();
  return (v || "https://example.com").replace(/\/$/, "");
}

function normalizeCountry(c) {
  if (!c) return "";
  return String(c)
    .trim()
    .toLowerCase()
    .replace(/ă/g, "a")
    .replace(/â/g, "a")
    .replace(/î/g, "i")
    .replace(/ș/g, "s")
    .replace(/ț/g, "t");
}

function pickCurrencyForUser(user) {
  const country = normalizeCountry(user?.country);
  if (country.includes("romania")) return "ron";
  return "eur";
}

function priceIdFor(role, tier, currency) {
  if (role === "guide" && tier === "pro" && currency === "eur") return PRICE_GUIDE_PRO_EUR.value();
  if (role === "guide" && tier === "elite" && currency === "eur") return PRICE_GUIDE_ELITE_EUR.value();
  if (role === "host" && tier === "pro" && currency === "eur") return PRICE_HOST_PRO_EUR.value();
  if (role === "host" && tier === "elite" && currency === "eur") return PRICE_HOST_ELITE_EUR.value();

  if (role === "guide" && tier === "pro" && currency === "ron") return PRICE_GUIDE_PRO_RON.value();
  if (role === "guide" && tier === "elite" && currency === "ron") return PRICE_GUIDE_ELITE_RON.value();
  if (role === "host" && tier === "pro" && currency === "ron") return PRICE_HOST_PRO_RON.value();
  if (role === "host" && tier === "elite" && currency === "ron") return PRICE_HOST_ELITE_RON.value();

  throw new Error(`Missing priceId for ${role}.${tier}.${currency}`);
}

function commissionPercentForTier(tier) {
  const t = String(tier || "free").toLowerCase();
  if (t === "elite") return 5;
  if (t === "pro") return 10;
  return 15; // free/default
}

function computeRefundPercent(policy, startDate, canceledAt) {
  // policy: { type:"custom", freeCancelHours:int, refundPercentAfterDeadline:int, noShowRefundPercent:int }
  const p = policy || {};
  const freeH = Number(p.freeCancelHours ?? 48);
  const afterPct = Number(p.refundPercentAfterDeadline ?? 0);

  const hoursBefore = (startDate.getTime() - canceledAt.getTime()) / (1000 * 60 * 60);
  if (hoursBefore >= freeH) return 100;

  return Math.max(0, Math.min(100, afterPct));
}

async function requireFirebaseAuth(req) {
  const authHeader = req.headers.authorization || "";
  const match = authHeader.match(/^Bearer (.+)$/);
  if (!match) throw new HttpsError("unauthenticated", "Missing Authorization: Bearer <token>");
  return admin.auth().verifyIdToken(match[1]);
}

async function isAdminUid(uid) {
  // In this app, admin is modeled as role === "admin" in Firestore.
  // You can harden with custom claims later.
  const snap = await admin.firestore().collection("users").doc(uid).get();
  const u = snap.exists ? snap.data() : null;
  return !!u && u.role === "admin";
}

async function isCallerAdmin(uid) {
  // Prefer custom claims (recommended) but fall back to Firestore role.
  try {
    const user = await admin.auth().getUser(uid);
    const claims = user.customClaims || {};
    if (claims.role === "admin" || claims.admin === true) return true;
  } catch (e) {
    logger.warn("Failed to read custom claims for admin check", e);
  }
  return isAdminUid(uid);
}

function parseIsoToDate(iso) {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) throw new Error("Invalid ISO datetime");
  return d;
}

/* =======================
   STRIPE SUBSCRIPTION CHECKOUT (HTTP v2)
======================= */

exports.createSellerSubscriptionCheckout = onRequest(
  { region: REGION, secrets: [STRIPE_SECRET_KEY], cors: true },
  async (req, res) => {
    try {
      if (req.method !== "POST") return res.status(405).send("Method not allowed");

      const stripe = stripeClient();
      const decoded = await requireFirebaseAuth(req);
      const uid = decoded.uid;

      const { tier, role } = req.body || {};
      if (!tier || !role) return res.status(400).send("Missing tier or role");
      if (!["pro", "elite"].includes(tier)) return res.status(400).send("Tier must be pro or elite");
      if (!["guide", "host"].includes(role)) return res.status(400).send("Role must be guide or host");

      const userRef = admin.firestore().collection("users").doc(uid);
      const userSnap = await userRef.get();
      const user = userSnap.data() || {};

      const currency = pickCurrencyForUser(user);
      const priceId = priceIdFor(role, tier, currency);

      let customerId = user.stripeCustomerId;
      if (!customerId) {
        const customer = await stripe.customers.create({
          email: user.email || undefined,
          name: user.fullName || undefined,
          metadata: { firebaseUid: uid },
        });
        customerId = customer.id;
        await userRef.set({ stripeCustomerId: customerId }, { merge: true });
      }

      const session = await stripe.checkout.sessions.create({
        mode: "subscription",
        customer: customerId,
        line_items: [{ price: priceId, quantity: 1 }],
        success_url: `${baseUrl()}/seller-subscription-success?session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: `${baseUrl()}/seller-subscription-cancel`,
        billing_address_collection: "required",
        automatic_tax: { enabled: true },
        customer_update: { address: "auto", name: "auto" },
        metadata: { uid, role, tier, currency },
      });

      return res.json({ url: session.url, currency });
    } catch (e) {
      logger.error("createSellerSubscriptionCheckout failed", e);
      return res.status(500).send(e?.message || "Unknown error");
    }
  }
);

exports.createBillingPortal = onRequest(
  { region: REGION, secrets: [STRIPE_SECRET_KEY], cors: true },
  async (req, res) => {
    try {
      if (req.method !== "POST") return res.status(405).send("Method not allowed");

      const stripe = stripeClient();
      const decoded = await requireFirebaseAuth(req);
      const uid = decoded.uid;

      const userSnap = await admin.firestore().collection("users").doc(uid).get();
      const customerId = userSnap.data()?.stripeCustomerId;
      if (!customerId) return res.status(400).send("Missing stripeCustomerId. Subscribe first.");

      const session = await stripe.billingPortal.sessions.create({
        customer: customerId,
        return_url: `${baseUrl()}/app`,
      });

      return res.json({ url: session.url });
    } catch (e) {
      logger.error("createBillingPortal failed", e);
      return res.status(500).send(e?.message || "Unknown error");
    }
  }
);

/* =======================
   STRIPE CONNECT EXPRESS ONBOARDING (CALLABLE)
======================= */

exports.createConnectExpressOnboardingLink = onCall(
  { region: REGION, secrets: [STRIPE_SECRET_KEY] },
  async (request) => {
    if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Login required");
    const uid = request.auth.uid;

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    if (!userSnap.exists) throw new HttpsError("not-found", "User not found");
    const user = userSnap.data() || {};

    if (!["guide", "host"].includes(user.role)) {
      throw new HttpsError("failed-precondition", "Only guide/host can connect Stripe");
    }

    const stripe = stripeClient();

    let accountId = user.stripeAccountId;
    if (!accountId) {
      // Express account. Country defaults to RO for your initial market.
      // If you later collect seller country, set it here.
      const account = await stripe.accounts.create({
        type: "express",
        country: "RO",
        email: user.email || undefined,
        metadata: { firebaseUid: uid, role: user.role },
      });
      accountId = account.id;
      await userRef.set({ stripeAccountId: accountId }, { merge: true });
    }

    const link = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: `${baseUrl()}/connect-refresh`,
      return_url: `${baseUrl()}/connect-return`,
      type: "account_onboarding",
    });

    return { url: link.url, stripeAccountId: accountId };
  }
);

/* =======================
   BOOKING: RESERVE SLOT + CREATE BOOKING (CALLABLE)
   - Creates booking with status pending_payment
======================= */

exports.reserveSlotAndCreateBooking = onCall(
  { region: REGION },
  async (request) => {
    if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Login required");
    const uid = request.auth.uid;

    // Expected payload from the iOS app
    const {
      // New unified fields (preferred)
      listingType,
      listingId,
      providerId,

      // Backward compatible fields (older app builds)
      tourId,
      guideId,
      slotId,
      startISO,
      endISO,
      totalAmount, // cents
      currency,
      notes,
      peopleCount,
    } = request.data || {};

    const lt = (listingType || "tour").toLowerCase();
    const lid = listingId || tourId;
    const pid = providerId || guideId;

    if (!lid || !pid || !slotId || !startISO || !endISO) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    const db = admin.firestore();
    const slotRef = db.collection("availability").doc(slotId);
    const bookingRef = db.collection("bookings").doc();

    await db.runTransaction(async (tx) => {
      const slotSnap = await tx.get(slotRef);
      if (!slotSnap.exists) throw new HttpsError("not-found", "Slot not found");
      const slot = slotSnap.data() || {};

      if (slot.guideId !== pid) throw new HttpsError("permission-denied", "Provider mismatch");
      if (slot.isReserved === true || slot.status === "reserved") {
        throw new HttpsError("failed-precondition", "Slot already reserved");
      }

      tx.update(slotRef, {
        isReserved: true,
        status: "reserved",
        reservedBy: uid,
        reservedAt: admin.firestore.FieldValue.serverTimestamp(),
        bookingId: bookingRef.id,
      });

      // For backward compatibility, keep tourId/guideId fields populated.
      const compatTourId = tourId || lid;
      const compatGuideId = guideId || pid;

      tx.set(bookingRef, {
        id: bookingRef.id,
        tourId: compatTourId,
        guideId: compatGuideId,
        listingType: lt,
        listingId: lid,
        providerId: pid,
        userId: uid,
        slotId,
        startISO,
        endISO,
        peopleCount: peopleCount ?? 1,
        totalAmount: totalAmount ?? 0,
        currency: (currency || "eur").toLowerCase(),
        notes: notes ?? null,
        status: "pending_payment",
        payoutStatus: "not_scheduled", // not_scheduled | pending | paid
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        verified: true,
      });
    });

    return { bookingId: bookingRef.id };
  }
);

/* =======================
   PAYMENTINTENT: CREATE ON "PAY NOW" (CALLABLE)
   - Reads amount/currency from booking (anti-tampering)
   - Charges customer on PLATFORM account
   - Stores PI + client_secret on booking
======================= */

exports.createPaymentIntent = onCall(
  { region: REGION, secrets: [STRIPE_SECRET_KEY] },
  async (request) => {
    if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Login required");
    const uid = request.auth.uid;

    const { bookingId } = request.data || {};
    if (!bookingId) throw new HttpsError("invalid-argument", "Missing bookingId");

    const stripe = stripeClient();
    const db = admin.firestore();
    const bookingRef = db.collection("bookings").doc(bookingId);
    const bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) throw new HttpsError("not-found", "Booking not found");
    const booking = bookingSnap.data() || {};

    if (booking.userId !== uid) throw new HttpsError("permission-denied", "Not your booking");

    if (!["pending_payment", "payment_failed"].includes(booking.status)) {
      throw new HttpsError("failed-precondition", "Booking not pending payment");
    }

    // Ensure seller is Stripe-connected
    const sellerId = booking.providerId || booking.guideId;
    const sellerSnap = await db.collection("users").doc(sellerId).get();
    if (!sellerSnap.exists) throw new HttpsError("not-found", "Seller not found");
    const seller = sellerSnap.data() || {};
    const sellerStripeAccountId = seller.stripeAccountId;
    if (!sellerStripeAccountId) {
      throw new HttpsError("failed-precondition", "Seller has not connected Stripe (stripeAccountId missing)");
    }

    const amount = Number(booking.totalAmount || 0); // cents
    const currency = String(booking.currency || "eur").toLowerCase();
    if (!amount || amount <= 0) throw new HttpsError("invalid-argument", "Invalid booking amount");

    // Commission based on seller tier at time of booking
    const pct = commissionPercentForTier(seller.sellerTier);
    const feeAmount = Math.round((amount * pct) / 100);
    const sellerNet = Math.max(0, amount - feeAmount);

    // Idempotency: reuse existing PI if already created
    if (booking.paymentIntentId && booking.paymentIntentClientSecret) {
      return {
        paymentIntentId: booking.paymentIntentId,
        clientSecret: booking.paymentIntentClientSecret,
        currency,
        amount,
        commissionPercent: pct,
        applicationFeeAmount: feeAmount,
        sellerNetAmount: sellerNet,
      };
    }

    const pi = await stripe.paymentIntents.create({
      amount,
      currency,
      automatic_payment_methods: { enabled: true },
      // No transfer_data here: we will transfer after tour completion.
      metadata: {
        bookingId,
        tourId: booking.tourId,
        buyerUid: uid,
        sellerUid: sellerId,
        sellerStripeAccountId,
        commissionPercent: String(pct),
        feeAmount: String(feeAmount),
      },
    });

    await bookingRef.set(
      {
        paymentIntentId: pi.id,
        paymentIntentClientSecret: pi.client_secret,
        commissionPercent: pct,
        applicationFeeAmount: feeAmount,
        sellerNetAmount: sellerNet,
        status: "payment_intent_created",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      paymentIntentId: pi.id,
      clientSecret: pi.client_secret,
      currency,
      amount,
      commissionPercent: pct,
      applicationFeeAmount: feeAmount,
      sellerNetAmount: sellerNet,
    };
  }
);

/* =======================
   PAYOUT RELEASE (CALLABLE)
   - After tour/experience completion
   - Creates a Stripe Transfer to the seller's Connect Express account
   - Idempotent via booking.transferId
======================= */

exports.requestPayoutAfterCompletion = onCall(
  { region: REGION, secrets: [STRIPE_SECRET_KEY] },
  async (request) => {
    if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Login required");
    const uid = request.auth.uid;
    const { bookingId } = request.data || {};
    if (!bookingId) throw new HttpsError("invalid-argument", "Missing bookingId");

    const db = admin.firestore();
    const bookingRef = db.collection("bookings").doc(bookingId);
    const bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) throw new HttpsError("not-found", "Booking not found");
    const booking = bookingSnap.data() || {};

    const sellerId = booking.providerId || booking.guideId;
    if (sellerId !== uid) throw new HttpsError("permission-denied", "Not your booking");

    if (booking.status !== "confirmed") {
      throw new HttpsError("failed-precondition", "Booking not confirmed");
    }

    // Validate completion
    const endISO = booking.endISO;
    const end = endISO ? new Date(endISO) : null;
    if (!end || isNaN(end.getTime())) throw new HttpsError("failed-precondition", "Missing booking end time");
    if (end.getTime() > Date.now()) throw new HttpsError("failed-precondition", "Booking not completed yet");

    if (booking.transferId) {
      return { transferId: booking.transferId, alreadyDone: true };
    }

    // Ensure seller has connected Stripe
    const sellerSnap = await db.collection("users").doc(sellerId).get();
    if (!sellerSnap.exists) throw new HttpsError("not-found", "Seller not found");
    const seller = sellerSnap.data() || {};
    const destination = seller.stripeAccountId;
    if (!destination) throw new HttpsError("failed-precondition", "Seller has not connected Stripe");

    const amount = Number(booking.sellerNetAmount ?? (Number(booking.totalAmount || 0) - Number(booking.applicationFeeAmount || 0)));
    const currency = String(booking.currency || "eur").toLowerCase();
    if (!amount || amount <= 0) throw new HttpsError("invalid-argument", "Invalid payout amount");

    const stripe = stripeClient();
    const transfer = await stripe.transfers.create({
      amount,
      currency,
      destination,
      metadata: {
        bookingId,
        sellerUid: sellerId,
        paymentIntentId: booking.paymentIntentId || "",
      },
    });

    await bookingRef.set(
      {
        transferId: transfer.id,
        payoutReleasedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return { transferId: transfer.id, alreadyDone: false };
  }
);

/* =======================
   LIST PAYOUTS (CALLABLE)
   - Returns recent payouts on the seller's connected account
======================= */

exports.listStripePayouts = onCall(
  { region: REGION, secrets: [STRIPE_SECRET_KEY] },
  async (request) => {
    if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Login required");
    const uid = request.auth.uid;
    const limit = Math.min(100, Math.max(1, Number(request.data?.limit || 30)));

    const db = admin.firestore();
    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) throw new HttpsError("not-found", "User not found");
    const user = userSnap.data() || {};
    const acct = user.stripeAccountId;
    if (!acct) throw new HttpsError("failed-precondition", "stripeAccountId missing. Connect Stripe first.");

    const stripe = stripeClient();
    const resp = await stripe.payouts.list({ limit }, { stripeAccount: acct });
    const payouts = (resp.data || []).map((p) => ({
      id: p.id,
      amount: p.amount,
      currency: p.currency,
      arrival_date: p.arrival_date,
      status: p.status,
    }));

    return { payouts };
  }
);

/* =======================
   CANCELLATION (CALLABLE)
   - Uses per-listing custom policy stored on tours/{tourId}.cancellationPolicy
   - Refunds full/partial if eligible (before payout)
   - Releases slot
======================= */

exports.cancelBooking = onCall(
  { region: REGION, secrets: [STRIPE_SECRET_KEY] },
  async (request) => {
    if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Login required");
    const uid = request.auth.uid;
    const { bookingId } = request.data || {};
    if (!bookingId) throw new HttpsError("invalid-argument", "Missing bookingId");

    const stripe = stripeClient();
    const db = admin.firestore();
    const bookingRef = db.collection("bookings").doc(bookingId);
    const bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) throw new HttpsError("not-found", "Booking not found");
    const booking = bookingSnap.data() || {};

    const isBuyer = booking.userId === uid;
    const isSeller = (booking.providerId || booking.guideId) === uid;
    const isAdmin = await isAdminUid(uid);
    if (!isBuyer && !isSeller && !isAdmin) throw new HttpsError("permission-denied", "Not allowed");

    const slotRef = db.collection("availability").doc(booking.slotId);

    // Load listing policy (Tours + Experiences)
    const listingType = String(booking.listingType || "tour").toLowerCase();
    const listingId = booking.listingId || booking.tourId;
    const col = listingType === "experience" ? "experiences" : "tours";
    const listingSnap = await db.collection(col).doc(listingId).get();
    const listing = listingSnap.exists ? listingSnap.data() : null;
    const policy = listing?.cancellationPolicy || null;

    const start = parseIsoToDate(booking.startISO);
    const now = new Date();
    const refundPercent = computeRefundPercent(policy, start, now);

    // If already paid out, cancellation should typically be blocked or require admin.
    // We'll allow admin override here; for user/seller we block if payout was completed.
    if (booking.payoutStatus === "paid" && !isAdmin) {
      throw new HttpsError("failed-precondition", "Cannot cancel after payout. Contact support.");
    }

    // If payment was never made, just cancel and release slot
    const payableStatuses = ["pending_payment", "payment_failed", "payment_intent_created"];
    if (payableStatuses.includes(booking.status)) {
      await db.runTransaction(async (tx) => {
        tx.set(bookingRef, { status: "canceled", canceledAt: admin.firestore.FieldValue.serverTimestamp(), refundPercentApplied: 0 }, { merge: true });
        tx.set(slotRef, { status: "available", isReserved: false, reservedBy: null, bookingId: null }, { merge: true });
      });
      return { canceled: true, refunded: false, refundPercent: 0 };
    }

    // Paid/confirmed hold: process refund if eligible and not paid out
    let refunded = false;
    if (refundPercent > 0 && booking.paymentIntentId) {
      const amount = Number(booking.totalAmount || 0);
      const refundAmount = Math.floor((amount * refundPercent) / 100);
      if (refundAmount > 0) {
        await stripe.refunds.create({
          payment_intent: booking.paymentIntentId,
          amount: refundAmount,
          reason: "requested_by_customer",
          metadata: { bookingId, refundPercent: String(refundPercent) },
        });
        refunded = true;
      }
    }

    // If there was a transfer already (admin-only case), attempt reversal
    if (booking.transferId && isAdmin) {
      try {
        await stripe.transfers.createReversal(booking.transferId, { amount: booking.sellerNetAmount || undefined });
      } catch (e) {
        logger.warn("Transfer reversal failed", e);
      }
    }

    await db.runTransaction(async (tx) => {
      tx.set(
        bookingRef,
        {
          status: "canceled",
          canceledAt: admin.firestore.FieldValue.serverTimestamp(),
          refundPercentApplied: refundPercent,
          refunded,
          payoutStatus: "not_scheduled",
        },
        { merge: true }
      );
      tx.set(slotRef, { status: "available", isReserved: false, reservedBy: null, bookingId: null }, { merge: true });
    });

    return { canceled: true, refunded, refundPercent };
  }
);

/* =======================
   REVIEWS (CALLABLE v2)
   - one review per booking
   - updates aggregates for listing (tour/experience) and provider (guide/host)
======================= */

exports.addReview = onCall(
  { region: "europe-west1", memory: "256MiB" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const uid = request.auth.uid;
    const { bookingId, rating, comment } = request.data || {};
    if (!bookingId) throw new HttpsError("invalid-argument", "Missing bookingId");
    const stars = Math.max(1, Math.min(5, parseInt(rating || 0, 10)));

    const db = admin.firestore();
    const bookingRef = db.collection("bookings").doc(bookingId);
    const reviewsCol = db.collection("reviews");

    // Helper for running average
    function applyAvg(prevAvg, prevCount, newValue) {
      const c = prevCount || 0;
      const a = prevAvg || 0;
      const nextCount = c + 1;
      const nextAvg = (a * c + newValue) / nextCount;
      return { nextAvg, nextCount };
    }

    // Bayesian / weighted score to prevent a single 5-star review from dominating.
    const GLOBAL_PRIOR_AVG = 4.5;
    const GLOBAL_PRIOR_COUNT = 10;
    function bayesianScore(avg, count) {
      const a = avg || 0;
      const v = count || 0;
      const m = GLOBAL_PRIOR_COUNT;
      const C = GLOBAL_PRIOR_AVG;
      return ((v / (v + m)) * a) + ((m / (v + m)) * C);
    }

    // ISO week key (Mon-start) for "Top rated this week"
    function isoWeekKeyNow() {
      const d = new Date();
      const date = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
      const dayNum = date.getUTCDay() || 7;
      date.setUTCDate(date.getUTCDate() + 4 - dayNum);
      const yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
      const weekNo = Math.ceil((((date - yearStart) / 86400000) + 1) / 7);
      return `${date.getUTCFullYear()}-W${String(weekNo).padStart(2, '0')}`;
    }

// We do everything in a transaction so duplicates can't sneak in.
    return await db.runTransaction(async (tx) => {
      const bookingSnap = await tx.get(bookingRef);
      if (!bookingSnap.exists) throw new HttpsError("not-found", "Booking not found");
      const booking = bookingSnap.data() || {};
      if (booking.userId !== uid) throw new HttpsError("permission-denied", "Not your booking");
      // App may mark successful payments as "paid" or "completed".
      const okStatuses = new Set(["confirmed", "paid", "completed"]);
      if (!okStatuses.has(String(booking.status || "").toLowerCase())) {
        throw new HttpsError("failed-precondition", "Only paid/confirmed bookings can be reviewed");
      }

      // Optional: only after end time
      const endISO = booking.endISO;
      if (endISO) {
        const end = new Date(endISO);
        if (!isNaN(end.getTime()) && end.getTime() > Date.now()) {
          throw new HttpsError("failed-precondition", "You can review after the session ends");
        }
      }

      // Ensure no existing review for this booking.
      // IMPORTANT: Firestore transactions in the Admin SDK do not reliably support `tx.get(query)`.
      // Use a deterministic doc id (bookingId) instead.
      const reviewRef = reviewsCol.doc(bookingId);
      const existingReview = await tx.get(reviewRef);
      if (existingReview.exists) {
        throw new HttpsError("already-exists", "Review already exists for this booking");
      }

      const listingType = (booking.listingType || "tour").toLowerCase();
      const listingId = booking.listingId || booking.tourId;
      const providerId = booking.providerId || booking.guideId;
      const providerRole = listingType === "experience" ? "host" : "guide";

      // Store review at reviews/{bookingId}
      tx.set(reviewRef, {
        id: bookingId,
        bookingId,
        userId: uid,
        listingType,
        listingId,
        providerId,
        providerRole,
        rating: stars,
        comment: (comment || "").toString().slice(0, 2000),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        verified: true,
      });

      // Update listing aggregates
      const listingRef = listingType === "experience"
        ? db.collection("experiences").doc(listingId)
        : db.collection("tours").doc(listingId);
      const listingSnap = await tx.get(listingRef);
      if (listingSnap.exists) {
        const d = listingSnap.data() || {};
        const { nextAvg, nextCount } = applyAvg(d.ratingAvg, d.ratingCount, stars);
        const weightedScore = bayesianScore(nextAvg, nextCount);

        const wk = isoWeekKeyNow();
        let weekAvg = stars;
        let weekCount = 1;
        if (d.weekKey === wk) {
          const r = applyAvg(d.weeklyRatingAvg, d.weeklyRatingCount, stars);
          weekAvg = r.nextAvg;
          weekCount = r.nextCount;
        }
        const weeklyScore = bayesianScore(weekAvg, weekCount);

        tx.set(
          listingRef,
          {
            ratingAvg: nextAvg,
            ratingCount: nextCount,
            weightedScore,
            weekKey: wk,
            weeklyRatingAvg: weekAvg,
            weeklyRatingCount: weekCount,
            weeklyScore,
            lastReviewAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      // Update provider aggregates
      const providerRef = providerRole === "host"
        ? db.collection("hosts").doc(providerId)
        : db.collection("guides").doc(providerId);
      const providerSnap = await tx.get(providerRef);
      if (providerSnap.exists) {
        const d = providerSnap.data() || {};
        const { nextAvg, nextCount } = applyAvg(d.ratingAvg, d.ratingCount, stars);
        const weightedScore = bayesianScore(nextAvg, nextCount);

        const wk = isoWeekKeyNow();
        let weekAvg = stars;
        let weekCount = 1;
        if (d.weekKey === wk) {
          const r = applyAvg(d.weeklyRatingAvg, d.weeklyRatingCount, stars);
          weekAvg = r.nextAvg;
          weekCount = r.nextCount;
        }
        const weeklyScore = bayesianScore(weekAvg, weekCount);

        tx.set(
          providerRef,
          {
            ratingAvg: nextAvg,
            ratingCount: nextCount,
            weightedScore,
            weekKey: wk,
            weeklyRatingAvg: weekAvg,
            weeklyRatingCount: weekCount,
            weeklyScore,
            lastReviewAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      return { reviewId: bookingId };
    });
  }
);

exports.adminOverrideCancel = onCall(
  { region: REGION, secrets: [STRIPE_SECRET_KEY] },
  async (request) => {
    if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Login required");
    const uid = request.auth.uid;
    if (!(await isCallerAdmin(uid))) throw new HttpsError("permission-denied", "Admin only");

    const { bookingId, refundPercent } = request.data || {};
    if (!bookingId) throw new HttpsError("invalid-argument", "Missing bookingId");
    const pct = Math.max(0, Math.min(100, Number(refundPercent ?? 0)));

    const stripe = stripeClient();
    const db = admin.firestore();

    const bookingRef = db.collection("bookings").doc(bookingId);
    const bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) throw new HttpsError("not-found", "Booking not found");
    const booking = bookingSnap.data() || {};

    let refunded = false;
    if (pct > 0 && booking.paymentIntentId) {
      const amount = Number(booking.totalAmount || 0);
      const refundAmount = Math.floor((amount * pct) / 100);
      if (refundAmount > 0) {
        await stripe.refunds.create({
          payment_intent: booking.paymentIntentId,
          amount: refundAmount,
          reason: "requested_by_customer",
          metadata: { bookingId, adminOverride: "true", refundPercent: String(pct) },
        });
        refunded = true;
      }
    }

    if (booking.transferId) {
      try {
        await stripe.transfers.createReversal(booking.transferId, { amount: booking.sellerNetAmount || undefined });
      } catch (e) {
        logger.warn("Transfer reversal failed", e);
      }
    }

    await db.runTransaction(async (tx) => {
      tx.set(
        bookingRef,
        {
          status: "canceled_admin",
          canceledAt: admin.firestore.FieldValue.serverTimestamp(),
          refundPercentApplied: pct,
          refunded,
          payoutStatus: "not_scheduled",
          adminOverrideBy: uid,
        },
        { merge: true }
      );
      tx.set(db.collection("availability").doc(booking.slotId), { status: "available", isReserved: false, reservedBy: null, bookingId: null }, { merge: true });
    });

    return { canceled: true, refunded, refundPercent: pct };
  }
);

/* =======================
   ADMIN: SET ADMIN ROLE (CALLABLE)
   - Requires caller to be admin (custom claim OR Firestore role)
   - Sets custom claim { role: 'admin', admin: true }
   - Ensures Firestore users/{uid}.role === 'admin'
======================= */
exports.setAdminRole = onCall({ region: REGION }, async (request) => {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Login required");
  const callerUid = request.auth.uid;
  if (!(await isCallerAdmin(callerUid))) throw new HttpsError("permission-denied", "Admin only");

  const { targetUid, targetEmail } = request.data || {};
  if (!targetUid && !targetEmail) {
    throw new HttpsError("invalid-argument", "Provide targetUid or targetEmail");
  }

  let uid = targetUid;
  if (!uid) {
    const email = String(targetEmail || "").trim().toLowerCase();
    if (!email) throw new HttpsError("invalid-argument", "Invalid targetEmail");
    try {
      const u = await admin.auth().getUserByEmail(email);
      uid = u.uid;
    } catch (e) {
      logger.warn("getUserByEmail failed", e);
      throw new HttpsError("not-found", "No auth user found for that email");
    }
  }

  // 1) Set custom claims
  try {
    const user = await admin.auth().getUser(uid);
    const existing = user.customClaims || {};
    const nextClaims = { ...existing, role: "admin", admin: true };
    await admin.auth().setCustomUserClaims(uid, nextClaims);
  } catch (e) {
    logger.error("Failed to set custom claims", e);
    throw new HttpsError("internal", "Failed to set admin custom claims");
  }

  // 2) Ensure Firestore role
  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);
  await userRef.set(
    {
      role: "admin",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return { ok: true, uid };
});

/* =======================
   PAYOUT JOB (SCHEDULED)
   - Finds paid bookings whose end time has passed
   - Creates Stripe Transfer to connected account
   - Marks booking payoutStatus=paid
======================= */

exports.payoutCompletedBookings = onSchedule(
  {
    region: REGION,
    secrets: [STRIPE_SECRET_KEY],
    schedule: "every 15 minutes",
  },
  async () => {
    const stripe = stripeClient();
    const db = admin.firestore();

    const bufferMin = Number(PAYOUT_BUFFER_MINUTES.value() || "60");
    const now = new Date(Date.now() - bufferMin * 60 * 1000);

    // We store endISO as a string. For efficient querying, the app should also store endAt (Timestamp).
    // As a safe fallback, we scan a limited window of bookings and filter in memory.
    const snap = await db
      .collection("bookings")
      .where("status", "==", "paid_hold")
      .where("payoutStatus", "in", ["not_scheduled", "pending"])
      .limit(200)
      .get();

    if (snap.empty) return;

    for (const doc of snap.docs) {
      const booking = doc.data() || {};
      try {
        const end = parseIsoToDate(booking.endISO);
        if (end > now) continue;

        if (booking.payoutStatus === "paid") continue;
        if (!booking.sellerStripeAccountId || !booking.sellerNetAmount || !booking.chargeId) continue;

        // Mark pending to avoid double transfer under concurrency
        await doc.ref.set({ payoutStatus: "pending", payoutUpdatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });

        // Create transfer linked to the original charge
        const transfer = await stripe.transfers.create({
          amount: Number(booking.sellerNetAmount),
          currency: String(booking.currency || "eur").toLowerCase(),
          destination: booking.sellerStripeAccountId,
          source_transaction: booking.chargeId,
          metadata: { bookingId: booking.id || doc.id, tourId: booking.tourId || "" },
        });

        await doc.ref.set(
          {
            payoutStatus: "paid",
            transferId: transfer.id,
            paidOutAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      } catch (e) {
        logger.error("payoutCompletedBookings failed for booking", doc.id, e);
        // leave it as pending/not_scheduled; it will retry
        await doc.ref.set({ payoutStatus: "not_scheduled" }, { merge: true });
      }
    }
  }
);

/* =======================
   STRIPE WEBHOOK (HTTP v2)
   - Updates seller tiers on subscription changes
   - Marks booking paid_hold on payment_intent.succeeded
======================= */

exports.stripeWebhook = onRequest(
  { region: REGION, secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async (req, res) => {
    const stripe = stripeClient();
    const webhookSecret = STRIPE_WEBHOOK_SECRET.value();
    if (!webhookSecret) return res.status(400).send("Missing STRIPE_WEBHOOK_SECRET");

    let event;
    try {
      const sig = req.headers["stripe-signature"];
      event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
    } catch (err) {
      logger.error("Webhook signature verification failed", err);
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    const db = admin.firestore();

    try {
      const obj = event.data.object;

      // Seller subscription tier changes
      if (
        event.type === "customer.subscription.created" ||
        event.type === "customer.subscription.updated" ||
        event.type === "customer.subscription.deleted"
      ) {
        const uid = obj.metadata?.uid;

        if (uid) {
          const patch = {
            sellerTier: obj.metadata?.tier || undefined,
            sellerRole: obj.metadata?.role || undefined,
            sellerCurrency: obj.metadata?.currency || undefined,
            subscriptionStatus: obj.status,
            stripeSubscriptionId: obj.id,
            currentPeriodEnd: obj.current_period_end ? new Date(obj.current_period_end * 1000) : null,
          };

          if (event.type === "customer.subscription.deleted") {
            patch.sellerTier = "free";
            patch.subscriptionStatus = "canceled";
          }

          await db.collection("users").doc(uid).set(patch, { merge: true });
        }
      }

      // Checkout completion (subscription)
      if (event.type === "checkout.session.completed") {
        const session = obj;
        const uid = session.metadata?.uid;
        if (uid) {
          await db.collection("users").doc(uid).set(
            {
              lastCheckoutSessionId: session.id,
              lastCheckoutAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        }
      }

      // Booking payment succeeded
      if (event.type === "payment_intent.succeeded") {
        const pi = obj;
        const bookingId = pi.metadata?.bookingId;
        if (bookingId) {
          const chargeId = pi.charges?.data?.[0]?.id || null;
          const sellerStripeAccountId = pi.metadata?.sellerStripeAccountId || null;
          const commissionPercent = Number(pi.metadata?.commissionPercent || 0);
          const feeAmount = Number(pi.metadata?.feeAmount || 0);

          await db.collection("bookings").doc(bookingId).set(
            {
              status: "paid_hold",
              paidAt: admin.firestore.FieldValue.serverTimestamp(),
              chargeId,
              sellerStripeAccountId,
              commissionPercent,
              applicationFeeAmount: feeAmount,
              payoutStatus: "not_scheduled",
            },
            { merge: true }
          );
        }
      }

      // Booking payment failed (allow retry)
      if (event.type === "payment_intent.payment_failed") {
        const pi = obj;
        const bookingId = pi.metadata?.bookingId;
        if (bookingId) {
          await db.collection("bookings").doc(bookingId).set(
            {
              status: "payment_failed",
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        }
      }

      return res.json({ received: true });
    } catch (e) {
      logger.error("stripeWebhook failed", e);
      return res.status(500).send(e?.message || "Webhook processing failed");
    }
  }
);

/* =======================
   AI TRIP DESIGNER (CALLABLE v2)

   Server-side OpenAI call. Never expose API keys in iOS client.
======================= */

async function openAIResponsesJSON({ model, input, schema }) {
  const apiKey = OPENAI_API_KEY.value();
  if (!apiKey) throw new Error("Missing secret OPENAI_API_KEY");

  const body = {
    model,
    input,
    // Ask the model to return a strict JSON object matching schema.
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "trip_plan",
        schema,
        // In production we prefer "strict", but occasional minor schema deviations
        // (extra keys, number-as-string, etc.) can cause hard failures that bubble up
        // to the client as INTERNAL. We keep schema guidance but allow slight drift.
        strict: false,
      },
    },
  };

  const resp = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!resp.ok) {
    const t = await resp.text();
    throw new Error(`OpenAI error ${resp.status}: ${t}`);
  }

  const json = await resp.json();

  // Best-effort extraction for the Responses API. Depending on model/version,
  // JSON may appear in different slots.
  const direct = json?.output?.[0]?.content?.find?.((c) => c?.json)?.json
    ?? json?.output?.[0]?.content?.[0]?.json;
  if (direct && typeof direct === "object") return direct;

  const txt = json?.output_text
    ?? json?.output?.[0]?.content?.find?.((c) => c?.type === "output_text")?.text
    ?? json?.output?.[0]?.content?.[0]?.text;

  if (typeof txt === "string" && txt.trim().length > 0) {
    // Try plain JSON parse first.
    try {
      return JSON.parse(txt);
    } catch (_) {
      // Attempt to extract the first JSON object from a mixed response.
      const start = txt.indexOf("{");
      const end = txt.lastIndexOf("}");
      if (start >= 0 && end > start) {
        const slice = txt.slice(start, end + 1);
        return JSON.parse(slice);
      }
    }
  }

  throw new Error("OpenAI response missing JSON output");
}

exports.generateTripPlan = onCall(
  { region: REGION, secrets: [OPENAI_API_KEY] },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const uid = request.auth.uid;
    const data = request.data || {};
    const {
      country,
      city,
      startDateISO,
      endDateISO,
      interests,
      budgetPerDay,
      pace,
      groupSize,
      languageCode,
      notes,
    } = data;

    if (!city || !country || !startDateISO || !endDateISO) {
      throw new HttpsError("invalid-argument", "Missing country/city/startDateISO/endDateISO");
    }

    const db = admin.firestore();

    // Minimal schema the app can render safely.
    const schema = {
      type: "object",
      additionalProperties: false,
      properties: {
        title: { type: "string" },
        summary: { type: "string" },
        days: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            properties: {
              dateISO: { type: "string" },
              theme: { type: "string" },
              items: {
                type: "array",
                items: {
                  type: "object",
                  additionalProperties: false,
                  properties: {
                    time: { type: "string" },
                    title: { type: "string" },
                    description: { type: "string" },
                    neighborhood: { type: "string" },
                    estimatedCost: { type: "number" },
                    bookingHint: { type: "string" },
                  },
                  required: ["time", "title", "description"],
                },
              },
            },
            required: ["dateISO", "items"],
          },
        },
        budgetNotes: { type: "string" },
      },
      required: ["title", "summary", "days"],
    };

    const lang = languageCode === "ro" ? "Romanian" : "English";
    const user = await db.collection("users").doc(uid).get();
    const fullName = user.exists ? user.data()?.fullName : "";

    const prompt = `You are a premium travel planner for a local experiences marketplace.
Create a day-by-day itinerary for ${fullName || "the traveler"} visiting ${city}, ${country}.
Dates: ${startDateISO} to ${endDateISO}.
Interests: ${Array.isArray(interests) ? interests.join(", ") : ""}.
Pace: ${pace || "balanced"}. Group size: ${groupSize || 1}. Budget per day: ${budgetPerDay || "unspecified"}.
Extra notes: ${notes || ""}.

Output must be in ${lang}. Use realistic neighborhoods/areas and include booking hints like: "Book a certified guide in-app" or "Book a host experience in-app".
Do not include any URLs.
Return ONLY valid JSON that matches the provided schema.`;

    let plan;
    try {
      // Use a widely available mini model. If your OpenAI project doesn't have
      // access to a newer model name, the fallback will try an alternative.
      plan = await openAIResponsesJSON({
        model: "gpt-4o-mini",
        input: [{ role: "user", content: [{ type: "text", text: prompt }] }],
        schema,
      });
    } catch (e) {
      const msg = String(e?.message || e);
      // Retry once with the other model name used previously.
      try {
        plan = await openAIResponsesJSON({
          model: "gpt-4.1-mini",
          input: [{ role: "user", content: [{ type: "text", text: prompt }] }],
          schema,
        });
      } catch (e2) {
        const msg2 = String(e2?.message || e2);
        logger.error("generateTripPlan failed", { first: msg, second: msg2 });
        if (msg2.includes("Missing secret OPENAI_API_KEY")) {
          throw new HttpsError("failed-precondition", "AI Trip Planner is not configured (missing OPENAI_API_KEY secret)");
        }
        throw new HttpsError("internal", `AI Trip Planner failed: ${msg2}`);
      }
    }

    const ref = db.collection("tripPlans").doc();
    await ref.set({
      id: ref.id,
      uid,
      country,
      city,
      startDateISO,
      endDateISO,
      interests: Array.isArray(interests) ? interests : [],
      budgetPerDay: budgetPerDay ?? null,
      pace: pace ?? null,
      groupSize: groupSize ?? null,
      languageCode: languageCode ?? "en",
      plan,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { tripPlanId: ref.id, plan };
  }
);
