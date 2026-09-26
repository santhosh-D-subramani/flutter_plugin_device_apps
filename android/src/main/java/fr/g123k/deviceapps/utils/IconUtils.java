package fr.g123k.deviceapps.utils;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;

import androidx.annotation.NonNull;

import java.io.ByteArrayOutputStream;

public final class IconUtils {

    /**
     * Used when a drawable has no intrinsic size (eg: a ColorDrawable), which would otherwise
     * make {@link Bitmap#createBitmap} throw.
     */
    private static final int FALLBACK_SIZE_PX = 192;

    private IconUtils() {
    }

    /**
     * Renders the drawable to a PNG.
     *
     * @param sizePx expected width/height in pixels. When <= 0, the intrinsic size is used.
     *               Requesting the size actually displayed avoids encoding (and sending over the
     *               platform channel) icons that are often 300px+ for a 48dp avatar.
     */
    @NonNull
    public static byte[] toPng(@NonNull Drawable drawable, int sizePx) {
        Bitmap bitmap = toBitmap(drawable, sizePx);
        ByteArrayOutputStream out = new ByteArrayOutputStream(bitmap.getByteCount() / 4);
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out);
        return out.toByteArray();
    }

    @NonNull
    private static Bitmap toBitmap(@NonNull Drawable drawable, int sizePx) {
        int width = sizePx > 0 ? sizePx : drawable.getIntrinsicWidth();
        int height = sizePx > 0 ? sizePx : drawable.getIntrinsicHeight();
        if (width <= 0 || height <= 0) {
            width = FALLBACK_SIZE_PX;
            height = FALLBACK_SIZE_PX;
        }

        if (drawable instanceof BitmapDrawable) {
            Bitmap source = ((BitmapDrawable) drawable).getBitmap();
            if (source != null) {
                if (source.getWidth() == width && source.getHeight() == height) {
                    return source;
                }
                return Bitmap.createScaledBitmap(source, width, height, true);
            }
        }

        Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        drawable.setBounds(0, 0, width, height);
        drawable.draw(canvas);
        return bitmap;
    }
}
