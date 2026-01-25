import Foundation
import FirebaseFirestore
import FirebaseAuth

final class FirestoreService {
    static let shared = FirestoreService()
    private let db = FirebaseManager.shared.db
    private init() {}

    private var usersCol: CollectionReference { db.collection("users") }
    private var guidesCol: CollectionReference { db.collection("guides") }
    private var hostsCol: CollectionReference { db.collection("hosts") }
    private var toursCol: CollectionReference { db.collection("tours") }
    private var experiencesCol: CollectionReference { db.collection("experiences") }
    private var bookingsCol: CollectionReference { db.collection("bookings") }
    private var reviewsCol: CollectionReference { db.collection("reviews") }
    private var configCol: CollectionReference { db.collection("config") }
    private var availabilityCol: CollectionReference { db.collection("availability") }
    private var threadsCol: CollectionReference { db.collection("threads") }
    private var postsCol: CollectionReference { db.collection("posts") }
    private var postCommentsCol: CollectionReference { db.collection("postComments") }
    private var postReportsCol: CollectionReference { db.collection("postReports") }
    private var tripPlansCol: CollectionReference { db.collection("tripPlans") }

    // Firestore doc ids are migrated to use lowercased email where possible.
    private func emailKey(_ email: String?) -> String? {
        guard let e = email?.trimmingCharacters(in: .whitespacesAndNewlines), !e.isEmpty else { return nil }
        return e.lowercased()
    }

    // MARK: Users
    func createUser(_ user: AppUser) async throws {
        var u = user
        // Prefer email-keyed docs.
        let docId = emailKey(u.email) ?? u.id
        if u.id != docId { u.id = docId }
        try usersCol.document(docId).setData(from: u, merge: true)
        // Keep the auth uid for lookups/back-compat.
        if let uid = Auth.auth().currentUser?.uid {
            try? await usersCol.document(docId).setData(["uid": uid], merge: true)
        }
    }

    /// Load user by doc id (email-key) or fallback lookup by auth uid.
    func getUserByAuth(uid: String, email: String?) async throws -> AppUser {
        if let key = emailKey(email) {
            let snap = try await usersCol.document(key).getDocument()
            if snap.exists, let decoded = try snap.data(as: AppUser?.self) {
                var fixed = decoded
                if fixed.id.isEmpty { fixed.id = key }
                return fixed
            }
        }
        // Fallback: old uid doc id
        do {
            return try await getUser(docId: uid)
        } catch {
            // Fallback: query by stored uid field
            let q = try await usersCol.whereField("uid", isEqualTo: uid).limit(to: 1).getDocuments()
            if let doc = q.documents.first {
                return try doc.data(as: AppUser.self)
            }
            throw error
        }
    }

    func getUser(uid: String) async throws -> AppUser {
        // Backwards compatible API (treat param as auth uid)
        return try await getUserByAuth(uid: uid, email: nil)
    }

    func getUser(docId: String) async throws -> AppUser {
        let snap = try await usersCol.document(docId).getDocument()
        guard let decoded = try snap.data(as: AppUser?.self) else {
            throw NSError(domain: "AppUser", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        // Older docs may not store the id field. Always fall back to the document id.
        if decoded.id.isEmpty {
            var fixed = decoded
            fixed.id = docId
            // Best-effort patch so next loads are correct.
            try? await usersCol.document(docId).setData(["id": docId], merge: true)
            return fixed
        }
        return decoded
    }

    /// Ensures an AppUser document exists. If missing, creates a minimal one.
    /// Useful for accounts created in Firebase Auth without a corresponding Firestore user document.
    func getOrCreateUser(uid: String, email: String?, roleHint: UserRole = .traveler) async throws -> AppUser {
        let key = emailKey(email) ?? uid
        let emailRef = usersCol.document(key)
        let emailSnap = try await emailRef.getDocument()
        if emailSnap.exists {
            var u = try emailSnap.data(as: AppUser.self)
            if u.id.isEmpty { u.id = key }
            // Ensure uid is present for fallback lookups.
            try? await emailRef.setData(["uid": uid], merge: true)
            return u
        }

        // If an old uid-keyed doc exists, migrate it to email-keyed doc.
        let uidRef = usersCol.document(uid)
        let uidSnap = try await uidRef.getDocument()
        if uidSnap.exists, let old = try uidSnap.data(as: AppUser?.self) {
            var migrated = old
            migrated.id = key
            migrated.email = email ?? migrated.email
            try emailRef.setData(from: migrated, merge: true)
            try? await emailRef.setData(["uid": uid], merge: true)
            try? await uidRef.delete()
            return migrated
        }

        let newUser = AppUser(
            id: key,
            email: email,
            fullName: "",
            preferredLanguageCode: "en",
            role: roleHint,
            subscriptionPlan: .freeAds,
            guideProfileCreated: roleHint == .guide ? false : nil,
            guideApproved: roleHint == .guide ? false : nil,
            hostApproved: roleHint == .host ? false : nil,
            disabled: false,
            createdAt: Date()
        )
        try emailRef.setData(from: newUser, merge: true)
        try? await emailRef.setData(["uid": uid], merge: true)
        return newUser
    }

    func updateUser(uid: String, fields: [String: Any]) async throws {
        // `uid` parameter is treated as doc id if it contains '@' else auth uid.
        if uid.contains("@") {
            try await usersCol.document(uid.lowercased()).updateData(fields)
            return
        }
        if let email = Auth.auth().currentUser?.email, let key = emailKey(email) {
            try await usersCol.document(key).updateData(fields)
            return
        }
        try await usersCol.document(uid).updateData(fields)
    }

    func listUsers(limit: Int = 200) async throws -> [AppUser] {
        let snap = try await usersCol.order(by: "createdAt", descending: true).limit(to: limit).getDocuments()
        return try snap.documents.compactMap { try $0.data(as: AppUser.self) }
    }

    // MARK: Guide profile
    func createGuideProfile(_ profile: GuideProfile) async throws {
        try guidesCol.document(profile.id).setData(from: profile, merge: true)
        try await usersCol.document(profile.id).setData([
            "guideProfileCreated": true
        ], merge: true)
    }

    
    func getGuideProfile(guideEmail: String) async throws -> GuideProfile {
        let snap = try await guidesCol.document(guideEmail).getDocument()
        guard let profile = try snap.data(as: GuideProfile?.self) else {
            throw NSError(domain: "GuideProfile", code: 404, userInfo: [NSLocalizedDescriptionKey: "Guide profile not found"])
        }
        return profile
    }


func updateGuideProfile(_ profile: GuideProfile) async throws {
    try guidesCol.document(profile.id).setData(from: profile, merge: true)
}


    // MARK: Host profile
    func createHostProfile(_ profile: HostProfile) async throws {
        try hostsCol.document(profile.id).setData(from: profile, merge: true)
        // mark in user doc for easier gating/admin lists
        try await usersCol.document(profile.id).setData([
            "hostProfileCreated": true
        ], merge: true)
    }

    func getHostProfile(hostEmail: String) async throws -> HostProfile {
        let snap = try await hostsCol.document(hostEmail).getDocument()
        guard let profile = try snap.data(as: HostProfile?.self) else {
            throw NSError(domain: "HostProfile", code: 404, userInfo: [NSLocalizedDescriptionKey: "Host profile not found"])
        }
        return profile
    }

    func updateHostProfile(_ profile: HostProfile) async throws {
        try hostsCol.document(profile.id).setData(from: profile, merge: true)
    }

    func listHosts(limit: Int = 200) async throws -> [HostProfile] {
        let snap = try await hostsCol.order(by: "createdAt", descending: true).limit(to: limit).getDocuments()
        return try snap.documents.compactMap { try $0.data(as: HostProfile.self) }
    }



    func listGuides(limit: Int = 200) async throws -> [GuideProfile] {
        let snap = try await guidesCol.order(by: "createdAt", descending: true).limit(to: limit).getDocuments()
        return try snap.documents.compactMap { try $0.data(as: GuideProfile.self) }
    }

    // MARK: Tours
    func createTour(_ tour: Tour) async throws {
        try toursCol.document(tour.id).setData(from: tour, merge: true)
    }

    func updateTour(tourId: String, fields: [String: Any]) async throws {
        try await toursCol.document(tourId).updateData(fields)
    }

    func getTours(city: String? = nil) async throws -> [Tour] {
        var query: Query = toursCol.whereField("active", isEqualTo: true).order(by: "createdAt", descending: true)
        if let city, !city.isEmpty { query = query.whereField("city", isEqualTo: city) }
        let snap = try await query.getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Tour.self) }
    }

    /// Loads tours within a latitude range (used for map visible-region loading).
    /// Note: This query intentionally does NOT filter by "active" to avoid composite indexes.
    /// Filter "active" client-side.
    func getToursByLatitudeRange(minLat: Double, maxLat: Double, limit: Int = 400) async throws -> [Tour] {
        let snap = try await toursCol
            .whereField("latitude", isGreaterThanOrEqualTo: minLat)
            .whereField("latitude", isLessThanOrEqualTo: maxLat)
            .order(by: "latitude")
            .limit(to: limit)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Tour.self) }
    }

    func getToursForGuide(guideEmail: String) async throws -> [Tour] {
        let snap = try await toursCol.whereField("guideEmail", isEqualTo: guideEmail)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Tour.self) }
    }

    func getTour(tourId: String) async throws -> Tour {
        let doc = try await toursCol.document(tourId).getDocument()
        return try doc.data(as: Tour.self)
    }

    func listTopRatedToursThisWeek(limit: Int = 10) async throws -> [Tour] {
        let snap = try await toursCol
            .whereField("active", isEqualTo: true)
            .order(by: "weeklyScore", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Tour.self) }
    }

    // MARK: Experiences (Hosts)
    func createExperience(_ exp: Experience) async throws {
        try experiencesCol.document(exp.id).setData(from: exp, merge: true)
    }

    func updateExperience(experienceId: String, fields: [String: Any]) async throws {
        try await experiencesCol.document(experienceId).updateData(fields)
    }

    func getExperiences(city: String? = nil) async throws -> [Experience] {
        var query: Query = experiencesCol.whereField("active", isEqualTo: true).order(by: "createdAt", descending: true)
        if let city, !city.isEmpty { query = query.whereField("city", isEqualTo: city) }
        let snap = try await query.getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Experience.self) }
    }

    /// Loads experiences within a latitude range (used for map visible-region loading).
    /// Note: This query intentionally does NOT filter by "active" to avoid composite indexes.
    /// Filter "active" client-side.
    func getExperiencesByLatitudeRange(minLat: Double, maxLat: Double, limit: Int = 400) async throws -> [Experience] {
        let snap = try await experiencesCol
            .whereField("latitude", isGreaterThanOrEqualTo: minLat)
            .whereField("latitude", isLessThanOrEqualTo: maxLat)
            .order(by: "latitude")
            .limit(to: limit)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Experience.self) }
    }

    func getExperiencesForHost(hostEmail: String) async throws -> [Experience] {
        let snap = try await experiencesCol.whereField("hostEmail", isEqualTo: hostEmail)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Experience.self) }
    }

    func getExperience(experienceId: String) async throws -> Experience {
        let doc = try await experiencesCol.document(experienceId).getDocument()
        return try doc.data(as: Experience.self)
    }

    func listTopRatedExperiencesThisWeek(limit: Int = 10) async throws -> [Experience] {
        let snap = try await experiencesCol
            .whereField("active", isEqualTo: true)
            .order(by: "weeklyScore", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Experience.self) }
    }

    // MARK: Bookings
    func createBooking(_ booking: Booking) async throws {
        try bookingsCol.document(booking.id).setData(from: booking, merge: true)
    }

    func getBookingsForUser(userId: String) async throws -> [Booking] {
        let snap = try await bookingsCol.whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Booking.self) }
    }

    // MARK: Trip Plans
    func listTripPlansForUser(uid: String, limit: Int = 20) async throws -> [TripPlan] {
        let snap = try await tripPlansCol
            .whereField("uid", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()

        var out: [TripPlan] = []
        for doc in snap.documents {
            do {
                out.append(try doc.data(as: TripPlan.self))
            } catch {
                // Skip malformed documents rather than breaking the entire list.
                print("Failed to decode trip plan \(doc.documentID): \(error)")
            }
        }
        return out
    }

    func updateTripPlan(tripPlanId: String, fields: [String: Any]) async throws {
        try await tripPlansCol.document(tripPlanId).updateData(fields)
    }

    func getBookingsForGuide(guideEmail: String) async throws -> [Booking] {
        // Prefer unified `providerId` field; fall back to legacy `guideId`.
        async let a = getBookingsForProvider(providerEmail: guideEmail, listingType: "tour")
        let legacy = try await bookingsCol.whereField("guideEmail", isEqualTo: guideEmail)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        var out = try await a
        out.append(contentsOf: try legacy.documents.compactMap { try $0.data(as: Booking.self) })
        // De-dup by id
        var seen = Set<String>()
        out = out.filter { seen.insert($0.id).inserted }
        return out.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    /// Unified marketplace: bookings for a provider (guide/host). Optionally filter by listingType.
    func getBookingsForProvider(providerEmail: String, listingType: String? = nil) async throws -> [Booking] {
        var q: Query = bookingsCol.whereField("providerEmail", isEqualTo: providerEmail)
        if let listingType {
            q = q.whereField("listingType", isEqualTo: listingType)
        }
        let snap = try await q.order(by: "createdAt", descending: true).getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Booking.self) }
    }

    /// Convenience: host bookings (experiences).
    func getBookingsForHost(hostEmail: String) async throws -> [Booking] {
        // Prefer unified `providerId` field; fall back to legacy `hostId`.
        async let a = getBookingsForProvider(providerEmail: hostEmail, listingType: "experience")
        let legacy = try await bookingsCol.whereField("guideEmail", isEqualTo: hostEmail)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        var out = try await a
        out.append(contentsOf: try legacy.documents.compactMap { try $0.data(as: Booking.self) })
        var seen = Set<String>()
        out = out.filter { seen.insert($0.id).inserted }
        return out.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    /// Seller earnings: list bookings for a provider in a month range (client-side summaries / PDFs).
    func getBookingsForProvider(providerEmail: String, from: Date, to: Date, listingType: String? = nil) async throws -> [Booking] {
        // Firestore can't filter on computed dates; we use createdAt for range.
        // For accurate period-by-service-date reporting, store startAt timestamp and filter on that.
        var q: Query = bookingsCol.whereField("providerEmail", isEqualTo: providerEmail)
        if let listingType { q = q.whereField("listingType", isEqualTo: listingType) }
        let snap = try await q
            .whereField("createdAt", isGreaterThanOrEqualTo: from)
            .whereField("createdAt", isLessThanOrEqualTo: to)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Booking.self) }
    }

    /// Admin-only: fetch recent bookings (single-field orderBy, no composite index required).
    func getAllBookings(limit: Int = 500) async throws -> [Booking] {
        let snap = try await bookingsCol
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Booking.self) }
    }

    // MARK: Reviews
    func createReview(_ review: Review) async throws {
        try reviewsCol.document(review.id).setData(from: review, merge: true)
    }

    /// Reviews for a listing (tour or experience).
    func getReviewsForListing(listingType: String, listingId: String, limit: Int = 50) async throws -> [Review] {
        let snap = try await reviewsCol
            .whereField("listingType", isEqualTo: listingType)
            .whereField("listingId", isEqualTo: listingId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Review.self) }
    }

    /// Reviews for a provider (guide or host).
    func getReviewsForProvider(providerEmail: String, limit: Int = 50) async throws -> [Review] {
        let snap = try await reviewsCol
            .whereField("providerEmail", isEqualTo: providerEmail)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Review.self) }
    }

    /// Returns the current user's review for a booking, if any.
    func getReviewForBooking(bookingId: String) async throws -> Review? {
        let snap = try await reviewsCol.whereField("bookingId", isEqualTo: bookingId)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .getDocuments()
        return try snap.documents.first?.data(as: Review.self)
    }

    func getReviewsForTour(tourId: String, limit: Int = 50) async throws -> [Review] {
        try await getReviewsForListing(listingType: "tour", listingId: tourId, limit: limit)
    }

    func getReviewsForGuide(guideEmail: String, limit: Int = 50) async throws -> [Review] {
        try await getReviewsForProvider(providerEmail: guideEmail, limit: limit)
    }

    // MARK: Availability
func createAvailability(_ slot: AvailabilitySlot) async throws {
    try availabilityCol.document(slot.id).setData(from: slot, merge: true)
}

func deleteAvailability(slotId: String) async throws {
    try await availabilityCol.document(slotId).delete()
}

func getAvailabilityForGuide(guideEmail: String, limit: Int = 200) async throws -> [AvailabilitySlot] {
    let snap = try await availabilityCol.whereField("email", isEqualTo: guideEmail)
        .order(by: "start", descending: false)
        .limit(to: limit)
        .getDocuments()
    return try snap.documents.compactMap { try $0.data(as: AvailabilitySlot.self) }
}

    /// Availability slots for a specific listing (tour or experience).
    func getAvailabilityForListing(listingType: String, listingId: String, limit: Int = 200) async throws -> [AvailabilitySlot] {
        let snap = try await availabilityCol
            .whereField("listingType", isEqualTo: listingType)
            .whereField("listingId", isEqualTo: listingId)
            .order(by: "start", descending: false)
            .limit(to: limit)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: AvailabilitySlot.self) }
    }

    /// Next available slot for a listing (tour or experience). Used for "Soonest available" sorting.
    /// Requires slots to be written with listingType + listingId fields (Stage 6+).
    func getNextAvailability(listingType: String, listingId: String, now: Date = Date()) async throws -> AvailabilitySlot? {
        let snap = try await availabilityCol
            .whereField("listingType", isEqualTo: listingType)
            .whereField("listingId", isEqualTo: listingId)
            .whereField("isReserved", isEqualTo: false)
            .whereField("start", isGreaterThan: now)
            .order(by: "start", descending: false)
            .limit(to: 1)
            .getDocuments()
        return try snap.documents.first.map { try $0.data(as: AvailabilitySlot.self) }
    }

    /// Returns availability slots whose **start** time falls within [start, end].
    /// Firestore cannot query arbitrary overlap efficiently without additional indices,
    /// so we use a "start in range" query and then callers may do additional filtering.
    func getAvailabilityForListingInRange(
        listingType: String,
        listingId: String,
        start: Date,
        end: Date,
        limit: Int = 200
    ) async throws -> [AvailabilitySlot] {
        let snap = try await availabilityCol
            .whereField("listingType", isEqualTo: listingType)
            .whereField("listingId", isEqualTo: listingId)
            .whereField("start", isGreaterThanOrEqualTo: start)
            .whereField("start", isLessThanOrEqualTo: end)
            .order(by: "start", descending: false)
            .limit(to: limit)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: AvailabilitySlot.self) }
    }

// MARK: Chat Threads
func getOrCreateThread(userId: String, email: String, tourId: String? = nil) async throws -> ChatThread {
    // Deterministic thread id for (user, guide, tour)
    let tId = [userId, email, tourId ?? "none"].joined(separator: "_")
    let ref = threadsCol.document(tId)
    let snap = try await ref.getDocument()
    if let existing = try snap.data(as: ChatThread?.self) {
        return existing
    }
    let thread = ChatThread(
        id: tId,
        userId: userId,
        email: email,
        tourId: tourId,
        lastMessage: nil,
        lastSenderId: nil,
        updatedAt: Date(),
        createdAt: Date()
    )
    try ref.setData(from: thread, merge: true)
    return thread
}

func getChatThreadsForUser(userId: String, limit: Int = 100) async throws -> [ChatThread] {
    let snap = try await threadsCol.whereField("userId", isEqualTo: userId)
        .order(by: "updatedAt", descending: true)
        .limit(to: limit)
        .getDocuments()
    return try snap.documents.compactMap { try $0.data(as: ChatThread.self) }
}

func getChatThreadsForGuide(email: String, limit: Int = 100) async throws -> [ChatThread] {
    let snap = try await threadsCol.whereField("email", isEqualTo: email)
        .order(by: "updatedAt", descending: true)
        .limit(to: limit)
        .getDocuments()
    return try snap.documents.compactMap { try $0.data(as: ChatThread.self) }
}

func listenToMessages(threadId: String, onUpdate: @escaping ([ChatMessage]) -> Void) -> ListenerRegistration {
    threadsCol.document(threadId).collection("messages")
        .order(by: "createdAt", descending: false)
        .addSnapshotListener { snap, _ in
            let docs = snap?.documents ?? []
            let msgs = docs.compactMap { try? $0.data(as: ChatMessage.self) }
            onUpdate(msgs)
        }
}

func sendMessage(threadId: String, senderId: String, text: String, userId: String, email: String, tourId: String?) async throws {
    let msg = ChatMessage(
        id: UUID().uuidString,
        threadId: threadId,
        senderId: senderId,
        text: text,
        createdAt: Date()
    )

    let threadRef = threadsCol.document(threadId)
    // Update only the mutable fields so `createdAt` isn't reset on every message.
    try await threadRef.setData([
        "id": threadId,
        "userId": userId,
        "email": email,
        "tourId": tourId as Any,
        "lastMessage": text,
        "lastSenderId": senderId,
        "updatedAt": Date()
    ], merge: true)

    try threadRef.collection("messages").document(msg.id).setData(from: msg, merge: true)
}

    // MARK: Community Feed
    func createPost(_ post: FeedPost) async throws {
        try postsCol.document(post.id).setData(from: post, merge: true)
    }

    func listPosts(limit: Int = 50) async throws -> [FeedPost] {
        let snap = try await postsCol
            .whereField("isHidden", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: FeedPost.self) }
    }

    /// Like a post once. Returns true if a new like was recorded, false if the user had already liked.
    func likePost(postId: String, userId: String) async throws -> Bool {
        let ref = postsCol.document(postId)
        // Firestore's runTransaction closure is non-throwing; handle errors inside and return a concrete Bool
        let result: Bool? = try await db.runTransaction { tx, errorPointer in
            do {
                let snap = try tx.getDocument(ref)
                var likedBy = (snap.get("likedBy") as? [String]) ?? []
                if likedBy.contains(userId) {
                    // Already liked; no write needed
                    return false
                }
                likedBy.append(userId)
                tx.updateData([
                    "likedBy": likedBy,
                    "likeCount": FieldValue.increment(Int64(1))
                ], forDocument: ref)
                return true
            } catch {
                // Set the error pointer so Firestore knows the transaction failed
                if let errorPointer = errorPointer {
                    errorPointer.pointee = error as NSError
                }
                return nil
            }
        } as? Bool
        // If result is nil, the transaction failed and runTransaction threw; propagate a descriptive error
        guard let unwrapped = result else {
            throw NSError(domain: "FirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to complete like transaction"]) 
        }
        return unwrapped
    }

    /// Backwards compatible API (still used in older screens). Positive delta increments likeCount.
    func likePost(postId: String, delta: Int) async throws {
        try await postsCol.document(postId).updateData(["likeCount": FieldValue.increment(Int64(delta))])
    }

    func createComment(_ comment: FeedComment) async throws {
        try postCommentsCol.document(comment.id).setData(from: comment, merge: true)
        try await postsCol.document(comment.postId).updateData(["commentCount": FieldValue.increment(Int64(1))])
    }

    func listComments(postId: String, limit: Int = 100) async throws -> [FeedComment] {
        let snap = try await postCommentsCol
            .whereField("postId", isEqualTo: postId)
            .whereField("isHidden", isEqualTo: false)
            .order(by: "createdAt", descending: false)
            .limit(to: limit)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: FeedComment.self) }
    }

    func report(targetType: FeedReport.TargetType, targetId: String, postId: String?, reporterId: String, reason: String) async throws {
        let report = FeedReport(
            id: UUID().uuidString,
            targetType: targetType,
            targetId: targetId,
            postId: postId,
            reporterId: reporterId,
            reason: reason,
            createdAt: Date()
        )
        try postReportsCol.document(report.id).setData(from: report, merge: true)
        if targetType == .post {
            try await postsCol.document(targetId).updateData(["reportCount": FieldValue.increment(Int64(1))])
        } else {
            try await postCommentsCol.document(targetId).updateData(["reportCount": FieldValue.increment(Int64(1))])
        }
    }

    // Admin moderation
    func listReports(limit: Int = 200) async throws -> [FeedReport] {
        let snap = try await postReportsCol
            .whereField("resolved", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: FeedReport.self) }
    }

    func resolveReport(reportId: String, adminId: String) async throws {
        try await postReportsCol.document(reportId).updateData([
            "resolved": true,
            "resolvedAt": Date(),
            "resolvedBy": adminId
        ])
    }

    func hidePost(postId: String) async throws {
        try await postsCol.document(postId).updateData(["isHidden": true])
    }

    func hideComment(commentId: String) async throws {
        try await postCommentsCol.document(commentId).updateData(["isHidden": true])
    }

// MARK: Config

    func getStripePublishableKey() async throws -> String {
        let snap = try await configCol.document("stripe").getDocument()
        let data = snap.data() ?? [:]
        guard let pk = data["publishableKey"] as? String, !pk.isEmpty else {
            throw NSError(domain: "Config", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing config/stripe.publishableKey"])
        }
        return pk
    }

    // MARK: Admin - Attestations
    struct PendingGuideAttestation: Identifiable {
        let id: String
        let user: AppUser
        let profile: GuideProfile
    }

    func listPendingGuideAttestations(limit: Int = 200) async throws -> [PendingGuideAttestation] {
        // Guides where profile created and not approved yet
        let snap = try await usersCol
            .whereField("role", isEqualTo: UserRole.guide.rawValue)
            .whereField("guideProfileCreated", isEqualTo: true)
            .whereField("guideApproved", isEqualTo: false)
            .limit(to: limit)
            .getDocuments()

        var results: [PendingGuideAttestation] = []
        for doc in snap.documents {
            if let user = try? doc.data(as: AppUser.self) {
                // Must have guide profile + attestation
                if let profile = try? await guidesCol.document(user.id).getDocument().data(as: GuideProfile.self) {
                    if profile.attestationURL != nil {
                        results.append(PendingGuideAttestation(id: user.id, user: user, profile: profile))
                    }
                }
            }
        }
        return results
    }

    func setGuideApprovalStatus(uid: String, approved: Bool, note: String? = nil) async throws {
        var patch: [String: Any] = [
            "guideApproved": approved,
            "guideApprovalUpdatedAt": FieldValue.serverTimestamp()
        ]
        if let note {
            patch["guideApprovalNote"] = note
        }
        try await usersCol.document(uid).setData(patch, merge: true)
    }

    // MARK: Admin - Host Compliance
    struct PendingHostCompliance: Identifiable {
        let id: String
        let user: AppUser
        let profile: HostProfile?
    }

    /// Hosts who uploaded SRL/PFA certificate and are not approved yet.
    func listPendingHostCompliance(limit: Int = 200) async throws -> [PendingHostCompliance] {
        // Require hostApproved == false (we set this at registration) and certificate URL present (non-empty)
        let snap = try await usersCol
            .whereField("role", isEqualTo: UserRole.host.rawValue)
            .whereField("hostApproved", isEqualTo: false)
            .whereField("businessCertificateURL", isGreaterThan: "")
            .limit(to: limit)
            .getDocuments()

        var results: [PendingHostCompliance] = []
        for doc in snap.documents {
            if let user = try? doc.data(as: AppUser.self) {
                let profile = try? await hostsCol.document(user.id).getDocument().data(as: HostProfile.self)
                results.append(PendingHostCompliance(id: user.id, user: user, profile: profile))
            }
        }
        return results
    }

    func setHostApprovalStatus(uid: String, approved: Bool, note: String? = nil) async throws {
        var patch: [String: Any] = [
            "hostApproved": approved,
            "hostApprovalUpdatedAt": FieldValue.serverTimestamp()
        ]
        if let note {
            patch["hostApprovalNote"] = note
        }
        try await usersCol.document(uid).setData(patch, merge: true)
    }

}
