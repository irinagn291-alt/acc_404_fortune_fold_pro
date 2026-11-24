import XCTest

final class FortuneFoldUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ language: String, _ locale: String) {
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        app.launch()
    }

    private func button(_ id: String) -> XCUIElement {
        app.buttons[id]
    }

    private func tap(_ id: String) {
        let item = button(id)
        if !item.exists { XCTAssertTrue(item.waitForExistence(timeout: 8), id) }
        XCTAssertTrue(item.isHittable, id)
        item.tap()
    }

    private func see(_ id: String, _ expected: String) {
        let item = app.staticTexts[id]
        if item.exists && item.label == expected { return }
        let condition = NSPredicate(format: "label == %@", expected)
        expectation(for: condition, evaluatedWith: item)
        waitForExpectations(timeout: 10)
    }

    private func contains(_ id: String, _ expected: String) {
        let item = app.staticTexts[id]
        expectation(for: NSPredicate(format: "label CONTAINS %@", expected), evaluatedWith: item)
        waitForExpectations(timeout: 10)
    }

    private func shot(_ name: String) {
        let evidence = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        evidence.name = name
        evidence.lifetime = .keepAlways
        add(evidence)
    }

    private func measure(_ name: String, hinge: String) {
        let sheet = app.descendants(matching: .any).matching(identifier: "active-sheet").firstMatch
        let target = button("edge-\(hinge)")
        XCTAssertTrue(sheet.waitForExistence(timeout: 8))
        let field = sheet.frame
        let window = app.frame
        let grip = target.frame
        XCTAssertGreaterThanOrEqual(field.width, window.width * 0.94)
        XCTAssertGreaterThanOrEqual(field.height, window.height * 0.66)
        XCTAssertGreaterThanOrEqual(grip.width, 44)
        XCTAssertGreaterThanOrEqual(grip.height, 44)
        XCTAssertTrue(field.contains(grip))
        XCTAssertTrue(target.isHittable)
        let sample = String(
            format: "%@ window %.1f × %.1f pt\nActive sheet %.1f × %.1f pt at (%.1f, %.1f)\n%@ grip %.1f × %.1f pt at (%.1f, %.1f)",
            name, window.width, window.height, field.width, field.height, field.minX, field.minY,
            hinge, grip.width, grip.height, grip.minX, grip.minY
        )
        print(sample)
        let attachment = XCTAttachment(string: sample)
        attachment.name = "measurement-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func fold(_ edge: String, _ left: Bool) {
        tap("edge-\(edge)")
        tap(left ? "fold-left" : "fold-right")
    }

    private func pull(x: CGFloat, y: CGFloat) {
        let corner = button("envelope-corner")
        XCTAssertTrue(corner.waitForExistence(timeout: 8))
        let start = corner.coordinate(withNormalizedOffset: CGVector(dx: 0.64, dy: 0.43))
        start.press(forDuration: 0.10, thenDragTo: start.withOffset(CGVector(dx: x, dy: y)))
    }

    private func gesture(_ edge: String, by x: CGFloat, down y: CGFloat = 0, hold: TimeInterval = 0.36) {
        let button = button("edge-\(edge)")
        XCTAssertTrue(button.waitForExistence(timeout: 8))
        let start = button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.11, thenDragTo: start.withOffset(CGVector(dx: x, dy: y)),
                    withVelocity: .slow, thenHoldForDuration: hold)
    }

    private func release() {
        tap("release")
    }

    private func printed(_ best: String? = nil) {
        XCTAssertTrue(app.staticTexts["print"].waitForExistence(timeout: 10))
        if let best { see("best", best) }
    }

    private func play(_ actions: String) {
        for action in actions.split(separator: " ") {
            if action == "go" {
                release()
            } else {
                let edge = String(action.dropLast())
                let direction = action.last == "-"
                let arrow = button(direction ? "fold-left" : "fold-right")
                // A release may start a short walk before the next hinge becomes available.
                if !button("edge-\(edge)").isEnabled {
                    expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: button("edge-\(edge)"))
                    waitForExpectations(timeout: 8)
                }
                let hinge = button("edge-\(edge)")
                tap("edge-\(edge)")
                XCTAssertTrue(hinge.isSelected, "Selected hinge \(edge)")
                if !arrow.isEnabled {
                    expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: arrow)
                    waitForExpectations(timeout: 8)
                }
                arrow.tap()
            }
        }
    }

    func testPhoneCampaignAndRestoration() {
        XCUIDevice.shared.orientation = .portrait
        launch("en-GB", "en_GB")
        see("desk-title", "Whiskers")
        shot("iphone-01-clean-envelope")
        pull(x: -19, y: 14)
        see("desk-title", "Whiskers")
        XCTAssertFalse(app.staticTexts["sheet-title"].exists)
        pull(x: -93, y: 108)
        see("sheet-title", "Whiskers")
        see("fold-count", "Folds 0")
        release()
        contains("sheet-status", "seal is still open")
        tap("hint")
        see("sheet-status", "Try the highlighted hinge.")
        gesture("whiskers", by: 88, down: 67)
        see("fold-count", "Folds 1")
        fold("ear", true)
        release()
        printed("Best 2")
        shot("iphone-02-whiskers-print")
        tap("next")

        see("sheet-title", "Tail across the Brook")
        fold("body", false)
        release()
        contains("sheet-status", "stopped at the brook")
        measure("iphone-portrait", hinge: "tail")
        shot("iphone-03-brook-stall")
        gesture("tail", by: -15, down: 8, hold: 0.30)
        see("fold-count", "Folds 1")
        fold("tail", false)
        see("fold-count", "Folds 2")
        contains("sheet-status", "stopped at the brook")
        shot("iphone-04-wrong-tail")
        tap("undo")
        see("fold-count", "Folds 1")
        gesture("tail", by: -78, down: 57, hold: 0.49)
        printed("Best 2")
        shot("iphone-05-bridged")
        tap("undo")
        see("fold-count", "Folds 1")
        contains("sheet-status", "stopped at the brook")
        shot("iphone-06-bridge-undone")
        fold("tail", true)
        printed("Best 2")
        tap("next")

        see("sheet-title", "Behind the Shutter")
        XCTAssertFalse(button("edge-inner").exists)
        fold("shutter", false)
        fold("inner", false)
        release()
        contains("sheet-status", "seal is still open")
        shot("iphone-07-shutter-wrong-order")
        fold("shutter", true)
        fold("shutter", true)
        release()
        printed("Best 4")
        tap("replay")
        fold("shutter", true)
        see("fold-count", "Folds 1")
        XCTAssertTrue(button("edge-inner").isHittable)
        XCUIDevice.shared.press(.home)
        app.terminate()
        launch("en-GB", "en_GB")
        see("desk-title", "Behind the Shutter")
        tap("open")
        see("fold-count", "Folds 1")
        XCTAssertTrue(button("edge-inner").isHittable)
        shot("iphone-08-restored-layer")
        fold("inner", false)
        release()
        printed("Best 2")
        tap("replay")
        fold("shutter", false)
        fold("shutter", true)
        fold("shutter", true)
        fold("inner", false)
        release()
        printed("Best 2")
        see("fold-count", "Folds 4")
        shot("iphone-09-best-kept")

        let remainder: [(String, String)] = [
            ("Two Banks", "body- go tail- bank+"),
            ("Moon Window", "lantern- go"),
            ("The Other Side", "lantern+ track- go"),
            ("Paper Door", "screen- door+ track- go"),
            ("Second Shadow", "shadow- shadow- track- go"),
            ("The Ridge", "ridge+ ear- go ridge- ridge-"),
            ("The Fork", "ridge+ turn- go ridge- ridge-"),
            ("Garden under the Roof", "roof+ ridge+ go garden- ridge- ridge-"),
            ("The Long Jump", "ridge+ go tail- tail+ tail+"),
            ("Two Seals", "track- lantern- go"),
            ("A Bridge within a Bridge", "lantern+ go bridge+ inner-"),
            ("Folding Screen", "screen+ tail+ seal+ go tail- tail- track-")
        ]
        for (name, actions) in remainder {
            tap("next")
            see("sheet-title", name)
            if name == "Moon Window" { shot("iphone-10-moon-window") }
            play(actions)
            printed()
        }
        tap("next")
        see("sheet-title", "Homeward")
        XCTAssertFalse(button("edge-seal").exists)
        fold("bridge", false)
        fold("window", true)
        release()
        contains("sheet-status", "seal is still open")
        shot("iphone-11-window-moved-too-early")
        tap("undo")
        XCTAssertFalse(button("edge-seal").exists)
        release()
        contains("sheet-status", "break in the path")
        shot("iphone-12-final-first-gap")
        play("tail+ tail- tail-")
        contains("sheet-status", "break in the path")
        shot("iphone-13-final-second-bridge")
        fold("window", true)
        printed("Best 5")
        shot("iphone-14-homeward-print")
        tap("next")
        XCTAssertTrue(button("chapter-3").isHittable)
        XCTAssertTrue(button("folio-home").isHittable)
        shot("iphone-15-palace-album")
    }

    func testStreamClip() {
        launch("en-GB", "en_GB")
        tap("open")
        gesture("whiskers", by: 88, down: 67)
        fold("ear", true)
        release()
        printed("Best 2")
        shot("iphone-02-whiskers-print")
        tap("next")
        see("sheet-title", "Tail across the Brook")
        fold("body", false)
        release()
        contains("sheet-status", "stopped at the brook")
        shot("iphone-03-brook-stall")
        gesture("tail", by: -15, down: 8, hold: 0.45)
        see("fold-count", "Folds 1")
        fold("tail", false)
        see("fold-count", "Folds 2")
        contains("sheet-status", "stopped at the brook")
        shot("iphone-04-wrong-tail")
        tap("undo")
        gesture("tail", by: -43, down: 42, hold: 0.82)
        printed("Best 2")
        Thread.sleep(forTimeInterval: 1.10)
        shot("iphone-05-bridged")
    }

    func testPadArabic() {
        XCUIDevice.shared.orientation = .portrait
        launch("ar", "ar_SA")
        see("desk-title", "الشوارب")
        tap("open")
        see("sheet-title", "الشوارب")
        let whiskers = button("edge-whiskers")
        let ear = button("edge-ear")
        XCTAssertLessThan(whiskers.frame.midX, ear.frame.midX)
        XCTAssertGreaterThanOrEqual(whiskers.frame.width, 44)
        XCTAssertGreaterThanOrEqual(whiskers.frame.height, 44)
        shot("ipad-01-arabic-sheet")
        gesture("whiskers", by: 165, down: 120)
        XCTAssertEqual(whiskers.value as? String, "مطويّ إلى اليمين")
        fold("ear", true)
        release()
        printed()
        tap("next")
        see("sheet-title", "ذيل فوق الجدول")
        fold("body", false)
        release()
        contains("sheet-status", "عند الجدول")
        measure("ipad-portrait", hinge: "tail")
        shot("ipad-02-arabic-brook")
        gesture("tail", by: -151, down: 113, hold: 0.54)
        printed()
        shot("ipad-03-arabic-bridge")
        tap("album")
        XCTAssertTrue(button("folio-stream").isHittable)
        XCTAssertTrue(button("album-play").isHittable)
        shot("ipad-04-arabic-album")

        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 8)
        shot("ipad-05-arabic-album-landscape")
        tap("album-play")
        see("sheet-title", "ذيل فوق الجدول")
        fold("body", false)
        release()
        contains("sheet-status", "عند الجدول")
        measure("ipad-landscape", hinge: "tail")
        shot("ipad-06-arabic-brook-landscape")
        fold("tail", true)
        printed()
        XCUIDevice.shared.orientation = .portrait

        for (language, locale, title) in [
            ("en-US", "en_US", "Tail across the Creek"),
            ("zh-Hans", "zh_CN", "虎尾过溪"),
            ("zh-Hant", "zh_TW", "虎尾過溪")
        ] {
            app.terminate()
            launch(language, locale)
            see("desk-title", title)
            tap("open")
            see("sheet-title", title)
        }
    }
    func testPadMotionReview() {
        XCUIDevice.shared.orientation = .portrait
        launch("en-GB", "en_GB")
        tap("open")
        gesture("whiskers", by: 165, down: 120)
        fold("ear", true)
        release()
        printed("Best 2")
        tap("next")
        see("sheet-title", "Tail across the Brook")
        fold("body", false)
        release()
        contains("sheet-status", "stopped at the brook")
        measure("ipad-review-portrait", hinge: "tail")
        shot("pad-review-at-the-brook")
        gesture("tail", by: -151, down: 113, hold: 0.54)
        printed("Best 2")
        shot("pad-review-tail-bridge-print")
        tap("album")
        XCTAssertTrue(button("album-play").isHittable)
        shot("pad-review-letters-album")

        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 8)
        tap("album-play")
        fold("body", false)
        release()
        contains("sheet-status", "stopped at the brook")
        measure("ipad-review-landscape", hinge: "tail")
        fold("tail", true)
        printed("Best 2")
        XCUIDevice.shared.orientation = .portrait
        expectation(for: NSPredicate { _, _ in self.app.frame.width < self.app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 8)

        let leadIn: [(String, String)] = [
            ("Behind the Shutter", "shutter- inner+ go"),
            ("Two Banks", "body- go tail- bank+"),
            ("Moon Window", "lantern- go"),
            ("The Other Side", "lantern+ track- go"),
            ("Paper Door", "screen- door+ track- go"),
        ]
        for (name, actions) in leadIn {
            tap("next")
            see("sheet-title", name)
            play(actions)
            printed()
        }
        tap("next")
        see("sheet-title", "Second Shadow")
        let field = app.descendants(matching: .any).matching(identifier: "active-sheet").firstMatch.frame
        let shadow = button("edge-shadow")
        XCTAssertEqual(shadow.value as? String, "Folded right")
        let start = shadow.frame
        let dx = (field.minX + field.width * 0.84 - start.midX) * 0.20
        let dy = (field.minY + field.height * 0.165 - start.midY) * 0.20
        print("FF_CAPTURE SHADOW_READY")
        Thread.sleep(forTimeInterval: 0.20)
        gesture("shadow", by: dx, down: dy, hold: 2.15)
        XCTAssertEqual(shadow.value as? String, "Folded right")
        fold("shadow", true)
        XCTAssertEqual(shadow.value as? String, "Flat")
        play("shadow- track- go")
        printed("Best 3")
        shot("pad-review-second-shadow-print")
    }

}
