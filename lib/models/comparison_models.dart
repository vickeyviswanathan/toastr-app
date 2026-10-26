import 'package:flutter/material.dart';
import '../theme/toastr_theme.dart';

enum VerticalType { food, grocery }

class PlatformInfo {
  final String id;
  final String name;
  final VerticalType vertical;
  final String logoUrl;
  final String baseUrl;
  final String loginUrl;
  final Color brandColor;
  bool isConnected;
  String? cookieHeader;
  Map<String, String> localStorageData;
  DateTime? lastSyncedAt;

  PlatformInfo({
    required this.id,
    required this.name,
    required this.vertical,
    required this.logoUrl,
    required this.baseUrl,
    required this.loginUrl,
    required this.brandColor,
    this.isConnected = false,
    this.cookieHeader,
    Map<String, String>? localStorageData,
    this.lastSyncedAt,
  }) : localStorageData = localStorageData ?? {};

  static List<PlatformInfo> defaultPlatforms() => [
        // Food Delivery Platforms
        PlatformInfo(
          id: 'swiggy',
          name: 'Swiggy',
          vertical: VerticalType.food,
          logoUrl:
              'https://nkeyeblpesmfsvwugxxh.supabase.co/storage/v1/object/public/provider_logos/swiggy.png',
          baseUrl: 'https://www.swiggy.com',
          loginUrl: 'https://www.swiggy.com/auth',
          brandColor: ToastrTheme.swiggyOrange,
        ),
        PlatformInfo(
          id: 'zomato',
          name: 'Zomato',
          vertical: VerticalType.food,
          logoUrl:
              'https://nkeyeblpesmfsvwugxxh.supabase.co/storage/v1/object/public/provider_logos/zomato.png',
          baseUrl: 'https://www.zomato.com',
          loginUrl: 'https://www.zomato.com/',
          brandColor: ToastrTheme.zomatoRed,
        ),
        // Quick-Commerce Grocery Platforms
        PlatformInfo(
          id: 'blinkit',
          name: 'Blinkit',
          vertical: VerticalType.grocery,
          logoUrl:
              'https://nkeyeblpesmfsvwugxxh.supabase.co/storage/v1/object/public/provider_logos/blinkit.png',
          baseUrl: 'https://blinkit.com',
          loginUrl: 'https://blinkit.com/',
          brandColor: ToastrTheme.blinkitYellow,
        ),
        PlatformInfo(
          id: 'zepto',
          name: 'Zepto',
          vertical: VerticalType.grocery,
          logoUrl:
              'https://nkeyeblpesmfsvwugxxh.supabase.co/storage/v1/object/public/provider_logos/zepto.png',
          baseUrl: 'https://www.zeptonow.com',
          loginUrl: 'https://www.zeptonow.com/',
          brandColor: ToastrTheme.zeptoPurple,
        ),
        PlatformInfo(
          id: 'instamart',
          name: 'Instamart',
          vertical: VerticalType.grocery,
          logoUrl:
              'https://nkeyeblpesmfsvwugxxh.supabase.co/storage/v1/object/public/provider_logos/instamart.png',
          baseUrl: 'https://www.swiggy.com/instamart',
          loginUrl: 'https://www.swiggy.com/instamart',
          brandColor: ToastrTheme.instamartPink,
        ),
        PlatformInfo(
          id: 'bigbasket',
          name: 'BigBasket',
          vertical: VerticalType.grocery,
          logoUrl:
              'https://nkeyeblpesmfsvwugxxh.supabase.co/storage/v1/object/public/provider_logos/bigbasket.png',
          baseUrl: 'https://www.bigbasket.com',
          loginUrl: 'https://www.bigbasket.com/',
          brandColor: ToastrTheme.bigbasketGreen,
        ),
      ];
}

class UserLocation {
  final double latitude;
  final double longitude;
  final String addressLabel;
  final String pincode;
  final String city;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.addressLabel,
    required this.pincode,
    required this.city,
  });

  // Default fallback: Bengaluru (Koramangala) until GPS or search updates it
  static const UserLocation defaultLocation = UserLocation(
    latitude: 12.9352,
    longitude: 77.6245,
    addressLabel: 'Koramangala, Bengaluru',
    pincode: '560034',
    city: 'bangalore',
  );
}

class PlatformPriceQuote {
  final String platformId;
  final String platformName;
  final double itemPrice;
  final double originalMrp;
  final double packagingFee;
  final double deliveryFee;
  final double platformFee;
  final double gstAndTaxes;
  final double discountAmount;
  final String? couponCode;
  final int etaMinutes;
  final bool inStock;
  final String? deepLinkUrl;
  final String? storeOrRestaurantId;

  const PlatformPriceQuote({
    required this.platformId,
    required this.platformName,
    required this.itemPrice,
    this.originalMrp = 0,
    this.packagingFee = 0,
    this.deliveryFee = 0,
    this.platformFee = 0,
    this.gstAndTaxes = 0,
    this.discountAmount = 0,
    this.couponCode,
    this.etaMinutes = 25,
    this.inStock = true,
    this.deepLinkUrl,
    this.storeOrRestaurantId,
  });

  double get finalPayable =>
      (itemPrice + packagingFee + deliveryFee + platformFee + gstAndTaxes - discountAmount)
          .clamp(0, double.infinity);
}

class ComparedRestaurant {
  final String id;
  final String name;
  final String cuisineSummary;
  final String imageUrl;
  final double rating;
  final String distanceKm;
  final Map<String, PlatformPriceQuote> platformQuotes; // 'swiggy' | 'zomato'
  final List<ComparedMenuItem> menuItems;

  const ComparedRestaurant({
    required this.id,
    required this.name,
    required this.cuisineSummary,
    required this.imageUrl,
    required this.rating,
    required this.distanceKm,
    required this.platformQuotes,
    this.menuItems = const [],
  });

  String? get cheapestPlatformId {
    if (platformQuotes.isEmpty) return null;
    final entries = platformQuotes.entries.toList()
      ..sort((a, b) => a.value.finalPayable.compareTo(b.value.finalPayable));
    return entries.first.key;
  }

  double get maxSavings {
    if (platformQuotes.length < 2) return 0;
    final totals = platformQuotes.values.map((q) => q.finalPayable).toList()
      ..sort();
    return totals.last - totals.first;
  }
}

class ComparedMenuItem {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final bool isVeg;
  final Map<String, double> platformPrices; // {'swiggy': 249.0, 'zomato': 279.0}

  const ComparedMenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.isVeg,
    required this.platformPrices,
  });

  double get cheapestPrice {
    if (platformPrices.isEmpty) return 0;
    return platformPrices.values.reduce((a, b) => a < b ? a : b);
  }

  double get priceDifference {
    if (platformPrices.length < 2) return 0;
    final vals = platformPrices.values.toList()..sort();
    return vals.last - vals.first;
  }
}

class ComparedGroceryProduct {
  final String id;
  final String name;
  final String brand;
  final String quantityUnit; // e.g., "500 g", "1 L"
  final String imageUrl;
  final Map<String, PlatformPriceQuote> quotes; // 'blinkit', 'zepto', 'instamart', 'bigbasket'

  const ComparedGroceryProduct({
    required this.id,
    required this.name,
    required this.brand,
    required this.quantityUnit,
    required this.imageUrl,
    required this.quotes,
  });

  PlatformPriceQuote? get bestQuote {
    final available = quotes.values.where((q) => q.inStock).toList();
    if (available.isEmpty) return null;
    available.sort((a, b) => a.itemPrice.compareTo(b.itemPrice));
    return available.first;
  }

  double get savingsSpread {
    final available = quotes.values.where((q) => q.inStock).map((q) => q.itemPrice).toList();
    if (available.length < 2) return 0;
    available.sort();
    return available.last - available.first;
  }
}

class CartEntry {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final VerticalType vertical;
  final Map<String, double> unitPricesByPlatform;
  int quantity;

  CartEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.vertical,
    required this.unitPricesByPlatform,
    this.quantity = 1,
  });
}
