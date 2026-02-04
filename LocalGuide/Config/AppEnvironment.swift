import Foundation
import FirebaseCore

enum AppEnvironment {
    private static var env: [String: String] {
        ProcessInfo.processInfo.environment
    }

    static var isUITest: Bool {
        env["UITEST"] == "1"
    }

    static var uiTestAutofill: Bool {
        isUITest && env["UITEST_AUTOFILL"] == "1"
    }

    static var isStaging: Bool {
        env["APP_ENV"]?.lowercased() == "staging"
    }

    static var firebaseOptions: FirebaseOptions? {
        guard isStaging else { return nil }
        guard let path = Bundle.main.path(forResource: "GoogleService-Info-Staging", ofType: "plist") else {
            return nil
        }
        return FirebaseOptions(contentsOfFile: path)
    }

    static var uiTestEmail: String? {
        env["UITEST_EMAIL"]
    }

    static var uiTestPassword: String? {
        env["UITEST_PASSWORD"]
    }

    static var uiTestFullName: String? {
        env["UITEST_FULLNAME"]
    }

    static var uiTestCountry: String? {
        env["UITEST_COUNTRY"]
    }

    static var uiTestCity: String? {
        env["UITEST_CITY"]
    }

    static var uiTestPostTitle: String? {
        env["UITEST_POST_TITLE"]
    }

    static var uiTestPostBody: String? {
        env["UITEST_POST_BODY"]
    }

    static var uiTestComment: String? {
        env["UITEST_COMMENT"]
    }

    static var uiTestExperienceTitle: String? {
        env["UITEST_EXPERIENCE_TITLE"]
    }

    static var uiTestExperienceDescription: String? {
        env["UITEST_EXPERIENCE_DESC"]
    }

    static var uiTestTourTitle: String? {
        env["UITEST_TOUR_TITLE"]
    }

    static var uiTestTourDescription: String? {
        env["UITEST_TOUR_DESC"]
    }

    static var uiTestBusinessName: String? {
        env["UITEST_BUSINESS_NAME"]
    }

    static var uiTestBusinessRegNo: String? {
        env["UITEST_BUSINESS_REGNO"]
    }

    static var uiTestBusinessTaxId: String? {
        env["UITEST_BUSINESS_TAXID"]
    }

    static var uiTestBusinessAddress: String? {
        env["UITEST_BUSINESS_ADDRESS"]
    }
}
