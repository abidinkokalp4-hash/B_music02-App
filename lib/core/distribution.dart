/// Which channel this build is for, set at build time:
/// `flutter build appbundle --dart-define=BMUSIC_STORE=play` for Google Play,
/// nothing (default `github`) for the signed APK on GitHub releases.
///
/// Play builds never update themselves (Play policy: apps installed from Play
/// may only be updated through Play) and share the Play Store link instead of
/// the APK link. The Play manifest also drops REQUEST_INSTALL_PACKAGES
/// (tool/configure_android.py with BMUSIC_STORE=play).
const String kDistribution =
    String.fromEnvironment('BMUSIC_STORE', defaultValue: 'github');
const bool kPlayBuild = kDistribution == 'play';
