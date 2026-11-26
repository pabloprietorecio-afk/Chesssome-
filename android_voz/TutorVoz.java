package com.pabloprieto.voz;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import android.util.Base64;
import android.os.Bundle;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.Set;

/**
 * Preguntas al tutor por voz: el reconocimiento de voz del sistema (SpeechRecognizer, normalmente el de Google),
 * sin interfaz propia. Copiado del complemento de A Tank Story (Tank-Ahead, android_plugins/speech_commands), que
 * funciona en el móvil de Pablo, y con los mismos extras que el dictado de WakeAgenda. El primer TutorVoz forzaba
 * EXTRA_LANGUAGE_PREFERENCE y el servicio de Google acababa en «no te he entendido» a los dos segundos (21 nov).
 * El permiso del micrófono lo pide GDScript (OS.request_permission), como en A Tank Story.
 * La app no graba ni guarda audio: el texto reconocido llega a GDScript y se manda como pregunta escrita.
 * Desde GDScript: Engine.get_singleton("TutorVoz") (lo usa core/tutor_voice.gd).
 */
public class TutorVoz extends GodotPlugin {
	private SpeechRecognizer recognizer;
	/** Último texto parcial de la sesión: si el servicio acaba con «no te he entendido», se usa este. */
	private String lastPartial = "";

	public TutorVoz(Godot godot) {
		super(godot);
	}

	@Override
	public String getPluginName() {
		return "TutorVoz";
	}

	@Override
	public Set<SignalInfo> getPluginSignals() {
		Set<SignalInfo> out = new HashSet<>();
		out.add(new SignalInfo("voz_lista"));
		out.add(new SignalInfo("voz_parcial", String.class));
		out.add(new SignalInfo("voz_texto", String.class));
		out.add(new SignalInfo("voz_error", Integer.class));
		out.add(new SignalInfo("voz_audio", String.class));
		out.add(new SignalInfo("voz_nivel", Float.class));
		return out;
	}

	/** Hay un servicio de reconocimiento de voz instalado. */
	@UsedByGodot
	public boolean available() {
		Activity a = getActivity();
		return a != null && SpeechRecognizer.isRecognitionAvailable(a);
	}

	/** Empieza a escuchar en el idioma indicado (etiqueta BCP 47, p. ej. «es-ES»). */
	@UsedByGodot
	public void start(final String lang) {
		final Activity a = getActivity();
		if (a == null) return;
		a.runOnUiThread(() -> {
			destroyRecognizer();
			try {
				recognizer = SpeechRecognizer.createSpeechRecognizer(a);
			} catch (Exception e) {
				recognizer = null;
			}
			if (recognizer == null) {
				emit("voz_error", Integer.valueOf(SpeechRecognizer.ERROR_CLIENT));
				return;
			}
			recognizer.setRecognitionListener(new Listener());
			// Los mismos extras que A Tank Story y WakeAgenda: sin forzar la preferencia de idioma ni pistas.
			Intent i = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
			i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
			i.putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang);
			i.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true);
			i.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1);
			i.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, a.getPackageName());
			lastPartial = "";
			try {
				recognizer.startListening(i);
			} catch (Exception e) {
				destroyRecognizer();
				emit("voz_error", Integer.valueOf(SpeechRecognizer.ERROR_CLIENT));
			}
		});
	}

	/** Deja de escuchar y entrega lo que haya entendido. */
	@UsedByGodot
	public void stop() {
		Activity a = getActivity();
		if (a == null) return;
		a.runOnUiThread(() -> {
			if (recognizer != null) recognizer.stopListening();
		});
	}

	/** Deja de escuchar y descarta lo oído. */
	@UsedByGodot
	public void cancel() {
		Activity a = getActivity();
		if (a == null) return;
		a.runOnUiThread(this::destroyRecognizer);
	}

	// ------------------------------------------------------------ grabar para Whisper (servidor)
	// Grabación nativa (AudioRecord, 16 kHz, mono, 16 bits): el micrófono de Godot no grababa nada en el móvil de
	// Pablo (22 nov). Corta sola tras 1,3 s de silencio después de hablar, a los 12 s como mucho, y se rinde si en
	// 7 s no oye nada. Entrega un WAV en base64 por «voz_audio».
	private static final int RATE = 16000;
	private volatile boolean recording = false;
	private volatile boolean cancelled = false;

	@UsedByGodot
	public boolean record_start() {
		Activity a = getActivity();
		if (a == null || recording) return false;
		if (a.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) return false;
		destroyRecognizer();
		recording = true;
		cancelled = false;
		new Thread(this::recordLoop, "TutorVozGraba").start();
		return true;
	}

	/** Deja de grabar y entrega lo grabado. */
	@UsedByGodot
	public void record_stop() {
		recording = false;
	}

	@UsedByGodot
	public void record_cancel() {
		cancelled = true;
		recording = false;
	}

	private void recordLoop() {
		AudioRecord rec = null;
		ByteArrayOutputStream pcm = new ByteArrayOutputStream();
		try {
			int min = AudioRecord.getMinBufferSize(RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT);
			rec = new AudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION, RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, Math.max(min, RATE));
			if (rec.getState() != AudioRecord.STATE_INITIALIZED) throw new IllegalStateException("micrófono");
			rec.startRecording();
			short[] buf = new short[RATE / 10];
			long start = System.currentTimeMillis();
			long quietSince = -1;
			boolean heard = false;
			double floor = -1;
			while (recording) {
				int n = rec.read(buf, 0, buf.length);
				if (n <= 0) continue;
				double sum = 0;
				byte[] bytes = new byte[n * 2];
				for (int i = 0; i < n; i++) {
					double v = buf[i] / 32768.0;
					sum += v * v;
					bytes[i * 2] = (byte) (buf[i] & 0xff);
					bytes[i * 2 + 1] = (byte) ((buf[i] >> 8) & 0xff);
				}
				pcm.write(bytes, 0, bytes.length);
				double rms = Math.sqrt(sum / n);
				long now = System.currentTimeMillis();
				// Ruido de fondo: la décima más callada hasta ahora (las pausas entre palabras), no las primeras décimas:
				// si se empezaba a hablar nada más pulsar, la voz pasaba por ruido y las partes suaves por silencio, y
				// cortaba antes de tiempo (lo vio Pablo, 22 nov).
				if (floor < 0 || rms < floor) floor = rms;
				double threshold = Math.max(0.006, Math.min(floor * 2.5, 0.03));
				if (rms >= threshold) {
					heard = true;
					quietSince = -1;
				} else if (heard && quietSince < 0) {
					quietSince = now;
				}
				// La onda del campo de texto (Pablo, 26 nov): sigue la voz de verdad. Bajo el umbral (silencio o ruido
				// de fondo), 0: la onda se queda quieta. Encima, en decibelios sobre el umbral (unos 26 dB llenan la barra).
				float level = 0f;
				if (rms >= threshold) {
					level = (float) Math.max(0.12, Math.min(1.0, 20.0 * Math.log10(rms / threshold) / 26.0));
				}
				if (recording) emit("voz_nivel", Float.valueOf(level));
				// 2,2 s de silencio: deja pensar entre palabras («caballo… a efe tres»). Se puede cortar antes tocando.
				if (heard && quietSince > 0 && now - quietSince >= 2200) break;
				if (now - start >= 20000) break;
				if (!heard && now - start >= 7000) {
					recording = false;
					cancelled = true;
					emit("voz_error", Integer.valueOf(SpeechRecognizer.ERROR_SPEECH_TIMEOUT));
				}
			}
		} catch (Exception e) {
			recording = false;
			cancelled = true;
			emit("voz_error", Integer.valueOf(SpeechRecognizer.ERROR_AUDIO));
		} finally {
			if (rec != null) {
				try {
					rec.stop();
				} catch (Exception ignored) {
				}
				rec.release();
			}
		}
		recording = false;
		if (cancelled) return;
		byte[] data = pcm.toByteArray();
		emit("voz_audio", Base64.encodeToString(wav(data), Base64.NO_WRAP));
	}

	private static byte[] wav(byte[] pcm) {
		ByteArrayOutputStream out = new ByteArrayOutputStream();
		int total = 36 + pcm.length;
		int[] header = { 0x46464952, total, 0x45564157, 0x20746d66, 16 };
		for (int v : header) le32(out, v);
		le16(out, 1);
		le16(out, 1);
		le32(out, RATE);
		le32(out, RATE * 2);
		le16(out, 2);
		le16(out, 16);
		le32(out, 0x61746164);
		le32(out, pcm.length);
		out.write(pcm, 0, pcm.length);
		return out.toByteArray();
	}

	private static void le32(ByteArrayOutputStream o, int v) {
		o.write(v & 0xff);
		o.write((v >> 8) & 0xff);
		o.write((v >> 16) & 0xff);
		o.write((v >> 24) & 0xff);
	}

	private static void le16(ByteArrayOutputStream o, int v) {
		o.write(v & 0xff);
		o.write((v >> 8) & 0xff);
	}

	@Override
	public void onMainPause() {
		super.onMainPause();
		record_cancel();
		destroyRecognizer();
	}

	@Override
	public void onMainDestroy() {
		destroyRecognizer();
		super.onMainDestroy();
	}

	/** Las señales se emiten en el hilo de Godot, no en el de la interfaz de Android. */
	private void emit(final String name, final Object... args) {
		runOnRenderThread(() -> emitSignal(name, args));
	}

	private void destroyRecognizer() {
		if (recognizer != null) {
			try {
				recognizer.cancel();
				recognizer.destroy();
			} catch (Exception ignored) {
			}
			recognizer = null;
		}
	}

	private static String first(Bundle b) {
		if (b == null) return "";
		ArrayList<String> list = b.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
		return list == null || list.isEmpty() || list.get(0) == null ? "" : list.get(0);
	}

	private class Listener implements RecognitionListener {
		@Override public void onReadyForSpeech(Bundle params) { emit("voz_lista"); }
		@Override public void onBeginningOfSpeech() {}
		/**
		 * Volumen del micrófono según el reconocedor del sistema (sin servidor de dictado). Cada servicio da su escala;
		 * el de Google suele moverse entre −2 dB (silencio) y 10 dB: por debajo de 2, la onda quieta. Algunos móviles
		 * lo mandan a ratos o nada: entonces la onda no se mueve (sin animación de adorno).
		 */
		@Override
		public void onRmsChanged(float rmsdB) {
			float level = rmsdB <= 2f ? 0f : Math.max(0.12f, Math.min(1f, (rmsdB - 2f) / 8f));
			emit("voz_nivel", Float.valueOf(level));
		}
		@Override public void onBufferReceived(byte[] buffer) {}
		@Override public void onEndOfSpeech() {}

		@Override
		public void onError(int error) {
			String heard = lastPartial;
			destroyRecognizer();
			// Como A Tank Story y WakeAgenda: si el servicio no da resultado final pero ya había entendido algo, vale eso.
			if ((error == SpeechRecognizer.ERROR_NO_MATCH || error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) && !heard.isEmpty()) {
				emit("voz_texto", heard);
			} else {
				emit("voz_error", Integer.valueOf(error));
			}
		}

		@Override
		public void onResults(Bundle results) {
			String t = first(results);
			destroyRecognizer();
			emit("voz_texto", t.isEmpty() ? lastPartial : t);
		}

		@Override
		public void onPartialResults(Bundle partial) {
			String t = first(partial);
			if (!t.isEmpty()) {
				lastPartial = t;
				emit("voz_parcial", t);
			}
		}

		@Override public void onEvent(int eventType, Bundle params) {}
	}
}
