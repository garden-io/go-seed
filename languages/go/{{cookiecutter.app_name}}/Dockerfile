# Development Stage -> Garden uses this stage for the `local` environment.
FROM golang:1.20.0 AS development

WORKDIR /app

# Install dependencies
COPY go.mod go.sum ./
RUN go mod download

# We only need this dependency in development, as we use it to watch for changes
RUN go install -mod=mod github.com/githubnemo/CompileDaemon

# Copy the rest of the app
COPY . .

# Set the command to use CompileDaemon for hot-reloading
CMD CompileDaemon --build="go build main.go" --command=./main

# Builder stage, this will extract the dependencies and build the binary
FROM golang:1.20.0 AS builder

WORKDIR /app

RUN --mount=type=cache,target=/go/pkg/mod/ \
    --mount=type=bind,source=go.sum,target=go.sum \
    --mount=type=bind,source=go.mod,target=go.mod \
    go mod download -x

COPY . .

RUN --mount=type=cache,target=/go/pkg/mod/ \
    --mount=type=bind,target=. \
    CGO_ENABLED=0 go build -o /bin/main .

# Final production stage, using the smallest image possible (11.8MB in this case)
FROM alpine:3.14 as production

WORKDIR /app

# Creating a non-root user to run the application
ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    go-runner
USER go-runner

# Copying the binary from the builder stage
COPY --from=builder /bin/main .

# Run it! 🚀
CMD ["/app/main"]
