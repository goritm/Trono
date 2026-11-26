import 'package:material_ui/material_ui.dart';

import '../models/bathroom_log.dart';

class AppStrings {
  AppStrings(this.locale);

  final Locale locale;
  bool get isEs => locale.languageCode == 'es';

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings) ??
        AppStrings(const Locale('en'));
  }

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  String _t(String es, String en) => isEs ? es : en;

  // App & Navigation
  String get appName => 'Trono';
  String get navLog => _t('Registrar', 'Log');
  String get navCalendar => _t('Calendario', 'Calendar');
  String get navStats => _t('Stats', 'Stats');
  String get navMap => _t('Mapa', 'Map');
  String get navSocial => _t('Amigos', 'Friends');
  String get navAchievements => _t('Logros', 'Awards');
  String get navSettings => _t('Ajustes', 'Settings');
  String get statsTabCalendar => _t('Calendario', 'Calendar');
  String get statsTabAnalysis => _t('Análisis', 'Insights');
  String get statsTabAwards => _t('Logros', 'Awards');
  String get mapSubTabMap => _t('Mapa', 'Map');
  String get mapSubTabPlaces => _t('Lugares ⭐', 'Places ⭐');

  // Home screen
  String get homeSubtitle => _t('¿Listo para registrar?', 'Ready to log?');
  String get oneTapHint => _t('1 toque guarda al instante', '1 tap logs instantly');
  String get heroLogTitle => _t('Registrar Trono', 'Claim Throne');
  String get heroLoggedFlash => _t('¡Registrado!', 'Logged!');
  String get heroLogSubtitle => _t(
    'Toca para guardar al instante · detalles opcionales después',
    'Tap to save instantly · optional details right after',
  );
  String get todayCountLabel => _t('Hoy', 'Today');
  String get dailyAvgLabel => _t('Prom/día', 'Avg/day');
  String get streakLabel => _t('Racha', 'Streak');
  String daysShort(int n) => _t('${n}d', '${n}d');
  String get addPastVisit => _t('Registrar visita pasada', 'Log past visit');
  String get pastVisitShort => _t('Pasada', 'Past');
  String get timerShort => _t('Cronómetro', 'Timer');
  String get todayHistory => _t('Hoy en el baño', 'Today’s visits');
  String get recentHistory => _t('Últimos registros', 'Recent visits');
  String get noLogsYetTitle => _t('Tu historial está vacío', 'No visits logged yet');
  String get noLogsYetBody => _t(
    'Toca el botón de arriba para registrar tu primer trono en 1 segundo.',
    'Tap the button above to claim your first throne in 1 second.',
  );
  String get savedInstantToast => _t('¡Registrado! (+10 XP)', 'Logged! (+10 XP)');
  String get undoAction => _t('Deshacer', 'Undo');
  String get undoneToast => _t('Registro deshecho', 'Log undone');
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
    BathroomType.poop => _t('Trono', 'Throne'),
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
  String get tagsField => _t('Comida y detonantes', 'Food & triggers');
  String get noteField => _t('Nota libre', 'Note');
  String get notePlaceholder => _t('Algo que quieras recordar...', 'Anything worth noting...');
  String get privacyField => _t('Privacidad con amigos', 'Privacy with friends');
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
    _ => '👑',
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
    'dairy' => _t('🧀 Lácteos', '🧀 Dairy'),
    'alcohol' => _t('🍺 Alcohol', '🍺 Alcohol'),
    'fast_food' => _t('🍔 Comida rápida', '🍔 Fast food'),
    'fiber' => _t('🥗 Fibra', '🥗 Fiber'),
    'sweets' => _t('🍫 Dulces', '🍫 Sweets'),
    'stress' => _t('😰 Estrés', '😰 Stress'),
    // Legacy fallbacks for previously saved logs
    'home' => _t('🏠 Casa', '🏠 Home'),
    'work' => _t('💼 Trabajo', '💼 Work'),
    'travel' => _t('✈️ Viaje', '✈️ Travel'),
    'restaurant' => _t('🍽️ Restaurante', '🍽️ Restaurant'),
    'morning' => _t('🌅 Mañana', '🌅 Morning'),
    'late_night' => _t('🌙 Madrugada', '🌙 Late night'),
    _ => tag,
  };

  // V1.5 Location, Home / Work / Away & Map
  String locationKindName(LocationKind kind) => switch (kind) {
    LocationKind.home => _t('En casa', 'At home'),
    LocationKind.work => _t('En el trabajo', 'At work'),
    LocationKind.away => _t('Fuera de casa', 'Away'),
  };

  String get quickHomeButton => _t('Casa', 'Home');
  String get quickWorkButton => _t('Trabajo', 'Work');
  String get quickAwayButton => _t('Fuera', 'Away');
  String get quickAutoChip => _t('Auto', 'Auto');
  String get locationField => _t('Ubicación', 'Location');
  String get placeNamePlaceholder =>
      _t('Ej. Oficina, Aeropuerto, Bar...', 'e.g. Office, Airport, Cafe...');
  String get captureGpsButton => _t('Fijar pin GPS aquí', 'Pin current GPS');
  String get gpsPinnedLabel => _t('Pin GPS guardado', 'GPS pin saved');
  String get clearPinGps => _t('Quitar pin', 'Remove pin');
  String get gpsUnavailableToast => _t(
    'No se pudo obtener GPS (revisa permisos)',
    'Could not get GPS (check permissions)',
  );

  String get territoryTitle => _t('En casa vs Fuera', 'Home vs Away');
  String get homeShort => _t('Casa', 'Home');
  String get awayShort => _t('Fuera', 'Away');
  String get noLocationDataYet => _t(
    'Marca "En casa" o "Fuera" al registrar para descubrir tu porcentaje de supervivencia.',
    'Mark "At home" or "Away" when logging to unlock your survival ratio.',
  );
  String spotsConqueredLabel(int n) =>
      _t('$n lugares conquistados', '$n spots conquered');
  String farthestDropLabel(double km) =>
      _t('Máx. distancia: ${km.toStringAsFixed(1)} km', 'Farthest: ${km.toStringAsFixed(1)} km');
  String get openMapButton => _t('Ver Mapa de Tronos', 'Open Throne Map');
  String get mapScreenTitle => _t('Mapa de Tronos', 'Throne Map');
  String get mapEmptyTitle => _t('Tu mapa espera conquistas', 'No pins on your map yet');
  String get mapEmptyBody => _t(
    'Activa el GPS en Ajustes o toca "Fijar pin GPS" al registrar un trono para ir marcando tu territorio en el mapa.',
    'Enable GPS in Settings or tap "Pin current GPS" when logging to map your conquered spots.',
  );
  String get homePinLabel => _t('Tu Casa (Base)', 'Home Base');

  String get locationSettingsSection => _t('Ubicación y Casa', 'Location & Home');
  String get autoGpsLabel => _t('Guardar GPS automáticamente', 'Auto-save GPS pin');
  String get autoGpsSub => _t(
    'Detecta Casa vs Fuera y marca pines en tu mapa local',
    'Auto-detects Home vs Away & drops local map pins',
  );
  String get setHomeLocationLabel => _t('Guardar ubicación actual como Casa', 'Set current spot as Home');
  String get homeConfiguredSub => _t('Casa configurada (radio 150 m)', 'Home set (150 m radius)');
  String get homeNotSetSub => _t('Útil para detectar Casa vs Fuera sin tocar nada', 'Auto-detects Home vs Away automatically');
  String get homeSavedToast => _t('¡Ubicación de Casa guardada!', 'Home location saved!');
  String get clearHomeLabel => _t('Borrar ubicación de Casa', 'Clear Home location');

  // V2.2 Favorite Places & 1–5 ⭐ Bathroom Ratings
  String get bathroomRatingField => _t('Valoración del baño', 'Bathroom rating');
  String ratingLabel(int stars) => switch (stars) {
    1 => _t('1/5 · Para olvidar', '1/5 · Never again'),
    2 => _t('2/5 · Justito', '2/5 · Barely okay'),
    3 => _t('3/5 · Cumple', '3/5 · Gets it done'),
    4 => _t('4/5 · Muy bien', '4/5 · Very nice'),
    5 => _t('5/5 · Trono VIP', '5/5 · VIP Throne'),
    _ => '$stars/5',
  };
  String get favoritePlacesQuickPickLabel =>
      _t('Lugares favoritos', 'Favorite places');
  String get favoritePlacesTitle =>
      _t('Lugares Favoritos y Top Baños ⭐', 'Favorite Places & Top Bathrooms ⭐');
  String get favoritePlacesShortTitle =>
      _t('Lugares y Top Baños', 'Places & Top Bathrooms');
  String get favoritePlacesMenuTitle =>
      _t('Lugares Favoritos y Top Baños ⭐', 'Favorite Places & Top Bathrooms ⭐');
  String favoritePlacesMenuSub(int count) {
    if (count == 0) {
      return _t(
        'Guarda lugares para autodetectarlos por GPS',
        'Save spots for silent GPS auto-detection',
      );
    }
    if (count == 1) {
      return _t('1 lugar guardado · radio 150 m', '1 saved place · 150 m radius');
    }
    return _t(
      '$count lugares guardados · radio 150 m',
      '$count saved places · 150 m radius',
    );
  }

  String get saveCurrentLocationButton =>
      _t('Guardar ubicación actual', 'Save current location');
  String get addFavoritePlaceTitle =>
      _t('Guardar lugar favorito', 'Save favorite place');
  String get favoritePlaceNameLabel => _t('Nombre del lugar', 'Place name');
  String get favoritePlaceNameHint =>
      _t('Ej. Oficina, Gimnasio, Café...', 'e.g. Office, Gym, Cafe...');
  String get favoritePlaceEmojiLabel => _t('Icono del lugar', 'Place icon');
  String get favoritePlaceKindLabel => _t('Tipo de ubicación', 'Location type');
  String get favoritePlaceGpsNotice => _t(
    'Captura tu GPS actual solo en tu dispositivo (radio 150 m). Nunca se sube a la nube.',
    'Captures your current GPS on this device only (150 m radius). Never uploaded to the cloud.',
  );
  String get favoritePlaceSavedToast =>
      _t('¡Lugar favorito guardado!', 'Favorite place saved!');
  String get favoritePlaceDeletedToast =>
      _t('Lugar favorito eliminado', 'Favorite place deleted');
  String get savedPlacesSectionTitle =>
      _t('Lugares favoritos', 'Favorite places');
  String get noFavoritePlacesTitle =>
      _t('Sin lugares favoritos aún', 'No favorite places yet');
  String get noFavoritePlacesBody => _t(
    'Guarda tu oficina, gimnasio o bar favorito para que Trono los autodetecte por GPS al registrar un trono.',
    'Save your office, gym, or go-to cafe so Trono auto-labels your thrones via GPS.',
  );
  String get topBathroomsSectionTitle => _t('Top Baños ⭐', 'Top Bathrooms ⭐');
  String get noTopBathroomsTitle =>
      _t('Tu ranking espera visitas', 'Your ranking awaits visits');
  String get noTopBathroomsBody => _t(
    'Ponle nombre al lugar o guarda favoritos y valora los baños de 1 a 5 ⭐ para ver tu Top Baños.',
    'Add a place name or save favorites and rate bathrooms 1–5 ⭐ to build your Top Bathrooms.',
  );
  String placeVisitsCount(int n) =>
      n == 1 ? _t('1 visita', '1 visit') : _t('$n visitas', '$n visits');
  String get unratedLabel => _t('Sin valorar', 'Unrated');
  String radiusMetersLabel(int meters) =>
      _t('Radio $meters m · Solo local', '$meters m radius · Local only');

  // V1.6 Paid on the Throne, Insights, Wrapped & Map Filters
  String get paidThroneTitle => _t('Pagado en el Trono', 'Paid on the Throne');
  String get paidThisMonthLabel => _t('Este mes', 'This month');
  String get paidAllTimeLabel => _t('Total acumulado', 'All-time earned');
  String get paidSetupHint => _t(
    'Configura tu sueldo aproximado en Ajustes (100% local) y elige 💼 Trabajo al registrar para ver cuánto ganas en el trono.',
    'Set your approximate pay in Settings (100% local) and pick 💼 Work when logging to see how much you earn on the throne.',
  );
  String get configureSalaryButton => _t('Configurar sueldo', 'Set pay rate');
  String get salarySettingsSection => _t('Pagado en el Trono', 'Paid on the Throne');
  String get salarySettingsLabel => _t('Sueldo aproximado (100% local)', 'Approximate pay (100% local)');
  String salaryConfiguredSub(String symbol, double hourly) => _t(
    '$symbol${hourly.toStringAsFixed(2)}/hora · nunca sale de tu teléfono',
    '$symbol${hourly.toStringAsFixed(2)}/hr · stays 100% on device',
  );
  String get salaryNotSetSub => _t(
    'Opcional · calcula cuánto te pagan en horario laboral',
    'Optional · calculates money earned during work hours',
  );
  String get salaryDialogTitle => _t('Configurar sueldo (local)', 'Set pay rate (local)');
  String get salaryModeMonthly => _t('Mensual neto', 'Monthly net');
  String get salaryModeHourly => _t('Por hora', 'Hourly');
  String get salaryAmountHint => _t('Ej. 2000', 'e.g. 2000');
  String get salarySavedToast => _t('Sueldo guardado localmente', 'Pay rate saved locally');
  String get clearSalaryButton => _t('Quitar sueldo', 'Clear pay');
  String workVisitsSub(int count, String duration) =>
      _t('$count visitas · $duration en el trabajo', '$count visits · $duration at work');

  String get insightsTitle => _t('Tus Patrones', 'Your Insights');
  String weekdayFull(int weekday) => switch (weekday) {
    1 => _t('lunes', 'Mondays'),
    2 => _t('martes', 'Tuesdays'),
    3 => _t('miércoles', 'Wednesdays'),
    4 => _t('jueves', 'Thursdays'),
    5 => _t('viernes', 'Fridays'),
    6 => _t('sábados', 'Saturdays'),
    7 => _t('domingos', 'Sundays'),
    _ => '',
  };

  String insightText(
    String typeName, {
    int int1 = 0,
    int int2 = 0,
    String str = '',
  }) => switch (typeName) {
    'busiestWeekday' => _t(
        'Tu día estrella son los ${weekdayFull(int1)} ($int2 tronos).',
        'Your busiest day is ${weekdayFull(int1)} ($int2 thrones).',
      ),
    'topBristol' => _t(
        'Tu clásico: Bristol ${bristolShort(int1)} ($int2% de las veces).',
        'Your signature: Bristol ${bristolShort(int1)} ($int2% of logs).',
      ),
    'topTriggerTag' => _t(
        '${tagLabel(str)} aparece en el $int1% de tus tronos ($int2 veces).',
        '${tagLabel(str)} shows up in $int1% of your thrones ($int2 times).',
      ),
    'awaySuperpower' => _t(
        'Superpoder activo: $int1% de tus tronos son fuera de casa ($int2).',
        'Superpower unlocked: $int1% of your thrones are away from home ($int2).',
      ),
    'timeMovies' => _t(
        'Llevas ${formatDuration(int1 * 60)} en el trono — equivale a ~$int2 película(s).',
        'You’ve spent ${formatDuration(int1 * 60)} on the throne — roughly ~$int2 movie(s).',
      ),
    _ => '',
  };

  // Trono Wrapped
  String get wrappedButtonLabel => _t('Ver mi Trono Wrapped', 'View Trono Wrapped');
  String get wrappedTitle => 'Trono Wrapped';
  String get wrappedThisMonth => _t('Este mes', 'This month');
  String get wrappedAllTime => _t('Histórico', 'All time');
  String get shareWrappedButton => _t('Compartir tarjeta', 'Share card');
  String get showEarningsToggle => _t('Mostrar dinero ganado', 'Show work earnings');
  String get wrappedFooter => _t('Generado en local con Trono 👑', 'Made locally with Trono 👑');
  String archetypeTitle(String name) => switch (name) {
    'nomad' => _t('Nómada del Trono', 'Throne Nomad'),
    'officeKing' => _t('Ejecutivo de Porcelana', 'Office Porcelain VIP'),
    'nightOwl' => _t('Búho del Trono', 'Midnight Ruler'),
    'coffeeRocket' => _t('Propulsión a Café', 'Espresso Powered'),
    'swissClock' => _t('Reloj Suizo', 'Swiss Clockwork'),
    _ => _t('Monarca Constante', 'Steady Monarch'),
  };

  // Map filters & clusters
  String get mapFilterAll => _t('Todos', 'All');
  String get mapFilterMonth => _t('Este mes', 'This month');
  String get mapFilterAway => _t('🌍 Fuera', '🌍 Away');
  String get mapFilterWork => _t('💼 Trabajo', '💼 Work');
  String get mapFilterHome => _t('🏠 Casa', '🏠 Home');
  String clusterHeader(int count) => _t('$count tronos en este lugar', '$count thrones at this spot');

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
  String get poopPerDay => _t('Tronos / día', 'Thrones / day');
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

  // V2.2 Monthly Comparison & 8-Week Trend
  String get monthlyComparisonTitle =>
      _t('Este mes vs Mes pasado', 'This month vs Last month');
  String get comparisonEmptyHint => _t(
    'Registra tus tronos para comparar tu evolución mes a mes.',
    'Log your thrones to compare your month-over-month progress.',
  );
  String get comparisonDeltaNew => _t('Nuevo', 'New');
  String get comparisonAwayLabel => _t('% Fuera de casa', '% Away from home');
  String get comparisonBristolLabel => _t('Media Bristol', 'Avg Bristol');
  String get bristolZoneIdeal => _t('Zona ideal', 'Ideal zone');
  String get bristolZoneFirm => _t('Más firme', 'Firmer');
  String get bristolZoneSoft => _t('Más blando', 'Softer');
  String idealBristolPctSub(int pct) =>
      _t('$pct% en zona ideal (3–4)', '$pct% in ideal zone (3–4)');
  String get weeklyTrendTitle =>
      _t('Evolución semanal · 8 semanas', 'Weekly trend · 8 weeks');
  String weeklyAvgPill(double avg) =>
      _t('Media ${avg.toStringAsFixed(1)}/sem', 'Avg ${avg.toStringAsFixed(1)}/wk');
  String get currentWeekBadge => _t('Esta semana', 'This week');
  String weekRangeLabel(String start, String end) =>
      _t('Sem. $start – $end', 'Wk $start – $end');
  String get perDayShort => _t('/día', '/day');
  String get bristolShortLabel => _t('Bristol', 'Bristol');
  String get tapBarInspectHint => _t('Toca una barra', 'Tap a bar');
  String poopUnitFor(int count) =>
      count == 1 ? _t('trono', 'throne') : _t('tronos', 'thrones');
  String poopsCountLabel(int count) => '$count ${poopUnitFor(count)}';

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
    'survival_fittest' => _t('Supervivencia del Más Apto', 'Survival of the Fittest'),
    'throne_nomad' => _t('Nómada del Trono', 'Throne Nomad'),
    'territory_conqueror' => _t('Conquistador', 'Conqueror'),
    'international_drop' => _t('Alcance Internacional', 'Long-Distance Drop'),
    'hat_trick' => _t('Tripleta', 'Hat-Trick'),
    'turbo_day' => _t('Modo Turbo', 'Turbo Day'),
    'streak_7' => _t('Semana de Acero', '7-Day Streak'),
    'streak_30' => _t('Reloj Suizo', 'Swiss Clock'),
    'night_owl' => _t('Búho Nocturno', 'Night Owl'),
    'early_bird' => _t('Madrugador', 'Early Bird'),
    'perfect_four' => _t('El 4 Perfecto', 'The Perfect 4'),
    'false_alarm_pro' => _t('Falsa Alarma Pro', 'False Alarm Pro'),
    'paid_to_poop' => _t('En Horario Laboral', 'Paid to Go'),
    'paid_throne_pro' => _t('Sueldo de Porcelana', 'Porcelain Paycheck'),
    'coffee_effect' => _t('Efecto Cafeína', 'Caffeine Kick'),
    'marathoner' => _t('Maratonista', 'Marathoner'),
    'epic_drop' => _t('Obra Maestra', 'Masterpiece'),
    'detail_scientist' => _t('Científico de Datos', 'Data Scientist'),
    'spicy_survivor' => _t('Sobreviviente Picante', 'Spicy Survivor'),
    'century_club' => _t('Club de los 100', 'Century Club'),
    'poop_veteran' => _t('Veterano del Trono', 'Throne Veteran'),
    _ => id,
  };

  String achievementDesc(String id) => switch (id) {
    'first_visit' => _t('Registra tu primera visita', 'Log your very first visit'),
    'survival_fittest' => _t('5 tronos fuera de casa (superpoder)', '5 thrones away from home (superpower)'),
    'throne_nomad' => _t('15 tronos fuera de casa', '15 thrones away from home'),
    'territory_conqueror' => _t('Marca 5 ubicaciones distintas en el mapa', 'Pin 5 distinct spots on the map'),
    'international_drop' => _t('Un trono a +50 km de tu casa', 'A throne 50+ km away from home'),
    'hat_trick' => _t('3 o más visitas en un solo día', '3+ visits in a single day'),
    'turbo_day' => _t('6 o más visitas en un solo día', '6+ visits in a single day'),
    'streak_7' => _t('Registra 7 días seguidos', 'Log 7 days in a row'),
    'streak_30' => _t('Registra 30 días seguidos', 'Log 30 days in a row'),
    'night_owl' => _t('Una visita entre 00:00 y 05:00', 'A visit between 12am and 5am'),
    'early_bird' => _t('5 visitas entre 05:00 y 08:00', '5 visits between 5am and 8am'),
    'perfect_four' => _t('5 veces Bristol tipo 4 (perfección)', '5 times Bristol type 4 (ideal)'),
    'false_alarm_pro' => _t('5 falsas alarmas registradas', '5 false alarms logged'),
    'paid_to_poop' => _t('5 visitas en el Trabajo', '5 visits at Work'),
    'paid_throne_pro' => _t('Acumula 60 min en el trono en el trabajo', 'Reach 60 min on the throne at work'),
    'coffee_effect' => _t('5 visitas con el tag Café', '5 visits tagged Coffee'),
    'marathoner' => _t('Una sesión de 15+ minutos', 'A 15+ minute session'),
    'epic_drop' => _t('3 registros con tamaño Épico', '3 logs with Epic size'),
    'detail_scientist' => _t('Añade detalles en 15 visitas', 'Add details to 15 visits'),
    'spicy_survivor' => _t('5 registros con el tag Picante', '5 logs tagged Spicy'),
    'century_club' => _t('Alcanza 100 visitas totales', 'Reach 100 total visits'),
    'poop_veteran' => _t('Alcanza 50 tronos registrados', 'Reach 50 thrones logged'),
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
  String get defaultPrivacyLabel => _t('Privacidad por defecto en grupos', 'Default privacy in groups');
  String get accountCloudSection => _t('Cuenta y Nube', 'Account & Cloud');
  String get cloudConnectTitle => _t('Conecta tu Trono en la nube', 'Connect Trono Cloud');
  String get cloudConnectBody => _t(
    'Respalda tu historial automáticamente y únete a grupos privados con tu pareja o amigos. GPS y sueldo siempre se quedan en tu móvil.',
    'Auto-backup your history and join private groups with your partner or friends. Exact GPS & pay rate always stay on your device.',
  );
  String get createAccountBtn => _t('Crear cuenta gratis', 'Create free account');
  String get signInBtn => _t('Iniciar sesión', 'Sign in');
  String get haveAccountSignIn => _t('Ya tengo cuenta · Iniciar sesión', 'I have an account · Sign in');
  String get signOutBtn => _t('Cerrar sesión', 'Sign out');
  String get signOutConfirmBody => _t(
    'Tus registros locales se mantienen intactos en este teléfono.',
    'Your local logs stay safe on this device.',
  );
  String get syncNowBtn => _t('Sincronizar ahora', 'Sync now');
  String get syncingLabel => _t('Sincronizando...', 'Syncing...');
  String get allSyncedLabel => _t('Todo sincronizado en la nube', 'All synced to cloud');
  String pendingSyncLabel(int n) => _t('$n registro(s) pendientes de subir', '$n log(s) pending upload');
  String syncedToast(int pushed, int pulled) => _t(
    'Sincronizado · $pushed subidos, $pulled traídos',
    'Synced · $pushed uploaded, $pulled downloaded',
  );
  String get editProfileTitle => _t('Editar perfil', 'Edit profile');
  String get displayNameLabel => _t('Tu alias', 'Your alias');
  String get displayNameHint => _t('Ej. Jose, Reina del Trono...', 'e.g. Alex, Throne Ruler...');
  String get chooseAvatarLabel => _t('Tu avatar', 'Your avatar');
  String get emailLabel => _t('Correo electrónico', 'Email');
  String get passwordLabel => _t('Contraseña (mín. 6 caracteres)', 'Password (min. 6 chars)');
  String get confirmEmailNotice => _t(
    '¡Cuenta creada! Revisa tu correo para confirmarla y luego inicia sesión.',
    'Account created! Check your email to confirm it, then sign in.',
  );
  String get profileSavedToast => _t('Perfil actualizado', 'Profile updated');

  // Social / Multiplayer tab
  String get socialTitle => _t('Amigos', 'Friends');
  String get socialHeroTitle => _t('Trono con Amigos', 'Trono with Friends');
  String get socialHeroSubtitle => _t(
    'Grupos privados por código, feed en vivo con reacciones y rankings semanales.',
    'Private invite-code groups, live feed with reactions, and weekly leaderboards.',
  );
  String get socialPerkPrivacyTitle => _t('Privacidad real', 'Real privacy');
  String get socialPerkPrivacyBody => _t(
    'Tu GPS exacto y sueldo nunca suben a la nube; tú eliges qué ve cada visita.',
    'Exact GPS & salary never leave your phone; you control each log’s privacy.',
  );
  String get socialPerkSyncTitle => _t('Sync offline-first', 'Offline-first sync');
  String get socialPerkSyncBody => _t(
    'Registra en 1 toque sin internet y sincroniza automáticamente al volver.',
    'Log in 1 tap offline and sync automatically whenever you’re online.',
  );
  String get socialPerkGroupsTitle => _t('Grupos privados de 6 letras', '6-letter private groups');
  String get socialPerkGroupsBody => _t(
    'Ideal para tu pareja, compañeros de piso o grupo de amigos.',
    'Built for your partner, roommates, or close friend group.',
  );
  String get createGroupBtn => _t('Crear grupo', 'Create group');
  String get joinGroupBtn => _t('Unirse con código', 'Join with code');
  String get noGroupsTitle => _t('Crea o únete a tu primer grupo', 'Create or join your first group');
  String get noGroupsBody => _t(
    'Crea un grupo privado en 5 segundos y comparte el código de 6 letras por WhatsApp.',
    'Create a private group in 5 seconds and share the 6-letter invite code.',
  );
  String get groupNameLabel => _t('Nombre del grupo', 'Group name');
  String get groupNameHint => _t('Ej. Casa & Pareja, Los del Trono...', 'e.g. Home Squad, Throne Crew...');
  String get groupEmojiLabel => _t('Icono del grupo', 'Group icon');
  String get inviteCodeLabel => _t('Código de invitación', 'Invite code');
  String get enterInviteCodeHint => _t('Ej. TRN8K2', 'e.g. TRN8K2');
  String get copyCodeBtn => _t('Copiar', 'Copy');
  String get shareCodeBtn => _t('Invitar', 'Invite');
  String get codeCopiedToast => _t('¡Código copiado!', 'Invite code copied!');
  String inviteShareMessage(String groupName, String code) => _t(
    'Únete a mi grupo "$groupName" en Trono 👑🚽\nCódigo de invitación: $code',
    'Join my group "$groupName" on Trono 👑🚽\nInvite code: $code',
  );
  String membersCountLabel(int n) =>
      n == 1 ? _t('1 miembro', '1 member') : _t('$n miembros', '$n members');
  String get leaveGroupBtn => _t('Salir del grupo', 'Leave group');
  String get leaveGroupConfirm => _t(
    '¿Seguro que quieres salir de este grupo? Puedes volver a entrar con el código.',
    'Are you sure you want to leave this group? You can rejoin anytime with the code.',
  );
  String get socialTabFeed => _t('Feed en vivo', 'Live feed');
  String get socialTabRanking => _t('Ranking', 'Leaderboard');
  String get emptyFeedTitle => _t('El trono está tranquilo', 'All quiet on the throne');
  String get emptyFeedBody => _t(
    'Cuando alguien del grupo registre un trono compartido (Solo resumen o Completo), aparecerá aquí al instante.',
    'Whenever someone in the group logs a shared throne (Summary or Full), it appears here live.',
  );
  String get rankingPeriodWeek => _t('7 días', '7 days');
  String get rankingPeriodMonth => _t('30 días', '30 days');
  String get rankingPeriodAll => _t('Histórico', 'All time');
  String get poopsUnit => _t('tronos', 'thrones');
  String awayPctShort(int pct) => _t('$pct% fuera', '$pct% away');
  String get summaryOnlyBadge => _t('Solo resumen', 'Summary only');
  String get youBadge => _t('Tú', 'You');
  String get groupNotFoundError => _t('No existe ningún grupo con ese código', 'No group found with that code');
  String get authGenericError => _t('No se pudo completar. Revisa tus datos o conexión.', 'Could not complete. Check your details or connection.');

  // V2.1 Trono Social+ (Synced Duo, Group Badges, Group Weekly Wrapped)
  String get socialBadgesTitle => _t('Logros de grupo', 'Group awards');
  String syncedDuoPill(String partnerEmoji, String partnerName, int gapMins) =>
      gapMins == 0
          ? _t(
              '¡Dúo Sincronizado con $partnerEmoji $partnerName (a la vez)!',
              'Synced Duo with $partnerEmoji $partnerName (at the same time)!',
            )
          : _t(
              '¡Dúo Sincronizado con $partnerEmoji $partnerName (${gapMins}m)!',
              'Synced Duo with $partnerEmoji $partnerName (${gapMins}m apart)!',
            );

  String socialBadgeTitle(String id) => switch (id) {
    'social_founder' => _t('Fundador', 'Founder'),
    'synced_duo' => _t('Dúo Sincro', 'Synced Duo'),
    'weekly_king' => _t('Rey Semanal', 'Weekly King'),
    'hype_squad' => _t('Fan #1', 'Hype Squad'),
    'crowd_favorite' => _t('Ídolo', 'Fan Favorite'),
    'away_mvp' => _t('MVP Fuera', 'Away MVP'),
    _ => id,
  };

  String socialBadgeDesc(String id) => switch (id) {
    'social_founder' => _t('Crea o únete a tu primer grupo privado', 'Create or join your first private group'),
    'synced_duo' => _t('Coincide con alguien del grupo en menos de 15 min', 'Claim a throne within 15 min of a group mate'),
    'weekly_king' => _t('Sé #1 en el ranking semanal de tu grupo', 'Hold #1 on your group’s 7-day leaderboard'),
    'hype_squad' => _t('Envía 5 reacciones a tronos de tus amigos', 'Send 5 reactions to friends’ thrones'),
    'crowd_favorite' => _t('Recibe 5 reacciones de tus amigos', 'Receive 5 reactions from friends'),
    'away_mvp' => _t('Lidera los tronos fuera de casa esta semana', 'Lead away-from-home thrones this week'),
    _ => '',
  };

  String get groupWrappedButton => _t('Wrapped Semanal', 'Weekly Wrapped');
  String get groupWrappedTitle => _t('Wrapped del Grupo', 'Group Wrapped');
  String get groupWrappedBadge => _t('Resumen Semanal · 7 días', 'Weekly Recap · 7 days');
  String get weeklyKingLabel => _t('Rey de la Semana', 'King of the Week');
  String get groupTotalPoopsLabel => _t('Tronos totales', 'Total thrones');
  String get syncedDuosLabel => _t('Dúos sincro', 'Synced duos');
  String get reactionsLabel => _t('Reacciones', 'Reactions');
  String get podiumTitle => _t('Podio semanal', 'Weekly podium');
  String get awayMvpLabel => _t('MVP Fuera de casa', 'Away MVP');
  String get shareGroupWrappedButton => _t('Compartir resumen del grupo', 'Share group recap');
  String relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return _t('ahora mismo', 'just now');
    if (diff.inMinutes < 60) return _t('hace ${diff.inMinutes}m', '${diff.inMinutes}m ago');
    if (diff.inHours < 24) return _t('hace ${diff.inHours}h', '${diff.inHours}h ago');
    if (diff.inDays < 7) return _t('hace ${diff.inDays}d', '${diff.inDays}d ago');
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m';
  }

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
    'Mantén pulsada tu pantalla de inicio → Widgets → Trono para registrar un trono en 1 toque sin abrir la app.',
    'Long-press your home screen → Widgets → Trono to claim a throne in 1 tap without opening the app.',
  );

  // V2.4 In-App GitHub Releases Update Checker
  String get updatesSection => _t('Actualizaciones', 'App Updates');
  String updateAvailableTitle(String tag) =>
      _t('¡Nueva versión $tag disponible!', 'New version $tag available!');
  String get updateAvailableSub => _t(
    'Actualiza tu APK sin perder datos',
    'Update your APK without losing data',
  );
  String get updateDownloadBtn => _t('Descargar', 'Download');
  String get checkUpdatesLabel => _t('Buscar actualizaciones', 'Check for updates');
  String installedVersionSub(String version) =>
      _t('Versión instalada: v$version', 'Installed version: v$version');
  String get upToDateToast => _t('¡Ya tienes la última versión de Trono!', 'You’re on the latest version of Trono!');
  String get updateCheckFailedToast => _t(
    'No se pudo comprobar ahora (revisa tu conexión)',
    'Could not check right now (check connection)',
  );
  String get updateOpenFailedToast => _t(
    'No se pudo abrir el enlace de descarga',
    'Could not open download link',
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

  // V2.2 Onboarding & Replay Welcome
  String get replayWelcomeLabel => _t(
    'Ver bienvenida de nuevo',
    'Replay welcome',
  );
  String get replayWelcomeSub => _t(
    'Repasa idioma, tu Casa y las opciones iniciales',
    'Revisit language, Home setup & starter options',
  );
  String get onboardingNextBtn => _t('Siguiente', 'Next');
  String get onboardingBackBtn => _t('Atrás', 'Back');

  String get onboardingWelcomeBadge => _t('Bienvenido a Trono', 'Welcome to Trono');
  String get onboardingWelcomeTitle => _t('Tu trono, tus reglas.', 'Your throne, your rules.');
  String get onboardingWelcomePitch => _t(
    'Registra cada trono en 1 toque. Tus datos, tu mapa y tu sueldo se quedan 100% privados en tu teléfono.',
    'Claim every throne in 1 tap. Your history, map & pay rate stay 100% private on your phone.',
  );
  String get onboardingPerkOneTap => _t(
    'Registro instantáneo en 1 toque',
    'Instant 1-tap logging',
  );
  String get onboardingPerkPrivate => _t(
    'Offline-first y privado por diseño',
    'Offline-first & private by design',
  );
  String get onboardingPerkStats => _t(
    'Rangos, logros, mapa y Trono Wrapped',
    'Ranks, awards, map & Trono Wrapped',
  );
  String get onboardingChooseLang => _t('Elige tu idioma', 'Choose your language');

  String get onboardingHomeBadge => _t('Tu Casa y Territorio', 'Your Home & Territory');
  String get onboardingHomeTitle => _t('Conquista el mapa 🏠🌍', 'Conquer the map 🏠🌍');
  String get onboardingHomeBody => _t(
    'Detecta automáticamente tus tronos en Casa vs Fuera y desbloquea tu mapa de territorio.',
    'Auto-detect Home vs Away thrones and build your personal territory map.',
  );
  String get onboardingHomeSavedBtn => _t(
    'Casa guardada · Actualizar',
    'Home saved · Update',
  );
  String get onboardingGpsPrivacyNote => _t(
    'Tus coordenadas GPS exactas se guardan 100% en local en tu dispositivo y nunca salen a la nube.',
    'Your exact GPS coordinates stay 100% local on your device and are never uploaded to the cloud.',
  );

  String get onboardingSocialBadge => _t('Solo o con Amigos', 'Solo or with Friends');
  String get onboardingSocialTitle => _t('Tú eliges cómo usarlo 👥', 'Choose how you play 👥');
  String get onboardingSocialBody => _t(
    'Úsalo 100% offline y local, o crea una cuenta gratis para competir en grupos privados con tu pareja o amigos.',
    'Use Trono 100% locally offline, or create a free account to compete in private groups with your partner or friends.',
  );
  String get onboardingCreateOrJoinBtn => _t(
    'Crear cuenta / Unirme a un grupo',
    'Create account / Join a group',
  );
  String get onboardingStartLocalBtn => _t(
    'Empezar en local (sin cuenta)',
    'Start locally (no account)',
  );
  String get onboardingAlreadySignedInBtn => _t(
    '¡Entrar a Trono!',
    'Enter Trono!',
  );
  String get onboardingSocialNote => _t(
    'Siempre podrás conectar o quitar tu cuenta más tarde desde Ajustes.',
    'You can always connect or remove your account later in Settings.',
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
