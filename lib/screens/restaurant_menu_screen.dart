import 'package:flutter/material.dart';
import 'package:neopop/neopop.dart';
import 'package:provider/provider.dart';
import '../models/comparison_models.dart';
import '../providers/app_state_provider.dart';
import '../theme/toastr_theme.dart';

/// Replicates Toastr's `restaurants_menu_screen.dart` — fetches live menu items
/// from the restaurant and lets you add dishes to your cross-platform comparison cart.
class RestaurantMenuScreen extends StatefulWidget {
  final ComparedRestaurant restaurant;

  const RestaurantMenuScreen({
    super.key,
    required this.restaurant,
  });

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
  List<ComparedMenuItem> _menuItems = [];
  bool _loading = true;
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    setState(() => _loading = true);
    try {
      final items = await context
          .read<AppStateProvider>()
          .fetchRestaurantMenu(widget.restaurant);
      if (mounted) {
        setState(() {
          _menuItems = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final filtered = _menuItems
        .where((m) =>
            _filterQuery.isEmpty ||
            m.name.toLowerCase().contains(_filterQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.restaurant.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            Text(
              widget.restaurant.cuisineSummary,
              style: const TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _filterQuery = v),
              decoration: InputDecoration(
                hintText: 'Search dishes in ${widget.restaurant.name}...',
                prefixIcon: const Icon(Icons.search, color: ToastrTheme.primaryYellow),
                filled: true,
                fillColor: ToastrTheme.cardSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: ToastrTheme.cardBorder),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: ToastrTheme.primaryYellow,
                    ),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No live menu items returned yet. You can still add "${widget.restaurant.name}" directly to your comparison cart.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white60),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: ToastrTheme.cardSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: ToastrTheme.cardBorder),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.radio_button_checked,
                                  size: 16,
                                  color: item.isVeg
                                      ? ToastrTheme.neonGreen
                                      : ToastrTheme.errorRed,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (item.description.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          item.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white60,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        children: item.platformPrices.entries.map((e) {
                                          final isSwiggy = e.key == 'swiggy';
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: (isSwiggy
                                                      ? ToastrTheme.swiggyOrange
                                                      : ToastrTheme.zomatoRed)
                                                  .withOpacity(0.18),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${e.key.toUpperCase()}: ₹${e.value.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: isSwiggy
                                                    ? ToastrTheme.swiggyOrange
                                                    : ToastrTheme.zomatoRed,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                NeoPopButton(
                                  color: ToastrTheme.primaryYellow,
                                  onTapUp: () {
                                    state.addToCart(
                                      id: '${widget.restaurant.id}_${item.id}',
                                      title: item.name,
                                      subtitle: widget.restaurant.name,
                                      imageUrl: item.imageUrl,
                                      unitPricesByPlatform: item.platformPrices,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        duration: const Duration(seconds: 1),
                                        content: Text('Added ${item.name} to comparison cart'),
                                      ),
                                    );
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
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
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
