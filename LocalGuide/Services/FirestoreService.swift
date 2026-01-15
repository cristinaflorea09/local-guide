import Foundation
import FirebaseFirestore

final class FirestoreService {
    static let shared = FirestoreService()
    private let db = FirebaseManager.shared.db
    private init() {}

    private var usersCol: CollectionReference { db.collection("users") }
    private var guidesCol: CollectionReference { db.collection("guides") }
    private var toursCol: CollectionReference { db.collection("tours") }
    private var bookingsCol: CollectionReference { db.collection("bookings") }
    private var reviewsCol: CollectionReference { db.collection("reviews") }
    private var configCol: CollectionReference { db.collection("config") }
    private var availabilityCol: CollectionReference { db.collection("availability") }
    private var threadsCol: CollectionReference { db.collection("threads") }

    // MARK: Users
    func createUser(_ user: AppUser) async throws {
        try usersCol.document(user.id).setData(from: user, merge: true)
    }

    func getUser(uid: String) async throws -> AppUser {
        let snap = try await usersCol.document(uid).getDocument()
        guard let user = try snap.data(as: AppUser?.self) else {
            throw NSError(domain: "AppUser", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        return user
    }

    func updateUser(uid: String, fields: [String: Any]) async throws {
        try await usersCol.document(uid).updateData(fields)
    }

    func listUsers(limit: Int = 200) async throws -> [AppUser] {
        let snap = try await usersCol.order(by: "createdAt", descending: true).limit(to: limit).getDocuments()
        return try snap.documents.compactMap { try $0.data(as: AppUser.self) }
    }

    // MARK: Guide profile
    func createGuideProfile(_ profile: GuideProfile) async throws {
        try guidesCol.document(profile.id).setData(from: profile, merge: true)
        try await usersCol.document(profile.id).updateData([
            "guideProfileCreated": true,
            "guideApproved": false
        ])
    }

    func getGuideProfile(guideId: String) async throws -> GuideProfile {
        let snap = try await guidesCol.document(guideId).getDocument()
        guard let profile = try snap.data(as: GuideProfile?.self) else {
            throw NSError(domain: "GuideProfile", code: 404, userInfo: [NSLocalizedDescriptionKey: "Guide profile not found"])
        }
        return profile
    }


func updateGuideProfile(_ profile: GuideProfile) async throws {
    try guidesCol.document(profile.id).setData(from: profile, merge: true)
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

    func getToursForGuide(guideId: String) async throws -> [Tour] {
        let snap = try await toursCol.whereField("guideId", isEqualTo: guideId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Tour.self) }
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

    func getBookingsForGuide(guideId: String) async throws -> [Booking] {
        let snap = try await bookingsCol.whereField("guideId", isEqualTo: guideId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Booking.self) }
    }

    // MARK: Reviews
    func createReview(_ review: Review) async throws {
        try reviewsCol.document(review.id).setData(from: review, merge: true)
    }

    func getReviewsForTour(tourId: String, limit: Int = 50) async throws -> [Review] {
        let snap = try await reviewsCol.whereField("tourId", isEqualTo: tourId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Review.self) }
    }

    func getReviewsForGuide(guideId: String, limit: Int = 50) async throws -> [Review] {
        let snap = try await reviewsCol.whereField("guideId", isEqualTo: guideId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Review.self) }
    }

    // MARK: Availability
func createAvailability(_ slot: AvailabilitySlot) async throws {
    try availabilityCol.document(slot.id).setData(from: slot, merge: true)
}

func deleteAvailability(slotId: String) async throws {
    try await availabilityCol.document(slotId).delete()
}

func getAvailabilityForGuide(guideId: String, limit: Int = 200) async throws -> [AvailabilitySlot] {
    let snap = try await availabilityCol.whereField("guideId", isEqualTo: guideId)
        .order(by: "start", descending: false)
        .limit(to: limit)
        .getDocuments()
    return try snap.documents.compactMap { try $0.data(as: AvailabilitySlot.self) }
}

// MARK: Chat Threads
func getOrCreateThread(userId: String, guideId: String, tourId: String? = nil) async throws -> ChatThread {
    // Deterministic thread id for (user, guide, tour)
    let tId = [userId, guideId, tourId ?? "none"].joined(separator: "_")
    let ref = threadsCol.document(tId)
    let snap = try await ref.getDocument()
    if let existing = try snap.data(as: ChatThread?.self) {
        return existing
    }
    let thread = ChatThread(
        id: tId,
        userId: userId,
        guideId: guideId,
        tourId: tourId,
        lastMessage: nil,
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

func getChatThreadsForGuide(guideId: String, limit: Int = 100) async throws -> [ChatThread] {
    let snap = try await threadsCol.whereField("guideId", isEqualTo: guideId)
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

func sendMessage(threadId: String, senderId: String, text: String, userId: String, guideId: String, tourId: String?) async throws {
    let msg = ChatMessage(
        id: UUID().uuidString,
        threadId: threadId,
        senderId: senderId,
        text: text,
        createdAt: Date()
    )

    let threadRef = threadsCol.document(threadId)
    try await threadRef.setData(from: ChatThread(
        id: threadId,
        userId: userId,
        guideId: guideId,
        tourId: tourId,
        lastMessage: text,
        updatedAt: Date(),
        createdAt: Date()
    ), merge: true)

    try threadRef.collection("messages").document(msg.id).setData(from: msg, merge: true)
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
}
