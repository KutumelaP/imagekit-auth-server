import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../screens/stunning_product_upload.dart';
import '../theme/app_theme.dart';

class SellerActionButton extends StatelessWidget {
  const SellerActionButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Only rebuild this widget when seller status changes
    final bool isSeller = context.select<UserProvider, bool>((p) => p.isSeller);
    
    if (!isSeller) return const SizedBox.shrink();
    
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StunningProductUpload(
            storeId: 'all',
            storeName: 'My Store',
          )),
        );
      },
      backgroundColor: AppTheme.deepTeal,
      foregroundColor: Colors.white,
      child: const Icon(Icons.add_shopping_cart),
      tooltip: 'Upload Product',
    );
  }
}
