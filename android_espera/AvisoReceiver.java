package com.pabloprieto.espera;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;

/**
 * El aviso diario («Tu reto de hoy») con el diseño propio de A Chess Way (AvisoVista). La app lo programa con
 * EsperaOnline.scheduleReminder (hora, título, texto, pastilla) cada vez que cambia algo; aquí se guarda, se arma
 * una alarma del sistema (sin exactitud al segundo: Android puede retrasarla unos minutos para ahorrar batería) y,
 * cuando llega, se enseña. Si el móvil se reinicia o se actualiza la app, se vuelve a armar.
 */
public class AvisoReceiver extends BroadcastReceiver {
	static final String PREFS = "achessway_aviso";
	static final String ACTION_FIRE = "com.pabloprieto.espera.AVISO_DIARIO";
	/** El mismo canal que creaba el complemento de notificaciones (core: AVISO_CHANNEL). */
	static final String CHANNEL = "chessome_diario";
	/**
	 * Distinto del que usaba el complemento de notificaciones (4201): la app sigue llamando a su cancel(4201) cada
	 * vez que reprograma, y con el mismo número quitaba al instante el aviso recién enseñado (17-11).
	 */
	static final int ID = 4202;

	@Override
	public void onReceive(Context context, Intent intent) {
		String action = intent.getAction();
		if (Intent.ACTION_BOOT_COMPLETED.equals(action) || Intent.ACTION_MY_PACKAGE_REPLACED.equals(action)) {
			arm(context);
			return;
		}
		if (!ACTION_FIRE.equals(action)) {
			return;
		}
		SharedPreferences p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
		if (p.getLong("at", 0L) == 0L) {
			return;
		}
		show(context, p.getString("title", ""), p.getString("text", ""), p.getString("pill", ""), p.getString("channel", ""));
		p.edit().putLong("at", 0L).apply();
	}

	/** Guarda el aviso y arma la alarma. atMs: instante en milisegundos desde 1970. */
	static void schedule(Context c, long atMs, String title, String text, String pill, String channelName) {
		c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
			.putLong("at", atMs).putString("title", title).putString("text", text)
			.putString("pill", pill).putString("channel", channelName).apply();
		arm(c);
	}

	static void cancel(Context c) {
		AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
		if (am != null) {
			am.cancel(fire(c));
		}
		c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putLong("at", 0L).apply();
	}

	static void arm(Context c) {
		long at = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong("at", 0L);
		AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
		if (am == null || at <= System.currentTimeMillis()) {
			return;
		}
		am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, fire(c));
	}

	private static PendingIntent fire(Context c) {
		Intent i = new Intent(c, AvisoReceiver.class).setAction(ACTION_FIRE);
		return PendingIntent.getBroadcast(c, ID, i, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
	}

	/**
	 * Enseña el aviso. Devuelve "ok", "off" (avisos de la app desactivados en Android), "channel" (canal del aviso
	 * desactivado) o "error: …", para que la app pueda decir qué pasa.
	 */
	static String show(Context c, String title, String text, String pill, String channelName) {
		NotificationManager nm = (NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE);
		if (nm == null) {
			return "error: sin NotificationManager";
		}
		if (Build.VERSION.SDK_INT >= 24 && !nm.areNotificationsEnabled()) {
			return "off";
		}
		if (Build.VERSION.SDK_INT >= 26) {
			NotificationChannel existing = nm.getNotificationChannel(CHANNEL);
			if (existing != null && existing.getImportance() == NotificationManager.IMPORTANCE_NONE) {
				return "channel";
			}
		}
		try {
			post(c, nm, title, text, pill, channelName);
		} catch (RuntimeException e) {
			return "error: " + e;
		}
		return "ok";
	}

	private static void post(Context c, NotificationManager nm, String title, String text, String pill, String channelName) {
		Notification.Builder b;
		if (Build.VERSION.SDK_INT >= 26) {
			if (nm.getNotificationChannel(CHANNEL) == null) {
				nm.createNotificationChannel(new NotificationChannel(CHANNEL, channelName.isEmpty() ? "A Chess Way" : channelName, NotificationManager.IMPORTANCE_DEFAULT));
			}
			b = new Notification.Builder(c, CHANNEL);
		} else {
			b = new Notification.Builder(c);
		}
		b.setSmallIcon(AvisoVista.smallIcon(c));
		b.setColor(AvisoVista.BRAND);
		b.setContentIntent(AvisoVista.openApp(c));
		b.setAutoCancel(true);
		b.setCategory(Notification.CATEGORY_REMINDER);
		b.setWhen(System.currentTimeMillis()).setShowWhen(true);
		if (!AvisoVista.apply(c, b, title, text, pill)) {
			android.graphics.Bitmap large = AvisoVista.largeIcon(c);
			if (large != null) {
				b.setLargeIcon(large);
			}
		}
		nm.notify(ID, b.build());
	}
}
