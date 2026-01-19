import Foundation

enum LegalPDFType {
    case terms
    case privacy
    case cancellation
    case annex
    case dpa
    case intermediaryPFA
    case intermediarySRL

    var titleKey: String {
        switch self {
        case .terms: return "terms"
        case .privacy: return "privacy"
        case .cancellation: return "cancellation"
        case .annex: return "annex"
        case .dpa: return "dpa"
        case .intermediaryPFA: return "intermediary_pfa"
        case .intermediarySRL: return "intermediary_srl"
        }
    }

    var fileNameEn: String {
        switch self {
        case .terms: return "terms_en"
        case .privacy: return "privacy_en"
        case .cancellation: return "cancellation_en"
        case .annex: return "annex_en"
        case .dpa: return "dpa_en"
        case .intermediaryPFA: return "intermediary_pfa_en"
        case .intermediarySRL: return "intermediary_srl_en"
        }
    }
    var fileNameRo: String {
        switch self {
        case .terms: return "terms_ro"
        case .privacy: return "privacy_ro"
        case .cancellation: return "cancellation_ro"
        case .annex: return "annex_ro"
        case .dpa: return "dpa_ro"
        case .intermediaryPFA: return "intermediary_pfa_ro"
        case .intermediarySRL: return "intermediary_srl_ro"
        }
    }
}

enum LegalPDF {
    static func languageFolder(languageCode: String) -> String {
        languageCode.lowercased().hasPrefix("ro") ? "ro" : "en"
    }

    /// Returns a bundled PDF URL like Resources/LegalPDFs/<lang>/<file>.pdf
    static func url(for type: LegalPDFType, languageCode: String) -> URL? {
        let lang = languageFolder(languageCode: languageCode) // "en" or "ro"
        let baseName = (lang == "ro" ? type.fileNameRo : type.fileNameEn)

        return Bundle.main.url(
            forResource: baseName,
            withExtension: "pdf"
        )
    }

    /// Pick intermediary contract based on business type.
    /// businessType: "pfa" or "srl" (case-insensitive)
    static func intermediaryType(for businessType: String?) -> LegalPDFType {
        let t = (businessType ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t == "srl" { return .intermediarySRL }
        return .intermediaryPFA
    }
}
