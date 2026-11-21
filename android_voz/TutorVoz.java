package com.pabloprieto.voz;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
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
 * Preguntas al tutor por voz: el reconocimiento de voz del propio Android (SpeechRecognizer). La app no graba ni
 * guarda audio; el texto reconocido llega a GDScript y se manda como pregunta escrita.
 * Desde GDScript: Engine.get_singleton("TutorVoz") (lo usa core/tutor_voice.gd).
 * Lo copia el CI en la plantilla de Gradle, como android_espera/ (ver android_voz/LEEME.md).
 */
public class TutorVoz extends GodotPlugin {

	private static final int PERMISSION_CODE = 7311;
	private SpeechRecognizer recognizer;
	private boolean listening = false;

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
		out.add(new SignalInfo("voz_permiso", Boolean.class));
		return out;
	}

	@UsedByGodot
	public boolean available() {
		Activity a = getActivity();
		return a != null && SpeechRecognizer.isRecognitionAvailable(a);
	}

	@UsedByGodot
	public boolean has_permission() {
		Activity a = getActivity();
		if (a == null) return false;
		if (Build.VERSION.SDK_INT < 23) return true;
		return a.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED;
	}

	@UsedByGodot
	public void ask_permission() {
		Activity a = getActivity();
		if (a == null) return;
		if (has_permission()) {
			emitSignal("voz_permiso", true);
			return;
		}
		a.requestPermissions(new String[] { Manifest.permission.RECORD_AUDIO }, PERMISSION_CODE);
	}

	@Override
	public void onMainRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
		if (requestCode != PERMISSION_CODE) return;
		boolean ok = grantResults != null && grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED;
		emitSignal("voz_permiso", ok);
	}

	/** Empieza a escuchar. `lang`: etiqueta BCP-47 («es-ES», «en-US»…). */
	@UsedByGodot
	public void start(String lang) {
		final Activity a = getActivity();
		if (a == null) return;
		a.runOnUiThread(() -> {
			if (recognizer == null) {
				recognizer = SpeechRecognizer.createSpeechRecognizer(a);
				recognizer.setRecognitionListener(new Listener());
			} else if (listening) {
				recognizer.cancel();
			}
			Intent i = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
			i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
			i.putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang);
			i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, lang);
			i.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true);
			i.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1);
			// Deja hablar con calma: una pausa corta no corta la pregunta.
			i.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 1800);
			i.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 1500);
			listening = true;
			recognizer.startListening(i);
		});
	}

	/** Deja de escuchar y entrega lo que haya entendido. */
	@UsedByGodot
	public void stop() {
		Activity a = getActivity();
		if (a == null) return;
		a.runOnUiThread(() -> {
			if (recognizer != null && listening) recognizer.stopListening();
		});
	}

	@UsedByGodot
	public void cancel() {
		Activity a = getActivity();
		if (a == null) return;
		a.runOnUiThread(() -> {
			listening = false;
			if (recognizer != null) recognizer.cancel();
		});
	}

	@Override
	public void onMainDestroy() {
		Activity a = getActivity();
		if (a == null || recognizer == null) return;
		a.runOnUiThread(() -> {
			recognizer.destroy();
			recognizer = null;
		});
	}

	private static String first(Bundle b) {
		if (b == null) return "";
		ArrayList<String> list = b.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
		return list == null || list.isEmpty() || list.get(0) == null ? "" : list.get(0);
	}

	private class Listener implements RecognitionListener {
		@Override public void onReadyForSpeech(Bundle params) { emitSignal("voz_lista"); }
		@Override public void onBeginningOfSpeech() {}
		@Override public void onRmsChanged(float rmsdB) {}
		@Override public void onBufferReceived(byte[] buffer) {}
		@Override public void onEndOfSpeech() {}
		@Override public void onError(int error) {
			listening = false;
			emitSignal("voz_error", error);
		}
		@Override public void onResults(Bundle results) {
			listening = false;
			emitSignal("voz_texto", first(results));
		}
		@Override public void onPartialResults(Bundle partial) {
			String t = first(partial);
			if (!t.isEmpty()) emitSignal("voz_parcial", t);
		}
		@Override public void onEvent(int eventType, Bundle params) {}
	}
}
