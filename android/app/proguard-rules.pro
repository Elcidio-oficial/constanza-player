# ─── JAudioTagger ────────────────────────────────────────────────────────────
# Referencia classes Java AWT/ImageIO que não existem no Android (apenas desktop).
-dontwarn java.awt.**
-dontwarn javax.imageio.**
-dontwarn javax.swing.**
-keep class org.jaudiotagger.** { *; }

# ─── audio_service (com.ryanheise) ───────────────────────────────────────────
# AudioService, AudioServiceFragmentActivity e helpers são referenciados pelo
# AndroidManifest e por reflexão interna do plugin. Não podem ser ofuscados.
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.bgaudio.** { *; }
-dontwarn com.ryanheise.**

# ─── just_audio / ExoPlayer ──────────────────────────────────────────────────
# just_audio usa ExoPlayer internamente. O R8 pode remover extensões de
# renderers registradas via reflexão se não forem mantidas.
-keep class com.google.android.exoplayer2.** { *; }
-keep interface com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# Media3 (nova API do ExoPlayer — versões mais recentes do just_audio)
-keep class androidx.media3.** { *; }
-keep interface androidx.media3.** { *; }
-dontwarn androidx.media3.**

# ─── AndroidX Media / MediaSession ───────────────────────────────────────────
-keep class androidx.media.** { *; }
-dontwarn androidx.media.**

# ─── Plugins nativos do app ──────────────────────────────────────────────────
# Estes plugins são registrados manualmente via configureFlutterEngine()
# e precisam estar acessíveis pelo nome completo.
-keep class com.constanza.constanza_player.** { *; }

# ─── Flutter embedding ───────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep interface io.flutter.** { *; }
-dontwarn io.flutter.**

# ─── on_audio_query ──────────────────────────────────────────────────────────
-keep class com.lucasjosino.** { *; }
-dontwarn com.lucasjosino.**

# ─── Regras gerais de segurança para plugins Flutter ─────────────────────────
# Mantém anotações e metadados usados por reflexão.
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod
-keepattributes InnerClasses
