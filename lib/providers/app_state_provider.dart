import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/comparison_models.dart';
import '../services/on_device_scraper_service.dart';

class AppStateProvider extends ChangeNotifier {
  final OnDeviceScraperService _scraper = OnDeviceScraperService();

  VerticalType _activeVertical = VerticalType.food;
  UserLocation _currentLocation = UserLocation.defaultLocation;
  bool _isLoadingLocation = false;
  bool _isSearching = false;
  String _lastSearchQuery = '';
  String? _statusMessage;

  final Map<String, PlatformInfo> _platforms = {
    for (final p in PlatformInfo.defaultPlatforms()) p.id: p,
  };

  List<ComparedRestaurant> _restaurants = [];
  List<ComparedGroceryProduct> _groceryProducts = [];
  final Map<String, CartEntry> _cart = {};

  VerticalType get activeVertical => _activeVertical;
  UserLocation get currentLocation => _currentLocation;
  bool get isLoadingLocation => _isLoadingLocation;
  bool get isSearching => _isSearching;
  String get lastSearchQuery => _lastSearchQuery;
  String? get statusMessage => _statusMessage;
  Map<String, PlatformInfo> get platforms => _platforms;
  List<ComparedRestaurant> get restaurants => _restaurants;
  List<ComparedGroceryProduct> get groceryProducts => _groceryProducts;
  List<CartEntry> get cartEntries => _cart.values
      .where((c) => c.vertical == _activeVertical)
      .toList();

  int get totalCartItems => cartEntries.fold(0, (sum, e) => sum + e.quantity);

  Future<void> initialize() async {
    await _restoreSavedSessionsAndLocation();
    await detectGpsLocation(silent: true);
  }

  void setVertical(VerticalType vertical) {
    if (_activeVertical == vertical) return;
    _activeVertical = vertical;
    notifyListeners();
  }

  Future<void> _restoreSavedSessionsAndLocation() async {
    final prefs = await SharedPreferences.getInstance();
    for (final p in _platforms.values) {
      final savedCookie = prefs.getString('cookies_${p.id}');
      final connected = prefs.getBool('connected_${p.id}') ?? false;
      final syncedAtRaw = prefs.getString('synced_at_${p.id}');
      p.cookieHeader = savedCookie;
      p.isConnected = connected && (savedCookie?.isNotEmpty ?? false);
      if (syncedAtRaw != null) {
        p.lastSyncedAt = DateTime.tryParse(syncedAtRaw);
      }
    }

    final savedLat = prefs.getDouble('user_lat');
    final savedLng = prefs.getDouble('user_lng');
    final savedLabel = prefs.getString('user_label');
    final savedPincode = prefs.getString('user_pincode');
    final savedCity = prefs.getString('user_city');

    if (savedLat != null && savedLng != null && savedLabel != null) {
      _currentLocation = UserLocation(
        latitude: savedLat,
        longitude: savedLng,
        addressLabel: savedLabel,
        pincode: savedPincode ?? '560001',
        city: savedCity ?? 'bangalore',
      );
    }
    notifyListeners();
  }

  Future<void> updateManualLocation(UserLocation loc) async {
    _currentLocation = loc;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('user_lat', loc.latitude);
    await prefs.setDouble('user_lng', loc.longitude);
    await prefs.setString('user_label', loc.addressLabel);
    await prefs.setString('user_pincode', loc.pincode);
    await prefs.setString('user_city', loc.city);
    notifyListeners();
  }

  Future<void> detectGpsLocation({bool silent = false}) async {
    _isLoadingLocation = true;
    notifyListeners();

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent) _statusMessage = 'Location services are disabled.';
        _isLoadingLocation = false;
        notifyListeners();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!silent) _statusMessage = 'Location permission denied.';
        _isLoadingLocation = false;
        notifyListeners();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      String label = '${pos.latitude.toStringAsFixed(3)}, ${pos.longitude.toStringAsFixed(3)}';
      String pincode = '560001';
      String city = 'bangalore';

      try {
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final pm = placemarks.first;
          final subLoc = pm.subLocality?.isNotEmpty == true ? '${pm.subLocality}, ' : '';
          final locName = pm.locality ?? pm.administrativeArea ?? 'India';
          label = '$subLoc$locName';
          pincode = pm.postalCode ?? pincode;
          city = (pm.locality ?? 'bangalore').toLowerCase().replaceAll(' ', '-');
        }
      } catch (_) {}

      await updateManualLocation(
        UserLocation(
          latitude: pos.latitude,
          longitude: pos.longitude,
          addressLabel: label,
          pincode: pincode,
          city: city,
        ),
      );
    } catch (e) {
      debugPrint('[AppStateProvider] GPS error: $e');
    } finally {
      _isLoadingLocation = false;
      notifyListeners();
    }
  }

  Future<void> markPlatformSynced({
    required String platformId,
    required String cookieHeader,
    Map<String, String>? localStorageData,
  }) async {
    final p = _platforms[platformId];
    if (p == null) return;
    p.cookieHeader = cookieHeader;
    p.isConnected = cookieHeader.isNotEmpty;
    p.lastSyncedAt = DateTime.now();
    if (localStorageData != null) {
      p.localStorageData = localStorageData;
    }
    notifyListeners();
  }

  Future<void> disconnectPlatform(String platformId) async {
    final p = _platforms[platformId];
    if (p == null) return;
    p.cookieHeader = null;
    p.isConnected = false;
    p.lastSyncedAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cookies_$platformId');
    await prefs.setBool('connected_$platformId', false);
    notifyListeners();
  }

  Future<void> performLiveSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    _lastSearchQuery = trimmed;
    _isSearching = true;
    _statusMessage = _activeVertical == VerticalType.food
        ? 'Querying Swiggy & Zomato live from your device...'
        : 'Querying Blinkit, Zepto, Instamart & BigBasket live...';
    notifyListeners();

    try {
      if (_activeVertical == VerticalType.food) {
        _restaurants = await _scraper.searchAndCompareRestaurants(
          query: trimmed,
          location: _currentLocation,
          platforms: _platforms,
        );
        _statusMessage = _restaurants.isEmpty
            ? 'No live restaurants matched "$trimmed". Try linking your Swiggy/Zomato session or searching another dish/restaurant.'
            : null;
      } else {
        _groceryProducts = await _scraper.searchAndCompareGroceries(
          query: trimmed,
          location: _currentLocation,
          platforms: _platforms,
        );
        _statusMessage = _groceryProducts.isEmpty
            ? 'No live grocery items matched "$trimmed". Try linking your Blinkit/Zepto session or searching another product.'
            : null;
      }
    } catch (e) {
      _statusMessage = 'Live query encountered an error: $e';
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<List<ComparedMenuItem>> fetchRestaurantMenu(ComparedRestaurant restaurant) {
    return _scraper.fetchLiveRestaurantMenu(
      restaurant: restaurant,
      loc: _currentLocation,
      platforms: _platforms,
    );
  }

  void addToCart({
    required String id,
    required String title,
    required String subtitle,
    required String imageUrl,
    required Map<String, double> unitPricesByPlatform,
  }) {
    if (_cart.containsKey(id)) {
      _cart[id]!.quantity += 1;
    } else {
      _cart[id] = CartEntry(
        id: id,
        title: title,
        subtitle: subtitle,
        imageUrl: imageUrl,
        vertical: _activeVertical,
        unitPricesByPlatform: unitPricesByPlatform,
      );
    }
    notifyListeners();
  }

  void decrementCartItem(String id) {
    if (!_cart.containsKey(id)) return;
    if (_cart[id]!.quantity > 1) {
      _cart[id]!.quantity -= 1;
    } else {
      _cart.remove(id);
    }
    notifyListeners();
  }

  void clearCart() {
    _cart.removeWhere((_, v) => v.vertical == _activeVertical);
    notifyListeners();
  }

  /// Calculates full multi-platform cart breakdown (Items + Packaging + Delivery + Platform Fee + GST)
  Map<String, PlatformPriceQuote> calculateCartComparison() {
    final entries = cartEntries;
    if (entries.isEmpty) return {};

    final relevantPlatforms = _platforms.values
        .where((p) => p.vertical == _activeVertical)
        .toList();

    final Map<String, PlatformPriceQuote> comparison = {};

    for (final platform in relevantPlatforms) {
      double subtotal = 0;
      bool hasAllItems = true;

      for (final item in entries) {
        final unitPrice = item.unitPricesByPlatform[platform.id];
        if (unitPrice != null && unitPrice > 0) {
          subtotal += unitPrice * item.quantity;
        } else {
          hasAllItems = false;
        }
      }

      if (subtotal > 0) {
        final isFood = _activeVertical == VerticalType.food;
        final delivery = subtotal >= 499 ? 0.0 : (isFood ? 35.0 : 25.0);
        final packaging = isFood ? 20.0 : 6.0;
        final platformFee = isFood ? 6.0 : 4.0;
        final gst = isFood ? (subtotal * 0.05).roundToDouble() : 0.0;

        comparison[platform.id] = PlatformPriceQuote(
          platformId: platform.id,
          platformName: platform.name,
          itemPrice: subtotal,
          packagingFee: packaging,
          deliveryFee: delivery,
          platformFee: platformFee,
          gstAndTaxes: gst,
          inStock: hasAllItems,
          etaMinutes: isFood ? 28 : 12,
          deepLinkUrl: platform.baseUrl,
        );
      }
    }

    return comparison;
  }
}
