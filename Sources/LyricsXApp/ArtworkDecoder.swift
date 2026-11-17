import Foundation
import ImageIO

/// One deadline owns missing metadata, decode refinements, and rapid skips.
/// Publishing pixels resets it; another request must never extend old pixels.
struct ArtworkHandover {
    static let graceDuration = 0.8
    private(set) var deadline: Double?
    mutating func begin(at now: Double) -> Double {
        if deadline == nil { deadline = now + Self.graceDuration }
        return deadline!
    }
    mutating func finish() { deadline = nil }
}

/// ImageIO must finish decompression off the main actor, before either window
/// uploads the pixels. A serial actor bounds peak decode memory during skips.
actor ArtworkDecoder {
    static let shared = ArtworkDecoder()
    private var cached: (data: Data, image: CGImage)?
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    func load(data: Data?, url originalURL: URL?) async -> CGImage? {
        let fallback = data.flatMap { decode($0) }
        if let fallback, min(fallback.width, fallback.height) >= 640 || originalURL == nil { return fallback }
        guard !Task.isCancelled, let originalURL,
              let scheme = originalURL.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return fallback }
        var url = originalURL
        if scheme == "http", var components = URLComponents(url: originalURL, resolvingAgainstBaseURL: false) {
            components.scheme = "https"
            url = components.url ?? originalURL
        }
        do {
            // A source advertised by a player can still stall indefinitely.
            // Bound loading so the quiet pending surface eventually resolves.
            let (data, response) = try await session.data(for: URLRequest(url: url, timeoutInterval: 8))
            guard !Task.isCancelled, (response as? HTTPURLResponse)?.statusCode == 200 else { return fallback }
            guard let decoded = decode(data) else { return fallback }
            if let fallback, decoded.width < fallback.width || decoded.height < fallback.height { return fallback }
            return decoded
        } catch { return fallback }
    }

    func decode(_ data: Data) -> CGImage? {
        guard !Task.isCancelled, data.count < 8_000_000 else { return nil }
        if let cached, cached.data == data { return cached.image }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 1024,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary), !Task.isCancelled else { return nil }
        cached = (data, image)
        return image
    }
}
