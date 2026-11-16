package com.pabloprieto.espera;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Build;
import android.os.IBinder;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

/**
 * Servicio en primer plano mientras se espera rival con la app minimizada (Godot no se ejecuta en segundo plano).
 * Cada 10 s renueva el latido de espera/<partida> (si no, la partida en espera caduca y nadie la ve) y cada 3 s mira
 * si ha entrado alguien (partidas/<partida>/rival). Cuando entra, avisa con «¡Rival encontrado!» y se para: al
 * volver a la app, el juego sigue (y quien entró espera un minuto a que vuelvas).
 * Mismas peticiones REST que core/online.gd, con la sesión anónima que le pasa la app (y que renueva si caduca).
 */
public class EsperaService extends Service {
	static final String ACTION_START = "com.pabloprieto.espera.START";
	static final String ACTION_STOP = "com.pabloprieto.espera.STOP";
	static final String CHANNEL_WAIT = "espera_rival";
	static final String CHANNEL_FOUND = "rival_encontrado";
	static final int ID_WAIT = 7301;
	static final int ID_FOUND = 7302;
	/** Como mucho, dos horas esperando. */
	static final long MAX_WAIT_MS = 2L * 60L * 60L * 1000L;
	/** Lo que espera quien entró a que vuelvas (core/online.gd, JOIN_WAIT_MS): después, el aviso ya no sirve. */
	static final long FOUND_VALID_MS = 60L * 1000L;
	/** Naranja de la marca (el subrayado del inicio): tiñe el icono pequeño y el nombre de la app en el aviso. */
	static final int BRAND = 0xFFF26A1E;

	static volatile String state = "";
	/** Si la app está a la vista (lo dice el complemento con el ciclo de vida de la actividad). */
	static volatile boolean appVisible = true;

	private volatile boolean running = false;
	private Thread worker;
	private String host, game, token, refresh, apiKey, foundTitle, foundText, foundNamed, playLabel;
	private String channelWait = "Esperando rival", channelFound = "Rival encontrado";
	private long expiresAt;
	private long waitingSince;

	@Override
	public IBinder onBind(Intent intent) {
		return null;
	}

	@Override
	public int onStartCommand(Intent intent, int flags, int startId) {
		if (intent != null && ACTION_STOP.equals(intent.getAction())) {
			// «Dejar de esperar» desde el aviso: se borra la partida en espera y la app, al volver, deja de buscar.
			state = "cancelled";
			final String h = host, g = game, t = token;
			stopWaiting();
			if (h != null && g != null) {
				new Thread(() -> {
					request("DELETE", "https://" + h + "/espera/" + g + ".json?auth=" + t, null);
					request("DELETE", "https://" + h + "/partidas/" + g + ".json?auth=" + t, null);
				}).start();
			}
			return START_NOT_STICKY;
		}
		if (intent == null) {
			stopSelf();
			return START_NOT_STICKY;
		}
		host = intent.getStringExtra("host");
		game = intent.getStringExtra("game");
		token = intent.getStringExtra("token");
		refresh = intent.getStringExtra("refresh");
		apiKey = intent.getStringExtra("apiKey");
		expiresAt = intent.getLongExtra("expiresAt", 0L);
		foundTitle = intent.getStringExtra("foundTitle");
		foundText = intent.getStringExtra("foundText");
		foundNamed = intent.getStringExtra("foundNamed");
		playLabel = intent.getStringExtra("playLabel");
		channelWait = orElse(intent.getStringExtra("channelWait"), channelWait);
		channelFound = orElse(intent.getStringExtra("channelFound"), channelFound);
		if (waitingSince == 0L) {
			waitingSince = System.currentTimeMillis();
		}
		channels();
		Notification n = waitNotification(intent.getStringExtra("title"), intent.getStringExtra("text"), intent.getStringExtra("stopLabel"), intent.getStringExtra("backLabel"));
		if (Build.VERSION.SDK_INT >= 29) {
			startForeground(ID_WAIT, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC);
		} else {
			startForeground(ID_WAIT, n);
		}
		state = "waiting";
		if (worker == null || !worker.isAlive()) {
			running = true;
			worker = new Thread(this::loop, "EsperaRival");
			worker.start();
		}
		return START_NOT_STICKY;
	}

	@Override
	public void onDestroy() {
		running = false;
		if (worker != null) {
			worker.interrupt();
		}
		super.onDestroy();
	}

	private void stopWaiting() {
		running = false;
		if (worker != null) {
			worker.interrupt();
		}
		if (Build.VERSION.SDK_INT >= 24) {
			stopForeground(STOP_FOREGROUND_REMOVE);
		} else {
			stopForeground(true);
		}
		stopSelf();
	}

	private void loop() {
		long started = System.currentTimeMillis();
		long lastBeat = 0;
		while (running && System.currentTimeMillis() - started < MAX_WAIT_MS) {
			try {
				ensureToken();
				long now = System.currentTimeMillis();
				if (now - lastBeat >= 10000) {
					lastBeat = now;
					request("PUT", "https://" + host + "/espera/" + game + "/latido.json?auth=" + token, "{\".sv\":\"timestamp\"}");
				}
				String rival = request("GET", "https://" + host + "/partidas/" + game + "/rival.json?auth=" + token, null);
				if (rival != null && !rival.trim().isEmpty() && !"null".equals(rival.trim())) {
					state = "found";
					if (!appVisible) {
						foundNotification(rivalName(rival.trim()));
					}
					stopWaiting();
					return;
				}
				Thread.sleep(3000);
			} catch (InterruptedException e) {
				return;
			} catch (RuntimeException e) {
				try {
					Thread.sleep(5000);
				} catch (InterruptedException ie) {
					return;
				}
			}
		}
		if (running) {
			stopWaiting();
		}
	}

	/** Renueva la sesión anónima si le quedan menos de cinco minutos. */
	private void ensureToken() {
		if (expiresAt - System.currentTimeMillis() / 1000L > 300 || refresh == null || refresh.isEmpty()) {
			return;
		}
		try {
			String body = "grant_type=refresh_token&refresh_token=" + URLEncoder.encode(refresh, "UTF-8");
			String r = requestForm("https://securetoken.googleapis.com/v1/token?key=" + apiKey, body);
			if (r == null) {
				return;
			}
			JSONObject j = new JSONObject(r);
			token = j.optString("id_token", token);
			refresh = j.optString("refresh_token", refresh);
			expiresAt = System.currentTimeMillis() / 1000L + Long.parseLong(j.optString("expires_in", "3600"));
		} catch (Exception e) {
			// Se reintenta en la siguiente vuelta.
		}
	}

	private static String request(String method, String url, String body) {
		HttpURLConnection c = null;
		try {
			c = (HttpURLConnection) new URL(url).openConnection();
			c.setRequestMethod(method);
			c.setConnectTimeout(15000);
			c.setReadTimeout(15000);
			if (body != null) {
				c.setDoOutput(true);
				c.setRequestProperty("Content-Type", "application/json");
				try (OutputStream o = c.getOutputStream()) {
					o.write(body.getBytes(StandardCharsets.UTF_8));
				}
			}
			int code = c.getResponseCode();
			if (code != 200) {
				return null;
			}
			return read(c.getInputStream());
		} catch (Exception e) {
			return null;
		} finally {
			if (c != null) {
				c.disconnect();
			}
		}
	}

	private static String requestForm(String url, String body) {
		HttpURLConnection c = null;
		try {
			c = (HttpURLConnection) new URL(url).openConnection();
			c.setRequestMethod("POST");
			c.setConnectTimeout(15000);
			c.setReadTimeout(15000);
			c.setDoOutput(true);
			c.setRequestProperty("Content-Type", "application/x-www-form-urlencoded");
			try (OutputStream o = c.getOutputStream()) {
				o.write(body.getBytes(StandardCharsets.UTF_8));
			}
			if (c.getResponseCode() != 200) {
				return null;
			}
			return read(c.getInputStream());
		} catch (Exception e) {
			return null;
		} finally {
			if (c != null) {
				c.disconnect();
			}
		}
	}

	private static String read(InputStream in) throws java.io.IOException {
		ByteArrayOutputStream out = new ByteArrayOutputStream();
		byte[] buf = new byte[4096];
		int n;
		while ((n = in.read(buf)) > 0) {
			out.write(buf, 0, n);
		}
		in.close();
		return out.toString("UTF-8");
	}

	// ------------------------------------------------------------------ avisos
	// Diseño: icono pequeño = el caballo de la app en blanco (res/drawable-*/ic_stat_achessway.png, de
	// tools/ui/icons.mjs), teñido del naranja de la marca; imagen grande = el icono de la app
	// (res/drawable-nodpi/ic_large_achessway.png, de tools/inicio/icono.py). Textos de core/online.gd, en el idioma
	// de la app.
	//  - «Esperando rival · 5+3»: fijo y silencioso (Android lo exige para seguir en segundo plano), con el tiempo que
	//    llevas esperando y los botones «Volver» y «Dejar de esperar».
	//  - «¡Rival encontrado!»: emergente, con sonido y vibración; dice quién (si tiene nombre) y desaparece solo al
	//    minuto, cuando quien entró deja de esperarte.

	private static String orElse(String value, String fallback) {
		return value == null || value.isEmpty() ? fallback : value;
	}

	private void channels() {
		if (Build.VERSION.SDK_INT < 26) {
			return;
		}
		NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
		NotificationChannel wait = new NotificationChannel(CHANNEL_WAIT, channelWait, NotificationManager.IMPORTANCE_LOW);
		wait.setShowBadge(false);
		wait.setSound(null, null);
		wait.enableVibration(false);
		nm.createNotificationChannel(wait);
		NotificationChannel found = new NotificationChannel(CHANNEL_FOUND, channelFound, NotificationManager.IMPORTANCE_HIGH);
		found.enableVibration(true);
		found.setVibrationPattern(new long[] {0, 180, 120, 260});
		found.enableLights(true);
		found.setLightColor(BRAND);
		found.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
		nm.createNotificationChannel(found);
	}

	private int drawable(String name) {
		return getResources().getIdentifier(name, "drawable", getPackageName());
	}

	private int smallIcon() {
		int id = drawable("ic_stat_achessway");
		if (id == 0) {
			id = drawable("ic_default_notification");
		}
		return id != 0 ? id : getApplicationInfo().icon;
	}

	private Bitmap largeIcon() {
		int id = drawable("ic_large_achessway");
		return id != 0 ? BitmapFactory.decodeResource(getResources(), id) : null;
	}

	private PendingIntent openApp() {
		Intent launch = getPackageManager().getLaunchIntentForPackage(getPackageName());
		if (launch == null) {
			launch = new Intent();
		}
		launch.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
		return PendingIntent.getActivity(this, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
	}

	private Notification.Builder builder(String channel) {
		Notification.Builder b = Build.VERSION.SDK_INT >= 26 ? new Notification.Builder(this, channel) : new Notification.Builder(this);
		b.setSmallIcon(smallIcon());
		b.setColor(BRAND);
		Bitmap large = largeIcon();
		if (large != null) {
			b.setLargeIcon(large);
		}
		b.setContentIntent(openApp());
		return b;
	}

	private Notification waitNotification(String title, String text, String stopLabel, String backLabel) {
		Intent stop = new Intent(this, EsperaService.class);
		stop.setAction(ACTION_STOP);
		PendingIntent stopIntent = PendingIntent.getService(this, 1, stop, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
		Notification.Builder b = builder(CHANNEL_WAIT);
		b.setContentTitle(title).setContentText(text).setOngoing(true).setOnlyAlertOnce(true);
		b.setStyle(new Notification.BigTextStyle().bigText(text));
		// El tiempo que llevas esperando, contando solo.
		b.setWhen(waitingSince).setShowWhen(true).setUsesChronometer(true);
		b.setCategory(Notification.CATEGORY_SERVICE);
		if (Build.VERSION.SDK_INT >= 31) {
			// Sin los 10 s de retraso que Android 12 pone a los avisos de servicios en primer plano.
			b.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE);
		}
		b.addAction(new Notification.Action.Builder(null, orElse(backLabel, "Volver"), openApp()).build());
		b.addAction(new Notification.Action.Builder(null, stopLabel, stopIntent).build());
		return b.build();
	}

	/** El nombre que puso el rival en su perfil de la partida (lo escribe nada más entrar), o null si no tiene. */
	private String rivalName(String rivalJson) {
		String uid = rivalJson.replace("\"", "");
		if (!uid.matches("[A-Za-z0-9_-]{1,128}")) {
			return null;
		}
		for (int i = 0; i < 3; i++) {
			String name = request("GET", "https://" + host + "/partidas/" + game + "/perfiles/" + uid + "/nombre.json?auth=" + token, null);
			if (name != null && name.trim().startsWith("\"")) {
				String clean = name.trim().replaceAll("^\"|\"$", "").replaceAll("[\\p{Cntrl}]", "").trim();
				if (clean.length() >= 2 && clean.length() <= 16) {
					return clean;
				}
			}
			try {
				Thread.sleep(600);
			} catch (InterruptedException e) {
				return null;
			}
		}
		return null;
	}

	private void foundNotification(String name) {
		NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
		String text = name != null && foundNamed != null && foundNamed.contains("{nombre}") ? foundNamed.replace("{nombre}", name) : foundText;
		Notification.Builder b = builder(CHANNEL_FOUND);
		b.setContentTitle(foundTitle).setContentText(text).setAutoCancel(true);
		b.setStyle(new Notification.BigTextStyle().bigText(text));
		b.setCategory(Notification.CATEGORY_EVENT);
		b.setVisibility(Notification.VISIBILITY_PUBLIC);
		b.setWhen(System.currentTimeMillis()).setShowWhen(true);
		b.addAction(new Notification.Action.Builder(null, orElse(playLabel, foundTitle), openApp()).build());
		if (Build.VERSION.SDK_INT >= 26) {
			// Quien entró espera un minuto: pasado ese tiempo, el aviso se quita solo.
			b.setTimeoutAfter(FOUND_VALID_MS);
		} else {
			b.setPriority(Notification.PRIORITY_HIGH);
			b.setDefaults(Notification.DEFAULT_ALL);
		}
		nm.notify(ID_FOUND, b.build());
	}

	/** Al volver a la app, el aviso «¡Rival encontrado!» ya no hace falta. */
	static void cancelFound(Context context) {
		NotificationManager nm = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
		if (nm != null) {
			nm.cancel(ID_FOUND);
		}
	}
}
