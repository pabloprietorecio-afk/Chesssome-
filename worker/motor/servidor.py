"""Stockfish por HTTP para el servidor del profesor (worker/motor).

POST /analizar {"fen": "...", "ms": 1000} → la misma forma que chess-api.com (valores desde las blancas):
{"type": "bestmove", "move", "depth", "centipawns", "mate", "continuationArr", "fuente": "motor"}
GET cualquier otra ruta → 200 «ok» (lo usa Cloudflare para saber que ha arrancado).

Un solo proceso de Stockfish, una consulta cada vez (con un candado): el contenedor tiene una vCPU.
"""
import json
import os
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MAX_MS = 3000
MAX_DEPTH = 24


def binary() -> str:
    forced = os.environ.get("STOCKFISH")
    if forced:
        return forced
    try:
        flags = open("/proc/cpuinfo").read()
    except OSError:
        flags = ""
    return "/usr/local/bin/stockfish-avx2" if " avx2" in flags else "/usr/local/bin/stockfish-sse41"


class Engine:
    def __init__(self, path: str):
        self.path = path
        self.lock = threading.Lock()
        self.proc = None

    def _start(self):
        self.proc = subprocess.Popen([self.path], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
        self._send("uci")
        self._until("uciok")
        self._send(f"setoption name Threads value {int(os.environ.get('THREADS', '1'))}")
        self._send(f"setoption name Hash value {int(os.environ.get('HASH', '256'))}")
        self._send("isready")
        self._until("readyok")

    def _send(self, line: str):
        self.proc.stdin.write(line + "\n")
        self.proc.stdin.flush()

    def _until(self, word: str):
        lines = []
        while True:
            line = self.proc.stdout.readline()
            if not line:
                raise RuntimeError("stockfish se ha cerrado")
            line = line.strip()
            lines.append(line)
            if line.startswith(word):
                return lines

    def analyze(self, fen: str, ms: int) -> dict:
        with self.lock:
            if self.proc is None or self.proc.poll() is not None:
                self._start()
            self._send(f"position fen {fen}")
            self._send("isready")
            self._until("readyok")
            self._send(f"go movetime {ms} depth {MAX_DEPTH}")
            lines = self._until("bestmove")
        return parse(lines, fen)


def parse(lines: list, fen: str) -> dict:
    """La última línea «info» con puntuación y variante (multipv 1), y la jugada final. Stockfish da la puntuación
    desde el bando que mueve; chess-api.com, desde las blancas: se da la vuelta si mueven las negras."""
    sign = -1 if fen.split()[1:2] == ["b"] else 1
    best = None
    for line in lines:
        t = line.split()
        if not t or t[0] != "info" or "score" not in t or " pv " not in f" {line} ":
            continue
        if "multipv" in t and t[t.index("multipv") + 1] != "1":
            continue
        if "lowerbound" in t or "upperbound" in t:
            continue
        best = t
    move = lines[-1].split()[1] if lines and len(lines[-1].split()) > 1 else ""
    out = {"type": "bestmove", "move": move, "depth": 0, "centipawns": 0, "mate": None, "continuationArr": [move] if move else [], "fuente": "motor"}
    if best:
        i = best.index("score")
        kind, value = best[i + 1], int(best[i + 2])
        out["depth"] = int(best[best.index("depth") + 1]) if "depth" in best else 0
        if kind == "mate":
            out["mate"] = value * sign
            out["centipawns"] = 10000 if value * sign > 0 else -10000
        else:
            out["centipawns"] = value * sign
        pv = best[best.index("pv") + 1 :]
        if pv:
            out["continuationArr"] = pv
            if not move or move == "(none)":
                out["move"] = pv[0]
    return out


ENGINE = Engine(binary())


class Handler(BaseHTTPRequestHandler):
    def _reply(self, code: int, body: dict | str):
        data = (json.dumps(body) if isinstance(body, dict) else body).encode()
        self.send_response(code)
        self.send_header("content-type", "application/json" if isinstance(body, dict) else "text/plain")
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        self._reply(200, "ok")

    def do_POST(self):
        if self.path.rstrip("/") != "/analizar":
            return self._reply(404, {"error": "ruta"})
        try:
            n = int(self.headers.get("content-length", "0"))
            req = json.loads(self.rfile.read(min(n, 4096)) or b"{}")
            fen = str(req.get("fen", "")).strip()
            parts = fen.split()
            if len(parts) < 2 or parts[1] not in ("w", "b") or len(fen) > 100 or any(c in fen for c in "\r\n"):
                return self._reply(400, {"error": "fen"})
            ms = max(50, min(MAX_MS, int(req.get("ms", 1000))))
            return self._reply(200, ENGINE.analyze(fen, ms))
        except Exception as e:  # noqa: BLE001
            return self._reply(500, {"error": str(e)[:200]})

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    print(f"Stockfish ({ENGINE.path}) en el puerto {port}", file=sys.stderr)
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
