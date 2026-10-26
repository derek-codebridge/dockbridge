import CoreGraphics
import Testing
@testable import DockBridgeCore

private func assertNoOverlap(_ frames: [CGRect], sourceLocation: SourceLocation = #_sourceLocation) {
    for (i, a) in frames.enumerated() {
        for b in frames[(i + 1)...] {
            let shared = a.intersection(b)
            #expect(shared.isNull || shared.width * shared.height == 0, "\(a) overlaps \(b)", sourceLocation: sourceLocation)
        }
    }
}

struct LayoutTests {
    private let laptop = CGRect(x: 0, y: 34, width: 1728, height: 1043)
    private let external = CGRect(x: 1728, y: -600, width: 3840, height: 2160)
    private let odd = CGRect(x: 10, y: 20, width: 1001, height: 701)
    private let window = CGRect(x: 100, y: 100, width: 800, height: 600)

    @Test func fillUsesWholeArea() {
        for area in [laptop, external, odd] {
            #expect(Layout.fill.frame(current: window, in: area) == area)
        }
    }

    @Test func halvesSplitAreaWithoutGapOrOverlap() {
        for area in [laptop, external, odd] {
            let left = Layout.left.frame(current: window, in: area)
            let right = Layout.right.frame(current: window, in: area)
            #expect(left.minX == area.minX)
            #expect(left.maxX == right.minX)
            #expect(right.maxX == area.maxX)
            #expect(left.height == area.height)
            #expect(right.height == area.height)

            let top = Layout.top.frame(current: window, in: area)
            let bottom = Layout.bottom.frame(current: window, in: area)
            #expect(top.minY == area.minY)
            #expect(top.maxY == bottom.minY)
            #expect(bottom.maxY == area.maxY)
        }
    }

    @Test func quartersTileTheArea() {
        for area in [laptop, external, odd] {
            let quarters: [Layout] = [.topLeft, .topRight, .bottomLeft, .bottomRight]
            let frames = quarters.map { $0.frame(current: window, in: area) }
            #expect(frames.map { $0.width * $0.height }.reduce(0, +) == area.width * area.height)
            #expect(frames.reduce(frames[0]) { $0.union($1) } == area)
            assertNoOverlap(frames)
        }
    }

    @Test func centerKeepsSizeAndCentres() {
        let frame = Layout.center.frame(current: window, in: laptop)
        #expect(frame.size == window.size)
        #expect(abs(frame.midX - laptop.midX) <= 1)
        #expect(abs(frame.midY - laptop.midY) <= 1)
    }

    @Test func centerShrinksOversizedWindowToArea() {
        let huge = CGRect(x: 0, y: 0, width: 5000, height: 3000)
        #expect(Layout.center.frame(current: huge, in: laptop) == laptop)
    }

    @Test func resizeGroupsCoverEveryLayoutExceptFill() {
        let grouped = Set(Layout.resizeGroups.flatMap { $0 })
        #expect(grouped == Set(Layout.allCases).subtracting([.fill]))
    }

    @Test func everyLayoutHasATitle() {
        #expect(Set(Layout.allCases.map(\.title)).count == Layout.allCases.count)
        #expect(Layout.fill.title == "Windowed Full Screen")
    }
}

struct FitTests {
    private let laptop = CGRect(x: 0, y: 34, width: 1728, height: 1043)

    @Test func windowThatFitsIsUnchanged() {
        let frame = CGRect(x: 100, y: 100, width: 800, height: 600)
        #expect(Fit.frame(frame, in: laptop) == frame)
    }

    @Test func tallPreviewShrinksKeepingProportionAndTitleBarVisible() {
        let quickLook = CGRect(x: 0, y: 0, width: 1108, height: 1511)
        let fitted = Fit.frame(quickLook, in: laptop)
        #expect(fitted.height == 1043)
        #expect(abs(fitted.width / fitted.height - quickLook.width / quickLook.height) < 0.01)
        #expect(laptop.contains(fitted))
        #expect(fitted.minY == laptop.minY)
    }

    @Test func offScreenWindowIsPulledBackInside() {
        let lost = CGRect(x: 5000, y: -900, width: 800, height: 600)
        let fitted = Fit.frame(lost, in: laptop)
        #expect(fitted.size == lost.size)
        #expect(laptop.contains(fitted))
    }

    @Test func oversizedWideWindowFitsBothDimensions() {
        let wide = CGRect(x: -200, y: 40, width: 3840, height: 900)
        let fitted = Fit.frame(wide, in: laptop)
        #expect(laptop.contains(fitted))
        #expect(fitted.width <= laptop.width)
    }
}

struct GridTests {
    private let area = CGRect(x: 1728, y: -600, width: 3840, height: 2160)

    @Test func noWindowsGivesNoFrames() {
        #expect(Grid.frames(count: 0, in: area).isEmpty)
    }

    @Test func oneWindowFillsArea() {
        #expect(Grid.frames(count: 1, in: area) == [area])
    }

    @Test func twoWindowsSitSideBySide() {
        let frames = Grid.frames(count: 2, in: area)
        #expect(frames.count == 2)
        #expect(frames[0].minY == frames[1].minY)
        #expect(frames[0].maxX == frames[1].minX)
        #expect(frames[0].height == area.height)
    }

    @Test(arguments: [(3, 2, 2), (4, 2, 2), (5, 3, 2), (9, 3, 3), (10, 4, 3)])
    func columnsAndRowsForLargerCounts(count: Int, columns: Int, rows: Int) {
        let frames = Grid.frames(count: count, in: area)
        #expect(frames.count == count)
        #expect(Set(frames.map(\.minX)).count == min(columns, count))
        #expect(Set(frames.map(\.minY)).count == rows)
    }

    @Test(arguments: 1...12)
    func framesStayInsideAreaAndDoNotOverlap(count: Int) {
        let frames = Grid.frames(count: count, in: area)
        for frame in frames {
            #expect(area.contains(frame), "\(frame) outside \(area)")
        }
        assertNoOverlap(frames)
    }
}

struct ScreenConversionTests {
    @Test func cocoaRectFlipsToTopLeftOrigin() {
        let builtIn = CGRect(x: 0, y: 40, width: 1728, height: 1043)
        #expect(Screens.axRect(fromCocoa: builtIn, primaryHeight: 1117) == CGRect(x: 0, y: 34, width: 1728, height: 1043))
    }

    @Test func displayAboveAndRightOfPrimaryHasNegativeY() {
        let external = CGRect(x: 1728, y: -443, width: 3840, height: 2160)
        #expect(Screens.axRect(fromCocoa: external, primaryHeight: 1117) == CGRect(x: 1728, y: -600, width: 3840, height: 2160))
    }

    @Test func pointConversionIsItsOwnInverse() {
        let point = CGPoint(x: 26, y: 1095)
        let cocoa = Screens.cocoaPoint(fromAX: point, primaryHeight: 1117)
        #expect(cocoa == CGPoint(x: 26, y: 22))
        #expect(Screens.cocoaPoint(fromAX: cocoa, primaryHeight: 1117) == point)
    }
}

struct ZoomActionTests {
    @Test func menuTitlesAreLowercaseAndDistinct() {
        let all = ZoomAction.allCases.flatMap(\.menuTitles)
        #expect(Set(all).count == all.count)
        #expect(all.allSatisfy { $0 == $0.lowercased() })
    }

    @Test func windowZoomIsNeverMatched() {
        for action in ZoomAction.allCases {
            #expect(!action.menuTitles.contains("zoom"))
        }
    }
}
