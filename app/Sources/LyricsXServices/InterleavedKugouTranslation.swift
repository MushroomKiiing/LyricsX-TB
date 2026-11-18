import LyricsXCore

/// Some Kugou KRC uploads put a short Chinese translation before each sung
/// Latin-script line and assign both rows word timings. Recover the pairs only
/// when the same timing and script pattern repeats across most of the track.
/// Explicit translations and unmatched original rows are left as supplied.
enum InterleavedKugouTranslation {
    static func normalize(_ rows: [LyricLine]) -> [LyricLine] {
        guard rows.count >= 16, !rows.contains(where: { $0.hasTranslation }) else { return rows }
        let scripts = rows.map { script(of: $0.text) }
        guard scripts.first(where: { $0 != .other }) == .latin else { return rows }
        var pairs: [Int: Int] = [:]
        var longestRun = 0, run = 0, lastPair = -2
        for i in rows.indices.dropLast() where scripts[i] == .han && scripts[i + 1] == .latin {
            let translation = rows[i], original = rows[i + 1]
            let gap = original.time - translation.time
            guard gap > 0, gap <= 2.5,
                  let translationEnd = translation.words.map(\.end).max(),
                  let originalEnd = original.words.map(\.end).max(),
                  abs(translationEnd - original.time) <= 0.13,
                  originalEnd - original.time >= max(0.8, gap * 1.15) else { continue }
            pairs[i] = i + 1
            run = i == lastPair + 2 ? run + 1 : 1
            longestRun = max(longestRun, run)
            lastPair = i
        }
        let hanCount = scripts.filter { $0 == .han }.count
        let latinCount = scripts.filter { $0 == .latin }.count
        guard pairs.count >= 8, longestRun >= 6,
              pairs.count * 100 >= hanCount * 85,
              pairs.count * 100 >= latinCount * 65 else { return rows }
        var result = rows
        for (translation, original) in pairs { result[original].translation = rows[translation].text }
        return result.enumerated().compactMap { pairs[$0.offset] == nil ? $0.element : nil }
    }

    private enum Script { case han, latin, other }
    private static func script(of text: String) -> Script {
        var han = 0, latin = 0, otherLetters = 0
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF: han += 1
            case 0x41...0x5A, 0x61...0x7A, 0xC0...0x24F: latin += 1
            default: if scalar.properties.isAlphabetic { otherLetters += 1 }
            }
        }
        guard otherLetters == 0 else { return .other }
        if han == 0, latin >= 2 { return .latin }
        if han >= 2, han > latin * 2 { return .han }
        return .other
    }
}
