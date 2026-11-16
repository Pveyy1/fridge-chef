import Foundation
import UIKit

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct APIClient {
    let baseURL: String

    private var root: URL {
        get throws {
            let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let url = URL(string: trimmed), url.scheme != nil else {
                throw APIError(message: "The server address looks wrong. Fix it in Settings (gear icon).")
            }
            return url
        }
    }

    func health() async throws -> Health {
        var req = URLRequest(url: try root.appendingPathComponent("health"))
        req.timeoutInterval = 75
        return try await send(req)
    }

    func detect(images: [UIImage]) async throws -> Detection {
        let boundary = "FridgeChef-\(UUID().uuidString)"
        var body = Data()
        for (i, image) in images.enumerated() {
            guard let jpeg = image.downscaled(maxSide: 1568).jpegData(compressionQuality: 0.8) else { continue }
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"photos\"; filename=\"shelf\(i).jpg\"\r\n")
            body.append("Content-Type: image/jpeg\r\n\r\n")
            body.append(jpeg)
            body.append("\r\n")
        }
        body.append("--\(boundary)--\r\n")

        var req = URLRequest(url: try root.appendingPathComponent("detect"))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.timeoutInterval = 120
        return try await send(req)
    }

    func recipes(_ request: RecipeRequest) async throws -> [Dish] {
        var req = URLRequest(url: try root.appendingPathComponent("recipes"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(request)
        req.timeoutInterval = 120
        let resp: DishesResponse = try await send(req)
        return resp.dishes
    }

    private func send<T: Decodable>(_ req: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError(message: "Can’t reach the Fridge Chef server. Check your internet connection and try again — if it’s been idle, the server may take a minute to wake up.")
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = obj["detail"] as? String {
                throw APIError(message: detail)
            }
            throw APIError(message: "The server had a hiccup (\(status)). Please try again.")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError(message: "The server's answer didn't make sense. Please try again.")
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}

extension UIImage {
    func downscaled(maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return self }
        let scale = maxSide / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
