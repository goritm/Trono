/// Centralized seasonal / rollout toggles for Trono.
class FeatureFlags {
  /// Spotify-style seasonal Wrapped gate.
  /// Keeps Personal & Group Wrapped screens and engines intact in the codebase
  /// while hiding their UI entry points outside Wrapped season.
  static const bool showWrapped = false;
}
