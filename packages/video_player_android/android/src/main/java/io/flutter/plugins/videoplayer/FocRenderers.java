// Foclaboard : copie locale de video_player_android (voir README du dossier).
package io.flutter.plugins.videoplayer;

import android.content.Context;
import android.content.pm.PackageManager;
import androidx.annotation.NonNull;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.DefaultRenderersFactory;
import androidx.media3.exoplayer.mediacodec.MediaCodecInfo;
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector;
import java.util.ArrayList;
import java.util.List;

/**
 * Décodeurs des vidéos de Foclaboard.
 *
 * <p>Si un décodeur n'arrive pas à démarrer, ExoPlayer essaie le suivant (au lieu de s'arrêter en
 * erreur). Sur Android TV, les décodeurs logiciels passent en premier : le décodeur matériel de
 * certaines TV (TCL 55P615) échoue sur les vidéos de l'appli, que le décodeur logiciel lit sans
 * problème (720p).
 */
@UnstableApi
public final class FocRenderers {
  private FocRenderers() {}

  public static boolean isTv(@NonNull Context context) {
    return context.getPackageManager().hasSystemFeature(PackageManager.FEATURE_LEANBACK);
  }

  @NonNull
  public static DefaultRenderersFactory create(@NonNull Context context) {
    DefaultRenderersFactory factory =
        new DefaultRenderersFactory(context).setEnableDecoderFallback(true);
    if (isTv(context)) {
      factory.setMediaCodecSelector(SOFTWARE_FIRST);
    }
    return factory;
  }

  static final MediaCodecSelector SOFTWARE_FIRST =
      (mimeType, requiresSecureDecoder, requiresTunnelingDecoder) -> {
        List<MediaCodecInfo> all =
            MediaCodecSelector.DEFAULT.getDecoderInfos(
                mimeType, requiresSecureDecoder, requiresTunnelingDecoder);
        if (!mimeType.startsWith("video/")) return all;
        List<MediaCodecInfo> sorted = new ArrayList<>();
        for (MediaCodecInfo info : all) if (info.softwareOnly) sorted.add(info);
        for (MediaCodecInfo info : all) if (!info.softwareOnly) sorted.add(info);
        return sorted;
      };

  /** Le message de l'erreur et de ses causes (nom du décodeur, raison de l'échec). */
  @NonNull
  public static String describe(@NonNull Throwable error) {
    StringBuilder text = new StringBuilder(String.valueOf(error));
    Throwable cause = error.getCause();
    for (int i = 0; cause != null && i < 4; i++, cause = cause.getCause()) {
      text.append(" | cause: ").append(cause);
    }
    return text.toString();
  }
}
