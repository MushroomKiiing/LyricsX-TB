import Foundation
@preconcurrency import LyricsKit
import LyricsXCore

/// Strict matching avoids replacing the playing album with another edition.
public actor NetEaseArtworkResolver {
    public static let shared = NetEaseArtworkResolver()
    private var current: (key: String, url: URL?)?
    private let session: URLSession
    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 8
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }
    public static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }
    public static func matches(title: String, artists: [String], album: String, duration: Double, track: Track) -> Bool {
        let artist = normalize(track.artist)
        guard !artist.isEmpty, normalize(title) == normalize(track.title),
              artists.contains(where: { normalize($0) == artist }) || normalize(artists.joined(separator: " / ")) == artist,
              track.album.isEmpty || normalize(album) == normalize(track.album) else { return false }
        return track.duration <= 0 || duration <= 0 || abs(track.duration - duration) <= 3
    }
    public func url(for track: Track) async -> URL? {
        guard track.playerID == "com.netease.163music" else { return nil }
        let key = track.cacheIdentity
        if let current, current.key == key { return current.url }
        do {
            let values = try await NetEaseArtworkSearch.search(title: track.title, artist: track.artist, duration: track.duration,
                httpClient: SecureLyricsHTTPClient(session: session))
            try Task.checkCancellation()
            let match = values.first { Self.matches(title: $0.title, artists: $0.artists, album: $0.album, duration: $0.duration, track: track) }
            var artworkURL = match?.url
            // Search metadata omits picUrl in current NetEase responses. Resolve
            // only the strictly matched album's numeric ID, without another search.
            if artworkURL == nil, let match, match.albumID > 0,
               let url = URL(string: "https://music.163.com/api/album/\(match.albumID)") {
                var request = URLRequest(url: url, timeoutInterval: 6)
                request.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
                let (data, response) = try await session.data(for: request)
                try Task.checkCancellation()
                if (response as? HTTPURLResponse)?.statusCode == 200, data.count < 4_000_000,
                   let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let album = object["album"] as? [String: Any], let address = album["picUrl"] as? String {
                    artworkURL = URL(string: address)
                }
            }
            if let original = artworkURL, let host = original.host?.lowercased(), host.hasSuffix(".music.126.net"),
               var components = URLComponents(url: original, resolvingAgainstBaseURL: false) {
                components.scheme = "https"
                components.queryItems = (components.queryItems ?? []).filter { $0.name != "param" } + [.init(name: "param", value: "1000y1000")]
                if let url = components.url {
                    current = (key, url); return url
                }
            }
        } catch { if Task.isCancelled { return nil } }
        current = (key, nil); return nil
    }
}
