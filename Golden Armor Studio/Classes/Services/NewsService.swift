import Foundation
import FirebaseAuth

final class NewsService {
    static let shared = NewsService()

    private let baseURL = URL(string: "https://us-central1-goldenarmorstudios.cloudfunctions.net")!
    private let session: URLSession
    private let decoder: JSONDecoder
    private let errorDecoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
        errorDecoder = JSONDecoder()
    }

    func fetchPublishedNews(completion: @escaping (Result<[NewsArticleSummary], Error>) -> Void) {
        call(function: "listPublishedNews", payload: [:], requiresAuth: false) { (result: Result<NewsListResponse, Error>) in
            completion(result.map { $0.articles })
        }
    }

    func fetchArticleDetail(id: String, completion: @escaping (Result<NewsArticleDetail, Error>) -> Void) {
        call(function: "getPublishedNewsArticle", payload: ["id": id], requiresAuth: false) { (result: Result<NewsArticleDetailResponse, Error>) in
            completion(result.map { $0.article })
        }
    }

    func fetchComments(for articleID: String, completion: @escaping (Result<[NewsComment], Error>) -> Void) {
        call(function: "getPublishedNewsComments", payload: ["id": articleID, "limit": 100], requiresAuth: false) { (result: Result<NewsCommentsResponse, Error>) in
            completion(result.map { $0.comments })
        }
    }

    func toggleFlag(newsID: String, commentID: String, completion: @escaping (Result<ToggleFlagResponse, Error>) -> Void) {
        call(function: "toggleNewsCommentFlag", payload: ["newsId": newsID, "commentId": commentID], requiresAuth: true, completion: completion)
    }

    private func call<T: Decodable>(function name: String, payload: [String: Any], requiresAuth: Bool, completion: @escaping (Result<T, Error>) -> Void) {
        var request = URLRequest(url: baseURL.appendingPathComponent(name))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["data": payload]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }

        let performRequest: (String?) -> Void = { [weak self] token in
            guard let self else { return }
            if let token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            self.session.dataTask(with: request) { data, response, error in
                if let error {
                    DispatchQueue.main.async { completion(.failure(error)) }
                    return
                }

                guard let data else {
                    let err = NSError(domain: "NewsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing response data"])
                    DispatchQueue.main.async { completion(.failure(err)) }
                    return
                }

                do {
                    let decoded = try self.decoder.decode(CallableResponse<T>.self, from: data)
                    DispatchQueue.main.async { completion(.success(decoded.value)) }
                } catch {
                    if let apiError = try? self.errorDecoder.decode(CallableErrorResponse.self, from: data) {
                        let err = NSError(domain: "NewsService", code: -2, userInfo: [NSLocalizedDescriptionKey: apiError.error.message])
                        DispatchQueue.main.async { completion(.failure(err)) }
                    } else {
                        DispatchQueue.main.async { completion(.failure(error)) }
                    }
                }
            }.resume()
        }

        if requiresAuth {
            guard let user = Auth.auth().currentUser else {
                let error = NSError(domain: "NewsService", code: -3, userInfo: [NSLocalizedDescriptionKey: "You must be signed in to perform this action."])
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            user.getIDToken { token, error in
                if let error {
                    DispatchQueue.main.async { completion(.failure(error)) }
                    return
                }
                performRequest(token)
            }
        } else {
            performRequest(nil)
        }
    }
}

private struct CallableResponse<T: Decodable>: Decodable {
    let value: T

    enum CodingKeys: String, CodingKey {
        case data
        case result
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let dataValue = try container.decodeIfPresent(T.self, forKey: .data) {
            value = dataValue
        } else if let resultValue = try container.decodeIfPresent(T.self, forKey: .result) {
            value = resultValue
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Missing data/result payload"))
        }
    }
}

private struct CallableErrorResponse: Decodable {
    struct ErrorBody: Decodable {
        let message: String
    }
    let error: ErrorBody
}
