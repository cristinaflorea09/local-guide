import Foundation

enum LegalDocumentType {
    case srlPfaGuide
}

enum LegalDocuments {
    static func markdown(_ type: LegalDocumentType, languageCode: String) -> String {
        let code = (languageCode.lowercased().hasPrefix("ro") ? "ro" : "en")
        switch (type, code) {
        case (.srlPfaGuide, "ro"): return srlGuideRO
        case (.srlPfaGuide, _): return srlGuideEN
        }
    }



    // MARK: - SRL/PFA guide
    static let srlGuideEN: String = """
# How to open a PFA/SRL in Romania (quick guide)

This is an informational guide (not legal advice).

## PFA (Authorized Individual)
1. Choose CAEN codes for your activity.
2. Prepare documents (ID, proof of address, specimen signature, etc.).
3. File at ONRC (Romanian Trade Registry) or online.
4. Register for tax obligations (ANAF) and consider VAT thresholds.

## SRL (Limited Liability)
1. Reserve company name.
2. Decide shareholders/administrator.
3. Establish registered office.
4. Draft articles of association.
5. File at ONRC.

We recommend consulting an accountant/lawyer.
"""

    static let srlGuideRO: String = """
# Cum deschizi un PFA/SRL în România (ghid rapid)

Acest ghid este informativ (nu reprezintă consultanță juridică).

## PFA
1. Alege codurile CAEN.
2. Pregătește documentele (CI, dovada sediului, specimen semnătură etc.).
3. Depune la ONRC (sau online).
4. Înregistrare obligații fiscale (ANAF) și prag TVA.

## SRL
1. Rezervă denumirea.
2. Stabilește asociații/administrator.
3. Sediu social.
4. Act constitutiv.
5. Depunere la ONRC.

Recomandăm consultarea unui contabil/avocat.
"""
}
