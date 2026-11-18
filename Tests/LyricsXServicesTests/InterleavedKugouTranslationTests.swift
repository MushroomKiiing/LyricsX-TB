import Foundation
import LyricsXCore
import Testing
@testable import LyricsXServices

private func interleavedLRCX(source: String = "Kugou", matchedBoundary: Bool = true) -> String {
    func cue(_ time: Int, _ text: String, _ length: Int) -> [String] {
        let tag = String(format: "[00:%06.3f]", Double(time) / 1000)
        return [tag + text, tag + "[tt]<0,0><\(length),\(text.count)><\(length)>"]
    }
    var rows = ["[by:\(source)]"] + cue(0, "Opening line", 1000)
    for i in 1...10 {
        let t = i * 3000
        rows += cue(t, "这是译文\(i)", matchedBoundary ? 500 : 250)
        rows += cue(t + 500, "English sample \(i)", 2250)
    }
    return rows.joined(separator: "\n")
}

@Test func recoverInterleavedKugouTranslationsFromAnExistingCache() throws {
    let input = interleavedLRCX()
    let document = try LyricsCodec.parse(input)
    #expect(document.lines.count == 11)
    #expect(document.lines[0].translation == nil)
    #expect(document.lines[1].text == "English sample 1")
    #expect(document.lines[1].translation == "这是译文1")
    #expect(document.lines[1].time == 3.5)
    #expect(document.lines[1].hasWordTiming)
    #expect(document.index(at: 3.1) == 0) // Never display the extra row on its own.
    #expect(document.index(at: 3.5) == 1)
    #expect(try LyricsCodec.parse(LyricsCodec.export(document)).lines == document.lines)
}

@Test func leaveIndependentBilingualLyricsAndOtherSourcesIntact() throws {
    let independent = try LyricsCodec.parse(interleavedLRCX(matchedBoundary: false))
    #expect(independent.lines.count == 21 && !independent.hasTranslation)
    let unsupported = try LyricsCodec.parse(interleavedLRCX(source: "NetEase"))
    #expect(unsupported.lines.count == 21 && !unsupported.hasTranslation)
    var marked = independent.lines
    marked[0].translation = "明确标记的译文"
    #expect(InterleavedKugouTranslation.normalize(marked) == marked)
}
