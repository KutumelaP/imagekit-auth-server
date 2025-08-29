import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'seller_management_table.dart';
import 'section_header.dart';

class SellersSection extends StatelessWidget {
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;
  
  const SellersSection({
    Key? key, 
    this.auth,
    this.firestore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('Seller Management'),
          const SizedBox(height: 16),
          SizedBox(
            height: 600,
            child: SellerManagementTable(
              auth: auth ?? FirebaseAuth.instance,
              firestore: firestore ?? FirebaseFirestore.instance,
            ),
          ),
        ],
      ),
    );
  }
} 