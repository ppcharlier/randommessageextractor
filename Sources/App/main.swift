import Vapor
import Foundation

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)

let app = Application(env)
defer { app.shutdown() }

// CORS Configuration
let corsConfiguration = CORSMiddleware.Configuration(
    allowedOrigin: .all,
    allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE],
    allowedHeaders: [.accept, .contentType]
)
app.middleware.use(CORSMiddleware(configuration: corsConfiguration))

// Configure multipart file upload handler
app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

// Routes
try extractionRoutes(app)
try webSocketRoutes(app)
try generatorRoutes(app)

// Serve index.html for all non-API routes (SPA fallback)
app.get("**") { req -> Response in
    let indexPath = app.directory.publicDirectory + "index.html"
    return try req.fileio.streamFile(at: indexPath)
}

try app.run()
