import Foundation
import os

enum AIError: Error, Equatable {
    case notConfigured(String)
    case http(Int, String)
    case transport(String)
    case malformed

    var message: String {
        switch self {
        case .notConfigured(let text): return text
        case .http(let status, let body): return "HTTP \(status): \(body.prefix(200))"
        case .transport(let text): return text
        case .malformed: return "The provider returned no usable completion"
        }
    }
}

final class AIRequestHandle {
    private let lock = NSLock()
    private var task: URLSessionDataTask?
    private(set) var cancelled = false

    func attach(_ task: URLSessionDataTask) {
        lock.lock()
        defer { lock.unlock() }
        self.task = task
        if cancelled {
            task.cancel()
        }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let task = task
        lock.unlock()
        task?.cancel()
    }
}

enum AIRequestKind {
    case completion
    case answer

    var maxTokens: Int {
        self == .completion ? 400 : 4000
    }
}

enum AIClient {
    static let log = Logger(subsystem: "dev.ride.Ride", category: "ai")
    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 120
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    @discardableResult
    static func complete(
        _ load: @escaping () -> AIPromptInput,
        config: AIConfig,
        done: @escaping (Result<[AISuggestion], AIError>) -> Void
    ) -> AIRequestHandle {
        run(kind: .completion, config: config, build: { (AIPrompt.system, AIPrompt.user(load())) }) { result in
            done(result.map { text in
                let suggestions = AIResponseParser.suggestions(in: text)
                if suggestions.isEmpty {
                    log.error("no suggestions in text: \(text.prefix(400), privacy: .public)")
                }
                return suggestions
            })
        }
    }

    @discardableResult
    static func ask(
        _ load: @escaping () -> (AIPromptInput, String, String?),
        config: AIConfig,
        done: @escaping (Result<String, AIError>) -> Void
    ) -> AIRequestHandle {
        run(kind: .answer, config: config, build: {
            let (input, request, selection) = load()
            return (AIPrompt.askSystem, AIPrompt.ask(input, request: request, selection: selection))
        }, done: done)
    }

    private static func run(
        kind: AIRequestKind,
        config: AIConfig,
        build: @escaping () -> (String, String),
        done: @escaping (Result<String, AIError>) -> Void
    ) -> AIRequestHandle {
        let handle = AIRequestHandle()
        AIActivity.shared.begin()
        DispatchQueue.global(qos: .userInitiated).async {
            let (system, user) = build()
            let built: Result<URLRequest, AIError>
            switch config.provider {
            case .anthropic:
                built = AnthropicMessages.request(system: system, user: user, kind: kind, config: config)
            case .openrouter:
                built = OpenRouterChat.request(system: system, user: user, kind: kind, config: config)
            }
            switch built {
            case .failure(let error):
                log.error("request not built: \(error.message, privacy: .public)")
                finish(.failure(error), handle: handle, done: done)
            case .success(let request):
                log.info("sending \(config.provider.rawValue, privacy: .public) \(config.model, privacy: .public) prompt \(request.httpBody?.count ?? 0) bytes")
                send(request, config: config, handle: handle, done: done)
            }
        }
        return handle
    }

    private static func finish(_ result: Result<String, AIError>, handle: AIRequestHandle, done: @escaping (Result<String, AIError>) -> Void) {
        DispatchQueue.main.async {
            AIActivity.shared.end()
            if !handle.cancelled {
                done(result)
            }
        }
    }

    private static func send(_ request: URLRequest, config: AIConfig, handle: AIRequestHandle, done: @escaping (Result<String, AIError>) -> Void) {
        let task = session.dataTask(with: request) { data, response, error in
            var result = parse(data: data, response: response, error: error, config: config)
            if case .failure(.http(401, _)) = result, config.provider == .anthropic, config.auth == .login {
                AnthropicLogin.forgetToken()
                result = .failure(.notConfigured("Anthropic login expired. Open Preferences › AI and log in again"))
            }
            switch result {
            case .success:
                log.info("reply \((response as? HTTPURLResponse)?.statusCode ?? 0) ok")
            case .failure(let failure):
                log.error("reply failed: \(failure.message, privacy: .public)")
            }
            finish(result, handle: handle, done: done)
        }
        handle.attach(task)
        task.resume()
    }

    private static func errorMessage(in data: Data) -> String {
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let error = object?["error"] as? [String: Any]
        return error?["message"] as? String ?? String(decoding: data, as: UTF8.self)
    }

    private static func parse(data: Data?, response: URLResponse?, error: Error?, config: AIConfig) -> Result<String, AIError> {
        if let error {
            return .failure(.transport(error.localizedDescription))
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let data = data ?? Data()
        guard (200 ..< 300).contains(status) else {
            return .failure(.http(status, errorMessage(in: data)))
        }
        let text: String?
        switch config.provider {
        case .anthropic:
            text = AnthropicMessages.text(in: data)
        case .openrouter:
            text = OpenRouterChat.text(in: data)
        }
        guard let text else {
            log.error("unparsed body: \(String(decoding: data.prefix(400), as: UTF8.self), privacy: .public)")
            return .failure(.malformed)
        }
        return .success(text)
    }
}
