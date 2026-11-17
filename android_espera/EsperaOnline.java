package com.pabloprieto.espera;

import android.app.Activity;
import android.content.Intent;
import android.os.Build;

import org.godotengine.godot.Dictionary;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

/**
 * Esperar rival online con la app minimizada. Desde GDScript: Engine.get_singleton("EsperaOnline").
 *   start(datos)  arranca el servicio en primer plano (aviso fijo «Esperando rival»): mantiene el latido de la
 *                 partida en espera y, cuando entra alguien, avisa con «¡Rival encontrado!».
 *   stop()        lo para (al volver a la app).
 *   state()       "" (nada), "waiting", "found" (entró alguien) o "cancelled" (se tocó «Dejar de esperar»).
 *   scheduleReminder(datos) / cancelReminder()   el aviso diario con el diseño propio (AvisoReceiver, AvisoVista).
 * Lo copia el CI en la plantilla de Gradle (android_espera/LEEME.md).
 */
public class EsperaOnline extends GodotPlugin {

	public EsperaOnline(Godot godot) {
		super(godot);
	}

	@Override
	public String getPluginName() {
		return "EsperaOnline";
	}

	/** Con la app a la vista no hace falta el aviso «¡Rival encontrado!»: la propia app lo ve. */
	@Override
	public void onMainPause() {
		EsperaService.appVisible = false;
	}

	@Override
	public void onMainResume() {
		EsperaService.appVisible = true;
		Activity activity = getActivity();
		if (activity != null) {
			EsperaService.cancelFound(activity);
		}
	}

	@UsedByGodot
	public void start(Dictionary data) {
		Activity activity = getActivity();
		if (activity == null) {
			return;
		}
		Intent intent = new Intent(activity, EsperaService.class);
		intent.setAction(EsperaService.ACTION_START);
		for (String key : new String[] {"host", "game", "token", "refresh", "apiKey", "title", "text", "foundTitle", "foundText", "foundNamed", "playLabel", "backLabel", "stopLabel", "channelWait", "channelFound"}) {
			Object value = data.get(key);
			intent.putExtra(key, value == null ? "" : value.toString());
		}
		Object expires = data.get("expiresAt");
		intent.putExtra("expiresAt", expires instanceof Number ? ((Number) expires).longValue() : 0L);
		EsperaService.state = "waiting";
		try {
			if (Build.VERSION.SDK_INT >= 26) {
				activity.startForegroundService(intent);
			} else {
				activity.startService(intent);
			}
		} catch (RuntimeException e) {
			// Android puede negarse a arrancar un servicio en primer plano (por ejemplo, sin permiso de avisos).
			EsperaService.state = "";
		}
	}

	@UsedByGodot
	public void stop() {
		Activity activity = getActivity();
		if (activity == null) {
			return;
		}
		activity.stopService(new Intent(activity, EsperaService.class));
		EsperaService.cancelFound(activity);
	}

	/**
	 * Aviso diario con el diseño de A Chess Way (AvisoReceiver). datos: at (segundos desde 1970), title, text, pill
	 * (texto de la pastilla, p. ej. «Entrenar») y channel (nombre del canal en el idioma de la app).
	 */
	@UsedByGodot
	public void scheduleReminder(Dictionary data) {
		Activity activity = getActivity();
		if (activity == null) {
			return;
		}
		Object at = data.get("at");
		long seconds = at instanceof Number ? ((Number) at).longValue() : 0L;
		AvisoReceiver.schedule(activity.getApplicationContext(), seconds * 1000L, text(data, "title"), text(data, "text"), text(data, "pill"), text(data, "channel"));
	}

	@UsedByGodot
	public void cancelReminder() {
		Activity activity = getActivity();
		if (activity != null) {
			AvisoReceiver.cancel(activity.getApplicationContext());
		}
	}

	/** Enseña el aviso diario ya (el de muestra al activarlo). Devuelve "ok", "off", "channel" o "error: …". */
	@UsedByGodot
	public String showReminderNow(Dictionary data) {
		Activity activity = getActivity();
		if (activity == null) {
			return "error: sin actividad";
		}
		return AvisoReceiver.show(activity.getApplicationContext(), text(data, "title"), text(data, "text"), text(data, "pill"), text(data, "channel"));
	}

	/** Para comprobar: cuándo está programado el próximo aviso (segundos desde 1970; 0 = ninguno). */
	@UsedByGodot
	public int reminderAt() {
		Activity activity = getActivity();
		if (activity == null) {
			return 0;
		}
		long ms = activity.getSharedPreferences(AvisoReceiver.PREFS, android.content.Context.MODE_PRIVATE).getLong("at", 0L);
		return (int) (ms / 1000L);
	}

	private static String text(Dictionary data, String key) {
		Object v = data.get(key);
		return v == null ? "" : v.toString();
	}

	@UsedByGodot
	public String state() {
		return EsperaService.state;
	}

	@UsedByGodot
	public void clearState() {
		EsperaService.state = "";
	}
}
