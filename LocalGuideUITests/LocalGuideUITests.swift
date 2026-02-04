//
//  LocalGuideUITests.swift
//  LocalGuideUITests
//
//  Created by Cristina Florea on 13.01.2026.
//

import XCTest

final class LocalGuideUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    @MainActor
    func testTravelerCommunityFlow() throws {
        let email = uniqueEmail()
        let postTitle = "UITest Post \(Int(Date().timeIntervalSince1970))"
        let postBody = "UITest post body \(UUID().uuidString.prefix(6))"
        let comment = "UITest comment \(UUID().uuidString.prefix(6))"

        let app = launchApp(extraEnv: [
            "UITEST_EMAIL": email,
            "UITEST_PASSWORD": "Passw0rd!123",
            "UITEST_FULLNAME": "UI Test Traveler",
            "UITEST_COUNTRY": "Romania",
            "UITEST_CITY": "Bucharest",
            "UITEST_POST_TITLE": postTitle,
            "UITEST_POST_BODY": postBody,
            "UITEST_COMMENT": comment
        ])

        register(app: app, roleId: "role_traveler")

        let communityTab = app.tabBars.buttons["Community"]
        XCTAssertTrue(communityTab.waitForExistence(timeout: 30))
        communityTab.tap()

        let composeButton = app.buttons["community_compose_button"]
        XCTAssertTrue(composeButton.waitForExistence(timeout: 10))
        composeButton.tap()

        let postSubmit = app.buttons["post_submit"]
        XCTAssertTrue(postSubmit.waitForExistence(timeout: 10))
        if !postSubmit.isEnabled {
            let titleField = app.textFields["post_title"]
            if titleField.waitForExistence(timeout: 5) {
                titleField.tap()
                titleField.typeText(postTitle)
            }
            let bodyView = app.textViews["post_body"]
            if bodyView.waitForExistence(timeout: 5) {
                bodyView.tap()
                bodyView.typeText(postBody)
            }
        }
        postSubmit.tap()

        let postTitleText = app.staticTexts[postTitle]
        XCTAssertTrue(postTitleText.waitForExistence(timeout: 20))
        postTitleText.tap()

        let commentInput = app.textViews["comment_input"]
        XCTAssertTrue(commentInput.waitForExistence(timeout: 10))
        commentInput.tap()
        let existing = (commentInput.value as? String) ?? ""
        if existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || existing == "Add a comment" {
            commentInput.typeText(comment)
        }

        let sendButton = app.buttons["comment_send"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 5))
        sendButton.tap()

        let commentText = app.staticTexts[comment]
        XCTAssertTrue(commentText.waitForExistence(timeout: 10))

        let likeButton = app.buttons["comment_like_button"].firstMatch
        if likeButton.waitForExistence(timeout: 5) {
            likeButton.tap()
        }

        let menuButton = app.buttons["comment_menu"].firstMatch
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
        menuButton.tap()

        let editButton = app.buttons["Edit comment"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()

        let editInput = app.textViews["comment_edit_input"]
        XCTAssertTrue(editInput.waitForExistence(timeout: 5))
        editInput.tap()
        editInput.typeText(" updated")

        let editSave = app.buttons["comment_edit_save"]
        XCTAssertTrue(editSave.waitForExistence(timeout: 5))
        editSave.tap()

        let menuButton2 = app.buttons["comment_menu"].firstMatch
        XCTAssertTrue(menuButton2.waitForExistence(timeout: 5))
        menuButton2.tap()

        let deleteButton = app.buttons["Delete comment"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        let confirmDelete = app.buttons["Delete"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5))
        confirmDelete.tap()
    }

    @MainActor
    func testHostCreateAndEditExperience() throws {
        let email = uniqueEmail(prefix: "uitest-host")
        let title = "UITest Experience \(UUID().uuidString.prefix(6))"
        let updatedTitle = title + " Updated"

        let app = launchApp(extraEnv: [
            "UITEST_EMAIL": email,
            "UITEST_PASSWORD": "Passw0rd!123",
            "UITEST_FULLNAME": "UI Test Host",
            "UITEST_COUNTRY": "Romania",
            "UITEST_CITY": "Bucharest",
            "UITEST_EXPERIENCE_TITLE": title,
            "UITEST_EXPERIENCE_DESC": "UI test experience description"
        ])

        register(app: app, roleId: "role_host")

        let experiencesTab = app.tabBars.buttons["Experiences"]
        XCTAssertTrue(experiencesTab.waitForExistence(timeout: 30))
        experiencesTab.tap()

        let createButton = app.buttons["host_experience_create"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 10))
        createButton.tap()

        let publishButton = app.buttons["experience_publish"]
        XCTAssertTrue(publishButton.waitForExistence(timeout: 10))
        scrollTo(publishButton, in: app)
        publishButton.tap()

        let createdTitle = app.staticTexts[title]
        XCTAssertTrue(createdTitle.waitForExistence(timeout: 30))
        createdTitle.tap()

        let editButton = app.buttons["experience_detail_edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 10))
        editButton.tap()

        let titleField = app.textFields["experience_edit_title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 10))
        clearAndType(titleField, text: updatedTitle)

        let saveButton = app.buttons["experience_edit_save"]
        scrollTo(saveButton, in: app)
        saveButton.tap()

        let updatedTitleText = app.staticTexts[updatedTitle]
        XCTAssertTrue(updatedTitleText.waitForExistence(timeout: 20))
    }

    @MainActor
    func testGuideCreateAndEditTour() throws {
        let email = uniqueEmail(prefix: "uitest-guide")
        let title = "UITest Tour \(UUID().uuidString.prefix(6))"
        let updatedTitle = title + " Updated"

        let app = launchApp(extraEnv: [
            "UITEST_EMAIL": email,
            "UITEST_PASSWORD": "Passw0rd!123",
            "UITEST_FULLNAME": "UI Test Guide",
            "UITEST_COUNTRY": "Romania",
            "UITEST_CITY": "Bucharest",
            "UITEST_TOUR_TITLE": title,
            "UITEST_TOUR_DESC": "UI test tour description"
        ])

        register(app: app, roleId: "role_guide")

        let toursTab = app.tabBars.buttons["Tours"]
        XCTAssertTrue(toursTab.waitForExistence(timeout: 30))
        toursTab.tap()

        let createButton = app.buttons["guide_tour_create"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 10))
        createButton.tap()

        let publishButton = app.buttons["tour_publish"]
        XCTAssertTrue(publishButton.waitForExistence(timeout: 10))
        scrollTo(publishButton, in: app)
        publishButton.tap()

        let createdTitle = app.staticTexts[title]
        XCTAssertTrue(createdTitle.waitForExistence(timeout: 30))
        createdTitle.tap()

        let editButton = app.buttons["tour_detail_edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 10))
        editButton.tap()

        let titleField = app.textFields["tour_edit_title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 10))
        clearAndType(titleField, text: updatedTitle)

        let saveButton = app.buttons["tour_edit_save"]
        scrollTo(saveButton, in: app)
        saveButton.tap()

        let updatedTitleText = app.staticTexts[updatedTitle]
        XCTAssertTrue(updatedTitleText.waitForExistence(timeout: 20))
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    // MARK: - Helpers

    private func launchApp(extraEnv: [String: String]) -> XCUIApplication {
        let app = XCUIApplication()
        var env: [String: String] = [
            "APP_ENV": "staging",
            "UITEST": "1",
            "UITEST_AUTOFILL": "1"
        ]
        extraEnv.forEach { env[$0.key] = $0.value }
        app.launchEnvironment = env
        app.launch()
        return app
    }

    private func register(app: XCUIApplication, roleId: String) {
        let createAccount = app.buttons["auth_create_account"]
        XCTAssertTrue(createAccount.waitForExistence(timeout: 20))
        createAccount.tap()

        let roleButton = app.buttons[roleId]
        XCTAssertTrue(roleButton.waitForExistence(timeout: 10))
        roleButton.tap()

        let register = app.buttons["register_submit"]
        XCTAssertTrue(register.waitForExistence(timeout: 20))
        register.tap()
    }

    private func uniqueEmail(prefix: String = "uitest") -> String {
        "\(prefix)+\(UUID().uuidString.prefix(8))@example.com"
    }

    private func clearAndType(_ element: XCUIElement, text: String) {
        element.tap()
        let existing = (element.value as? String) ?? ""
        if !existing.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count)
            element.typeText(deleteString)
        }
        element.typeText(text)
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 6) {
        var attempts = 0
        while !element.isHittable && attempts < maxSwipes {
            app.swipeUp()
            attempts += 1
        }
    }
}
