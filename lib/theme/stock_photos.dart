/// Curated Unsplash photo URLs used as decorative imagery around the app.
/// Every use goes through [NetworkPhoto], which falls back to a plain
/// gradient if a URL ever stops resolving.
class StockPhotos {
  StockPhotos._();

  static const runningGroup =
      'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?auto=format&fit=crop&w=1200&q=80';
  static const cycling =
      'https://images.unsplash.com/photo-1541625602330-2277a4c46182?auto=format&fit=crop&w=1200&q=80';
  static const teamHighFive =
      'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?auto=format&fit=crop&w=1200&q=80';
  static const swimming =
      'https://images.unsplash.com/photo-1530549387789-4c1017266635?auto=format&fit=crop&w=1200&q=80';
  static const hiking =
      'https://images.unsplash.com/photo-1551632811-561732d1e306?auto=format&fit=crop&w=1200&q=80';
}
