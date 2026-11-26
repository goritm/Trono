import 'package:material_ui/material_ui.dart';

import '../models/bathroom_log.dart';

class AppStrings {
  AppStrings(this.locale);

  final Locale locale;
  bool get isEs => locale.languageCode == 'es';

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings) ??
        AppStrings(const Locale('es'));
  }

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  String _t(String es, String en) => isEs ? es : en;

  // App & Navigation
  String get appName => 'Trono';
  String get navLog => _t('Registrar', 'Log');
  String get navCalendar => _t('Calendario', 'Calendar');
  String get navAchievements => _t('Logros', 'Awards');
  String get navSettings => _t('Ajustes', 'Settings');

  // Home screen
  String get homeSubtitle => _t('¿Listo para registrar?', 'Ready to log?');
  String get oneTapHint => _t('1 toque guarda al instante', '1 tap logs instantly');
  String get heroLogTitle => _t('Registrar Pupu', 'Log Poop');
  String get heroLogSubtitle => _t(
    'Toca para guardar al instante · detalles opcionales después',
    'Tap to save instantly · optional details right after',
  );
  String get todayCountLabel => _t('Hoy', 'Today');
  String get dailyAvgLabel => _t('Prom/día', 'Avg/day');
  String get streakLabel => _t('Racha', 'Streak');
  String daysShort(int n) => _t('${n}d', '${n}d');
  String get addPastVisit => _t('Registrar visita pasada', 'Log past visit');
  String get todayHistory => _t('Hoy en el baño', 'Today’s visits');
  String get recentHistory => _t('Últimos registros', 'Recent visits');
  String get noLogsYetTitle => _t('Tu historial está vacío', 'No visits logged yet');
  String get noLogsYetBody => _t(
    'Toca el botón de arriba para registrar tu primer pupu en 1 segundo.',
    'Tap the button above to log your first poop in 1 second.',
  );
  String get savedInstantToast => _t('¡Registrado! (+10 XP)', 'Logged! (+10 XP)');
  String get detailsSavedToast => _t('Detalles guardados', 'Details saved');
  String get logDeletedToast => _t('Registro eliminado', 'Visit deleted');

  // Live timer
  String get startTimer => _t('Iniciar cronómetro', 'Start timer');
  String get timerRunning => _t('En el baño...', 'On the seat...');
  String get stopTimer => _t('Detener', 'Stop');
  String get cancelTimer => _t('Cancelar', 'Cancel');
  String get timerHint => _t(
    'Al tocar un botón se guarda este tiempo',
    'Next tap attaches this duration',
  );

  // Bathroom types
  String typeName(BathroomType type) => switch (type) {
    BathroomType.poop => _t('Pupu', 'Poop'),
    BathroomType.falseAlarm => _t('Falsa alarma', 'False alarm'),
  };

  String typeSubtitle(BathroomType type) => switch (type) {
    BathroomType.poop => _t('Misión cumplida', 'Mission complete'),
    BathroomType.falseAlarm => _t('Solo a sentarme', 'Just sat there'),
  };

  // Detail bottom sheet
  String get quickDetailsTitle => _t('¡Guardado! ¿Añadir detalles?', 'Saved! Add details?');
  String get quickDetailsSubtitle => _t(
    'Opcional — puedes cerrar esto sin perder el registro',
    'Optional — swipe down anytime, it’s already saved',
  );
  String get editLogTitle => _t('Editar visita', 'Edit visit');
  String get pastLogTitle => _t('Registrar visita pasada', 'Log past visit');
  String get typeField => _t('Tipo de visita', 'Visit type');
  String get dateTimeField => _t('Fecha y hora', 'Date & time');
  String get bristolField => _t('Escala de Bristol', 'Bristol Scale');
  String get sizeField => _t('Tamaño', 'Size');
  String get effortField => _t('Sensación / Esfuerzo', 'Effort / Feeling');
  String get durationField => _t('Duración', 'Duration');
  String get colorField => _t('Color', 'Color');
  String get tagsField => _t('Tags rápidos', 'Quick tags');
  String get noteField => _t('Nota libre', 'Note');
  String get notePlaceholder => _t('Algo que quieras recordar...', 'Anything worth noting...');
  String get privacyField => _t('Privacidad (para V2 amigos)', 'Privacy (for V2 friends)');
  String get doneButton => _t('Listo', 'Done');
  String get saveButton => _t('Guardar', 'Save');
  String get deleteButton => _t('Eliminar', 'Delete');
  String get skipButton => _t('Saltar', 'Skip');

  // Bristol scale (1-7)
  String bristolShort(int type) => switch (type) {
    1 => _t('1 · Bolitas', '1 · Pellets'),
    2 => _t('2 · Grumosa', '2 · Lumpy'),
    3 => _t('3 · Agrietada', '3 · Cracked'),
    4 => _t('4 · Perfecta', '4 · Perfect'),
    5 => _t('5 · Trozos', '5 · Soft blobs'),
    6 => _t('6 · Pastosa', '6 · Mushy'),
    7 => _t('7 · Líquida', '7 · Liquid'),
    _ => '$type',
  };

  String bristolEmoji(int type) => switch (type) {
    1 => '🪨',
    2 => '🍇',
    3 => '🌽',
    4 => '🍌',
    5 => '☁️',
    6 => '🍦',
    7 => '🌊',
    _ => '💩',
  };

  String bristolHint(int type) => switch (type) {
    1 => _t('Dura como piedra, difícil', 'Hard lumps, tough to pass'),
    2 => _t('Forma de salchicha con bultos', 'Lumpy sausage shape'),
    3 => _t('Bien, con grietas afuera', 'Sausage with surface cracks'),
    4 => _t('Suave y perfecta, 10/10', 'Smooth & ideal, 10/10'),
    5 => _t('Trozos blandos, fácil', 'Soft blobs, easy pass'),
    6 => _t('Blanda / pastosa', 'Fluffy / mushy pieces'),
    7 => _t('Totalmente líquida', 'Entirely liquid'),
    _ => '',
  };

  String sizeName(PoopSize size) => switch (size) {
    PoopSize.small => _t('Poco', 'Small'),
    PoopSize.normal => _t('Normal', 'Normal'),
    PoopSize.epic => _t('Épico', 'Epic'),
  };

  String effortName(EffortLevel effort) => switch (effort) {
    EffortLevel.effortless => _t('Sin esfuerzo', 'Effortless'),
    EffortLevel.normal => _t('Normal', 'Normal'),
    EffortLevel.struggled => _t('Sufrido', 'Struggled'),
    EffortLevel.urgent => _t('Urgencia', 'Urgent'),
  };

  String colorName(StoolColor color) => switch (color) {
    StoolColor.brown => _t('Marrón', 'Brown'),
    StoolColor.lightBrown => _t('Claro', 'Light'),
    StoolColor.darkBrown => _t('Oscuro', 'Dark'),
    StoolColor.green => _t('Verde', 'Green'),
    StoolColor.yellow => _t('Amarillo', 'Yellow'),
    StoolColor.reddish => _t('Rojizo', 'Reddish'),
  };

  String tagLabel(String tag) => switch (tag) {
    'coffee' => _t('☕ Café', '☕ Coffee'),
    'spicy' => _t('🌶️ Picante', '🌶️ Spicy'),
    'home' => _t('🏠 Casa', '🏠 Home'),
    'work' => _t('💼 Trabajo', '💼 Work'),
    'travel' => _t('✈️ Viaje', '✈️ Travel'),
    'dairy' => _t('🧀 Lácteos', '🧀 Dairy'),
    'morning' => _t('🌅 Mañana', '🌅 Morning'),
    'late_night' => _t('🌙 Madrugada', '🌙 Late night'),
    _ => tag,
  };

  String shareLevelName(ShareLevel level) => switch (level) {
    ShareLevel.private => _t('🔒 Privado', '🔒 Private'),
    ShareLevel.summaryOnly => _t('👥 Solo resumen', '👥 Summary only'),
    ShareLevel.full => _t('🌍 Completo', '🌍 Full detail'),
  };

  String formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
    if (secs == 0 || mins >= 10) return '${mins}m';
    return '${mins}m ${secs}s';
  }

  // Calendar & Stats screen
  String get calendarStatsTitle => _t('Calendario y Stats', 'Calendar & Stats');
  String get dailyAverageTitle => _t('Promedio diario', 'Daily average');
  String get periodWeek => _t('7 días', '7 days');
  String get periodMonth => _t('30 días', '30 days');
  String get periodAll => _t('Histórico', 'All time');
  String get totalVisitsPerDay => _t('Visitas / día', 'Visits / day');
  String get poopPerDay => _t('Pupu / día', 'Poop / day');
  String visitsTotalSub(int n, int days) =>
      _t('$n en $days días', '$n across $days days');
  String get heatmapTitle => _t('Mapa de calor mensual', 'Monthly heatmap');
  String get heatmapLegendLess => _t('Menos', 'Less');
  String get heatmapLegendMore => _t('Más', 'More');
  String get tapDayHint => _t('Toca un día para ver o editar', 'Tap a day to view or edit');
  String get peakHoursTitle => _t('Horas pico', 'Peak hours');
  String peakHourSummary(int hour) {
    final formatted = '${hour.toString().padLeft(2, '0')}:00';
    return _t('Tu hora estrella: $formatted', 'Your prime hour: $formatted');
  }
  String get noPeakHourYet => _t('Aún sin suficientes datos', 'Not enough data yet');
  String get recordsTitle => _t('Récords personales', 'Personal records');
  String get recordDayLabel => _t('Día récord', 'Busiest day');
  String get longestStreakLabel => _t('Racha más larga', 'Longest streak');
  String get longestSessionLabel => _t('Sesión más larga', 'Longest session');
  String get totalTimeLabel => _t('Tiempo total est.', 'Est. total time');
  String visitsCount(int n) => _t('$n visitas', '$n visits');
  String daysCount(int n) => _t('$n días', '$n days');
  String get noVisitsThisDay => _t('Sin registros este día', 'No visits on this day');
  String get addForThisDay => _t('Añadir visita en este día', 'Add visit on this day');

  // Weekday initials (Mon..Sun)
  List<String> get weekdayShorts => isEs
      ? const ['L', 'M', 'X', 'J', 'V', 'S', 'D']
      : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  // Achievements & Ranks
  String get achievementsTitle => _t('Logros y Rangos', 'Awards & Ranks');
  String get rankLadderTitle => _t('Escalera de Rangos', 'Rank Ladder');
  String get badgesTitle => _t('Insignias', 'Badges');
  String get filterAll => _t('Todas', 'All');
  String get filterUnlocked => _t('Desbloqueadas', 'Unlocked');
  String get filterLocked => _t('Pendientes', 'Locked');
  String get maxRankReached => _t('¡Rango máximo alcanzado!', 'Max rank reached!');
  String xpToNext(int remaining, String nextName) => _t(
    'Faltan $remaining XP para $nextName',
    '$remaining XP to reach $nextName',
  );
  String get unlockedCelebrationTitle => _t('¡Logro desbloqueado!', 'Achievement unlocked!');
  String get rankUpTitle => _t('¡Subiste de rango!', 'Rank up!');
  String get awesomeButton => _t('¡Brutal!', 'Awesome!');

  String rankName(String id) => switch (id) {
    'rookie' => _t('Novato del Baño', 'Bathroom Rookie'),
    'regular' => _t('Cliente Frecuente', 'Regular Visitor'),
    'navigator' => _t('Explorador de Porcelana', 'Porcelain Explorer'),
    'duke' => _t('Duque del Rollito', 'Duke of the Roll'),
    'master' => _t('Maestro del Trono', 'Throne Master'),
    'legend' => _t('Leyenda de Porcelana', 'Porcelain Legend'),
    'deity' => _t('Deidad del Trono', 'Throne Deity'),
    _ => id,
  };

  String achievementTitle(String id) => switch (id) {
    'first_visit' => _t('Bautizo Oficial', 'First Drop'),
    'hat_trick' => _t('Tripleta', 'Hat-Trick'),
    'turbo_day' => _t('Modo Turbo', 'Turbo Day'),
    'streak_7' => _t('Semana de Acero', '7-Day Streak'),
    'streak_30' => _t('Reloj Suizo', 'Swiss Clock'),
    'night_owl' => _t('Búho Nocturno', 'Night Owl'),
    'early_bird' => _t('Madrugador', 'Early Bird'),
    'perfect_four' => _t('El 4 Perfecto', 'The Perfect 4'),
    'false_alarm_pro' => _t('Falsa Alarma Pro', 'False Alarm Pro'),
    'paid_to_poop' => _t('En Horario Laboral', 'Paid to Go'),
    'coffee_effect' => _t('Efecto Cafeína', 'Caffeine Kick'),
    'marathoner' => _t('Maratonista', 'Marathoner'),
    'epic_drop' => _t('Obra Maestra', 'Masterpiece'),
    'detail_scientist' => _t('Científico de Datos', 'Data Scientist'),
    'spicy_survivor' => _t('Sobreviviente Picante', 'Spicy Survivor'),
    'century_club' => _t('Club de los 100', 'Century Club'),
    'poop_veteran' => _t('Veterano #2', '#2 Veteran'),
    _ => id,
  };

  String achievementDesc(String id) => switch (id) {
    'first_visit' => _t('Registra tu primera visita', 'Log your very first visit'),
    'hat_trick' => _t('3 o más visitas en un solo día', '3+ visits in a single day'),
    'turbo_day' => _t('6 o más visitas en un solo día', '6+ visits in a single day'),
    'streak_7' => _t('Registra 7 días seguidos', 'Log 7 days in a row'),
    'streak_30' => _t('Registra 30 días seguidos', 'Log 30 days in a row'),
    'night_owl' => _t('Una visita entre 00:00 y 05:00', 'A visit between 12am and 5am'),
    'early_bird' => _t('5 visitas entre 05:00 y 08:00', '5 visits between 5am and 8am'),
    'perfect_four' => _t('5 veces Bristol tipo 4 (perfección)', '5 times Bristol type 4 (ideal)'),
    'false_alarm_pro' => _t('5 falsas alarmas registradas', '5 false alarms logged'),
    'paid_to_poop' => _t('5 visitas con el tag Trabajo', '5 visits tagged Work'),
    'coffee_effect' => _t('5 visitas con el tag Café', '5 visits tagged Coffee'),
    'marathoner' => _t('Una sesión de 15+ minutos', 'A 15+ minute session'),
    'epic_drop' => _t('3 registros con tamaño Épico', '3 logs with Epic size'),
    'detail_scientist' => _t('Añade detalles en 15 visitas', 'Add details to 15 visits'),
    'spicy_survivor' => _t('5 registros con el tag Picante', '5 logs tagged Spicy'),
    'century_club' => _t('Alcanza 100 visitas totales', 'Reach 100 total visits'),
    'poop_veteran' => _t('Alcanza 50 pupus registrados', 'Reach 50 Poop visits'),
    _ => '',
  };

  // Settings & Lock
  String get settingsTitle => _t('Ajustes', 'Settings');
  String get appearanceSection => _t('Apariencia e Idioma', 'Appearance & Language');
  String get languageLabel => _t('Idioma', 'Language');
  String get themeLabel => _t('Tema', 'Theme');
  String get themeSystem => _t('Sistema', 'System');
  String get themeLight => _t('Claro', 'Light');
  String get themeDark => _t('Oscuro', 'Dark');

  String get securitySection => _t('Seguridad y Privacidad', 'Security & Privacy');
  String get appLockLabel => _t('Bloqueo al abrir Trono', 'Lock Trono on launch');
  String get appLockSubtitle => _t(
    'Protege tu historial con huella o PIN de 4 dígitos',
    'Protect your log with biometrics or a 4-digit PIN',
  );
  String get biometricLabel => _t('Usar huella / biometría', 'Use fingerprint / biometrics');
  String get setPinLabel => _t('Configurar / cambiar PIN', 'Set / change PIN');
  String get removePinLabel => _t('Quitar PIN', 'Remove PIN');
  String get enterNewPin => _t('Nuevo PIN (4 dígitos)', 'New 4-digit PIN');
  String get pinSavedToast => _t('PIN guardado', 'PIN saved');
  String get defaultPrivacyLabel => _t('Privacidad por defecto (V2)', 'Default privacy (V2)');
  String get multiplayerTeaserTitle => _t('Multiplayer con amigos (V2)', 'Friends Multiplayer (V2)');
  String get multiplayerTeaserBody => _t(
    'Tu base de datos local ya guarda UUIDs y privacidad por registro para sincronizar grupos, feed en vivo y rankings cuando activemos V2.',
    'Your local database already stores UUIDs & per-log privacy so private groups, live feed, and leaderboards plug right in for V2.',
  );

  String get backupSection => _t('Respaldo de datos', 'Data Backup');
  String get exportJsonLabel => _t('Exportar respaldo JSON', 'Export JSON backup');
  String get exportJsonSub => _t('Respaldo completo re-importable', 'Full re-importable backup');
  String get exportCsvLabel => _t('Exportar tabla CSV', 'Export CSV spreadsheet');
  String get exportCsvSub => _t('Ideal para Excel o Google Sheets', 'Great for Excel or Sheets');
  String get importBackupLabel => _t('Importar respaldo (JSON / CSV)', 'Import backup (JSON / CSV)');
  String get importBackupSub => _t('Combina sin duplicar tus registros', 'Merges without duplicates');
  String importedCountToast(int n) => _t(
    '¡Importados $n registros!',
    'Imported $n visits!',
  );
  String get importFailedToast => _t(
    'No se pudo leer ese archivo',
    'Could not read that file',
  );

  String get widgetSection => _t('Widget de Android', 'Android Home Widget');
  String get widgetGuideBody => _t(
    'Mantén pulsada tu pantalla de inicio → Widgets → Trono para registrar un pupu en 1 toque sin abrir la app.',
    'Long-press your home screen → Widgets → Trono to log a poop in 1 tap without opening the app.',
  );

  // Lock screen
  String get lockTitle => _t('Trono está bloqueado', 'Trono is locked');
  String get lockSubtitle => _t('Desbloquea para ver tu historial', 'Unlock to view your log');
  String get unlockBiometric => _t('Usar huella / biometría', 'Use fingerprint / biometrics');
  String get wrongPin => _t('PIN incorrecto', 'Incorrect PIN');
  String get biometricReason => _t(
    'Autentícate para abrir Trono',
    'Authenticate to open Trono',
  );
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'es' || locale.languageCode == 'en';

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
