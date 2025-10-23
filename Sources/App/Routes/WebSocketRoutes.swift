import Vapor
import Foundation

// Shared WebSocket connections manager
actor WebSocketManager {
    static let shared = WebSocketManager()
    private var connections: [String: WebSocket] = [:]

    func register(_ ws: WebSocket, clientId: String) {
        connections[clientId] = ws
    }

    func unregister(_ clientId: String) {
        connections.removeValue(forKey: clientId)
    }

    func broadcast(_ message: String) async {
        for (_, ws) in connections {
            if !ws.isClosed {
                try? await ws.send(message)
            }
        }
    }

    func getConnectionCount() -> Int {
        return connections.count
    }
}

struct WSMessage: Codable {
    let type: String  // "extraction", "connected", "disconnected", "status"
    let data: String? // JSON data
    let clientId: String?
    let timestamp: String
    let activeConnections: Int?
}

struct WSExtractionData: Codable {
    let resultId: String
    let clientId: String
    let delimiter: String
    let messageCount: Int
    let processingTimeMs: Double
    let dataProcessedKB: Double
}

func webSocketRoutes(_ app: Application) throws {
    // WebSocket endpoint for real-time synchronization
    app.webSocket("api", "ws") { req, ws in
        let clientId = UUID().uuidString
        print("[WebSocket] Client connected: \(clientId)")

        // Register this connection
        Task {
            await WebSocketManager.shared.register(ws, clientId: clientId)

            // Send welcome message
            let connectionCount = await WebSocketManager.shared.getConnectionCount()
            let welcomeMsg = WSMessage(
                type: "connected",
                data: "Client connected with ID: \(clientId)",
                clientId: clientId,
                timestamp: ISO8601DateFormatter().string(from: Date()),
                activeConnections: connectionCount
            )

            if let jsonData = try? JSONEncoder().encode(welcomeMsg),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                try? await ws.send(jsonString)

                // Broadcast to all clients
                await WebSocketManager.shared.broadcast(jsonString)
            }
        }

        // Handle incoming messages from client
        ws.onText { ws, text in
            print("[WebSocket] Received from \(clientId): \(text.prefix(100))")

            // Try to parse as extraction notification
            if let data = text.data(using: .utf8),
               let extractionData = try? JSONDecoder().decode(WSExtractionData.self, from: data) {
                // Broadcast extraction to all clients
                Task {
                    let extractionMsg = WSMessage(
                        type: "extraction",
                        data: text,
                        clientId: clientId,
                        timestamp: ISO8601DateFormatter().string(from: Date()),
                        activeConnections: await WebSocketManager.shared.getConnectionCount()
                    )

                    if let jsonData = try? JSONEncoder().encode(extractionMsg),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        await WebSocketManager.shared.broadcast(jsonString)
                    }
                }
            }
        }

        // Handle disconnection
        ws.onClose.whenComplete { result in
            print("[WebSocket] Client disconnected: \(clientId)")
            Task {
                await WebSocketManager.shared.unregister(clientId)

                // Broadcast disconnection
                let connectionCount = await WebSocketManager.shared.getConnectionCount()
                let disconnectMsg = WSMessage(
                    type: "disconnected",
                    data: "Client disconnected: \(clientId)",
                    clientId: clientId,
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    activeConnections: connectionCount
                )

                if let jsonData = try? JSONEncoder().encode(disconnectMsg),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    await WebSocketManager.shared.broadcast(jsonString)
                }
            }
        }
    }

    // Status endpoint - get current WebSocket connection count
    app.get("api", "ws", "status") { req -> String in
        let count = await WebSocketManager.shared.getConnectionCount()
        return "Active WebSocket connections: \(count)"
    }
}
