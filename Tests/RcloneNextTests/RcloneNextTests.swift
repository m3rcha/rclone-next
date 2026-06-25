import XCTest
@testable import RcloneNext

final class RclonePathSettingsTests: XCTestCase {
    func testParseRemoteNames() {
        let output = "gdrive:\ns3:\n\nlocal\n"
        XCTAssertEqual(RclonePathSettings.parseRemoteNames(from: output), ["gdrive", "s3", "local"])
    }

    func testParseRemoteNamesEmpty() {
        XCTAssertTrue(RclonePathSettings.parseRemoteNames(from: "\n").isEmpty)
    }
}

final class SavedMountTests: XCTestCase {
    func testCompositeId() {
        let mount = SavedMount(remote: "gdrive", path: "/Volumes/GDrive", autoMount: true)
        XCTAssertEqual(mount.id, "gdrive@/Volumes/GDrive")
    }

    func testDistinctIdsForSameRemote() {
        let a = SavedMount(remote: "gdrive", path: "/Volumes/A", autoMount: true)
        let b = SavedMount(remote: "gdrive", path: "/Volumes/B", autoMount: true)
        XCTAssertNotEqual(a.id, b.id)
    }
}

final class ListingCacheTests: XCTestCase {
    @MainActor
    func testInvalidatePrefix() {
        let cache = ListingCache()
        let item = RcloneItem(path: "a", name: "a", size: 1, mimeType: nil, modTime: nil, isDir: false)
        cache.store([item], for: "gdrive:Docs")
        cache.store([item], for: "gdrive:Photos")
        cache.store([item], for: "s3:bucket")
        cache.invalidate(matchingPrefix: "gdrive:")
        XCTAssertNil(cache.cached("gdrive:Docs"))
        XCTAssertNil(cache.cached("gdrive:Photos"))
        XCTAssertNotNil(cache.cached("s3:bucket"))
    }
}
