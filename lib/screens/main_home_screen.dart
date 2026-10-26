import 'package:flutter/material.dart';
import 'package:neopop/neopop.dart';
import 'package:provider/provider.dart';
import '../models/comparison_models.dart';
import '../providers/app_state_provider.dart';
import '../theme/toastr_theme.dart';
import 'cart_comparison_screen.dart';
import 'platform_integration_screen.dart';
import 'restaurant_menu_screen.dart';

/// Replicates Toastr's `main_home_screen.dart`, `restaurants_search_screen.dart`,
/// and `grocery_home_screen.dart` with CRED NeoPop buttons and real-time on-device scraping.
class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _foodQuickChips = [
    'Biryani',
    'Pizza',
    'Burger',
    'Dosa',
    'Paneer',
    'Momos',
    'Shawarma',
  ];

  static const List<String> _groceryQuickChips = [
    'Milk',
    'Eggs',
    'Bread',
    'Atta',
    'Coca Cola',
    'Lays',
    'Butter',
  ];

  void _triggerSearch(String query) {
    _searchController.text = query;
    context.read<AppStateProvider>().performLiveSearch(query);
  }

  void _showLocationPickerDialog(BuildContext context, AppStateProvider state) {
    final presets = [
      const UserLocation(
        latitude: 12.9352,
        longitude: 77.6245,
        addressLabel: 'Koramangala, Bengaluru',
        pincode: '560034',
        city: 'bangalore',
      ),
      const UserLocation(
        latitude: 19.0760,
        longitude: 72.8777,
        addressLabel: 'Bandra West, Mumbai',
        pincode: '400050',
        city: 'mumbai',
      ),
      const UserLocation(
        latitude: 28.6139,
        longitude: 77.2090,
        addressLabel: 'Connaught Place, New Delhi',
        pincode: '110001',
        city: 'ncr',
      ),
      const UserLocation(
        latitude: 17.4401,
        longitude: 78.3489,
        addressLabel: 'Gachibowli, Hyderabad',
        pincode: '500032',
        city: 'hyderabad',
      ),
      const UserLocation(
        latitude: 18.5204,
        longitude: 73.8567,
        addressLabel: 'Koregaon Park, Pune',
        pincode: '411001',
        city: 'pune',
      ),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: ToastrTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SELECT DELIVERY LOCATION',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: ToastrTheme.primaryYellow,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.my_location, color: ToastrTheme.neonGreen),
              title: const Text(
                'Use Current Phone GPS Location',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Queries live store inventory at your exact coordinates'),
              onTap: () {
                Navigator.pop(context);
                state.detectGpsLocation();
              },
            ),
            const Divider(color: ToastrTheme.cardBorder),
            ...presets.map(
              (loc) => ListTile(
                leading: const Icon(Icons.location_on_outlined, color: Colors.white70),
                title: Text(loc.addressLabel),
                subtitle: Text('Pincode: ${loc.pincode}'),
                onTap: () {
                  Navigator.pop(context);
                  state.updateManualLocation(loc);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final isFood = state.activeVertical == VerticalType.food;
    final quickChips = isFood ? _foodQuickChips : _groceryQuickChips;
    final connectedCount =
        state.platforms.values.where((p) => p.isConnected).length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: GestureDetector(
          onTap: () => _showLocationPickerDialog(context, state),
          child: Row(
            children: [
              Image.asset(
                'assets/toastr_logo.png',
                width: 34,
                height: 34,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.bolt,
                  color: ToastrTheme.primaryYellow,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'TOASTR',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 1.2,
                            color: ToastrTheme.primaryYellow,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: ToastrTheme.neonGreen.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LOCAL ENGINE',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: ToastrTheme.neonGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 12,
                          color: ToastrTheme.accentOrange,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            state.isLoadingLocation
                                ? 'Detecting GPS...'
                                : '${state.currentLocation.addressLabel} (${state.currentLocation.pincode})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.white54),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: NeoPopButton(
              color: ToastrTheme.cardSurface,
              border: Border.all(color: ToastrTheme.primaryYellow),
              onTapUp: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PlatformIntegrationScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 15, color: ToastrTheme.primaryYellow),
                    const SizedBox(width: 4),
                    Text(
                      'ACCOUNTS ($connectedCount/6)',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // NeoPop Vertical Switcher: Food Delivery vs Groceries
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: NeoPopButton(
                    color: isFood ? ToastrTheme.primaryYellow : ToastrTheme.cardSurface,
                    onTapUp: () => state.setVertical(VerticalType.food),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          'FOOD (SWIGGY vs ZOMATO)',
                          style: TextStyle(
                            color: isFood ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NeoPopButton(
                    color: !isFood ? ToastrTheme.neonGreen : ToastrTheme.cardSurface,
                    onTapUp: () => state.setVertical(VerticalType.grocery),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          'GROCERY (BLINKIT • ZEPTO • INSTA)',
                          style: TextStyle(
                            color: !isFood ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Live Search Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _triggerSearch,
                    decoration: InputDecoration(
                      hintText: isFood
                          ? 'Search restaurant or dish (e.g. Meghana, Biryani)...'
                          : 'Search groceries (e.g. Amul Milk, Bread, Maggi)...',
                      hintStyle: const TextStyle(fontSize: 13, color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: ToastrTheme.primaryYellow),
                      filled: true,
                      fillColor: ToastrTheme.cardSurface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: ToastrTheme.cardBorder),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                NeoPopButton(
                  color: ToastrTheme.primaryYellow,
                  onTapUp: () => _triggerSearch(_searchController.text),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Text(
                      'COMPARE',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Quick Search Chips
          SizedBox(
            height: 46,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: quickChips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final chip = quickChips[index];
                return ActionChip(
                  backgroundColor: ToastrTheme.cardSurface,
                  side: const BorderSide(color: ToastrTheme.cardBorder),
                  label: Text(
                    chip,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  onPressed: () => _triggerSearch(chip),
                );
              },
            ),
          ),

          // Results Area
          Expanded(
            child: state.isSearching
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: ToastrTheme.primaryYellow,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.statusMessage ?? 'Fetching live prices...',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                : isFood
                    ? _FoodResultsList(restaurants: state.restaurants)
                    : _GroceryResultsList(products: state.groceryProducts),
          ),
        ],
      ),
      floatingActionButton: state.totalCartItems > 0
          ? NeoPopButton(
              color: ToastrTheme.primaryYellow,
              onTapUp: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CartComparisonScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shopping_bag, color: Colors.black, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'COMPARE CART (${state.totalCartItems})',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _FoodResultsList extends StatelessWidget {
  final List<ComparedRestaurant> restaurants;

  const _FoodResultsList({required this.restaurants});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();

    if (restaurants.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.fastfood_outlined,
                size: 48,
                color: ToastrTheme.primaryYellow,
              ),
              const SizedBox(height: 12),
              Text(
                state.statusMessage ??
                    'Tap any chip above or type a restaurant/dish name to compare live Swiggy & Zomato prices right from your phone.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: restaurants.length,
      itemBuilder: (context, index) {
        final r = restaurants[index];
        final cheapestId = r.cheapestPlatformId;
        final savings = r.maxSavings;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ToastrTheme.cardSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: savings > 0
                  ? ToastrTheme.neonGreen.withOpacity(0.6)
                  : ToastrTheme.cardBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${r.cuisineSummary} • ★ ${r.rating} • ${r.distanceKm}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (savings > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: ToastrTheme.neonGreen.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'SAVE ₹${savings.toStringAsFixed(0)} ON ${cheapestId?.toUpperCase()}',
                        style: const TextStyle(
                          color: ToastrTheme.neonGreen,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: r.platformQuotes.entries.map((entry) {
                  final q = entry.value;
                  final isCheapest = entry.key == cheapestId && r.platformQuotes.length > 1;
                  final brandColor = entry.key == 'swiggy'
                      ? ToastrTheme.swiggyOrange
                      : ToastrTheme.zomatoRed;

                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ToastrTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCheapest ? ToastrTheme.neonGreen : brandColor.withOpacity(0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                q.platformName.toUpperCase(),
                                style: TextStyle(
                                  color: brandColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                '${q.etaMinutes} mins',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${q.finalPayable.toStringAsFixed(0)} est. bill',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          if (q.couponCode != null && q.couponCode!.isNotEmpty)
                            Text(
                              q.couponCode!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: ToastrTheme.neonGreen,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: NeoPopButton(
                      color: ToastrTheme.surface,
                      border: Border.all(color: ToastrTheme.primaryYellow),
                      onTapUp: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RestaurantMenuScreen(restaurant: r),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Center(
                          child: Text(
                            'VIEW LIVE MENU',
                            style: TextStyle(
                              color: ToastrTheme.primaryYellow,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: NeoPopButton(
                      color: ToastrTheme.primaryYellow,
                      onTapUp: () {
                        state.addToCart(
                          id: r.id,
                          title: r.name,
                          subtitle: r.cuisineSummary,
                          imageUrl: r.imageUrl,
                          unitPricesByPlatform: {
                            for (final e in r.platformQuotes.entries)
                              e.key: e.value.itemPrice,
                          },
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 1),
                            content: Text('Added ${r.name} to comparison cart'),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Center(
                          child: Text(
                            '+ ADD TO CART',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GroceryResultsList extends StatelessWidget {
  final List<ComparedGroceryProduct> products;

  const _GroceryResultsList({required this.products});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();

    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_grocery_store_outlined,
                size: 48,
                color: ToastrTheme.neonGreen,
              ),
              const SizedBox(height: 12),
              Text(
                state.statusMessage ??
                    'Tap any grocery chip above or search a product to compare live prices across Blinkit, Zepto, Instamart & BigBasket.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final prod = products[index];
        final best = prod.bestQuote;
        final spread = prod.savingsSpread;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ToastrTheme.cardSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: spread > 0
                  ? ToastrTheme.neonGreen.withOpacity(0.6)
                  : ToastrTheme.cardBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prod.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${prod.quantityUnit}${prod.brand.isNotEmpty ? " • ${prod.brand}" : ""}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  NeoPopButton(
                    color: ToastrTheme.primaryYellow,
                    onTapUp: () {
                      state.addToCart(
                        id: prod.id,
                        title: prod.name,
                        subtitle: prod.quantityUnit,
                        imageUrl: prod.imageUrl,
                        unitPricesByPlatform: {
                          for (final e in prod.quotes.entries)
                            e.key: e.value.itemPrice,
                        },
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 1),
                          content: Text('Added ${prod.name} to grocery cart'),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        '+ ADD',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: prod.quotes.values.map((q) {
                  final isBest = best?.platformId == q.platformId && prod.quotes.length > 1;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isBest
                          ? ToastrTheme.neonGreen.withOpacity(0.18)
                          : ToastrTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isBest ? ToastrTheme.neonGreen : ToastrTheme.cardBorder,
                      ),
                    ),
                    child: Text(
                      '${q.platformName}: ₹${q.itemPrice.toStringAsFixed(0)} (${q.etaMinutes}m)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isBest ? ToastrTheme.neonGreen : Colors.white,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
