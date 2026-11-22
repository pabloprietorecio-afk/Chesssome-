package com.pabloprieto.motor;

import android.app.Activity;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Stockfish 19 dentro del móvil (GPL v3; ver android_motor/LEEME.md y la pantalla de licencias de la app).
 * El programa va en el APK como lib/arm64-v8a/libstockfish.so (Android solo deja ejecutar programas que vienen como
 * librerías nativas) y se habla con él por UCI, como cualquier interfaz de ajedrez: posición, «go movetime» y se lee
 * la última línea «info» antes de «bestmove».
 * Desde GDScript: Engine.get_singleton("MotorStockfish") (lo usa core/local_engine.gd). Señal: analisis(id, datos),
 * datos en texto «clave=valor» separados por «;» (move, depth, cp o mate desde el bando que mueve, pv).
 */
public class MotorStockfish extends GodotPlugin {
	private static final String BINARY = "libstockfish.so";
	private final ExecutorService worker = Executors.newSingleThreadExecutor();
	private Process process;
	private BufferedReader out;
	private Writer in;

	public MotorStockfish(Godot godot) {
		super(godot);
	}

	@Override
	public String getPluginName() {
		return "MotorStockfish";
	}

	@Override
	public Set<SignalInfo> getPluginSignals() {
		Set<SignalInfo> s = new HashSet<>();
		s.add(new SignalInfo("analisis", Integer.class, String.class));
		return s;
	}

	private File binary() {
		Activity a = getActivity();
		if (a == null) return null;
		return new File(a.getApplicationInfo().nativeLibraryDir, BINARY);
	}

	/** Está el programa en el móvil (solo en el APK compilado con Gradle). */
	@UsedByGodot
	public boolean available() {
		File f = binary();
		return f != null && f.exists();
	}

	/** Analiza una posición durante `millis` ms; el resultado llega por la señal «analisis» con el mismo `id`. */
	@UsedByGodot
	public void analyze(final int id, final String fen, final int millis) {
		worker.execute(() -> {
			String result;
			try {
				result = run(fen, millis, 0);
			} catch (Exception e) {
				shutdown();
				result = "error=" + e.getClass().getSimpleName();
			}
			final String r = result;
			runOnRenderThread(() -> emitSignal("analisis", id, r));
		});
	}

	/**
	 * Juega como rival: la jugada elegida en `millis` ms con la fuerza limitada a `elo` (UCI_LimitStrength y UCI_Elo,
	 * de 1320 a 3190 en Stockfish) o sin límite con `elo` 0. Llega por la misma señal «analisis» (move=…).
	 */
	@UsedByGodot
	public void play(final int id, final String fen, final int millis, final int elo) {
		worker.execute(() -> {
			String result;
			try {
				result = run(fen, millis, elo);
			} catch (Exception e) {
				shutdown();
				result = "error=" + e.getClass().getSimpleName();
			}
			final String r = result;
			runOnRenderThread(() -> emitSignal("analisis", id, r));
		});
	}

	private void send(String cmd) throws Exception {
		in.write(cmd + "\n");
		in.flush();
	}

	private String waitFor(String prefix) throws Exception {
		String line;
		while ((line = out.readLine()) != null) {
			if (line.startsWith(prefix)) return line;
		}
		throw new IllegalStateException("motor cerrado");
	}

	private void start() throws Exception {
		File f = binary();
		if (f == null || !f.exists()) throw new IllegalStateException("sin motor");
		ProcessBuilder pb = new ProcessBuilder(f.getAbsolutePath());
		pb.redirectErrorStream(true);
		process = pb.start();
		out = new BufferedReader(new InputStreamReader(process.getInputStream()));
		in = new OutputStreamWriter(process.getOutputStream());
		send("uci");
		waitFor("uciok");
		// Poco: es un móvil, y la app juega a la vez.
		int cores = Math.max(1, Math.min(2, Runtime.getRuntime().availableProcessors() - 1));
		send("setoption name Threads value " + cores);
		send("setoption name Hash value 32");
		send("isready");
		waitFor("readyok");
	}

	private String run(String fen, int millis, int elo) throws Exception {
		if (process == null || !process.isAlive()) start();
		// El análisis (tutor, pistas) siempre a toda fuerza; el rival, con su Elo.
		if (elo > 0) {
			send("setoption name UCI_LimitStrength value true");
			send("setoption name UCI_Elo value " + Math.max(1320, Math.min(3190, elo)));
		} else {
			send("setoption name UCI_LimitStrength value false");
		}
		send("position fen " + fen);
		send("go movetime " + Math.max(50, Math.min(millis, 5000)));
		String last = "";
		String line;
		while ((line = out.readLine()) != null) {
			if (line.startsWith("info ") && line.contains(" pv ") && line.contains(" score ") && !line.contains(" upperbound") && !line.contains(" lowerbound")) {
				last = line;
			} else if (line.startsWith("bestmove")) {
				return parse(last, line);
			}
		}
		throw new IllegalStateException("motor cerrado");
	}

	private static String parse(String info, String best) {
		StringBuilder r = new StringBuilder();
		String[] b = best.split(" ");
		r.append("move=").append(b.length > 1 ? b[1] : "");
		String[] t = info.split(" ");
		for (int i = 0; i < t.length; i++) {
			if (t[i].equals("depth") && i + 1 < t.length) r.append(";depth=").append(t[i + 1]);
			if (t[i].equals("score") && i + 2 < t.length) r.append(";").append(t[i + 1]).append("=").append(t[i + 2]);
			if (t[i].equals("pv")) {
				r.append(";pv=");
				for (int j = i + 1; j < t.length; j++) {
					if (j > i + 1) r.append(",");
					r.append(t[j]);
				}
				break;
			}
		}
		return r.toString();
	}

	private void shutdown() {
		try {
			if (in != null) send("quit");
		} catch (Exception ignored) {
		}
		if (process != null) process.destroy();
		process = null;
		in = null;
		out = null;
	}

	@Override
	public void onMainDestroy() {
		worker.execute(this::shutdown);
		worker.shutdown();
		super.onMainDestroy();
	}
}
