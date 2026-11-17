import Foundation
import Testing
import LyricsXCore
@testable import LyricsXServices

private final class CacheFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var enabled = false
    func get() -> Bool { lock.withLock { enabled } }
    func set(_ value: Bool) { lock.withLock { enabled = value } }
}

@Test func disabledCacheStillDeliversLyricsAndCanToggleWithoutLosingExistingFiles() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let cache = LyricsCache(directory: root), flag = CacheFlag()
    let doc = try LyricsCodec.parse("[ti:MemoryOnly]\n[ar:Tester]\n[00:01]A sample line", source: "Kugou")
    let track = Track(playerID: "test", playerName: "", title: "MemoryOnly", artist: "Tester")
    let store = LyricsStore(cache: cache, automaticCacheEnabled: { flag.get() },
        configuration: { var c = SourceConfiguration(); c.enabled = ["Kugou"]; return c },
        aliasResolver: TrackAliasResolver { _ in Data(#"{"results":[]}"#.utf8) },
        firstResultDelay: .milliseconds(1), fallbackGrace: .milliseconds(1)) { _, _, _, _ in
        .init { stream in
            let task = Task {
                stream.yield(doc)
                try? await Task.sleep(for: .milliseconds(30))
                stream.finish()
            }
            stream.onTermination = { _ in task.cancel() }
        }
    }
    var received: [LyricCandidate] = []
    for try await value in store.lyrics(for: track, forceRefresh: true) { received.append(value) }
    #expect(received.contains { $0.document.lines.first?.text == "A sample line" })
    try await store.save(doc, for: track)
    #expect(try await cache.entries().isEmpty)
    #expect(!FileManager.default.fileExists(atPath: root.path))
    flag.set(true)
    try await store.save(doc, for: track)
    #expect(try await cache.entries().count == 1)
    flag.set(false)
    var changed = doc; changed.offsetMilliseconds = 500
    try await store.save(changed, for: track)
    #expect(await cache.load(for: track)?.offsetMilliseconds == 0)
    // Turning writes off does not discard a file already saved by the user.
    var restored: [LyricCandidate] = []
    for try await value in store.lyrics(for: track, forceRefresh: false) { restored.append(value) }
    #expect(restored.first?.score == 1000)
}

@Test func cacheCleanupIsFlatRecoverableAndInvalidatesOldCheckpointTokens() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let folder = root.appendingPathComponent("lyrics"), trash = root.appendingPathComponent("recovery")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let cache = LyricsCache(directory: folder)
    let track = Track(playerID: "test", playerName: "", title: "Sample", artist: "Tester")
    let doc = try LyricsCodec.parse("[00:01]A sample line")
    let token = await cache.beginSearch(for: track)
    for name in ["one.lrc", "two.LRCX", "three.txt", "keep.json", ".hidden.lrc"] {
        try Data("[00:01]Sample".utf8).write(to: folder.appendingPathComponent(name))
    }
    let nested = folder.appendingPathComponent("nested.lrc")
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try Data("keep".utf8).write(to: nested.appendingPathComponent("nested.txt"))
    let outside = root.appendingPathComponent("outside.lrc")
    try Data("outside".utf8).write(to: outside)
    try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("link.lrc"), withDestinationURL: outside)
    let count = try await cache.trashLyricsFiles { url in
        try FileManager.default.moveItem(at: url, to: trash.appendingPathComponent(url.lastPathComponent))
    }
    #expect(count == 3)
    #expect(try FileManager.default.contentsOfDirectory(atPath: trash.path).count == 3)
    #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("keep.json").path))
    #expect(FileManager.default.fileExists(atPath: nested.appendingPathComponent("nested.txt").path))
    #expect(try String(contentsOf: outside, encoding: .utf8) == "outside")
    try await cache.saveCheckpoint(.init(document: doc, score: 70), for: track, searchID: token, configuration: "test")
    #expect(await cache.existingURL(for: track) == nil)
    // Recover the same bytes using the file operation used for Trash recovery.
    try FileManager.default.moveItem(at: trash.appendingPathComponent("one.lrc"), to: folder.appendingPathComponent("one.lrc"))
    #expect(try String(contentsOf: folder.appendingPathComponent("one.lrc"), encoding: .utf8) == "[00:01]Sample")
}
