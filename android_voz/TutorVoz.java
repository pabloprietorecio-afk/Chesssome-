package com.pabloprieto.voz;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

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

	@Override
	public void onMainPause() {
		super.onMainPause();
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
		@Override public void onRmsChanged(float rmsdB) {}
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
