package com.pabloprieto.espera;

import android.app.Notification;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.view.View;
import android.widget.RemoteViews;

/**
 * Diseño propio de los avisos de A Chess Way, como los de WakeAgenda (alarm/CustomNotificationViews.kt): en vez del
 * aviso gris estándar, una tarjeta con degradado gris, el logo del caballo en grande, título, texto y una pastilla
 * con la acción (res/layout/aviso_notif.xml y aviso_notif_grande.xml). Android 12+ mantiene la cabecera del sistema
 * (icono pequeño, nombre de la app, hora) y deja personalizar el contenido.
 * Los recursos se buscan por nombre (el CI los copia en la plantilla de Gradle): si faltaran, el aviso sale estándar.
 */
final class AvisoVista {
	/** Naranja de la marca: tiñe el icono pequeño de la barra de estado y la pastilla. */
	static final int BRAND = 0xFFF26A1E;

	private AvisoVista() {
	}

	static int res(Context c, String name, String type) {
		return c.getResources().getIdentifier(name, type, c.getPackageName());
	}

	static int smallIcon(Context c) {
		int id = res(c, "ic_stat_achessway", "drawable");
		if (id == 0) {
			id = res(c, "ic_default_notification", "drawable");
		}
		return id != 0 ? id : c.getApplicationInfo().icon;
	}

	static Bitmap largeIcon(Context c) {
		int id = res(c, "ic_large_achessway", "drawable");
		return id != 0 ? BitmapFactory.decodeResource(c.getResources(), id) : null;
	}

	/** Abrir la app (a donde estaba). */
	static PendingIntent openApp(Context c) {
		Intent launch = c.getPackageManager().getLaunchIntentForPackage(c.getPackageName());
		if (launch == null) {
			launch = new Intent();
		}
		launch.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
		return PendingIntent.getActivity(c, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
	}

	/**
	 * Pone el diseño propio en el aviso. El título y el texto se ponen también en el aviso estándar (los lee el
	 * sistema: pantalla de bloqueo, accesibilidad, relojes). Devuelve false si faltan los recursos.
	 */
	static boolean apply(Context c, Notification.Builder b, String title, String text, String pill) {
		b.setContentTitle(title).setContentText(text);
		int compact = res(c, "aviso_notif", "layout");
		int big = res(c, "aviso_notif_grande", "layout");
		if (compact == 0 || big == 0) {
			return false;
		}
		RemoteViews small = views(c, compact, title, text, pill);
		b.setStyle(new Notification.DecoratedCustomViewStyle());
		b.setCustomContentView(small);
		b.setCustomHeadsUpContentView(small);
		b.setCustomBigContentView(views(c, big, title, text, pill));
		b.setColor(BRAND);
		// Sin «large icon»: el logo ya va en la tarjeta, y con él Android reserva una columna a la derecha que deja
		// el texto sin sitio (en el móvil de Pablo, 17-11, no se veían ni el título ni el texto).
		b.setLargeIcon((Bitmap) null);
		return true;
	}

	private static RemoteViews views(Context c, int layout, String title, String text, String pill) {
		RemoteViews v = new RemoteViews(c.getPackageName(), layout);
		v.setTextViewText(res(c, "aviso_titulo", "id"), title);
		v.setTextViewText(res(c, "aviso_texto", "id"), text);
		int p = res(c, "aviso_pastilla", "id");
		if (pill == null || pill.isEmpty()) {
			v.setViewVisibility(p, View.GONE);
		} else {
			v.setTextViewText(p, pill);
			// La pastilla también abre la app (como tocar el aviso).
			v.setOnClickPendingIntent(p, openApp(c));
		}
		return v;
	}
}
