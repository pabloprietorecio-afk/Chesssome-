@tool
extends EditorPlugin
## Complemento de Android «TutorVoz» (android_voz/TutorVoz.java): al exportar con Gradle, lo registra en el
## manifiesto con el permiso del micrófono. El código Java lo copia el CI dentro de la plantilla de Gradle.

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = AndroidExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class AndroidExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "TutorVoz"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return "\n".join([
			# El permiso RECORD_AUDIO va en export_presets.cfg (permissions/record_audio), como en A Tank Story: si se
			# declarase también aquí, el manifiesto saldría con el elemento repetido.
			'<queries><intent><action android:name="android.speech.RecognitionService" /></intent></queries>',
			# Como en A Tank Story: el micrófono es opcional (sin esto Play dejaría fuera móviles sin micrófono).
			'<uses-feature android:name="android.hardware.microphone" android:required="false" />',
		])

	func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return '<meta-data android:name="org.godotengine.plugin.v2.TutorVoz" android:value="com.pabloprieto.voz.TutorVoz" />'
