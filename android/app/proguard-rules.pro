# --- REGLAS PARA FLUTTER LOCAL NOTIFICATIONS Y GSON ---

# Mantiene la firma de las clases para que la serialización no falle
-keepattributes Signature

# Mantiene las clases de modelos de la librería de notificaciones
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }

# Mantiene las clases de Gson necesarias para la reflexión y el manejo de tipos
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken