# Reused Customer design system

Existing tokens: emerald #0F9D7A, dark green #087A60, soft mint #DDF5EE, mint #B9EFE3, background #F7FBF9, ink #0F172A, muted #667085, border #DDE7E4. `AppTheme`, `HomeColors`, `Panel`, `PrimaryButton`, `EmptyState`, `HomeSurface`, robot and bottom navigation were reused.

Home keeps its mint hero, location selector, search, pastel service tiles and server-derived recommendations. ServiceGrid accepts real catalogue entries. No hardcoded partner ratings or reward balances are injected into authenticated Customer home.

Booking uses native forms, choice dropdowns, integer keyboards, date/time pickers, step progress, address cards and a review summary. Content is scrollable under SafeArea and constrained to 640dp. No WebView or copied HTML/JS appears in lib/. Existing bitmap assets were reused; no new generated assets were needed.

Favorite cards now have enough carousel height for their existing avatar/text/button content. Tests cover Home at 360/390/430dp and enlarged text, plus new booking at 360dp. Pixel-identical rendering of all V3 routes has not been verified.
