@tool
extends EditorPlugin
## Complemento de Android «EsperaOnline» (android_espera/*.java): al exportar con Gradle, añade al manifiesto los
## permisos, el servicio en primer plano y el registro del complemento. El código Java lo copia el CI dentro de la
## plantilla de Gradle (ver android_espera/LEEME.md). Solo se activa en el APK con avisos.

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = AndroidExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class AndroidExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "EsperaOnline"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	# El permiso de avisos (POST_NOTIFICATIONS) ya lo declara el complemento de notificaciones del mismo APK.
	func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return "\n".join([
			'<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />',
			'<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />',
		])

	func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return "\n".join([
			'<meta-data android:name="org.godotengine.plugin.v2.EsperaOnline" android:value="com.pabloprieto.espera.EsperaOnline" />',
			'<service android:name="com.pabloprieto.espera.EsperaService" android:exported="false" android:foregroundServiceType="dataSync" />',
		])
