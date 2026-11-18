import Testing
import LyricsXCore
@testable import LyricsXServices

struct NetEaseArtworkResolverTests {
    @Test func coverRequiresSameSongArtistAlbumAndDuration() {
        let track = Track(playerID: "com.netease.163music", playerName: "NetEase", title: "Song", artist: "Artist", album: "Studio", duration: 200)
        #expect(NetEaseArtworkResolver.matches(title: "SONG", artists: ["Artist"], album: "Studio", duration: 201, track: track))
        #expect(!NetEaseArtworkResolver.matches(title: "Song (Live)", artists: ["Artist"], album: "Studio", duration: 200, track: track))
        #expect(!NetEaseArtworkResolver.matches(title: "Song", artists: ["Other"], album: "Studio", duration: 200, track: track))
        #expect(!NetEaseArtworkResolver.matches(title: "Song", artists: ["Artist"], album: "Greatest Hits", duration: 200, track: track))
        #expect(!NetEaseArtworkResolver.matches(title: "Song", artists: ["Artist"], album: "Studio", duration: 220, track: track))
    }
}
