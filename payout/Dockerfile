FROM golang:1.22-bookworm AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /symp-payout ./cmd/symp-payout

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /
COPY --from=build /symp-payout /symp-payout
ENV HTTP_ADDR=:8088
EXPOSE 8088
USER nonroot:nonroot
ENTRYPOINT ["/symp-payout"]
