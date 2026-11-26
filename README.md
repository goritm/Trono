# 👑 Trono

Aplicación móvil (Flutter · Android + lista para iOS) para registrar tus idas al baño de forma ultra rápida, conocer tu promedio diario real y desbloquear rangos y logros graciosos.

## Funciones (V1)
- **Registro en 1 toque**: botón principal gigante para registrar **Pupu** al instante (+ opción secundaria para **Falsa alarma**).
- **Detalles rápidos opcionales**: Escala de Bristol (1–7), tamaño, esfuerzo/sensación, duración (chips rápidos + cronómetro en vivo), color, tags rápidos y nota libre.
- **Historial flexible**: añade visitas pasadas y edita o elimina cualquier registro.
- **Calendario y Estadísticas**: promedio diario (7 días / 30 días / histórico), mapa de calor mensual interactivo, gráfica de horas pico y récords personales.
- **Gamificación**: XP por registro, 7 rangos (*Novato del Baño* → *Deidad del Trono*) y 17 insignias desbloqueables con celebración.
- **Extras prácticos**: Widget de pantalla de inicio en Android (`+1 Pupu` en 1 toque), bloqueo opcional con huella/PIN, respaldo JSON/CSV e interfaz bilingüe (ES/EN) con modo claro/oscuro.
- **Preparada para V2 (Multiplayer)**: SQLite local con UUIDs, borrado lógico, `sync_status` y nivel de privacidad por registro.

## Comandos útiles
```bash
flutter pub get
flutter test
flutter build apk --release
```
El APK compilado se genera en `build/app/outputs/flutter-apk/app-release.apk`.
