FROM golang:1.24
WORKDIR /app
COPY . .
RUN go mod download
RUN go build -o orders .
RUN useradd -m appuser && chown -R appuser:appuser /app
EXPOSE 8080
USER appuser
CMD ["./orders"]
