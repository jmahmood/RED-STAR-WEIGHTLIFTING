import Foundation

public enum StoredLinkKind: String, CaseIterable, Codable {
    case reading
    case video
    case music

    public var displayName: String {
        switch self {
        case .reading: "Reading List"
        case .video: "Video List"
        case .music: "Music List"
        }
    }
}

public struct StoredLink: Identifiable, Hashable {
    public let id: Int64
    public let url: URL
    public let kind: StoredLinkKind
    public let title: String?
    public let createdAt: Date
}
