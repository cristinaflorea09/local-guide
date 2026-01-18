import Foundation

struct AppUser: Identifiable, Codable {
    var id: String
    var email: String?

    // Profile
    var fullName: String
    var dateOfBirth: Date?
    var country: String
    var city: String
    var preferredLanguageCode: String

    // Role & entitlements
    var role: UserRole
    var subscriptionPlan: SubscriptionPlan   // free_ads or premium

    // Guide onboarding flags (used by GuideGateView/Admin)
    var guideProfileCreated: Bool? = nil
    var guideApproved: Bool? = nil

    /// Host onboarding/compliance approval (set by Admin). Kept separate from guide approval.
    var hostApproved: Bool? = nil

    /// Seller tier for Guides/Hosts (Stripe subscription). Travelers typically keep this nil.
    var sellerTier: SellerTier? = nil

    // Stripe Connect Express (for Guides/Hosts payouts)
    var stripeAccountId: String? = nil
    var disabled: Bool

    // Legal
    var acceptedTermsVersion: Int? = nil
    var acceptedTermsAt: Date? = nil

    /// Intermediary contract between platform and Provider (Guide/Host)
    var acceptedIntermediaryVersion: Int? = nil
    var acceptedIntermediaryAt: Date? = nil

    // Business compliance (SRL/PFA)
    var businessType: String? = nil // "PFA" or "SRL"
    var businessName: String? = nil
    var businessRegistrationNumber: String? = nil
    var businessTaxId: String? = nil
    var businessAddress: String? = nil
    var businessCertificateURL: String? = nil

    // Optional avatar
    var photoURL: String? = nil

    // Finance / tax (optional; used for earnings dashboard & VAT summaries)
    var vatRegistered: Bool? = nil
    /// VAT rate percentage (e.g., 19 for Romania). If nil, app falls back to country defaults.
    var vatRate: Int? = nil

    var createdAt: Date

    init(
        id: String,
        email: String? = nil,
        fullName: String = "",
        dateOfBirth: Date? = nil,
        country: String = "",
        city: String = "",
        preferredLanguageCode: String = "en",
        role: UserRole = .traveler,
        subscriptionPlan: SubscriptionPlan = .freeAds,
        guideProfileCreated: Bool? = nil,
        guideApproved: Bool? = nil,
        hostApproved: Bool? = nil,
        sellerTier: SellerTier? = nil,
        stripeAccountId: String? = nil,
        disabled: Bool = false,
        acceptedTermsVersion: Int? = nil,
        acceptedTermsAt: Date? = nil,
        acceptedIntermediaryVersion: Int? = nil,
        acceptedIntermediaryAt: Date? = nil,
        businessType: String? = nil,
        businessName: String? = nil,
        businessRegistrationNumber: String? = nil,
        businessTaxId: String? = nil,
        businessAddress: String? = nil,
        businessCertificateURL: String? = nil,
        photoURL: String? = nil,
        vatRegistered: Bool? = nil,
        vatRate: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.dateOfBirth = dateOfBirth
        self.country = country
        self.city = city
        self.preferredLanguageCode = preferredLanguageCode
        self.role = role
        self.subscriptionPlan = subscriptionPlan
        self.guideProfileCreated = guideProfileCreated
        self.guideApproved = guideApproved
        self.hostApproved = hostApproved
        self.sellerTier = sellerTier
        self.stripeAccountId = stripeAccountId
        self.disabled = disabled
        self.acceptedTermsVersion = acceptedTermsVersion
        self.acceptedTermsAt = acceptedTermsAt
        self.acceptedIntermediaryVersion = acceptedIntermediaryVersion
        self.acceptedIntermediaryAt = acceptedIntermediaryAt
        self.businessType = businessType
        self.businessName = businessName
        self.businessRegistrationNumber = businessRegistrationNumber
        self.businessTaxId = businessTaxId
        self.businessAddress = businessAddress
        self.businessCertificateURL = businessCertificateURL
        self.photoURL = photoURL
        self.vatRegistered = vatRegistered
        self.vatRate = vatRate
        self.createdAt = createdAt
    }

    // Firestore documents in early versions of the app may miss some fields
    // (especially for travelers). Provide tolerant decoding to avoid login
    // crashes when a field is absent.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        email = try c.decodeIfPresent(String.self, forKey: .email)

        fullName = try c.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        dateOfBirth = try c.decodeIfPresent(Date.self, forKey: .dateOfBirth)
        country = try c.decodeIfPresent(String.self, forKey: .country) ?? ""
        city = try c.decodeIfPresent(String.self, forKey: .city) ?? ""
        preferredLanguageCode = try c.decodeIfPresent(String.self, forKey: .preferredLanguageCode) ?? "en"

        role = try c.decodeIfPresent(UserRole.self, forKey: .role) ?? .traveler
        subscriptionPlan = try c.decodeIfPresent(SubscriptionPlan.self, forKey: .subscriptionPlan) ?? .freeAds

        guideProfileCreated = try c.decodeIfPresent(Bool.self, forKey: .guideProfileCreated)
        guideApproved = try c.decodeIfPresent(Bool.self, forKey: .guideApproved)
        hostApproved = try c.decodeIfPresent(Bool.self, forKey: .hostApproved)
        sellerTier = try c.decodeIfPresent(SellerTier.self, forKey: .sellerTier)
        stripeAccountId = try c.decodeIfPresent(String.self, forKey: .stripeAccountId)
        disabled = try c.decodeIfPresent(Bool.self, forKey: .disabled) ?? false

        acceptedTermsVersion = try c.decodeIfPresent(Int.self, forKey: .acceptedTermsVersion)
        acceptedTermsAt = try c.decodeIfPresent(Date.self, forKey: .acceptedTermsAt)
        acceptedIntermediaryVersion = try c.decodeIfPresent(Int.self, forKey: .acceptedIntermediaryVersion)
        acceptedIntermediaryAt = try c.decodeIfPresent(Date.self, forKey: .acceptedIntermediaryAt)

        businessType = try c.decodeIfPresent(String.self, forKey: .businessType)
        businessName = try c.decodeIfPresent(String.self, forKey: .businessName)
        businessRegistrationNumber = try c.decodeIfPresent(String.self, forKey: .businessRegistrationNumber)
        businessTaxId = try c.decodeIfPresent(String.self, forKey: .businessTaxId)
        businessAddress = try c.decodeIfPresent(String.self, forKey: .businessAddress)
        businessCertificateURL = try c.decodeIfPresent(String.self, forKey: .businessCertificateURL)

        photoURL = try c.decodeIfPresent(String.self, forKey: .photoURL)

        vatRegistered = try c.decodeIfPresent(Bool.self, forKey: .vatRegistered)
        vatRate = try c.decodeIfPresent(Int.self, forKey: .vatRate)

        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

enum SubscriptionPlan: String, Codable {
    case freeAds = "free_ads"
    case premium = "premium"
}
