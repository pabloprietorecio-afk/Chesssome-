@tool
extends EditorPlugin
## Complemento de Android «PagosGoogle» (android_pagos/): al exportar con Gradle, añade la librería de facturación de
## Google Play (y la de valoraciones) y registra el complemento en el manifiesto. El Java lo copia la CI dentro de la plantilla de Gradle.

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = AndroidExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class AndroidExport extends EditorExportPlugin:
	## Play Billing Library 8: Play la acepta en apps nuevas y actualizaciones hasta el 31 de agosto de 2027.
	const BILLING := "com.android.billingclient:billing:8.3.0"
	## Ventanita de valoración de Google Play (In-App Review API; developer.android.com/guide/playcore/in-app-review).
	const REVIEW := "com.google.android.play:review:2.0.2"

	func _get_name() -> String:
		return "PagosGoogle"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([BILLING, REVIEW])

	func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return '<meta-data android:name="org.godotengine.plugin.v2.PagosGoogle" android:value="com.pabloprieto.pagos.PagosGoogle" />'
