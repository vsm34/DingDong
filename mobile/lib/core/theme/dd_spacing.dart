/// DingDong spacing system — 4pt base unit
/// Per PRD Section 5.5
abstract final class DDSpacing {
  // ── Named spacing tokens ───────────────────────────────────────────────────
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // ── Padding shorthands ────────────────────────────────────────────────────
  /// Screen horizontal padding (xl = 32px)
  static const double pagePadding = 32.0;
  /// Card internal padding (md = 16px)
  static const double cardPadding = 16.0;
  /// List tile horizontal padding
  static const double listTilePaddingH = 16.0;
  /// List tile vertical padding
  static const double listTilePaddingV = 12.0;

  // ── Component sizes ───────────────────────────────────────────────────────
  static const double buttonHeight = 52.0;
  static const double bottomNavHeight = 64.0;
  static const double appBarHeight = 56.0;
  static const double iconSize = 24.0;
  static const double iconSizeSm = 20.0;
  static const double iconSizeLg = 32.0;
  static const double avatarSize = 40.0;

  // ── Border radius ─────────────────────────────────────────────────────────
  /// 6px — chips, badges, small buttons
  static const double radiusSm = 6.0;
  /// 8px — cards, input fields, event rows
  static const double radiusMd = 8.0;
  /// 12px — bottom sheets, modals, large cards
  static const double radiusLg = 12.0;
  /// 16px — screen-level rounded corners (bottom nav)
  static const double radiusXl = 16.0;
  /// 9999px — pills, status indicators
  static const double radiusFull = 9999.0;
}
