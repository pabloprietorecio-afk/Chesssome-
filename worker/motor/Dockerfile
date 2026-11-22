# Stockfish propio para el servidor del profesor (worker/motor). Se compila desde el código oficial, en dos
# variantes: AVX2 (rápida) y SSE4.1 (por si la máquina no tiene AVX2); servidor.py elige al arrancar.
FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends git make g++ ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
ARG SF_TAG=sf_19
RUN git clone --depth 1 --branch "$SF_TAG" https://github.com/official-stockfish/Stockfish.git /sf
WORKDIR /sf/src
RUN make -j"$(nproc)" build ARCH=x86-64-avx2 && strip stockfish && mv stockfish /stockfish-avx2 \
    && make clean && make -j"$(nproc)" build ARCH=x86-64-sse41-popcnt && strip stockfish && mv stockfish /stockfish-sse41

FROM python:3.12-slim
COPY --from=build /stockfish-avx2 /stockfish-sse41 /usr/local/bin/
COPY servidor.py /app/servidor.py
EXPOSE 8080
CMD ["python3", "-u", "/app/servidor.py"]
