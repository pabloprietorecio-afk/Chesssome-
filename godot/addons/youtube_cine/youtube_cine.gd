@tool
extends EditorPlugin
## Complemento de Android «YouTubeCine» (android_cine/YouTubeCine.java): al exportar con Gradle, lo registra en el
## manifiesto. El código Java lo copia el CI dentro de la plantilla de Gradle (ver android_cine/LEEME.md). Usa el
## permiso de Internet, que la app ya tiene.

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = AndroidExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class AndroidExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "YouTubeCine"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return '<meta-data android:name="org.godotengine.plugin.v2.YouTubeCine" android:value="com.pabloprieto.cine.YouTubeCine" />'
