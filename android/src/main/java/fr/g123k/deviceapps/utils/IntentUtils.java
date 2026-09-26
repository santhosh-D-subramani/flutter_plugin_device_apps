package fr.g123k.deviceapps.utils;

import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;

import androidx.annotation.Nullable;

public final class IntentUtils {

    private IntentUtils() {
    }

    /**
     * Starts the activity from a non-Activity context.
     * <p>
     * Launching and catching {@link ActivityNotFoundException} is used instead of resolving the
     * intent first: since Android 11, resolving requires the target to be declared in
     * {@code <queries>}, while simply starting it does not.
     */
    public static boolean startActivity(@Nullable Context context, @Nullable Intent intent) {
        if (intent == null || context == null) {
            return false;
        }

        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try {
            context.startActivity(intent);
            return true;
        } catch (ActivityNotFoundException | SecurityException ignored) {
            return false;
        }
    }
}
