import Foundation

struct NewsListResponse: Codable {
    let articles: [NewsArticleSummary]
}

struct NewsArticleSummary: Codable {
    let id: String
    let title: String
    let summary: String?
    let status: String?
    let coverImage: MediaAsset?
    let media: [MediaAsset]?
    let likesCount: Int?
    let commentsCount: Int?
    let publishedAt: FirestoreTimestamp?
    let updatedAt: FirestoreTimestamp?

    var heroImageURL: URL? {
        if let urlString = coverImage?.downloadUrl ?? coverImage?.url,
           let url = URL(string: urlString) {
            return url
        }
        if let media,
           let urlString = media.compactMap({ $0.downloadUrl ?? $0.url }).first,
           let url = URL(string: urlString) {
            return url
        }
        return nil
    }
}

struct MediaAsset: Codable {
    let downloadUrl: String?
    let url: String?
    let storagePath: String?
}

struct NewsArticleDetailResponse: Codable {
    let article: NewsArticleDetail
}

struct NewsArticleDetail: Codable {
    let id: String
    let title: String
    let summary: String?
    let contentHtml: String?
    let legacyContent: String?
    let coverImage: MediaAsset?
    let media: [MediaAsset]?
    let likesCount: Int?
    let commentsCount: Int?
    let publishedAt: FirestoreTimestamp?
    let updatedAt: FirestoreTimestamp?
    let createdBy: String?
}

struct NewsCommentsResponse: Codable {
    let comments: [NewsComment]
}

struct NewsComment: Codable {
    let id: String
    let uid: String?
    let displayName: String
    let avatarUrl: String?
    let message: String
    let createdAt: FirestoreTimestamp?
    var likesCount: Int?
    var likedByCurrentUser: Bool?
    let flagsCount: Int?
    var flaggedByCurrentUser: Bool?
}

struct ToggleFlagResponse: Codable {
    let flagged: Bool
    let flagsCount: Int?
}

struct NewsEngagement: Codable {
    let liked: Bool
    let likesCount: Int
    let commentsCount: Int?
}

struct ToggleNewsLikeResponse: Codable {
    let liked: Bool
    let likesCount: Int
}

struct ToggleCommentLikeResponse: Codable {
    let liked: Bool
    let likesCount: Int
}

struct AddNewsCommentResponse: Codable {
    let comment: NewsComment
    let commentsCount: Int
}

struct FirestoreTimestamp: Codable {
    let seconds: TimeInterval

    var date: Date {
        Date(timeIntervalSince1970: seconds)
    }

    init(seconds: TimeInterval) {
        self.seconds = seconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let doubleValue = try? container.decode(Double.self) {
            seconds = doubleValue
            return
        }

        if let stringValue = try? container.decode(String.self),
           let doubleValue = Double(stringValue) {
            seconds = doubleValue
            return
        }

        if let intValue = try? container.decode(Int.self) {
            seconds = TimeInterval(intValue)
            return
        }

        if let dict = try? container.decode([String: Double].self),
           let value = dict["_seconds"] ?? dict["seconds"] {
            seconds = value
            return
        }

        if let dictInt = try? container.decode([String: Int].self),
           let value = dictInt["_seconds"] ?? dictInt["seconds"] {
            seconds = TimeInterval(value)
            return
        }

        seconds = 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(seconds)
    }
}
