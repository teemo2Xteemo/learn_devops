# stage 1: build binary
FROM golang:1.26.5-alpine AS builder
WORKDIR /app
COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -o server main.go


# stage 2: create minimal image
FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /
COPY --from=builder /app/server .
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/server"]