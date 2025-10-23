# Multi-stage build for Swift Vapor app

# Build stage
FROM swift:5.9-jammy as builder

WORKDIR /build

# Install dependencies
RUN apt-get update && apt-get install -y \
    libssl-dev \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy source code
COPY Package.swift Package.resolved* ./
COPY Sources ./Sources
COPY Public ./Public

# Build release
RUN swift build -c release

# Runtime stage
FROM swift:5.9-jammy-slim

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libssl3 \
    libsqlite3-0 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy built artifacts from builder
COPY --from=builder /build/.build/release/App /app/app
COPY --from=builder /build/Public ./Public

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/api/health || exit 1

# Set environment
ENV PORT=8080
ENV LOG_LEVEL=info

# Expose port
EXPOSE 8080

# Run application
CMD ["/app/app", "serve", "--hostname", "0.0.0.0", "--port", "8080"]
