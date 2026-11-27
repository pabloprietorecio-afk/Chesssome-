package com.pabloprieto.pagos;

import android.app.Activity;

import com.android.billingclient.api.AcknowledgePurchaseParams;
import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingFlowParams;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.ConsumeParams;
import com.android.billingclient.api.PendingPurchasesParams;
import com.android.billingclient.api.ProductDetails;
import com.android.billingclient.api.Purchase;
import com.android.billingclient.api.PurchasesUpdatedListener;
import com.android.billingclient.api.QueryProductDetailsParams;
import com.android.billingclient.api.QueryPurchasesParams;
import com.google.android.play.core.review.ReviewInfo;
import com.google.android.play.core.review.ReviewManager;
import com.google.android.play.core.review.ReviewManagerFactory;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Compras en Google Play (Play Billing Library 8) para A Chess Way: la suscripción Premium («premium_mensual») y la
 * recarga de explicaciones («explicaciones_100»). La app no da nada por comprado: manda cada compra al servidor, que la
 * verifica con Google y lleva el cupo (worker/src/cuentas.js). Después, la app la reconoce (suscripción) o la consume
 * (recarga). Señales con JSON de texto, para no depender de tipos de Godot.
 */
public class PagosGoogle extends GodotPlugin implements PurchasesUpdatedListener {
	private BillingClient client;
	private final Map<String, ProductDetails> details = new HashMap<>();

	public PagosGoogle(Godot godot) {
		super(godot);
	}

	@Override
	public String getPluginName() {
		return "PagosGoogle";
	}

	@Override
	public Set<SignalInfo> getPluginSignals() {
		Set<SignalInfo> s = new HashSet<>();
		s.add(new SignalInfo("conectado", Boolean.class));
		s.add(new SignalInfo("productos", String.class));
		s.add(new SignalInfo("compras", String.class));
		s.add(new SignalInfo("fallo", Integer.class, String.class));
		s.add(new SignalInfo("hecho", String.class, String.class));
		return s;
	}

	/**
	 * Ventanita de valoración de Google Play (In-App Review API). La app la pide en un buen momento (al cerrar la
	 * enhorabuena de subir de nivel), nunca desde un botón y sin preguntar nada antes. Google decide si la enseña
	 * (tiene su propio cupo) y no dice si el jugador ha valorado: no hay señal de vuelta y, si falla, no se avisa.
	 */
	@UsedByGodot
	public void valorar() {
		final Activity a = getActivity();
		if (a == null) {
			return;
		}
		a.runOnUiThread(() -> {
			try {
				final ReviewManager manager = ReviewManagerFactory.create(a);
				manager.requestReviewFlow().addOnCompleteListener(task -> {
					if (!task.isSuccessful()) {
						return;
					}
					ReviewInfo info = task.getResult();
					manager.launchReviewFlow(a, info);
				});
			} catch (Exception e) {
				// Sin Play Store o con un error: la app sigue igual.
			}
		});
	}

	@UsedByGodot
	public void conectar() {
		Activity a = getActivity();
		if (a == null) {
			emitSignal("conectado", false);
			return;
		}
		if (client == null) {
			client = BillingClient.newBuilder(a)
					.setListener(this)
					.enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
					.enableAutoServiceReconnection()
					.build();
		}
		if (client.isReady()) {
			emitSignal("conectado", true);
			return;
		}
		client.startConnection(new BillingClientStateListener() {
			@Override
			public void onBillingSetupFinished(BillingResult r) {
				emitSignal("conectado", r.getResponseCode() == BillingClient.BillingResponseCode.OK);
			}

			@Override
			public void onBillingServiceDisconnected() {
				emitSignal("conectado", false);
			}
		});
	}

	/** Precios y ofertas de los productos (los pone Google, en la moneda del jugador). */
	@UsedByGodot
	public void productos(String subId, String packId) {
		if (client == null || !client.isReady()) {
			emitSignal("fallo", -1, "sin conexión con Google Play");
			return;
		}
		final JSONArray out = new JSONArray();
		final int[] pending = {2};
		query(subId, BillingClient.ProductType.SUBS, out, pending);
		query(packId, BillingClient.ProductType.INAPP, out, pending);
	}

	private void query(String id, String type, JSONArray out, int[] pending) {
		List<QueryProductDetailsParams.Product> list = Collections.singletonList(
				QueryProductDetailsParams.Product.newBuilder().setProductId(id).setProductType(type).build());
		client.queryProductDetailsAsync(QueryProductDetailsParams.newBuilder().setProductList(list).build(), (r, result) -> {
			synchronized (out) {
				if (r.getResponseCode() == BillingClient.BillingResponseCode.OK) {
					for (ProductDetails d : result.getProductDetailsList()) {
						details.put(d.getProductId(), d);
						try {
							JSONObject o = new JSONObject();
							o.put("id", d.getProductId());
							o.put("tipo", d.getProductType());
							o.put("titulo", d.getName());
							String price = "";
							if (BillingClient.ProductType.SUBS.equals(d.getProductType()) && d.getSubscriptionOfferDetails() != null && !d.getSubscriptionOfferDetails().isEmpty()) {
								List<ProductDetails.PricingPhase> phases = d.getSubscriptionOfferDetails().get(0).getPricingPhases().getPricingPhaseList();
								price = phases.get(phases.size() - 1).getFormattedPrice();
							} else if (d.getOneTimePurchaseOfferDetails() != null) {
								price = d.getOneTimePurchaseOfferDetails().getFormattedPrice();
							}
							o.put("precio", price);
							out.put(o);
						} catch (Exception e) {
							// Un producto sin datos: se omite.
						}
					}
				}
				pending[0] -= 1;
				if (pending[0] == 0) emitSignal("productos", out.toString());
			}
		});
	}

	/** Abre la compra de Google Play. `cuenta`: el identificador anónimo de la app (va con la compra). */
	@UsedByGodot
	public void comprar(String id, String cuenta) {
		final Activity a = getActivity();
		final ProductDetails d = details.get(id);
		if (a == null || client == null || d == null) {
			emitSignal("fallo", -2, "producto no disponible");
			return;
		}
		BillingFlowParams.ProductDetailsParams.Builder p = BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(d);
		if (BillingClient.ProductType.SUBS.equals(d.getProductType())) {
			if (d.getSubscriptionOfferDetails() == null || d.getSubscriptionOfferDetails().isEmpty()) {
				emitSignal("fallo", -2, "suscripción sin oferta");
				return;
			}
			p.setOfferToken(d.getSubscriptionOfferDetails().get(0).getOfferToken());
		}
		final BillingFlowParams params = BillingFlowParams.newBuilder()
				.setProductDetailsParamsList(Collections.singletonList(p.build()))
				.setObfuscatedAccountId(cuenta)
				.build();
		a.runOnUiThread(() -> {
			BillingResult r = client.launchBillingFlow(a, params);
			if (r.getResponseCode() != BillingClient.BillingResponseCode.OK) emitSignal("fallo", r.getResponseCode(), r.getDebugMessage());
		});
	}

	@Override
	public void onPurchasesUpdated(BillingResult r, List<Purchase> purchases) {
		if (r.getResponseCode() == BillingClient.BillingResponseCode.OK && purchases != null) {
			emitSignal("compras", toJson(purchases));
		} else {
			emitSignal("fallo", r.getResponseCode(), r.getDebugMessage());
		}
	}

	/** Compras vigentes (para restaurar: otro móvil, reinstalación o una compra que no llegó a confirmarse). */
	@UsedByGodot
	public void consultar() {
		if (client == null || !client.isReady()) {
			emitSignal("fallo", -1, "sin conexión con Google Play");
			return;
		}
		final List<Purchase> all = new ArrayList<>();
		final int[] pending = {2};
		for (String type : new String[]{BillingClient.ProductType.SUBS, BillingClient.ProductType.INAPP}) {
			client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(type).build(), (res, list) -> {
				synchronized (all) {
					if (res.getResponseCode() == BillingClient.BillingResponseCode.OK && list != null) all.addAll(list);
					pending[0] -= 1;
					if (pending[0] == 0) emitSignal("compras", toJson(all));
				}
			});
		}
	}

	@UsedByGodot
	public void reconocer(final String token) {
		if (client == null) return;
		client.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(token).build(),
				r -> emitSignal("hecho", r.getResponseCode() == BillingClient.BillingResponseCode.OK ? "reconocida" : "no_reconocida", token));
	}

	@UsedByGodot
	public void consumir(final String token) {
		if (client == null) return;
		client.consumeAsync(ConsumeParams.newBuilder().setPurchaseToken(token).build(),
				(r, t) -> emitSignal("hecho", r.getResponseCode() == BillingClient.BillingResponseCode.OK ? "consumida" : "no_consumida", token));
	}

	private static String toJson(List<Purchase> purchases) {
		JSONArray out = new JSONArray();
		for (Purchase p : purchases) {
			try {
				JSONObject o = new JSONObject();
				o.put("productos", new JSONArray(p.getProducts()));
				o.put("token", p.getPurchaseToken());
				o.put("pagada", p.getPurchaseState() == Purchase.PurchaseState.PURCHASED);
				o.put("reconocida", p.isAcknowledged());
				out.put(o);
			} catch (Exception e) {
				// Una compra rara: se omite.
			}
		}
		return out.toString();
	}
}
