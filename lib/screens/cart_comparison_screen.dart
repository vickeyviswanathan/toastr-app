import 'package:flutter/material.dart';
import 'package:neopop/neopop.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/comparison_models.dart';
import '../providers/app_state_provider.dart';
import '../theme/toastr_theme.dart';

/// Replicates Toastr's `restaurants_cart_screen.dart` & `grocery_cart_screen.dart`
/// (`cart_comparison_view.dart` / `grocery_cart_comparison_view.dart`).
/// Computes side-by-side final payable bills across Swiggy vs Zomato or Blinkit vs Zepto vs Instamart vs BigBasket.
class CartComparisonScreen extends StatelessWidget {
  const CartComparisonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final items = state.cartEntries;
    final quotesMap = state.calculateCartComparison();
    final sortedQuotes = quotesMap.values.toList()
      ..sort((a, b) => a.finalPayable.compareTo(b.finalPayable));

    final double maxSavings = sortedQuotes.length >= 2
        ? sortedQuotes.last.finalPayable - sortedQuotes.first.finalPayable
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.activeVertical == VerticalType.food
              ? 'Food Cart Comparison'
              : 'Grocery Cart Comparison',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: state.clearCart,
              child: const Text(
                'CLEAR',
                style: TextStyle(
                  color: ToastrTheme.errorRed,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
      body: items.isEmpty
          ? const Center(
              child: Text(
                'Your comparison cart is empty.\nSearch and add dishes or groceries to compare final bills!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (maxSavings > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ToastrTheme.neonGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ToastrTheme.neonGreen),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.savings, color: ToastrTheme.neonGreen),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You save ₹${maxSavings.toStringAsFixed(0)} by ordering on ${sortedQuotes.first.platformName} instead of ${sortedQuotes.last.platformName}!',
                            style: const TextStyle(
                              color: ToastrTheme.neonGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Text(
                  'ITEMS IN COMPARISON CART',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 8),
                ...items.map(
                  (entry) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: ToastrTheme.cardSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ToastrTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                entry.subtitle,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          onPressed: () => state.decrementCartItem(entry.id),
                        ),
                        Text(
                          '${entry.quantity}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle_outline,
                            size: 20,
                            color: ToastrTheme.primaryYellow,
                          ),
                          onPressed: () => state.addToCart(
                            id: entry.id,
                            title: entry.title,
                            subtitle: entry.subtitle,
                            imageUrl: entry.imageUrl,
                            unitPricesByPlatform: entry.unitPricesByPlatform,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'FINAL BILL BREAKDOWN BY PLATFORM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: ToastrTheme.primaryYellow,
                  ),
                ),
                const SizedBox(height: 10),
                ...sortedQuotes.asMap().entries.map((entry) {
                  final isCheapest = entry.key == 0;
                  final q = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ToastrTheme.cardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCheapest
                            ? ToastrTheme.neonGreen
                            : ToastrTheme.cardBorder,
                        width: isCheapest ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  q.platformName.toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                if (isCheapest) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ToastrTheme.neonGreen,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'BEST PRICE',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              '₹${q.finalPayable.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: isCheapest
                                    ? ToastrTheme.neonGreen
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20, color: ToastrTheme.cardBorder),
                        _BillRow(label: 'Items Subtotal', amount: q.itemPrice),
                        _BillRow(label: 'Delivery Partner Fee', amount: q.deliveryFee),
                        _BillRow(label: 'Packaging & Handling', amount: q.packagingFee),
                        _BillRow(label: 'Platform Fee', amount: q.platformFee),
                        if (q.gstAndTaxes > 0)
                          _BillRow(label: 'GST & Restaurant Taxes (5%)', amount: q.gstAndTaxes),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: NeoPopButton(
                            color: isCheapest
                                ? ToastrTheme.primaryYellow
                                : ToastrTheme.surface,
                            onTapUp: () async {
                              if (q.deepLinkUrl != null) {
                                final uri = Uri.tryParse(q.deepLinkUrl!);
                                if (uri != null) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  'CHECKOUT ON ${q.platformName.toUpperCase()} (${q.etaMinutes} MINS)',
                                  style: TextStyle(
                                    color: isCheapest ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final double amount;

  const _BillRow({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          Text(
            amount == 0 ? 'FREE' : '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: amount == 0 ? ToastrTheme.neonGreen : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
