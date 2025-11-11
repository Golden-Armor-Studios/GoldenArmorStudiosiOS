import UIKit

final class ImageLoader {
    static let shared = ImageLoader()

    private let cache = NSCache<NSURL, UIImage>()
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: configuration)
    }

    func loadImage(from url: URL?, completion: @escaping (UIImage?) -> Void) {
        guard let url else {
            completion(nil)
            return
        }

        if let cached = cache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }

        session.dataTask(with: url) { [weak self] data, response, error in
            guard let self else { return }

            if let error {
                print("[ImageLoader] Failed to load image: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            guard let data, let image = UIImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            self.cache.setObject(image, forKey: url as NSURL)
            DispatchQueue.main.async { completion(image) }
        }.resume()
    }
}
