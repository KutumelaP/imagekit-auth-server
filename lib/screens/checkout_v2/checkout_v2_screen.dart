import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/safe_ui.dart' as safe_ui_widget;
import '../../utils/responsive_utils.dart' as responsive_utils;
import '../../services/real_pickup_service.dart';
// import '../../services/seller_delivery_management_service.dart';
import '../../widgets/smart_address_input.dart';
import '../../services/here_maps_address_service.dart';
import '../../services/paxi_pudo_service.dart';
import '../../widgets/paxi_speed_selector.dart';
import '../../widgets/phone_number_input.dart';
import 'checkout_v2_view_model.dart';

class CheckoutV2Screen extends StatelessWidget {
  final double totalPrice;
  const CheckoutV2Screen({super.key, required this.totalPrice});

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final storeItems = cartProvider.items;
    
    // Guard: If cart is empty, redirect to home
    if (storeItems.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/home');
      });
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Cart is empty', style: TextStyle(fontSize: 18, color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    
    // Map provider items to expected structure
    final List<Map<String, dynamic>> cartItems = storeItems.map((it) => {
      'name': it.name,
      'category': it.storeCategory,
      'quantity': it.quantity,
      'price': it.price,
      'sellerId': it.sellerId,
      'productId': it.id,
      'imageUrl': it.imageUrl,
      'sellerName': it.sellerName,
    }).toList();

    return ChangeNotifierProvider(
      create: (_) => CheckoutV2ViewModel(
        totalPrice: totalPrice,
        cartItems: cartItems,
      ),
      child: const _CheckoutV2Body(),
    );
  }
}

class _CheckoutV2Body extends StatelessWidget {
  const _CheckoutV2Body();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CheckoutV2ViewModel>();

    return Scaffold(
      backgroundColor: AppTheme.angel,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: AppTheme.primaryGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: AppTheme.angel,
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.angel.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.angel.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.shopping_cart_checkout, 
                size: 20,
                color: AppTheme.angel,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Secure Checkout',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.angel,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Complete your order securely',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.angel.withOpacity(0.85),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: safe_ui_widget.SafeUI.safeWidget(
        SingleChildScrollView(
          padding: EdgeInsets.all(responsive_utils.ResponsiveUtils.getPadding(context).left),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ModeToggle(vm: vm),
              const SizedBox(height: 16),
              _CustomerInformation(vm: vm),
              const SizedBox(height: 16),
              _AddressOrPickup(vm: vm),
              const SizedBox(height: 16),
              if (vm.isDelivery && vm.sellerOffersDelivery) _ProductHandlingInstructions(vm: vm),
              if (vm.isDelivery && vm.sellerOffersDelivery) const SizedBox(height: 16),
              _PaymentMethodSelection(vm: vm),
              const SizedBox(height: 16),
              _SmartSummary(vm: vm),
              const SizedBox(height: 16),
              _PlaceOrder(vm: vm),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildSecureBottomBar(vm),
    );
  }

  Widget _buildSecureBottomBar(CheckoutV2ViewModel vm) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppTheme.cardGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepTeal.withOpacity(0.15),
            blurRadius: 20,
            offset: Offset(0, -8),
            spreadRadius: 0,
          ),
        ],
        border: Border(
          top: BorderSide(
            color: AppTheme.cloud.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Security indicators
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.whisper.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.cloud.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.security, color: AppTheme.success, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'SSL Secured',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    width: 1,
                    height: 16,
                    color: AppTheme.cloud.withOpacity(0.4),
                  ),
                  Icon(Icons.verified_user, color: AppTheme.info, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'PayFast Protected',
                    style: TextStyle(
                      color: AppTheme.info,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            // Enhanced place order button
            _PlaceOrderEnhanced(vm: vm),
          ],
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final CheckoutV2ViewModel vm;
  const _ModeToggle({required this.vm});

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while checking seller info
    if (vm.isLoadingSellerInfo) {
      return Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: AppTheme.cardGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.cardElevation,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Loading delivery options...',
              style: TextStyle(
                color: AppTheme.deepTeal,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    
    // If seller doesn't offer delivery, only show pickup option
    if (!vm.sellerOffersDelivery) {
      return Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: AppTheme.primaryGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.cardElevation,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.store,
              color: AppTheme.angel,
              size: 18,
            ),
            SizedBox(width: 10),
            Text(
              'Pickup Only',
              style: TextStyle(
                color: AppTheme.angel,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
    }
    
    // Show both delivery and pickup options
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppTheme.cardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardElevation,
        border: Border.all(
          color: AppTheme.breeze.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: vm.sellerOffersDelivery ? () => vm.setIsDelivery(true) : null,
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: vm.isDelivery 
                    ? LinearGradient(
                        colors: AppTheme.primaryGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: vm.isDelivery ? AppTheme.buttonElevation : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_shipping,
                      color: vm.isDelivery ? AppTheme.angel : AppTheme.mediumGrey,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Delivery',
                      style: TextStyle(
                        color: vm.isDelivery ? AppTheme.angel : AppTheme.mediumGrey,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => vm.setIsDelivery(false),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: !vm.isDelivery 
                    ? LinearGradient(
                        colors: AppTheme.primaryGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: !vm.isDelivery ? AppTheme.buttonElevation : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.store,
                      color: !vm.isDelivery ? AppTheme.angel : AppTheme.mediumGrey,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Pickup',
                      style: TextStyle(
                        color: !vm.isDelivery ? AppTheme.angel : AppTheme.mediumGrey,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressOrPickup extends StatelessWidget {
  final CheckoutV2ViewModel vm;
  const _AddressOrPickup({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppTheme.cardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardElevation,
        border: Border.all(
          color: AppTheme.breeze.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppTheme.lightGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.cloud.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  vm.isDelivery ? Icons.local_shipping : Icons.store,
                  color: AppTheme.deepTeal,
                  size: 22,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vm.isDelivery ? 'Delivery Address' : 'Pickup Location',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: AppTheme.deepTeal,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      vm.isDelivery ? 'Where should we deliver?' : 'Choose a pickup point',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.mediumGrey,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Delivery Section
          if (vm.isDelivery && vm.sellerOffersDelivery) ...[
            SmartAddressInput(
              hintText: 'Search for your delivery address...',
              onAddressSelected: (address) {
                print('🔍 Checkout: onAddressSelected called with: $address');
                if (address != null) {
                  final formattedAddress = HereMapsAddressService.formatAddressForDisplay(address);
                  print('🔍 Checkout: Formatted address: "$formattedAddress"');
                  
                  // Ensure we have a non-empty address
                  final finalAddress = formattedAddress.isNotEmpty 
                      ? formattedAddress 
                      : (address['title']?.toString() ?? address['label']?.toString() ?? 'Selected Address');
                  
                  print('🔍 Checkout: Final address to save: "$finalAddress"');
                  
                  // Set address in ViewModel
                  vm.setAddress(finalAddress);
                  vm.setSelectedAddress(address);
                  
                  // Calculate delivery fee based on real address
                  final deliveryZone = HereMapsAddressService.getDeliveryZone(address);
                  final isUrban = deliveryZone.contains('metro') || deliveryZone.contains('urban');
                  print('🔍 Checkout: Delivery zone: $deliveryZone, isUrban: $isUrban');
                  
                  vm.computeFeesAndEta(isUrbanArea: isUrban);
                  
                  print('🔍 Checkout: Address selection complete - saved: "$finalAddress"');
                } else {
                  print('❌ Checkout: Address is null!');
                }
              },
            ),
            
            // Show selected address confirmation
            if (vm.addressText != null && vm.addressText!.isNotEmpty)
              Container(
                margin: EdgeInsets.only(top: 12),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery Address Confirmed',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green[700],
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            vm.addressText!,
                            style: TextStyle(
                              color: Colors.green[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          
          // Pickup Section (separate from delivery)
          if (!vm.isDelivery) ...[
            _PickupPointSelector(vm: vm),
            if (vm.selectedPickupPoint != null && vm.selectedPickupPoint!['type'] == 'paxi')
              PaxiSpeedSelector(vm: vm),
            if (vm.selectedPickupPoint != null && vm.selectedPickupPoint!['type'] == 'pudo')
              _PudoDeliveryDetails(vm: vm),
          ],
        ],
      ),
    );
  }
}

class _SmartSummary extends StatelessWidget {
  final CheckoutV2ViewModel vm;
  const _SmartSummary({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.deepTeal.withOpacity(0.05),
            AppTheme.angel.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.deepTeal.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: AppTheme.deepTeal, size: 20),
              const SizedBox(width: 8),
              Text(
                'Order Summary',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.deepTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Items total
          _SummaryRow('Items', 'R${vm.totalPrice.toStringAsFixed(2)}'),
          
          // Delivery/pickup fee
          if (vm.isDelivery)
            _SummaryRow(
              'Delivery fee', 
              vm.deliveryFee != null ? 'R${vm.deliveryFee!.toStringAsFixed(2)}' : 'Calculating...',
              isSubtotal: true,
            )
          else if (vm.selectedPickupPoint != null)
            _SummaryRow(
              'Pickup fee', 
              'R${vm.selectedPickupPoint!['fees']['collection'] ?? 0.0}',
              isSubtotal: true,
            ),
          
          // Service fee
          _SummaryRow(
            'Service fee', 
            'R${(vm.totalPrice * 0.035).toStringAsFixed(2)}',
            isSubtotal: true,
          ),
          
          const Divider(),
          
          // Total
          _SummaryRow(
            'Total', 
            'R${vm.calculateTotal().toStringAsFixed(2)}',
            isTotal: true,
          ),
          
          if (vm.isDelivery && vm.etaMinutes != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: Colors.green[700], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Estimated delivery: ${vm.etaMinutes} minutes',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          if (vm.error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      vm.error!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _SummaryRow(String label, String amount, {bool isSubtotal = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? AppTheme.deepTeal : Colors.grey[700],
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: isTotal ? AppTheme.deepTeal : Colors.grey[800],
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceOrder extends StatelessWidget {
  final CheckoutV2ViewModel vm;
  const _PlaceOrder({required this.vm});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 0); // Hidden - using enhanced version in bottom bar
  }
}

class _PlaceOrderEnhanced extends StatelessWidget {
  final CheckoutV2ViewModel vm;
  const _PlaceOrderEnhanced({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppTheme.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepTeal.withOpacity(0.4),
            blurRadius: 16,
            offset: Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: vm.isLoading || !vm.isStoreOpenNow
            ? null
            : () async {
                vm.setLoading(true);
                vm.setError(null);

                final ok = await vm.validateAndStepUp(context);
                if (!ok) {
                  vm.setLoading(false);
                  return;
                }

                // Submit order with all services integration
                try {
                  final result = await vm.submitOrder(context);
                  if (context.mounted) {
                    if (vm.selectedPaymentMethod == 'payfast') {
                      // Do not pop checkout; user will complete payment in WebView
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.sync, color: Colors.white),
                              SizedBox(width: 6),
                              Text('Redirecting to PayFast...'),
                            ],
                          ),
                          backgroundColor: Colors.blue,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    } else if (vm.selectedPaymentMethod == 'eft') {
                      final eft = result['payment'] as Map<String, dynamic>?;
                      final ref = eft?['reference'] ?? 'N/A';
                      final amount = (result['total'] ?? vm.grandTotal) as double?;
                      final bank = (eft?['bankDetails'] ?? const {}) as Map<String, dynamic>;
                      final bankName = (bank['bank'] ?? 'Bank').toString();
                      final acc = (bank['account'] ?? 'Account').toString();
                      final branch = (bank['branch'] ?? 'Branch').toString();
                      final holder = (bank['accountHolder'] ?? 'Account Holder').toString();
                      await showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Row(
                            children: const [
                              Icon(Icons.account_balance, color: Colors.teal),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Bank Transfer (EFT)',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Use these details to complete your bank transfer:'),
                              const SizedBox(height: 12),
                              _kvRow('Bank', bankName, canCopy: true),
                              _kvRow('Account Holder', holder, canCopy: true),
                              _kvRow('Account Number', acc, canCopy: true),
                              _kvRow('Branch Code', branch, canCopy: true),
                              const Divider(height: 20),
                              _kvRow('Amount', 'R${(amount ?? 0).toStringAsFixed(2)}'),
                              _kvRow('Reference', ref, canCopy: true),
                              const SizedBox(height: 12),
                              const Text('We will process your order once payment reflects. Send proof if requested.'),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
                          ],
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: const [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 6),
                              Text('Order placed. EFT details sent.'),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 6),
                              Text('Order placed successfully! 🎉'),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                      Navigator.of(context).pop(); // Return to previous screen for non-card flows
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.error, color: Colors.white),
                            SizedBox(width: 6),
                            Expanded(child: Text('Order failed: $e')),
                          ],
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                }
                vm.setLoading(false);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppTheme.angel,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ).copyWith(
          backgroundColor: MaterialStateProperty.all(Colors.transparent),
        ),
        child: vm.isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppTheme.angel),
                      strokeWidth: 2.5,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Processing...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.angel,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_checkout, 
                    size: 22,
                    color: AppTheme.angel,
                  ),
                  SizedBox(width: 14),
                  Text(
                    vm.isStoreOpenNow
                      ? 'Place Order • R${vm.grandTotal.toStringAsFixed(2)}'
                      : 'Store closed - try later',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.angel,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// PAXI/PUDO Pickup Point Selector
class _PickupPointSelector extends StatefulWidget {
  final CheckoutV2ViewModel vm;
  const _PickupPointSelector({required this.vm});

  @override
  State<_PickupPointSelector> createState() => _PickupPointSelectorState();
}

class _PickupPointSelectorState extends State<_PickupPointSelector> {
  List<Map<String, dynamic>> _nearbyPoints = [];
  bool _isLoading = false;
  String _selectedType = 'paxi'; // 'paxi' or 'pudo'
  
  // Address search for PAXI
  final TextEditingController _addressController = TextEditingController();
  List<Map<String, dynamic>> _addressSuggestions = [];
  bool _isSearchingAddress = false;

  @override
  void initState() {
    super.initState();
    
    // Set default selection based on available services
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bool hasPaxi = widget.vm.sellerOffersPaxi;
      final bool hasPudo = widget.vm.sellerOffersPudo;
      
      // Auto-select the only available service
      if (hasPaxi && !hasPudo) {
        setState(() => _selectedType = 'paxi');
      } else if (hasPudo && !hasPaxi) {
        setState(() => _selectedType = 'pudo');
      } else if (hasPaxi) {
        // Default to PAXI if both available
        setState(() => _selectedType = 'paxi');
      }
      
      _loadNearbyPoints();
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _searchAddress(String query) async {
    if (query.length < 3) {
      setState(() {
        _addressSuggestions = [];
        _isSearchingAddress = false;
      });
      return;
    }

    setState(() => _isSearchingAddress = true);

    try {
      final suggestions = await HereMapsAddressService.searchAddresses(
        query: query,
        countryCode: 'ZA',
        limit: 5,
        latitude: -25.7461, // Default South Africa location (Pretoria)
        longitude: 28.1881,
      );

      setState(() {
        _addressSuggestions = suggestions;
        _isSearchingAddress = false;
      });
    } catch (e) {
      print('❌ Error searching addresses: $e');
      setState(() {
        _addressSuggestions = [];
        _isSearchingAddress = false;
      });
    }
  }

  Future<void> _loadPointsForAddress(Map<String, dynamic> address) async {
    final lat = address['latitude'] as double? ?? 0.0;
    final lng = address['longitude'] as double? ?? 0.0;
    
    if (lat == 0.0 || lng == 0.0) return;

    setState(() => _isLoading = true);
    
    try {
      List<Map<String, dynamic>> points = [];
      
      if (_selectedType == 'paxi') {
        points = await PaxiPudoService.getNearbyPaxiPoints(
          latitude: lat,
          longitude: lng,
          radiusKm: 20.0, // Larger radius for address search
        );
      }
      
      setState(() {
        _nearbyPoints = points;
        _isLoading = false;
        _addressSuggestions = [];
      });
      
    } catch (e) {
      print('❌ Error loading points for address: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNearbyPoints() async {
    setState(() => _isLoading = true);
    
    try {
      // Mock user location - in real app, get from GPS
      final double userLat = -25.7461;
      final double userLng = 28.1881;
      
      List<Map<String, dynamic>> points = [];
      
      if (_selectedType == 'paxi') {
        // Get real PAXI pickup points
        points = await PaxiPudoService.getNearbyPaxiPoints(
          latitude: userLat,
          longitude: userLng,
          radiusKm: 15.0,
        );
      } else if (_selectedType == 'pudo') {
        // PUDO is seller-managed - no location selection needed
        // The seller will handle the locker drop-off through their PUDO account
        points = [];
      } else {
        // Get real OmniaSA sellers as pickup points (fallback)
        points = await RealPickupService.getNearbyPickupPoints(
          latitude: userLat,
          longitude: userLng,
          radiusKm: 15.0,
        );
      }
      
      setState(() {
        _nearbyPoints = points;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load pickup points: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wait for seller info to load before checking services
    if (widget.vm.isLoadingSellerInfo) {
      return Container(
        padding: EdgeInsets.all(20),
        margin: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Color(0xFFE9ECEF)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Loading pickup services...',
              style: TextStyle(
                color: AppTheme.deepTeal,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    
    // Check if seller offers any pickup services
    final bool hasPaxi = widget.vm.sellerOffersPaxi;
    final bool hasPudo = widget.vm.sellerOffersPudo;
    final bool hasAnyPickup = hasPaxi || hasPudo;
    
    print('🔍 DEBUG: Pickup services - PAXI: $hasPaxi, PUDO: $hasPudo, Any: $hasAnyPickup');
    
    // If no pickup services available, show message
    if (!hasAnyPickup) {
      return Container(
        padding: EdgeInsets.all(20),
        margin: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Color(0xFFE9ECEF)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              color: Color(0xFF6C757D),
              size: 24,
            ),
            SizedBox(height: 8),
            Text(
              'Pickup services not available',
              style: TextStyle(
                color: Color(0xFF495057),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'This seller doesn\'t offer PAXI or PUDO pickup services.',
              style: TextStyle(
                color: Color(0xFF6C757D),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // STUNNING PAXI/PUDO Type Selector
        Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              // PAXI Card (only if seller offers it)
              if (hasPaxi) Expanded(
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: _selectedType == 'paxi' 
                        ? LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [Colors.white, Color(0xFFF8F9FA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedType == 'paxi' ? Color(0xFFFF6B35) : Color(0xFFE9ECEF),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _selectedType == 'paxi' 
                            ? Color(0xFFFF6B35).withOpacity(0.4)
                            : Colors.black.withOpacity(0.1),
                        blurRadius: _selectedType == 'paxi' ? 20 : 8,
                        offset: Offset(0, _selectedType == 'paxi' ? 8 : 4),
                        spreadRadius: _selectedType == 'paxi' ? 2 : 0,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        setState(() => _selectedType = 'paxi');
                        _loadNearbyPoints();
                      },
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _selectedType == 'paxi'
                                    ? Colors.white.withOpacity(0.2)
                                    : Color(0xFFFF6B35).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(
                                Icons.store_mall_directory,
                                color: _selectedType == 'paxi' ? Colors.white : Color(0xFFFF6B35),
                                size: 22,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'PAXI',
                              style: TextStyle(
                                color: _selectedType == 'paxi' ? Colors.white : Color(0xFF495057),
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                letterSpacing: 0.8,
                              ),
                            ),
                              if (_selectedType == 'paxi')
                              Container(
                                margin: EdgeInsets.only(top: 1),
                                width: 20,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Spacing only if both services available
              if (hasPaxi && hasPudo) SizedBox(width: 16),
              
              // PUDO Card (only if seller offers it)
              if (hasPudo) Expanded(
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: _selectedType == 'pudo' 
                        ? LinearGradient(
                            colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [Colors.white, Color(0xFFF8F9FA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedType == 'pudo' ? Color(0xFF4ECDC4) : Color(0xFFE9ECEF),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _selectedType == 'pudo' 
                            ? Color(0xFF4ECDC4).withOpacity(0.4)
                            : Colors.black.withOpacity(0.1),
                        blurRadius: _selectedType == 'pudo' ? 20 : 8,
                        offset: Offset(0, _selectedType == 'pudo' ? 8 : 4),
                        spreadRadius: _selectedType == 'pudo' ? 2 : 0,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        setState(() {
                          _selectedType = 'pudo';
                          _nearbyPoints = []; // Clear points immediately 
                          _addressSuggestions = []; // Clear address suggestions
                          _isLoading = false;
                        });
                        // For PUDO, we don't load locker locations - seller manages that
                        widget.vm.setSelectedPickupPoint({
                          'id': 'pudo_seller_managed',
                          'name': 'PUDO Locker-to-Door Service',
                          'address': 'Seller will use their PUDO locker',
                          'type': 'pudo',
                          'fees': {'collection': 35.00}, // Standard PUDO fee
                        });
                      },
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _selectedType == 'pudo'
                                    ? Colors.white.withOpacity(0.2)
                                    : Color(0xFF4ECDC4).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(
                                Icons.local_shipping_outlined,
                                color: _selectedType == 'pudo' ? Colors.white : Color(0xFF4ECDC4),
                                size: 22,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'PUDO',
                              style: TextStyle(
                                color: _selectedType == 'pudo' ? Colors.white : Color(0xFF495057),
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                letterSpacing: 0.8,
                              ),
                            ),
                            if (_selectedType == 'pudo')
                              Container(
                                margin: EdgeInsets.only(top: 1),
                                width: 20,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Address search for PAXI
        if (_selectedType == 'paxi') ...[
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cloud.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.deepTeal.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.search_outlined, color: AppTheme.deepTeal, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Search PAXI Collection Area',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.deepTeal,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    hintText: 'Enter area, mall, or suburb (e.g., Sandton)',
                    hintStyle: TextStyle(color: AppTheme.mediumGrey, fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.cloud),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.deepTeal, width: 2),
                    ),
                    suffixIcon: _isSearchingAddress
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(AppTheme.deepTeal),
                            ),
                          )
                        : Icon(Icons.search, color: AppTheme.mediumGrey),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  style: TextStyle(fontSize: 14),
                  onChanged: _searchAddress,
                ),
                
                // Address suggestions
                if (_addressSuggestions.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Container(
                    constraints: BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.cloud),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _addressSuggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _addressSuggestions[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.location_on, color: AppTheme.deepTeal, size: 18),
                          title: Text(
                            suggestion['title'] ?? '',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            suggestion['label'] ?? '',
                            style: TextStyle(fontSize: 11, color: AppTheme.mediumGrey),
                          ),
                          onTap: () {
                            _addressController.text = suggestion['title'] ?? '';
                            _loadPointsForAddress(suggestion);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 12),
        ],
        
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_nearbyPoints.isEmpty && _selectedType != 'pudo')
          Center(
            child: Text(
              'No ${_selectedType.toUpperCase()} points found nearby',
              style: TextStyle(color: Colors.grey[600]),
            ),
          )
        else if (_selectedType == 'pudo')
          // PUDO explanation instead of location list  
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.info.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.info, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PUDO Locker-to-Door Selected',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.info,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  '• Seller will drop your package at their chosen PUDO locker\n'
                  '• PUDO will collect from the locker and deliver to your address\n'
                  '• You\'ll provide your delivery address and phone number below\n'
                  '• Standard PUDO fee: R35.00',
                  style: TextStyle(
                    color: AppTheme.info,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          )
        else if (_selectedType == 'paxi' && _nearbyPoints.isNotEmpty)
          Container(
            constraints: BoxConstraints(
              maxHeight: 400, // Limit height to 400px
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.cloud),
            ),
            child: Scrollbar(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(), // Enable scrolling
                itemCount: _nearbyPoints.length,
                itemBuilder: (context, index) {
                  final point = _nearbyPoints[index];
                  final isSelected = widget.vm.selectedPickupPoint == point;
                  
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(
                              colors: [Colors.white, Color(0xFFFAFAFA)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Color(0xFFFF6B35) : Color(0xFFE9ECEF),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected 
                              ? Color(0xFFFF6B35).withOpacity(0.3)
                              : Colors.black.withOpacity(0.08),
                          blurRadius: isSelected ? 12 : 6,
                          offset: Offset(0, isSelected ? 6 : 3),
                          spreadRadius: isSelected ? 1 : 0,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            widget.vm.setSelectedPickupPoint(point);
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Enhanced Icon
                              AnimatedContainer(
                                duration: Duration(milliseconds: 200),
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.2)
                                      : Color(0xFFFF6B35).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.store_mall_directory,
                                  color: isSelected ? Colors.white : Color(0xFFFF6B35),
                                  size: 24,
                                ),
                              ),
                              
                              SizedBox(width: 16),
                              
                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Store Name
                                    Text(
                                      point['name'] ?? 'PAXI Point',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Color(0xFF2D3748),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    
                                    SizedBox(height: 4),
                                    
                                    // Brand & Address
                                    if (point['brand'] != null)
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isSelected 
                                              ? Colors.white.withOpacity(0.2)
                                              : Color(0xFFFF6B35).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${point['brand']}',
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : Color(0xFFFF6B35),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    
                                    SizedBox(height: 8),
                                    
                                    // Address
                                    Text(
                                      point['address'] ?? 'Address not available',
                                      style: TextStyle(
                                        color: isSelected 
                                            ? Colors.white.withOpacity(0.9)
                                            : Color(0xFF718096),
                                        fontSize: 13,
                                        height: 1.3,
                                      ),
                                    ),
                                    
                                    SizedBox(height: 6),
                                    
                                    // Operating Hours & Distance
                                    Row(
                                      children: [
                                        if (point['operatingHours'] != null) ...[
                                          Icon(
                                            Icons.access_time,
                                            size: 14,
                                            color: isSelected 
                                                ? Colors.white.withOpacity(0.8)
                                                : Color(0xFF718096),
                                          ),
                                          SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              point['operatingHours'] ?? '',
                                              style: TextStyle(
                                                color: isSelected 
                                                    ? Colors.white.withOpacity(0.8)
                                                    : Color(0xFF718096),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                        
                                        if (point['distance'] != null) ...[
                                          SizedBox(width: 8),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isSelected 
                                                  ? Colors.white.withOpacity(0.2)
                                                  : Colors.green.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.location_on,
                                                  size: 12,
                                                  color: isSelected 
                                                      ? Colors.white.withOpacity(0.8)
                                                      : Colors.green,
                                                ),
                                                SizedBox(width: 2),
                                                Text(
                                                  point['distance'] ?? '',
                                                  style: TextStyle(
                                                    color: isSelected 
                                                        ? Colors.white.withOpacity(0.8)
                                                        : Colors.green,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 11,
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
                              
                              // Selection Indicator
                              if (isSelected)
                                Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.check,
                                    color: Color(0xFFFF6B35),
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          )
        else if (_selectedType == 'paxi')
          Center(
            child: Text(
              'No PAXI points found nearby',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }
}

// Product Handling Instructions
class _ProductHandlingInstructions extends StatelessWidget {
  final CheckoutV2ViewModel vm;
  const _ProductHandlingInstructions({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cloud.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.deepTeal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note_outlined, color: AppTheme.deepTeal, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Special Handling Instructions (Optional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.deepTeal,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Add any special instructions for the seller and delivery team (e.g., "Fragile", "Keep upright", "Handle with care").',
            style: TextStyle(
              color: AppTheme.deepTeal,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          
          TextField(
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter special handling instructions (optional - can be left empty)...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.deepTeal.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.deepTeal, width: 2),
              ),
              filled: true,
              fillColor: AppTheme.angel,
              contentPadding: EdgeInsets.all(12),
              suffixIcon: IconButton(
                icon: Icon(Icons.clear, color: AppTheme.mediumGrey),
                onPressed: () {
                  // Clear the text field
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final textField = FocusScope.of(context).focusedChild;
                    if (textField != null) {
                      textField.unfocus();
                    }
                  });
                  vm.setSpecialHandlingInstructions(null);
                },
                tooltip: 'Clear instructions',
              ),
            ),
            onChanged: (value) {
              vm.setSpecialHandlingInstructions(value.trim().isEmpty ? null : value);
            },
          ),
        ],
      ),
    );
  }
}

// Payment Method Selection
class _PaymentMethodSelection extends StatelessWidget {
  final CheckoutV2ViewModel vm;
  const _PaymentMethodSelection({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.breeze.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: AppTheme.deepTeal, size: 20),
              const SizedBox(width: 8),
              Text(
                'Payment Method',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.deepTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // PayFast (Cards)
          _PaymentMethodTile(
            title: 'Card Payment',
            subtitle: 'Credit/Debit card via PayFast',
            icon: Icons.credit_card,
            isSelected: vm.selectedPaymentMethod == 'payfast',
            onTap: () => vm.setPaymentMethod('payfast'),
            trailingWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.security, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                Text('Secure', style: TextStyle(color: Colors.green, fontSize: 12)),
              ],
            ),
          ),
          
          // EFT
          _PaymentMethodTile(
            title: 'Bank Transfer (EFT)',
            subtitle: 'Manual bank transfer',
            icon: Icons.account_balance,
            isSelected: vm.selectedPaymentMethod == 'eft',
            onTap: () => vm.setPaymentMethod('eft'),
            trailingWidget: Text(
              'Manual verification',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
          
          // Cash on Delivery (only for delivery, and only when KYC approved and seller allows COD)
          if (vm.isDelivery && vm.codEnabledForSeller)
            _PaymentMethodTile(
              title: 'Cash on Delivery',
              subtitle: 'Pay when order is delivered',
              icon: Icons.money,
              isSelected: vm.selectedPaymentMethod == 'cod',
              onTap: () => vm.setPaymentMethod('cod'),
              trailingWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time, color: AppTheme.deepTeal, size: 16),
                  const SizedBox(width: 4),
                  Text('On delivery', style: TextStyle(color: AppTheme.deepTeal, fontSize: 12)),
                ],
              ),
            ),
          if (vm.isDelivery && !vm.codEnabledForSeller)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      (() {
                        if ((vm.kycStatus ?? '').toLowerCase() != 'approved') {
                          return 'Cash on Delivery unavailable: KYC not approved.';
                        }
                        if (vm.sellerOutstandingFees > 0.0) {
                          return 'Cash on Delivery unavailable: outstanding fees R${vm.sellerOutstandingFees.toStringAsFixed(2)}';
                        }
                        if (!vm.allowCOD) {
                          return 'Cash on Delivery disabled by seller.';
                        }
                        return 'Cash on Delivery unavailable.';
                      })(),
                      style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Widget _kvRow(String label, String value, {bool canCopy = false}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          flex: 4,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        if (canCopy)
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
            },
          ),
      ],
    ),
  );
}

class _PaymentMethodTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? trailingWidget;

  const _PaymentMethodTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.deepTeal.withOpacity(0.1) : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? AppTheme.deepTeal : Colors.grey.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSelected ? AppTheme.deepTeal : Colors.grey[400],
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: trailingWidget ?? (isSelected 
            ? Icon(Icons.check_circle, color: AppTheme.deepTeal)
            : Icon(Icons.radio_button_unchecked, color: Colors.grey)),
        onTap: onTap,
      ),
    );
  }
}

// PUDO Delivery Details Section
class _PudoDeliveryDetails extends StatelessWidget {
  final CheckoutV2ViewModel vm;
  const _PudoDeliveryDetails({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppTheme.cardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardElevation,
        border: Border.all(
          color: AppTheme.breeze.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppTheme.lightGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.cloud.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.local_shipping,
                  color: AppTheme.deepTeal,
                  size: 22,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PUDO Locker-to-Door Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: AppTheme.deepTeal,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Where should PUDO deliver after locker pickup?',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.mediumGrey,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // PUDO Delivery Address
          SmartAddressInput(
            hintText: 'Enter final delivery address for PUDO...',
            onAddressSelected: (address) {
              if (address != null) {
                vm.setPudoDeliveryAddress(address);
              }
            },
          ),
          
          SizedBox(height: 16),
          
          // PUDO Delivery Phone
          PhoneNumberInput(
            initialPhone: vm.pudoDeliveryPhone,
            hintText: '6x xxx xxxx',
            onPhoneChanged: (phone) {
              vm.setPudoDeliveryPhone(phone);
            },
          ),
          
          // PUDO Process Explanation
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.info.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.info,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'PUDO Locker-to-Door Process',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.info,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                _buildStep('1', 'Seller drops package at PUDO locker'),
                _buildStep('2', 'PUDO collects from locker'),
                _buildStep('3', 'PUDO delivers to your address above'),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStep(String number, String description) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.info,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: AppTheme.angel,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                color: AppTheme.info,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerInformation extends StatelessWidget {
  final CheckoutV2ViewModel vm;
  const _CustomerInformation({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.deepTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_outline,
                  color: AppTheme.deepTeal,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Information',
                      style: TextStyle(
                        color: AppTheme.deepTeal,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Required for delivery and order management',
                      style: TextStyle(
                        color: AppTheme.breeze,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Name input fields
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'First Name *',
                      style: TextStyle(
                        color: AppTheme.deepTeal,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      onChanged: vm.setFirstName,
                      decoration: InputDecoration(
                        hintText: 'Enter first name',
                        hintStyle: TextStyle(
                          color: AppTheme.breeze.withOpacity(0.6),
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: AppTheme.angel,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppTheme.whisper.withOpacity(0.6),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppTheme.deepTeal,
                            width: 2,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      style: TextStyle(
                        color: AppTheme.deepTeal,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Name *',
                      style: TextStyle(
                        color: AppTheme.deepTeal,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      onChanged: vm.setLastName,
                      decoration: InputDecoration(
                        hintText: 'Enter last name',
                        hintStyle: TextStyle(
                          color: AppTheme.breeze.withOpacity(0.6),
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: AppTheme.angel,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppTheme.whisper.withOpacity(0.6),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppTheme.deepTeal,
                            width: 2,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      style: TextStyle(
                        color: AppTheme.deepTeal,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Phone number field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phone Number *',
                style: TextStyle(
                  color: AppTheme.deepTeal,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                onChanged: vm.setCustomerPhone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Enter phone number (e.g., 0123456789)',
                  hintStyle: TextStyle(
                    color: AppTheme.breeze.withOpacity(0.6),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: AppTheme.angel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.whisper.withOpacity(0.6),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.deepTeal,
                      width: 2,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: TextStyle(
                  color: AppTheme.deepTeal,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
