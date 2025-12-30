import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const MaterialColor primarySwatch = MaterialColor(
    0xFF3b82f6, // fallback blue
    <int, Color>{
      50: Color(0xFFEFF6FF),
      100: Color(0xFFDBEAFE),
      200: Color(0xFFBFDBFE),
      300: Color(0xFF93C5FD),
      400: Color(0xFF60A5FA),
      500: Color(0xFF3b82f6),
      600: Color(0xFF2563EB),
      700: Color(0xFF1D4ED8),
      800: Color(0xFF1E40AF),
      900: Color(0xFF1E3A8A),
    },
  );

  static final ThemeData light = ThemeData(
    primarySwatch: primarySwatch,
    scaffoldBackgroundColor: Colors.white,
    // Color tokens (approximate values from the React design)
    colorScheme: ColorScheme.fromSwatch(primarySwatch: primarySwatch).copyWith(
      secondary: const Color(0xFF6B7280), // gray-500
      surface: const Color(
          0xFFF9FAFB), // use surface instead of background (deprecation guidance)
      // surface: Colors.white, // overridden above
    ),
    useMaterial3: true,
    textTheme: GoogleFonts.interTextTheme().copyWith(
      headlineLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF0F172A)),
      headlineMedium: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF0F172A)),
      bodyLarge:
          GoogleFonts.inter(fontSize: 16, color: const Color(0xFF374151)),
    ),
    // Global component theming for closer parity
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12))),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );

  // Semantic colors for receipts and payments
  static const Color receiptColor = Color(0xFF10B981); // emerald
  static const Color paymentColor = Color(0xFFEF4444); // red

  // Simple currency formatter used across widgets (small helper for parity)
  static String formatCurrency(double amount, {String currency = 'INR'}) {
    final symbol = _getCurrencySymbol(currency);
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  // Currency symbol helper
  static String _getCurrencySymbol(String currencyCode) {
    const currencySymbols = {
      'INR': '₹',
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
      'AUD': 'A\$',
      'CAD': 'C\$',
      'CHF': 'CHF',
      'CNY': '¥',
      'SEK': 'kr',
      'NZD': 'NZ\$',
      'SGD': 'S\$',
      'HKD': 'HK\$',
      'NOK': 'kr',
      'KRW': '₩',
      'TRY': '₺',
      'RUB': '₽',
      'BRL': 'R\$',
      'ZAR': 'R',
      'MXN': 'Mex\$',
      'AED': 'AED',
      'SAR': 'SAR',
      'THB': '฿',
      'MYR': 'RM',
      'IDR': 'Rp',
      'PHP': '₱',
      'PKR': 'Rs',
      'BDT': '৳',
      'LKR': 'Rs',
      'NPR': 'Rs',
    };
    return currencySymbols[currencyCode] ?? currencyCode;
  }

  // Primary gradient used in the index hero and other accents
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF3b82f6), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 1.0],
  );

  // A few HSL-like semantic color tokens (approximate)
  static const Color neutral100 = Color(0xFFF3F4F6);
  static const Color neutral200 = Color(0xFFE5E7EB);
  static const Color neutral500 = Color(0xFF6B7280);
  static const Color accent900 = Color(0xFF1D4ED8);
}
