import Foundation
import Testing
@testable import DockBridgeCore

struct AppLocationTests {
    @Test func installedCopiesStay() {
        #expect(!AppLocation.needsMove(bundlePath: "/Applications/DockBridge.app"))
        #expect(!AppLocation.needsMove(bundlePath: NSHomeDirectory() + "/Applications/DockBridge.app"))
    }

    @Test func diskImageAndTranslocatedCopiesMove() {
        #expect(AppLocation.needsMove(bundlePath: "/Volumes/DockBridge/DockBridge.app"))
        #expect(AppLocation.needsMove(bundlePath: "/private/var/folders/x1/abc/T/AppTranslocation/1234-ABCD/d/DockBridge.app"))
    }

    @Test func developerBuildsAreLeftAlone() {
        #expect(!AppLocation.needsMove(bundlePath: NSHomeDirectory() + "/Projects/dockbridge/build/DockBridge.app"))
    }
}

struct ZoomSearchOrderTests {
    @Test func viewMenuIsSearchedFirst() {
        let titles = ["File", "Edit", "View", "History", "Bookmarks", "Window", "Help"]
        #expect(ZoomAction.searchOrder(titles).first == 2)
    }

    @Test func heavyMenusAreSkipped() {
        let titles = ["File", "Edit", "View", "History", "Bookmarks", "Favorites", "Window", "Help"]
        let searched = Set(ZoomAction.searchOrder(titles).map { titles[$0] })
        #expect(searched == ["File", "Edit", "View"])
    }

    @Test func menusWithoutViewKeepTheirOrder() {
        #expect(ZoomAction.searchOrder(["File", "Edit", "Format"]) == [0, 1, 2])
    }

    @Test func searchIsBounded() {
        #expect(ZoomAction.maxVisitedElements <= 2000)
    }
}

struct ZoomTitleMatchingTests {
    @Test(arguments: [
        ("Reset Zoom [⌘NumPad0]", "reset zoom"),
        ("Zoom In", "zoom in"),
        ("  Actual Size  ", "actual size"),
        ("Zoom Out…", "zoom out"),
    ])
    func titlesNormaliseToMenuNames(raw: String, expected: String) {
        #expect(ZoomAction.normalizedTitle(raw) == expected)
    }

    @Test func vsCodeTitlesMatchActions() {
        #expect(ZoomAction.reset.menuTitles.contains(ZoomAction.normalizedTitle("Reset Zoom [⌘NumPad0]")))
        #expect(ZoomAction.zoomIn.menuTitles.contains(ZoomAction.normalizedTitle("Zoom In")))
        #expect(ZoomAction.zoomOut.menuTitles.contains(ZoomAction.normalizedTitle("Zoom Out")))
    }
}

struct ClickRuleTests {
    @Test func plainRightClickOpensMenuByDefault() {
        #expect(DockInterceptor.opensMenu(.rightMouseDown, flags: [], plainRightClick: true))
    }

    @Test func plainRightClickStaysNativeWhenTurnedOff() {
        #expect(!DockInterceptor.opensMenu(.rightMouseDown, flags: [], plainRightClick: false))
        #expect(DockInterceptor.opensMenu(.rightMouseDown, flags: .maskAlternate, plainRightClick: false))
    }

    @Test func controlClickFollowsTheSameRule() {
        #expect(DockInterceptor.opensMenu(.leftMouseDown, flags: .maskControl, plainRightClick: true))
        #expect(!DockInterceptor.opensMenu(.leftMouseDown, flags: .maskControl, plainRightClick: false))
        #expect(DockInterceptor.opensMenu(.leftMouseDown, flags: [.maskControl, .maskAlternate], plainRightClick: false))
    }

    @Test func plainLeftClickNeverOpensMenu() {
        #expect(!DockInterceptor.opensMenu(.leftMouseDown, flags: [], plainRightClick: true))
        #expect(!DockInterceptor.opensMenu(.leftMouseDown, flags: .maskAlternate, plainRightClick: true))
    }
}

struct DockMenuTitleTests {
    @Test func recentTitlesDescribeTheLayout() {
        #expect(DockMenu.recentTitle(2) == "2 Most Recent Side by Side")
        #expect(DockMenu.recentTitle(3) == "3 Most Recent")
        #expect(DockMenu.recentTitle(4) == "4 Most Recent in Quadrants")
    }

    @Test func currentDisplayIsMarked() {
        #expect(DockMenu.displayTitle("MPG 274U E16M", isCurrent: true) == "MPG 274U E16M (current)")
        #expect(DockMenu.displayTitle("Built-in Retina Display", isCurrent: false) == "Built-in Retina Display")
    }

    @Test func sendPositionsOfferEveryLayoutWithFullScreenFirst() {
        #expect(Layout.sendGroups.first == [.fill])
        #expect(Set(Layout.sendGroups.flatMap { $0 }) == Set(Layout.allCases))
    }

    @Test func halfTitlesUsePercentages() {
        #expect(Layout.left.title == "Left 50%")
        #expect(Layout.right.title == "Right 50%")
        #expect(Layout.top.title == "Top 50%")
        #expect(Layout.bottom.title == "Bottom 50%")
    }
}
