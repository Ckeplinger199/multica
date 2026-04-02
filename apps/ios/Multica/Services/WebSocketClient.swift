import Foundation

struct WSEvent: @unchecked Sendable {
    let type: String
    let payload: [String: Any]
    let actorId: String?

    var prefix: String {
        String(type.prefix(while: { $0 != ":" }))
    }
}

@MainActor
final class WebSocketClient: ObservableObject {
    static let shared = WebSocketClient()

    @Published var isConnected = false

    private var webSocketTask: URLSessionWebSocketTask?
    private var handlers: [(String, @Sendable (WSEvent) -> Void)] = []
    private var reconnectTask: Task<Void, Never>?
    private let session = URLSession(configuration: .default)

    private init() {}

    func connect() {
        guard let token = APIClient.shared.token,
              let workspaceId = APIClient.shared.workspaceId else { return }

        let wsScheme: String
        #if DEBUG
        wsScheme = "ws"
        #else
        wsScheme = "wss"
        #endif

        let baseHost = APIClient.shared.baseURL
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")

        guard let url = URL(string: "\(wsScheme)://\(baseHost)/ws?token=\(token)&workspace_id=\(workspaceId)") else {
            return
        }

        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        receiveMessage()
    }

    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        handlers.removeAll()
    }

    func on(_ eventType: String, handler: @escaping @Sendable (WSEvent) -> Void) {
        handlers.append((eventType, handler))
    }

    func onPrefix(_ prefix: String, handler: @escaping @Sendable (WSEvent) -> Void) {
        handlers.append(("prefix:\(prefix)", handler))
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleMessage(text)
                        }
                    @unknown default:
                        break
                    }
                    self.receiveMessage()
                case .failure:
                    self.isConnected = false
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        let payload = json["payload"] as? [String: Any] ?? [:]
        let actorId = json["actor_id"] as? String
        let event = WSEvent(type: type, payload: payload, actorId: actorId)

        for (pattern, handler) in handlers {
            if pattern == type {
                handler(event)
            } else if pattern.hasPrefix("prefix:") {
                let prefix = String(pattern.dropFirst(7))
                if event.prefix == prefix {
                    handler(event)
                }
            }
        }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self.connect()
        }
    }
}
