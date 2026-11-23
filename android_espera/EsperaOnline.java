package com.pabloprieto.espera;

import android.app.Activity;
import android.content.ClipData;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.HashSet;
import java.util.Set;

import org.godotengine.godot.Dictionary;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

/**
 * Esperar rival online con la app minimizada. Desde GDScript: Engine.get_singleton("EsperaOnline").
 *   start(datos)  arranca el servicio en primer plano (aviso fijo «Esperando rival»): mantiene el latido de la
 *                 partida en espera y, cuando entra alguien, avisa con «¡Rival encontrado!».
 *   stop()        lo para (al volver a la app).
 *   state()       "" (nada), "waiting", "found" (entró alguien) o "cancelled" (se tocó «Dejar de esperar»).
 *   scheduleReminder(datos) / cancelReminder()   el aviso diario con el diseño propio (AvisoReceiver, AvisoVista).
 *   Copia de seguridad (Opciones → «Copia de seguridad»; core/backup.gd, core/backup_io.gd):
 *     shareBackup(ruta, nombre, titulo)  abre el menú de compartir de Android con el archivo (correo, Drive…).
 *     saveBackup(ruta, nombre)           «Guardar en…» del sistema; avisa con la señal respaldo_guardado("ok" |
 *                                        "cancel" | "error: …").
 *     pickBackup()                       selector de archivos del sistema; devuelve el texto por la señal
 *                                        respaldo_leido(texto | "cancel" | "error: …").
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

	private static final int RC_SAVE = 7741;
	private static final int RC_OPEN = 7742;
	/** Una copia más grande que esto no es nuestra (core/backup.gd tiene el mismo tope en caracteres). */
	private static final int MAX_READ = 20 * 1024 * 1024;
	private String pendingSource = "";

	@Override
	public Set<SignalInfo> getPluginSignals() {
		Set<SignalInfo> s = new HashSet<>();
		s.add(new SignalInfo("respaldo_leido", String.class));
		s.add(new SignalInfo("respaldo_guardado", String.class));
		return s;
	}

	/** Menú de compartir de Android con la copia de seguridad (un archivo JSON). Devuelve "ok" o "error: …". */
	@UsedByGodot
	public String shareBackup(String path, String name, String chooserTitle) {
		Activity activity = getActivity();
		if (activity == null) {
			return "error: sin actividad";
		}
		try {
			File dir = new File(activity.getCacheDir(), BackupProvider.DIR);
			dir.mkdirs();
			File[] old = dir.listFiles();
			if (old != null) {
				for (File f : old) {
					f.delete();
				}
			}
			String safe = BackupProvider.safeName(name);
			File out = new File(dir, safe);
			copy(new FileInputStream(new File(path)), new FileOutputStream(out));
			Uri uri = Uri.parse("content://" + BackupProvider.AUTHORITY + "/" + Uri.encode(safe));
			Intent send = new Intent(Intent.ACTION_SEND);
			send.setType("application/json");
			send.putExtra(Intent.EXTRA_STREAM, uri);
			send.putExtra(Intent.EXTRA_SUBJECT, safe);
			send.setClipData(ClipData.newRawUri(safe, uri));
			send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
			Intent chooser = Intent.createChooser(send, chooserTitle);
			chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
			activity.startActivity(chooser);
			return "ok";
		} catch (Exception e) {
			return "error: " + e.getMessage();
		}
	}

	/** «Guardar en…» del sistema (Descargas, una carpeta de Drive…). El resultado llega por respaldo_guardado. */
	@UsedByGodot
	public void saveBackup(String path, String name) {
		Activity activity = getActivity();
		if (activity == null) {
			signalSaved("error: sin actividad");
			return;
		}
		pendingSource = path;
		try {
			Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
			intent.addCategory(Intent.CATEGORY_OPENABLE);
			intent.setType("application/json");
			intent.putExtra(Intent.EXTRA_TITLE, BackupProvider.safeName(name));
			activity.startActivityForResult(intent, RC_SAVE);
		} catch (Exception e) {
			signalSaved("error: " + e.getMessage());
		}
	}

	/** Selector de archivos del sistema. El texto del archivo llega por respaldo_leido. */
	@UsedByGodot
	public void pickBackup() {
		Activity activity = getActivity();
		if (activity == null) {
			signalRead("error: sin actividad");
			return;
		}
		try {
			Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
			intent.addCategory(Intent.CATEGORY_OPENABLE);
			// «*/*»: un adjunto del correo o de WhatsApp no siempre llega marcado como JSON.
			intent.setType("*/*");
			activity.startActivityForResult(intent, RC_OPEN);
		} catch (Exception e) {
			signalRead("error: " + e.getMessage());
		}
	}

	@Override
	public void onMainActivityResult(int requestCode, int resultCode, Intent data) {
		super.onMainActivityResult(requestCode, resultCode, data);
		if (requestCode != RC_SAVE && requestCode != RC_OPEN) {
			return;
		}
		Activity activity = getActivity();
		if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null || activity == null) {
			if (requestCode == RC_SAVE) {
				signalSaved("cancel");
			} else {
				signalRead("cancel");
			}
			return;
		}
		final Uri uri = data.getData();
		final String source = pendingSource;
		final Activity act = activity;
		final boolean saving = requestCode == RC_SAVE;
		new Thread(() -> {
			try {
				if (saving) {
					OutputStream out = act.getContentResolver().openOutputStream(uri, "wt");
					if (out == null) {
						throw new java.io.IOException("no se pudo abrir el destino");
					}
					copy(new FileInputStream(new File(source)), out);
					signalSaved("ok");
				} else {
					InputStream in = act.getContentResolver().openInputStream(uri);
					if (in == null) {
						throw new java.io.IOException("no se pudo abrir el archivo");
					}
					ByteArrayOutputStream buffer = new ByteArrayOutputStream();
					byte[] chunk = new byte[16384];
					int n;
					while ((n = in.read(chunk)) > 0) {
						buffer.write(chunk, 0, n);
						if (buffer.size() > MAX_READ) {
							in.close();
							signalRead("error: grande");
							return;
						}
					}
					in.close();
					signalRead(buffer.toString("UTF-8"));
				}
			} catch (Exception e) {
				if (saving) {
					signalSaved("error: " + e.getMessage());
				} else {
					signalRead("error: " + e.getMessage());
				}
			}
		}).start();
	}

	private void signalSaved(String result) {
		runOnRenderThread(() -> emitSignal("respaldo_guardado", result));
	}

	private void signalRead(String result) {
		runOnRenderThread(() -> emitSignal("respaldo_leido", result));
	}

	private static void copy(InputStream in, OutputStream out) throws java.io.IOException {
		try {
			byte[] chunk = new byte[16384];
			int n;
			while ((n = in.read(chunk)) > 0) {
				out.write(chunk, 0, n);
			}
			out.flush();
		} finally {
			in.close();
			out.close();
		}
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
