import Foundation

final class AIStreamHandle {
    fileprivate var task: Task<Void, Never>?

    func cancel() {
        task?.cancel()
    }
}

enum AIStreamEvent: Equatable {
    case text(String)
    case finished
    case failed(AIError)
}

enum AIStreamClient {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 600
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    @discardableResult
    static func stream(
        system: String,
        turns: [AIChatTurn],
        config: AIConfig,
        onEvent: @escaping (AIStreamEvent) -> Void
    ) -> AIStreamHandle {
        let handle = AIStreamHandle()
        AIActivity.shared.begin()
        let deliver: (AIStreamEvent) -> Void = { event in
            DispatchQueue.main.async {
                if handle.task?.isCancelled != true {
                    onEvent(event)
                }
            }
        }
        handle.task = Task.detached(priority: .userInitiated) {
            let ending = await run(system: system, turns: turns, config: config, deliver: deliver)
            DispatchQueue.main.async {
                AIActivity.shared.end()
                if !Task.isCancelled, handle.task?.isCancelled != true {
                    onEvent(ending)
                }
            }
        }
        return handle
    }

    private static func run(
        system: String,
        turns: [AIChatTurn],
        config: AIConfig,
        deliver: @escaping (AIStreamEvent) -> Void
    ) async -> AIStreamEvent {
        let request: URLRequest
        switch AIStreamRequest.build(system: system, turns: turns, config: config) {
        case .failure(let error):
            return .failed(error)
        case .success(let built):
            request = built
        }
        do {
            let (bytes, response) = try await session.bytes(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200 ..< 300).contains(status) else {
                return .failed(.http(status, await body(of: bytes)))
            }
            let decoder = AIStreamRequest.decoder(for: config.provider)
            for try await line in bytes.lines {
                if Task.isCancelled {
                    return .finished
                }
                guard let payload = AIStreamJSON.payload(ofLine: line), let piece = decoder.decode(data: payload) else {
                    continue
                }
                switch piece {
                case .text(let text):
                    deliver(.text(text))
                case .refused(let message):
                    deliver(.text("\n\n_\(message)_"))
                case .failed(let message):
                    return .failed(.transport(message))
                case .done:
                    return .finished
                }
            }
            return .finished
        } catch {
            return Task.isCancelled ? .finished : .failed(.transport(error.localizedDescription))
        }
    }

    private static func body(of bytes: URLSession.AsyncBytes) async -> String {
        var lines: [String] = []
        do {
            for try await line in bytes.lines {
                lines.append(line)
            }
        } catch {
            return lines.joined(separator: "\n")
        }
        let text = lines.joined(separator: "\n")
        let object = AIStreamJSON.object(text)
        let error = object?["error"] as? [String: Any]
        return error?["message"] as? String ?? text
    }
}
