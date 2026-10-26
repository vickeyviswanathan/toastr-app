import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/comparison_models.dart';
import 'webview_session_helper.dart';

/// 100% On-Device Real-Time Scraper & Parser for Food & Quick-Commerce Platforms.
/// Replaces Toastr's remote AWS Lambda + S3 backend with direct on-device execution:
/// 1. Direct Dio HTTP request with mobile User-Agent + user's linked session cookies.
/// 2. Automatic fallback to `HeadlessInAppWebView` same-origin fetch when WAF/Cloudflare challenges occur.
/// 3. Fuzzy entity matching across Swiggy + Zomato (Food) and Blinkit + Zepto + Instamart + BigBasket (Grocery).
class OnDeviceScraperService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': WebViewSessionHelper.mobileUserAgent,
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'en-IN,en-GB;q=0.9,en-US;q=0.8,en;q=0.7',
      },
    ),
  );

  // ===========================================================================
  // 1. LIVE RESTAURANT SEARCH & COMPARISON (SWIGGY + ZOMATO)
  // ===========================================================================

  Future<List<ComparedRestaurant>> searchAndCompareRestaurants({
    required String query,
    required UserLocation location,
    required Map<String, PlatformInfo> platforms,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    // Fetch Swiggy and Zomato concurrently from the user's device IP
    final results = await Future.wait([
      _searchSwiggyRestaurants(trimmed, location, platforms['swiggy']),
      _searchZomatoRestaurants(trimmed, location, platforms['zomato']),
    ]);

    final swiggyList = results[0];
    final zomatoList = results[1];

    return _mergeRestaurantsAcrossPlatforms(swiggyList, zomatoList);
  }

  /// Queries Swiggy's live `/dapi/restaurants/search/v3` endpoint using user's GPS coordinates
  Future<List<_RawRestaurantHit>> _searchSwiggyRestaurants(
    String query,
    UserLocation loc,
    PlatformInfo? swiggy,
  ) async {
    final encoded = Uri.encodeQueryComponent(query);
    final apiUrl =
        'https://www.swiggy.com/dapi/restaurants/search/v3?lat=${loc.latitude}&lng=${loc.longitude}&str=$encoded&trackingId=undefined&submitAction=ENTER&queryUniqueId=${DateTime.now().millisecondsSinceEpoch}';

    dynamic data;
    try {
      final resp = await _dio.get(
        apiUrl,
        options: Options(
          headers: {
            'Referer': 'https://www.swiggy.com/search?query=$encoded',
            if (swiggy?.cookieHeader != null && swiggy!.cookieHeader!.isNotEmpty)
              'Cookie': swiggy.cookieHeader!,
          },
        ),
      );
      data = resp.data;
    } catch (e) {
      debugPrint('[OnDeviceScraper] Direct Swiggy Dio call blocked/failed ($e), using HeadlessWebView...');
      data = await WebViewSessionHelper.fetchJsonInHeadlessWebView(
        originUrl: 'https://www.swiggy.com',
        targetApiUrl: apiUrl,
      );
    }

    return _parseSwiggySearchJson(data);
  }

  List<_RawRestaurantHit> _parseSwiggySearchJson(dynamic data) {
    final List<_RawRestaurantHit> hits = [];
    if (data is! Map) return hits;

    try {
      final cards = data['data']?['cards'];
      if (cards is! List) return hits;

      for (final cardGroup in cards) {
        final groupedCards =
            cardGroup?['groupedCard']?['cardGroupMap']?['RESTAURANT']?['cards'] ??
                cardGroup?['groupedCard']?['cardGroupMap']?['DISH']?['cards'];
        if (groupedCards is List) {
          for (final c in groupedCards) {
            final info = c?['card']?['card']?['info'] ??
                c?['card']?['card']?['restaurant']?['info'];
            if (info is Map) {
              final id = info['id']?.toString() ?? '';
              final name = info['name']?.toString() ?? '';
              if (id.isEmpty || name.isEmpty) continue;

              final costForTwoStr = info['costForTwoMessage']?.toString() ??
                  info['costForTwo']?.toString() ??
                  '300';
              final parsedCost = _extractNumber(costForTwoStr, fallback: 300) / 2;
              final rating = double.tryParse(info['avgRating']?.toString() ?? '4.2') ?? 4.2;
              final sla = info['sla'];
              final eta = int.tryParse(sla?['deliveryTime']?.toString() ?? '30') ?? 30;
              final distance = sla?['lastMileTravelString']?.toString() ?? '2.5 km';
              final cloudinaryId = info['cloudinaryImageId']?.toString() ?? '';
              final imageUrl = cloudinaryId.isNotEmpty
                  ? 'https://media-assets.swiggy.com/swiggy/image/upload/fl_lossy,f_auto,q_auto,w_508,h_320,c_fill/$cloudinaryId'
                  : '';
              final cuisines = (info['cuisines'] is List)
                  ? (info['cuisines'] as List).join(', ')
                  : 'Multi-Cuisine';

              // Check aggregated discount header if present
              final discountHeader =
                  info['aggregatedDiscountInfoV3']?['header']?.toString() ?? '';
              final discountSub =
                  info['aggregatedDiscountInfoV3']?['subHeader']?.toString() ?? '';
              final couponText = '$discountHeader $discountSub'.trim();
              final estDiscount = couponText.contains('%') ? (parsedCost * 0.15).roundToDouble() : 0.0;

              hits.add(
                _RawRestaurantHit(
                  platformId: 'swiggy',
                  restaurantId: id,
                  name: name,
                  cuisines: cuisines,
                  imageUrl: imageUrl,
                  rating: rating,
                  distanceKm: distance,
                  etaMinutes: eta,
                  basePriceEstimate: parsedCost,
                  deliveryFee: 35,
                  packagingFee: 20,
                  platformFee: 6,
                  gstAndTaxes: (parsedCost * 0.05).roundToDouble(),
                  discountAmount: estDiscount,
                  couponCode: couponText.isNotEmpty ? couponText : null,
                  deepLink: 'https://www.swiggy.com/restaurants/${name.toLowerCase().replaceAll(' ', '-')}-$id',
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[OnDeviceScraper] Swiggy parse error: $e');
    }
    return hits;
  }

  /// Queries Zomato's web search API / page payload for the same query and location
  Future<List<_RawRestaurantHit>> _searchZomatoRestaurants(
    String query,
    UserLocation loc,
    PlatformInfo? zomato,
  ) async {
    final encoded = Uri.encodeQueryComponent(query);
    final apiUrl =
        'https://www.zomato.com/webroutes/search/home?q=$encoded&lat=${loc.latitude}&lon=${loc.longitude}';

    dynamic data;
    try {
      final resp = await _dio.get(
        apiUrl,
        options: Options(
          headers: {
            'Referer': 'https://www.zomato.com/${loc.city}',
            if (zomato?.cookieHeader != null && zomato!.cookieHeader!.isNotEmpty)
              'Cookie': zomato.cookieHeader!,
          },
        ),
      );
      data = resp.data;
    } catch (_) {
      data = await WebViewSessionHelper.fetchJsonInHeadlessWebView(
        originUrl: 'https://www.zomato.com/${loc.city}',
        targetApiUrl: apiUrl,
      );
    }

    return _parseZomatoSearchJson(data, loc);
  }

  List<_RawRestaurantHit> _parseZomatoSearchJson(dynamic data, UserLocation loc) {
    final List<_RawRestaurantHit> hits = [];
    if (data is! Map) return hits;

    try {
      final sections = data['sections']?['SECTION_SEARCH_RESULT'] ??
          data['results'] ??
          data['entities'];
      if (sections is List) {
        for (final item in sections) {
          final info = item?['info'] ?? item;
          if (info is Map) {
            final id = info['resId']?.toString() ?? info['id']?.toString() ?? '';
            final name = info['name']?.toString() ?? '';
            if (name.isEmpty) continue;

            final cftText = info['cft']?['text']?.toString() ??
                info['costText']?['text']?.toString() ??
                '320';
            final parsedCost = _extractNumber(cftText, fallback: 320) / 2;
            final rating = double.tryParse(
                    info['rating']?['aggregate_rating']?.toString() ?? '4.1') ??
                4.1;
            final orderInfo = item?['order'];
            final etaStr = orderInfo?['deliveryTime']?.toString() ?? '32 min';
            final eta = _extractNumber(etaStr, fallback: 32).toInt();
            final imageUrl = info['image']?['url']?.toString() ??
                info['thumb']?.toString() ??
                '';
            final cuisineList = info['cuisine'];
            final cuisines = (cuisineList is List)
                ? cuisineList.map((c) => c['name'] ?? '').where((s) => s.toString().isNotEmpty).join(', ')
                : 'Restaurant';

            hits.add(
              _RawRestaurantHit(
                platformId: 'zomato',
                restaurantId: id.isEmpty ? name.hashCode.toString() : id,
                name: name,
                cuisines: cuisines,
                imageUrl: imageUrl,
                rating: rating,
                distanceKm: item?['distance']?.toString() ?? '2.8 km',
                etaMinutes: eta,
                basePriceEstimate: parsedCost,
                deliveryFee: 40,
                packagingFee: 25,
                platformFee: 7,
                gstAndTaxes: (parsedCost * 0.05).roundToDouble(),
                discountAmount: 0,
                deepLink: item?['actionInfo']?['clickUrl'] != null
                    ? 'https://www.zomato.com${item['actionInfo']['clickUrl']}'
                    : 'https://www.zomato.com/${loc.city}',
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[OnDeviceScraper] Zomato parse error: $e');
    }
    return hits;
  }

  /// Fetches live restaurant menu from Swiggy `/dapi/menu/pl` for deep item-level comparison
  Future<List<ComparedMenuItem>> fetchLiveRestaurantMenu({
    required ComparedRestaurant restaurant,
    required UserLocation loc,
    required Map<String, PlatformInfo> platforms,
  }) async {
    final swiggyQuote = restaurant.platformQuotes['swiggy'];
    final restId = swiggyQuote?.storeOrRestaurantId ?? restaurant.id;
    final apiUrl =
        'https://www.swiggy.com/dapi/menu/pl?page-type=REGULAR_MENU&complete-menu=true&lat=${loc.latitude}&lng=${loc.longitude}&restaurantId=$restId';

    dynamic data;
    try {
      final swiggy = platforms['swiggy'];
      final resp = await _dio.get(
        apiUrl,
        options: Options(
          headers: {
            'Referer': 'https://www.swiggy.com/',
            if (swiggy?.cookieHeader != null && swiggy!.cookieHeader!.isNotEmpty)
              'Cookie': swiggy.cookieHeader!,
          },
        ),
      );
      data = resp.data;
    } catch (_) {
      data = await WebViewSessionHelper.fetchJsonInHeadlessWebView(
        originUrl: 'https://www.swiggy.com',
        targetApiUrl: apiUrl,
      );
    }

    final List<ComparedMenuItem> items = [];
    if (data is Map) {
      try {
        final cards = data['data']?['cards'];
        if (cards is List) {
          for (final topCard in cards) {
            final regularCards =
                topCard?['groupedCard']?['cardGroupMap']?['REGULAR']?['cards'];
            if (regularCards is List) {
              for (final rc in regularCards) {
                final itemCards = rc?['card']?['card']?['itemCards'];
                if (itemCards is List) {
                  for (final ic in itemCards) {
                    final info = ic?['card']?['info'];
                    if (info is Map) {
                      final id = info['id']?.toString() ?? '';
                      final name = info['name']?.toString() ?? '';
                      final rawPaise = info['price'] ?? info['defaultPrice'] ?? 0;
                      final swiggyPrice = (double.tryParse(rawPaise.toString()) ?? 0) / 100.0;
                      if (name.isEmpty || swiggyPrice <= 0) continue;

                      final imgId = info['imageId']?.toString() ?? '';
                      final isVeg = info['isVeg'] == 1;
                      final desc = info['description']?.toString() ?? '';

                      items.add(
                        ComparedMenuItem(
                          id: id,
                          name: name,
                          description: desc,
                          imageUrl: imgId.isNotEmpty
                              ? 'https://media-assets.swiggy.com/swiggy/image/upload/fl_lossy,f_auto,q_auto,w_300,h_300,c_fit/$imgId'
                              : '',
                          isVeg: isVeg,
                          platformPrices: {
                            'swiggy': swiggyPrice,
                            if (restaurant.platformQuotes.containsKey('zomato'))
                              'zomato': restaurant.platformQuotes['zomato']!.itemPrice > 0
                                  ? (swiggyPrice *
                                          (restaurant.platformQuotes['zomato']!.itemPrice /
                                              (restaurant.platformQuotes['swiggy']?.itemPrice ?? swiggyPrice)))
                                      .roundToDouble()
                                  : swiggyPrice,
                          },
                        ),
                      );
                    }
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[OnDeviceScraper] Menu parse error: $e');
      }
    }
    return items;
  }

  // ===========================================================================
  // 2. LIVE QUICK-COMMERCE GROCERY SEARCH (BLINKIT, ZEPTO, INSTAMART, BIGBASKET)
  // ===========================================================================

  Future<List<ComparedGroceryProduct>> searchAndCompareGroceries({
    required String query,
    required UserLocation location,
    required Map<String, PlatformInfo> platforms,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final results = await Future.wait([
      _searchBlinkit(trimmed, location, platforms['blinkit']),
      _searchZepto(trimmed, location, platforms['zepto']),
      _searchSwiggyInstamart(trimmed, location, platforms['instamart']),
      _searchBigBasket(trimmed, location, platforms['bigbasket']),
    ]);

    return _mergeGroceriesAcrossPlatforms(
      results.expand((list) => list).toList(),
    );
  }

  /// Queries Blinkit (`https://blinkit.com/v1/layout/search`) using device lat/lon headers
  Future<List<_RawGroceryHit>> _searchBlinkit(
    String query,
    UserLocation loc,
    PlatformInfo? blinkit,
  ) async {
    final encoded = Uri.encodeQueryComponent(query);
    final apiUrl = 'https://blinkit.com/v1/layout/search?q=$encoded&search_type=type_to_search';

    dynamic data;
    try {
      final resp = await _dio.post(
        apiUrl,
        options: Options(
          headers: {
            'lat': loc.latitude.toString(),
            'lon': loc.longitude.toString(),
            'app_client': 'consumer_web',
            'Referer': 'https://blinkit.com/s/?q=$encoded',
            if (blinkit?.cookieHeader != null && blinkit!.cookieHeader!.isNotEmpty)
              'Cookie': blinkit.cookieHeader!,
          },
        ),
      );
      data = resp.data;
    } catch (_) {
      data = await WebViewSessionHelper.fetchJsonInHeadlessWebView(
        originUrl: 'https://blinkit.com',
        targetApiUrl: apiUrl,
        method: 'POST',
        headers: {
          'lat': loc.latitude.toString(),
          'lon': loc.longitude.toString(),
          'app_client': 'consumer_web',
          'Accept': 'application/json',
        },
      );
    }

    return _parseGenericGroceryJson(
      data: data,
      platformId: 'blinkit',
      platformName: 'Blinkit',
      defaultDeepLink: 'https://blinkit.com/s/?q=$encoded',
      defaultEta: 11,
    );
  }

  /// Queries Zepto (`https://api.zeptonow.com/api/v3/search`)
  Future<List<_RawGroceryHit>> _searchZepto(
    String query,
    UserLocation loc,
    PlatformInfo? zepto,
  ) async {
    final encoded = Uri.encodeQueryComponent(query);
    final apiUrl = 'https://www.zeptonow.com/search?query=$encoded';

    dynamic data = await WebViewSessionHelper.fetchJsonInHeadlessWebView(
      originUrl: 'https://www.zeptonow.com',
      targetApiUrl: 'https://api.zeptonow.com/api/v3/search?query=$encoded&latitude=${loc.latitude}&longitude=${loc.longitude}',
    );

    return _parseGenericGroceryJson(
      data: data,
      platformId: 'zepto',
      platformName: 'Zepto',
      defaultDeepLink: apiUrl,
      defaultEta: 10,
    );
  }

  /// Queries Swiggy Instamart (`/api/instamart/search`)
  Future<List<_RawGroceryHit>> _searchSwiggyInstamart(
    String query,
    UserLocation loc,
    PlatformInfo? instamart,
  ) async {
    final encoded = Uri.encodeQueryComponent(query);
    final apiUrl =
        'https://www.swiggy.com/api/instamart/search?pageNo=0&searchResultsOffset=0&limit=20&query=$encoded&lat=${loc.latitude}&lng=${loc.longitude}';

    dynamic data;
    try {
      final resp = await _dio.get(
        apiUrl,
        options: Options(
          headers: {
            'Referer': 'https://www.swiggy.com/instamart/search?custom_back=true&query=$encoded',
            if (instamart?.cookieHeader != null && instamart!.cookieHeader!.isNotEmpty)
              'Cookie': instamart.cookieHeader!,
          },
        ),
      );
      data = resp.data;
    } catch (_) {
      data = await WebViewSessionHelper.fetchJsonInHeadlessWebView(
        originUrl: 'https://www.swiggy.com/instamart',
        targetApiUrl: apiUrl,
      );
    }

    return _parseGenericGroceryJson(
      data: data,
      platformId: 'instamart',
      platformName: 'Instamart',
      defaultDeepLink: 'https://www.swiggy.com/instamart/search?query=$encoded',
      defaultEta: 13,
    );
  }

  /// Queries BigBasket (`/listing-svc/v2/products`)
  Future<List<_RawGroceryHit>> _searchBigBasket(
    String query,
    UserLocation loc,
    PlatformInfo? bigbasket,
  ) async {
    final encoded = Uri.encodeQueryComponent(query);
    final apiUrl = 'https://www.bigbasket.com/listing-svc/v2/products?type=pc&slug=$encoded&page=1';

    dynamic data;
    try {
      final resp = await _dio.get(
        apiUrl,
        options: Options(
          headers: {
            'Referer': 'https://www.bigbasket.com/ps/?q=$encoded',
            if (bigbasket?.cookieHeader != null && bigbasket!.cookieHeader!.isNotEmpty)
              'Cookie': bigbasket.cookieHeader!,
          },
        ),
      );
      data = resp.data;
    } catch (_) {
      data = await WebViewSessionHelper.fetchJsonInHeadlessWebView(
        originUrl: 'https://www.bigbasket.com',
        targetApiUrl: apiUrl,
      );
    }

    return _parseGenericGroceryJson(
      data: data,
      platformId: 'bigbasket',
      platformName: 'BigBasket',
      defaultDeepLink: 'https://www.bigbasket.com/ps/?q=$encoded',
      defaultEta: 18,
    );
  }

  /// Recursive JSON walker that extracts product objects (`name`, `price`/`sp`, `mrp`, `unit`/`weight`, `image`)
  /// from heterogeneous quick-commerce JSON responses (Blinkit snippets, Instamart variations, BigBasket tabs, Zepto cards).
  List<_RawGroceryHit> _parseGenericGroceryJson({
    required dynamic data,
    required String platformId,
    required String platformName,
    required String defaultDeepLink,
    required int defaultEta,
  }) {
    final List<_RawGroceryHit> hits = [];
    final Set<String> seenNames = {};

    void walk(dynamic node) {
      if (node is Map) {
        final rawName = node['display_name'] ??
            node['name'] ??
            node['product_name'] ??
            (node['title'] is Map ? node['title']['text'] : node['title']) ??
            node['desc'];

        final rawPrice = node['price'] ??
            node['selling_price'] ??
            node['offer_price'] ??
            node['sp'] ??
            (node['pricing'] is Map ? node['pricing']['discount']?['prim_price']?['sp'] : null);

        if (rawName is String && rawName.trim().length > 2 && rawPrice != null) {
          double price = _extractNumber(rawPrice.toString(), fallback: -1);
          // Zepto/Instamart sometimes return paise for prices > 50000
          if (price > 10000 && node['mrp'] != null && _extractNumber(node['mrp'].toString(), fallback: 0) > 10000) {
            price = price / 100.0;
          }
          if (price > 0 && price < 25000) {
            final cleanName = rawName.trim();
            final key = '${cleanName.toLowerCase()}_$price';
            if (!seenNames.contains(key)) {
              seenNames.add(key);
              final rawMrp = node['mrp'] ??
                  node['normal_price'] ??
                  (node['pricing'] is Map ? node['pricing']['discount']?['mrp'] : null) ??
                  price;
              double mrp = _extractNumber(rawMrp.toString(), fallback: price);
              if (mrp > 10000 && price < 1000) mrp = mrp / 100.0;

              final unit = (node['unit'] ??
                      node['weight'] ??
                      node['quantity'] ??
                      node['pack_desc'] ??
                      '1 pack')
                  .toString();
              final brand = (node['brand'] is Map
                      ? node['brand']['name']
                      : (node['brand'] ?? node['brand_name'] ?? ''))
                  .toString();
              final image = (node['image_url'] ??
                      node['image'] ??
                      (node['images'] is List && (node['images'] as List).isNotEmpty
                          ? (node['images'] as List).first.toString()
                          : ''))
                  .toString();

              hits.add(
                _RawGroceryHit(
                  platformId: platformId,
                  platformName: platformName,
                  name: cleanName,
                  brand: brand,
                  quantityUnit: unit,
                  imageUrl: image,
                  price: price,
                  mrp: mrp < price ? price : mrp,
                  etaMinutes: defaultEta,
                  deepLink: defaultDeepLink,
                ),
              );
            }
          }
        }

        for (final v in node.values) {
          if (hits.length < 35) walk(v);
        }
      } else if (node is List) {
        for (final item in node) {
          if (hits.length < 35) walk(item);
        }
      }
    }

    walk(data);
    return hits;
  }

  // ===========================================================================
  // 3. ENTITY RESOLUTION & NORMALIZATION HELPERS
  // ===========================================================================

  List<ComparedRestaurant> _mergeRestaurantsAcrossPlatforms(
    List<_RawRestaurantHit> swiggyHits,
    List<_RawRestaurantHit> zomatoHits,
  ) {
    final Map<String, ComparedRestaurant> merged = {};

    for (final s in swiggyHits) {
      final normKey = _normalizeTitle(s.name);
      merged[normKey] = ComparedRestaurant(
        id: s.restaurantId,
        name: s.name,
        cuisineSummary: s.cuisines,
        imageUrl: s.imageUrl,
        rating: s.rating,
        distanceKm: s.distanceKm,
        platformQuotes: {
          'swiggy': PlatformPriceQuote(
            platformId: 'swiggy',
            platformName: 'Swiggy',
            itemPrice: s.basePriceEstimate,
            packagingFee: s.packagingFee,
            deliveryFee: s.deliveryFee,
            platformFee: s.platformFee,
            gstAndTaxes: s.gstAndTaxes,
            discountAmount: s.discountAmount,
            couponCode: s.couponCode,
            etaMinutes: s.etaMinutes,
            deepLinkUrl: s.deepLink,
            storeOrRestaurantId: s.restaurantId,
          ),
        },
      );
    }

    for (final z in zomatoHits) {
      final normKey = _normalizeTitle(z.name);
      // Match exact normalized name or high token overlap
      String? targetKey = merged.containsKey(normKey) ? normKey : null;
      targetKey ??= merged.keys.cast<String?>().firstWhere(
            (k) => k != null && (k.contains(normKey) || normKey.contains(k)),
            orElse: () => null,
          );

      final zQuote = PlatformPriceQuote(
        platformId: 'zomato',
        platformName: 'Zomato',
        itemPrice: z.basePriceEstimate,
        packagingFee: z.packagingFee,
        deliveryFee: z.deliveryFee,
        platformFee: z.platformFee,
        gstAndTaxes: z.gstAndTaxes,
        discountAmount: z.discountAmount,
        couponCode: z.couponCode,
        etaMinutes: z.etaMinutes,
        deepLinkUrl: z.deepLink,
        storeOrRestaurantId: z.restaurantId,
      );

      if (targetKey != null) {
        final existing = merged[targetKey]!;
        merged[targetKey] = ComparedRestaurant(
          id: existing.id,
          name: existing.name,
          cuisineSummary: existing.cuisineSummary,
          imageUrl: existing.imageUrl.isNotEmpty ? existing.imageUrl : z.imageUrl,
          rating: existing.rating,
          distanceKm: existing.distanceKm,
          platformQuotes: {
            ...existing.platformQuotes,
            'zomato': zQuote,
          },
        );
      } else {
        merged[normKey] = ComparedRestaurant(
          id: z.restaurantId,
          name: z.name,
          cuisineSummary: z.cuisines,
          imageUrl: z.imageUrl,
          rating: z.rating,
          distanceKm: z.distanceKm,
          platformQuotes: {'zomato': zQuote},
        );
      }
    }

    final list = merged.values.toList();
    // Sort restaurants with multi-platform comparison first
    list.sort((a, b) => b.platformQuotes.length.compareTo(a.platformQuotes.length));
    return list;
  }

  List<ComparedGroceryProduct> _mergeGroceriesAcrossPlatforms(
    List<_RawGroceryHit> allHits,
  ) {
    final Map<String, ComparedGroceryProduct> grouped = {};

    for (final hit in allHits) {
      final normKey = _normalizeTitle('${hit.name} ${hit.quantityUnit}');
      String? matchKey = grouped.containsKey(normKey) ? normKey : null;
      matchKey ??= grouped.keys.cast<String?>().firstWhere(
            (k) => k != null && _tokenSimilarity(k, normKey) >= 0.65,
            orElse: () => null,
          );

      final quote = PlatformPriceQuote(
        platformId: hit.platformId,
        platformName: hit.platformName,
        itemPrice: hit.price,
        originalMrp: hit.mrp,
        deliveryFee: 25,
        platformFee: 4,
        etaMinutes: hit.etaMinutes,
        deepLinkUrl: hit.deepLink,
      );

      if (matchKey != null) {
        final existing = grouped[matchKey]!;
        grouped[matchKey] = ComparedGroceryProduct(
          id: existing.id,
          name: existing.name,
          brand: existing.brand.isNotEmpty ? existing.brand : hit.brand,
          quantityUnit: existing.quantityUnit,
          imageUrl: existing.imageUrl.isNotEmpty ? existing.imageUrl : hit.imageUrl,
          quotes: {
            ...existing.quotes,
            hit.platformId: quote,
          },
        );
      } else {
        grouped[normKey] = ComparedGroceryProduct(
          id: '${hit.platformId}_${grouped.length}',
          name: hit.name,
          brand: hit.brand,
          quantityUnit: hit.quantityUnit,
          imageUrl: hit.imageUrl,
          quotes: {hit.platformId: quote},
        );
      }
    }

    final results = grouped.values.toList();
    results.sort((a, b) => b.quotes.length.compareTo(a.quotes.length));
    return results;
  }

  String _normalizeTitle(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double _tokenSimilarity(String a, String b) {
    final setA = a.split(' ').where((s) => s.length > 1).toSet();
    final setB = b.split(' ').where((s) => s.length > 1).toSet();
    if (setA.isEmpty || setB.isEmpty) return 0;
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    return intersection / union;
  }

  double _extractNumber(String text, {required double fallback}) {
    final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(text.replaceAll(',', ''));
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? fallback;
    }
    return fallback;
  }
}

class _RawRestaurantHit {
  final String platformId;
  final String restaurantId;
  final String name;
  final String cuisines;
  final String imageUrl;
  final double rating;
  final String distanceKm;
  final int etaMinutes;
  final double basePriceEstimate;
  final double deliveryFee;
  final double packagingFee;
  final double platformFee;
  final double gstAndTaxes;
  final double discountAmount;
  final String? couponCode;
  final String deepLink;

  const _RawRestaurantHit({
    required this.platformId,
    required this.restaurantId,
    required this.name,
    required this.cuisines,
    required this.imageUrl,
    required this.rating,
    required this.distanceKm,
    required this.etaMinutes,
    required this.basePriceEstimate,
    required this.deliveryFee,
    required this.packagingFee,
    required this.platformFee,
    required this.gstAndTaxes,
    required this.discountAmount,
    this.couponCode,
    required this.deepLink,
  });
}

class _RawGroceryHit {
  final String platformId;
  final String platformName;
  final String name;
  final String brand;
  final String quantityUnit;
  final String imageUrl;
  final double price;
  final double mrp;
  final int etaMinutes;
  final String deepLink;

  const _RawGroceryHit({
    required this.platformId,
    required this.platformName,
    required this.name,
    required this.brand,
    required this.quantityUnit,
    required this.imageUrl,
    required this.price,
    required this.mrp,
    required this.etaMinutes,
    required this.deepLink,
  });
}
