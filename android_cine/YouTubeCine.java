package com.pabloprieto.cine;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.graphics.Color;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.JavascriptInterface;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.widget.FrameLayout;

import org.godotengine.godot.Dictionary;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.Locale;

/**
 * Vídeo de los «Finales de campeones» dentro de la app: el reproductor oficial de YouTube (API de iframe) en el
 * WebView del sistema, colocado encima del hueco que le deja la pantalla de Godot. Desde GDScript:
 * Engine.get_singleton("YouTubeCine") (lo usa core/cine_player.gd).
 *
 *   open(id, start, x, y, w, h, lang)  crea el reproductor con el vídeo cargado PARADO en `start`: lo arranca el
 *                                      jugador con el ▶ del propio reproductor (así cuenta como visita para el canal)
 *   place(x, y, w, h)                  lo recoloca (píxeles de la ventana de Godot)
 *   show(visible)                      lo oculta mientras hay algo de Godot encima (una hoja, un aviso)
 *   cue(t) play() pause() seek(t)      órdenes del director (core/cine_film.gd), con funciones documentadas de la API
 *   snapshot()                         {ready, time, duration, state, error, blocked}: última lectura (cada 100 ms)
 *   close()                            lo quita
 *
 * Requisitos de YouTube que se cumplen aquí (developers.google.com/youtube/terms/required-minimum-functionality):
 *  - Identificación con la cabecera Referer: el HTML se carga con la URL base https://com.pabloprieto.chessome
 *    (HTTPS y el identificador de la app como dominio).
 *  - Nada encima del reproductor: la vista nativa queda por encima de Godot, y Godot no dibuja en ese hueco.
 *  - Reproductor de al menos 200 × 200 px (la app lo hace a todo el ancho, 16:9).
 *  - Solo funciones documentadas: cueVideoById, playVideo, pauseVideo, seekTo, getCurrentTime, getDuration,
 *    getPlayerState; eventos onReady, onError y onAutoplayBlocked.
 * Lo copia el CI en la plantilla de Gradle, como android_espera/ (ver android_cine/LEEME.md).
 */
public class YouTubeCine extends GodotPlugin {

	private static final String BASE_URL = "https://com.pabloprieto.chessome";
	private static final String EMBED_HOST = "https://www.youtube-nocookie.com";

	private FrameLayout layer;
	private WebView web;

	private volatile boolean ready = false;
	private volatile double time = 0.0;
	private volatile double duration = 0.0;
	private volatile int state = -1;
	private volatile int error = 0;
	private volatile boolean blocked = false;
	private volatile boolean open = false;

	public YouTubeCine(Godot godot) {
		super(godot);
	}

	@Override
	public String getPluginName() {
		return "YouTubeCine";
	}

	/** Capa transparente encima de Godot, del tamaño de su vista: lo que no es el vídeo deja pasar los toques. */
	@Override
	public View onMainCreate(Activity activity) {
		layer = new FrameLayout(activity);
		layer.setLayoutParams(new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
		layer.setClickable(false);
		layer.setFocusable(false);
		return layer;
	}

	@Override
	public void onMainPause() {
		runOnUiThread(() -> {
			if (web != null) {
				web.evaluateJavascript("window.cinePause && cinePause()", null);
				web.onPause();
			}
		});
	}

	@Override
	public void onMainResume() {
		runOnUiThread(() -> {
			if (web != null) {
				web.onResume();
			}
		});
	}

	@Override
	public void onMainDestroy() {
		runOnUiThread(this::destroyWeb);
	}

	@SuppressLint({"SetJavaScriptEnabled", "AddJavascriptInterface"})
	@UsedByGodot
	public void open(String videoId, double start, int x, int y, int w, int h, String lang) {
		if (!videoId.matches("[A-Za-z0-9_-]{11}")) {
			error = -4;
			return;
		}
		ready = false;
		time = start;
		duration = 0.0;
		state = -1;
		error = 0;
		blocked = false;
		open = true;
		final String html = page(videoId, start, lang == null ? "es" : lang);
		runOnUiThread(() -> {
			Activity activity = getActivity();
			if (activity == null || layer == null) {
				error = -2;
				return;
			}
			destroyWeb();
			web = new WebView(activity);
			web.setBackgroundColor(Color.BLACK);
			// Sin foco: así el botón «atrás» y el teclado siguen yendo a Godot. Los toques en el reproductor funcionan igual.
			web.setFocusable(false);
			web.setFocusableInTouchMode(false);
			WebSettings s = web.getSettings();
			s.setJavaScriptEnabled(true);
			s.setDomStorageEnabled(true);
			// Para reanudar desde la app («Continuar») sin otro toque: solo tras una acción del jugador.
			s.setMediaPlaybackRequiresUserGesture(false);
			web.addJavascriptInterface(new Bridge(), "CineBridge");
			FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(w, h);
			lp.leftMargin = x;
			lp.topMargin = y;
			layer.addView(web, lp);
			web.loadDataWithBaseURL(BASE_URL + "/", html, "text/html", "UTF-8", null);
		});
	}

	@UsedByGodot
	public void place(int x, int y, int w, int h) {
		runOnUiThread(() -> {
			if (web == null) {
				return;
			}
			FrameLayout.LayoutParams lp = (FrameLayout.LayoutParams) web.getLayoutParams();
			if (lp.leftMargin == x && lp.topMargin == y && lp.width == w && lp.height == h) {
				return;
			}
			lp.leftMargin = x;
			lp.topMargin = y;
			lp.width = w;
			lp.height = h;
			web.setLayoutParams(lp);
		});
	}

	@UsedByGodot
	public void show(boolean visible) {
		runOnUiThread(() -> {
			if (web != null) {
				web.setVisibility(visible ? View.VISIBLE : View.INVISIBLE);
			}
		});
	}

	@UsedByGodot
	public void cue(double at) {
		js(String.format(Locale.ROOT, "cineCue(%.3f)", at));
	}

	@UsedByGodot
	public void play() {
		js("cinePlay()");
	}

	@UsedByGodot
	public void pause() {
		js("cinePause()");
	}

	@UsedByGodot
	public void seek(double at) {
		js(String.format(Locale.ROOT, "cineSeek(%.3f)", at));
	}

	@UsedByGodot
	public Dictionary snapshot() {
		Dictionary d = new Dictionary();
		d.put("open", open);
		d.put("ready", ready);
		d.put("time", time);
		d.put("duration", duration);
		d.put("state", state);
		d.put("error", error);
		d.put("blocked", blocked);
		return d;
	}

	@UsedByGodot
	public void close() {
		open = false;
		ready = false;
		runOnUiThread(this::destroyWeb);
	}

	private void js(String code) {
		runOnUiThread(() -> {
			if (web != null) {
				web.evaluateJavascript("window.cineReady && " + code, null);
			}
		});
	}

	private void destroyWeb() {
		if (web == null) {
			return;
		}
		try {
			web.evaluateJavascript("window.cinePause && cinePause()", null);
			if (layer != null) {
				layer.removeView(web);
			}
			web.removeJavascriptInterface("CineBridge");
			web.destroy();
		} catch (RuntimeException e) {
			// La vista ya no existe.
		}
		web = null;
	}

	/** Lo que cuenta la página: el reproductor está listo, la lectura de cada 100 ms y los errores. */
	private class Bridge {
		@JavascriptInterface
		public void ready() {
			ready = true;
		}

		@JavascriptInterface
		public void tick(double t, double d, int s) {
			time = t;
			duration = d;
			state = s;
		}

		@JavascriptInterface
		public void error(int code) {
			error = code;
		}

		@JavascriptInterface
		public void blocked() {
			blocked = true;
		}
	}

	/**
	 * Página con el reproductor: el iframe se crea a mano en el dominio de privacidad mejorada (como en la web, rama
	 * cine-video, src/ui/youtubePlayer.ts) y se controla con la API oficial. El vídeo se carga parado en `start`.
	 */
	private static String page(String id, double start, String lang) {
		String hl = lang.replaceAll("[^a-zA-Z-]", "");
		long at = (long) Math.floor(Math.max(0.0, start));
		String src = EMBED_HOST + "/embed/" + id + "?enablejsapi=1&playsinline=1&rel=0&fs=0&hl=" + hl
				+ "&origin=" + BASE_URL + (at >= 1 ? "&start=" + at : "");
		return "<!doctype html><html><head><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
				+ "<style>html,body{margin:0;height:100%;background:#000;overflow:hidden}"
				+ "iframe{position:absolute;left:0;top:0;width:100%;height:100%;border:0}</style></head><body>"
				+ "<iframe id=\"yt\" src=\"" + src + "\" title=\"YouTube\" allow=\"autoplay; encrypted-media; picture-in-picture\""
				+ " referrerpolicy=\"strict-origin-when-cross-origin\"></iframe>"
				+ "<script>"
				+ "var player=null;window.cineReady=false;"
				+ "function cineCue(t){if(player)player.cueVideoById({videoId:'" + id + "',startSeconds:t});}"
				+ "function cinePlay(){if(player)player.playVideo();}"
				+ "function cinePause(){if(player)player.pauseVideo();}"
				+ "function cineSeek(t){if(player)player.seekTo(t,true);}"
				+ "function onYouTubeIframeAPIReady(){player=new YT.Player('yt',{events:{"
				+ "onReady:function(){window.cineReady=true;CineBridge.ready();},"
				+ "onError:function(e){CineBridge.error(Number(e.data)||-1);},"
				+ "onAutoplayBlocked:function(){CineBridge.blocked();}}});"
				+ "setInterval(function(){if(!window.cineReady)return;try{CineBridge.tick(player.getCurrentTime()||0,"
				+ "player.getDuration()||0,player.getPlayerState());}catch(e){}},100);}"
				+ "var s=document.createElement('script');s.src='https://www.youtube.com/iframe_api';"
				+ "s.onerror=function(){CineBridge.error(-1);};document.head.appendChild(s);"
				+ "setTimeout(function(){if(!window.cineReady)CineBridge.error(-3);},12000);"
				+ "</script></body></html>";
	}
}
