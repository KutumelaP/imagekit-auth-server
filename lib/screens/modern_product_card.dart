import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/safe_network_image.dart';

class ModernProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final String id;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Function(String, bool) onToggleStatus;
  final Function(String, int) onUpdateQuantity;
  final Function(Map<String, dynamic>) onEdit;
  final Function(String, String) onDelete;
  final Function(String) onToggleSelect;

  const ModernProductCard({
    super.key,
    required this.product,
    required this.id,
    required this.isSelected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleStatus,
    required this.onUpdateQuantity,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final int qty = (product['quantity'] ?? product['stock'] ?? 0) is int
        ? (product['quantity'] ?? product['stock'] ?? 0) as int
        : int.tryParse('${product['quantity'] ?? product['stock'] ?? 0}') ?? 0;
    final bool isLowStock = qty > 0 && qty <= 5;
    final bool isActive = (product['status'] ?? 'active') == 'active';
    final bool hasImage = product['imageUrl'] != null && (product['imageUrl'] as String).isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: isSelected 
              ? LinearGradient(
                  colors: [Colors.white, AppTheme.deepTeal.withOpacity(0.08)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(colors: [Colors.white, Colors.white]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected 
              ? [
                  BoxShadow(color: AppTheme.deepTeal.withOpacity(0.2), blurRadius: 24, offset: const Offset(0, 12)),
                  BoxShadow(color: AppTheme.deepTeal.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
                ]
              : [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4)),
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
          border: Border.all(
            color: isSelected
                ? AppTheme.deepTeal.withOpacity(0.4)
                : qty == 0 
                    ? AppTheme.primaryRed.withOpacity(0.3) 
                    : isLowStock 
                        ? AppTheme.warning.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.15),
            width: isSelected ? 2.5 : 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Column(
                children: [
                  // Hero Image Section
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: hasImage 
                          ? null 
                          : LinearGradient(
                              colors: [
                                AppTheme.deepTeal.withOpacity(0.08),
                                AppTheme.breeze.withOpacity(0.12),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                    ),
                    child: hasImage
                        ? Hero(
                            tag: 'product_image_$id',
                            child: SafeNetworkImage(
                              imageUrl: product['imageUrl'],
                              fit: BoxFit.cover,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppTheme.deepTeal.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  color: AppTheme.deepTeal.withOpacity(0.7),
                                  size: 36,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No Image',
                                style: TextStyle(
                                  color: AppTheme.deepTeal.withOpacity(0.6),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                  ),
                  // Content Section
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product Name & Category
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['name'] ?? 'Unnamed Product',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.deepTeal,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.breeze.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  product['category'] ?? 'Uncategorized',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.deepTeal.withOpacity(0.8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          // Price & Stock Dashboard
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.whisper.withOpacity(0.4),
                                  AppTheme.breeze.withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.breeze.withOpacity(0.25)),
                            ),
                            child: Row(
                              children: [
                                // Price
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Price',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [AppTheme.primaryGreen, Color(0xFF4CAF50)],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.primaryGreen.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          'R${(product['price'] ?? 0.0).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1.5,
                                  height: 45,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.breeze.withOpacity(0.2),
                                        AppTheme.breeze.withOpacity(0.5),
                                        AppTheme.breeze.withOpacity(0.2),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                                // Stock
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Stock',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: qty > 5 
                                                    ? AppTheme.primaryGreen.withOpacity(0.2)
                                                    : qty > 0 
                                                        ? AppTheme.warning.withOpacity(0.2)
                                                        : AppTheme.primaryRed.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: qty > 5 
                                                      ? AppTheme.primaryGreen.withOpacity(0.4)
                                                      : qty > 0 
                                                          ? AppTheme.warning.withOpacity(0.4)
                                                          : AppTheme.primaryRed.withOpacity(0.4),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: Text(
                                                '$qty',
                                                style: TextStyle(
                                                  color: qty > 5 
                                                      ? AppTheme.primaryGreen
                                                      : qty > 0 
                                                          ? AppTheme.warning
                                                          : AppTheme.primaryRed,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            if (!selectionMode && qty > 0) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: AppTheme.breeze.withOpacity(0.4)),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.05),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    InkWell(
                                                      onTap: () => onUpdateQuantity(id, qty > 0 ? qty - 1 : 0),
                                                      borderRadius: const BorderRadius.only(
                                                        topLeft: Radius.circular(10),
                                                        bottomLeft: Radius.circular(10),
                                                      ),
                                                      child: Container(
                                                        padding: const EdgeInsets.all(6),
                                                        child: Icon(Icons.remove, size: 14, color: AppTheme.deepTeal),
                                                      ),
                                                    ),
                                                    InkWell(
                                                      onTap: () => onUpdateQuantity(id, qty + 1),
                                                      borderRadius: const BorderRadius.only(
                                                        topRight: Radius.circular(10),
                                                        bottomRight: Radius.circular(10),
                                                      ),
                                                      child: Container(
                                                        padding: const EdgeInsets.all(6),
                                                        child: Icon(Icons.add, size: 14, color: AppTheme.deepTeal),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.deepTeal.withOpacity(0.1),
                                        AppTheme.breeze.withOpacity(0.15),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppTheme.deepTeal.withOpacity(0.25)),
                                  ),
                                  child: InkWell(
                                    onTap: () => onEdit(product),
                                    borderRadius: BorderRadius.circular(16),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18, color: AppTheme.deepTeal),
                                        SizedBox(width: 8),
                                        Text(
                                          'Edit',
                                          style: TextStyle(
                                            color: AppTheme.deepTeal,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                height: 48,
                                width: 48,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryRed.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.primaryRed.withOpacity(0.25)),
                                ),
                                child: InkWell(
                                  onTap: () => onDelete(id, product['name'] ?? 'Product'),
                                  borderRadius: BorderRadius.circular(16),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: AppTheme.primaryRed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Floating Status Toggle
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive ? Icons.visibility : Icons.visibility_off,
                        size: 16,
                        color: isActive ? AppTheme.primaryGreen : AppTheme.warning,
                      ),
                      const SizedBox(width: 6),
                      if (!selectionMode)
                        GestureDetector(
                          onTap: () => onToggleStatus(id, !isActive),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 36,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isActive ? AppTheme.primaryGreen : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: AnimatedAlign(
                              duration: const Duration(milliseconds: 300),
                              alignment: isActive ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                width: 16,
                                height: 16,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Selection Indicator
              if (selectionMode)
                Positioned(
                  top: 16,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => onToggleSelect(id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.deepTeal : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppTheme.deepTeal : Colors.grey.shade400,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
                ),
              // Low Stock Badge
              if (isLowStock && !selectionMode)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.warning, Color(0xFFFF8C42)],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_outlined, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Low Stock',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
