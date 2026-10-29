import AppKit
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

struct NativeQuitItemTests {
    @Test func forceQuitIsTheOptionAlternateOfQuit() {
        let items = NativeDockItems.quitItems(for: .current)
        #expect(items.map(\.title) == ["Quit", "Force Quit"])
        #expect(items[0].keyEquivalentModifierMask.isEmpty)
        #expect(!items[0].isAlternate)
        #expect(items[1].keyEquivalentModifierMask == .option)
        #expect(items[1].isAlternate)
        #expect(items[0].keyEquivalent == items[1].keyEquivalent)
    }
}

struct DockMenuLayoutTests {
    @Test func normalItemsComeFirstThenDockBridgeThenQuit() {
        let item = DockAppItem(item: AXUIElementCreateApplication(getpid()), app: .current)
        let menu = DockMenu.make(for: item)
        let titles = menu.items.filter { !$0.isSeparatorItem }.map(\.title)
        let body = Array(titles.dropFirst())
        #expect(body.first == "Show All Windows")
        #expect(body.contains("Other Dock Options…"))
        let other = body.firstIndex(of: "Other Dock Options…") ?? 0
        #expect(Array(body[(other + 1)...]) == ["Windowed Full Screen", "DockBridge", "Quit", "Force Quit"])

        let bridge = menu.items.first { $0.title == "DockBridge" }?.submenu
        let bridgeTitles = bridge?.items.filter { !$0.isSeparatorItem }.map(\.title) ?? []
        #expect(bridgeTitles.first == "Fit Windows on Screen")
        #expect(["Resize", "Send to Display", "Arrange Recent Windows"].allSatisfy(bridgeTitles.contains))
        #expect(bridgeTitles.last == "Full Screen")
    }
}

struct DockEdgeTests {
    let laptop = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    let monitor = CGRect(x: 1728, y: -600, width: 3840, height: 2160)

    @Test func bottomLeftAndRightEdgesCount() {
        #expect(DockHitTest.isNearDockEdge(CGPoint(x: 517, y: 1095), displays: [laptop, monitor]))
        #expect(DockHitTest.isNearDockEdge(CGPoint(x: 3600, y: 1540), displays: [laptop, monitor]))
        #expect(DockHitTest.isNearDockEdge(CGPoint(x: 20, y: 500), displays: [laptop]))
        #expect(DockHitTest.isNearDockEdge(CGPoint(x: 5550, y: 300), displays: [laptop, monitor]))
    }

    @Test func clicksAwayFromTheDockSkipAccessibilityCalls() {
        #expect(!DockHitTest.isNearDockEdge(CGPoint(x: 860, y: 500), displays: [laptop, monitor]))
        #expect(!DockHitTest.isNearDockEdge(CGPoint(x: 3600, y: 1100), displays: [laptop, monitor]))
        #expect(!DockHitTest.isNearDockEdge(CGPoint(x: 860, y: 12), displays: [laptop]))
        #expect(!DockHitTest.isNearDockEdge(CGPoint(x: 517, y: 1095), displays: []))
    }

    @Test func liveDisplayListIsAvailable() {
        #expect(!DockHitTest.activeDisplayBounds().isEmpty)
    }
}

struct DockProbePointTests {
    let laptop = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    let bottomList = CGRect(x: 9, y: 1074, width: 1710, height: 33)

    @Test func clicksBelowTheReportedDockStripStillHitTheIcon() {
        for y in [1080.0, 1106, 1107, 1110, 1116] {
            #expect(DockHitTest.probePoint(for: CGPoint(x: 517, y: y), list: bottomList, display: laptop) == CGPoint(x: 517, y: bottomList.midY))
        }
    }

    @Test func clicksAboveOrBesideTheDockAreIgnored() {
        #expect(DockHitTest.probePoint(for: CGPoint(x: 517, y: 1060), list: bottomList, display: laptop) == nil)
        #expect(DockHitTest.probePoint(for: CGPoint(x: 4, y: 1100), list: bottomList, display: laptop) == nil)
        #expect(DockHitTest.probePoint(for: CGPoint(x: 1722, y: 1100), list: bottomList, display: laptop) == nil)
    }

    @Test func sideDocksReachTheirScreenEdge() {
        let leftList = CGRect(x: 6, y: 200, width: 40, height: 700)
        #expect(DockHitTest.probePoint(for: CGPoint(x: 0, y: 500), list: leftList, display: laptop) == CGPoint(x: leftList.midX, y: 500))
        #expect(DockHitTest.probePoint(for: CGPoint(x: 60, y: 500), list: leftList, display: laptop) == nil)
        let rightList = CGRect(x: 1682, y: 200, width: 40, height: 700)
        #expect(DockHitTest.probePoint(for: CGPoint(x: 1727, y: 500), list: rightList, display: laptop) == CGPoint(x: rightList.midX, y: 500))
    }
}

struct DockGapTests {
    let laptop = CGRect(x: 0, y: 0, width: 1728, height: 1117)

    @Test func bottomDockLeavesTheOnePointGapMacOSKeeps() {
        let visible = CGRect(x: 0, y: 39, width: 1728, height: 1044)
        let area = Screens.axRect(fromCocoa: Screens.clearOfDock(visible: visible, full: laptop), primaryHeight: 1117)
        #expect(area == CGRect(x: 0, y: 34, width: 1728, height: 1043))
        #expect(area.maxY == 1077)
    }

    @Test func sideDocksLeaveTheGapOnTheirSide() {
        #expect(Screens.clearOfDock(visible: CGRect(x: 70, y: 0, width: 1658, height: 1083), full: laptop) == CGRect(x: 71, y: 0, width: 1657, height: 1083))
        #expect(Screens.clearOfDock(visible: CGRect(x: 0, y: 0, width: 1658, height: 1083), full: laptop) == CGRect(x: 0, y: 0, width: 1657, height: 1083))
    }

    @Test func screensWithoutTheDockAreUnchanged() {
        let monitor = CGRect(x: 1728, y: -443, width: 3840, height: 2160)
        #expect(Screens.clearOfDock(visible: monitor, full: monitor) == monitor)
    }

    @Test func fittedOffscreenWindowStopsAboveTheDock() {
        let area = CGRect(x: 0, y: 34, width: 1728, height: 1043)
        let fitted = Fit.frame(CGRect(x: 100, y: 300, width: 2000, height: 1043), in: area)
        #expect(fitted == CGRect(x: 0, y: 176, width: 1728, height: 901))
        #expect(fitted.maxY == 1077)
    }
}

struct ClickMatchingTests {
    @Test func releaseNearThePressIsTheSameClick() {
        #expect(DockInterceptor.isSameClick(down: CGPoint(x: 517, y: 1095), up: CGPoint(x: 519, y: 1097)))
    }

    @Test func releaseFarFromThePressIsNotMatched() {
        #expect(!DockInterceptor.isSameClick(down: CGPoint(x: 517, y: 1095), up: CGPoint(x: 900, y: 400)))
    }
}

struct QuarantineTests {
    @Test func movedCopyLosesQuarantineEverywhere() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("DockBridgeQuarantine-\(UUID().uuidString).app")
        let inner = root.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        let binary = inner.appendingPathComponent("DockBridge")
        try Data("x".utf8).write(to: binary)
        defer { try? FileManager.default.removeItem(at: root) }
        let value = "0083;00000000;Safari;"
        for url in [root, binary] {
            #expect(setxattr(url.path, "com.apple.quarantine", value, value.utf8.count, 0, XATTR_NOFOLLOW) == 0)
        }

        AppLocation.removeQuarantine(under: root)

        for url in [root, binary] {
            #expect(getxattr(url.path, "com.apple.quarantine", nil, 0, 0, XATTR_NOFOLLOW) == -1)
        }
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
