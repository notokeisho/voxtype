FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY whisper.cpp/ ./whisper.cpp/

WORKDIR /build/whisper.cpp

RUN cmake -B build -DWHISPER_BUILD_SERVER=ON && \
    cmake --build build --config Release -j$(nproc)

FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    libgomp1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /build/whisper.cpp/build/bin/whisper-server /app/
COPY start.sh /app/

RUN chmod +x /app/start.sh /app/whisper-server

EXPOSE 8080

CMD ["/app/start.sh"]
