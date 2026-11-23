package com.pabloprieto.espera;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;

import java.io.File;
import java.io.FileNotFoundException;

/**
 * Entrega a otras apps (correo, Drive…) el archivo de la copia de seguridad que va en el menú de compartir.
 * Solo sirve archivos de cache/respaldo/ (una carpeta, sin subcarpetas) y solo de lectura. Sin dependencias
 * (no usa androidx FileProvider). El manifiesto lo declara res://addons/espera_online (exported=false con
 * grantUriPermissions: solo la app que recibe el permiso del menú de compartir puede leer).
 */
public class BackupProvider extends ContentProvider {

	public static final String AUTHORITY = "com.pabloprieto.chessome.respaldo";
	public static final String DIR = "respaldo";

	/** Nombre de archivo seguro: sin barras ni caracteres raros (y con .json). */
	public static String safeName(String name) {
		String safe = name == null ? "" : name.replaceAll("[^A-Za-z0-9._-]", "_");
		if (safe.isEmpty() || safe.startsWith(".")) {
			safe = "a-chess-way.json";
		}
		return safe;
	}

	private File fileFor(Uri uri) throws FileNotFoundException {
		String name = uri.getLastPathSegment();
		if (name == null || !name.equals(safeName(name))) {
			throw new FileNotFoundException("nombre no permitido");
		}
		File dir = new File(getContext().getCacheDir(), DIR);
		File file = new File(dir, name);
		if (!file.isFile()) {
			throw new FileNotFoundException("no existe");
		}
		return file;
	}

	@Override
	public boolean onCreate() {
		return true;
	}

	@Override
	public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
		if (!"r".equals(mode)) {
			throw new FileNotFoundException("solo lectura");
		}
		return ParcelFileDescriptor.open(fileFor(uri), ParcelFileDescriptor.MODE_READ_ONLY);
	}

	@Override
	public Cursor query(Uri uri, String[] projection, String selection, String[] selectionArgs, String sortOrder) {
		try {
			File file = fileFor(uri);
			MatrixCursor cursor = new MatrixCursor(new String[] {OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE});
			cursor.addRow(new Object[] {file.getName(), file.length()});
			return cursor;
		} catch (FileNotFoundException e) {
			return null;
		}
	}

	@Override
	public String getType(Uri uri) {
		return "application/json";
	}

	@Override
	public Uri insert(Uri uri, ContentValues values) {
		throw new UnsupportedOperationException();
	}

	@Override
	public int delete(Uri uri, String selection, String[] selectionArgs) {
		throw new UnsupportedOperationException();
	}

	@Override
	public int update(Uri uri, ContentValues values, String selection, String[] selectionArgs) {
		throw new UnsupportedOperationException();
	}
}
