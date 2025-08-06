import 'package:cloud_firestore/cloud_firestore.dart';

class PaginationService {
  static const int defaultPageSize = 10;
  static const int maxPageSize = 50;

  // Generic pagination for Firestore queries
  static Query<T> paginateQuery<T>({
    required Query<T> baseQuery,
    int pageSize = defaultPageSize,
    DocumentSnapshot? lastDocument,
    String? orderByField,
    bool descending = true,
  }) {
    Query<T> query = baseQuery;
    
    // Add ordering if specified
    if (orderByField != null) {
      query = query.orderBy(orderByField, descending: descending);
    }
    
    // Add pagination
    query = query.limit(pageSize);
    
    // Add start after if we have a last document
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }
    
    return query;
  }

  // Get stores with pagination
  static Query<Map<String, dynamic>> getStoresPaginated({
    int pageSize = defaultPageSize,
    DocumentSnapshot? lastDocument,
    String? category,
    bool? isVerified,
  }) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        .where('isStore', isEqualTo: true);
    
    // Add filters
    if (category != null) {
      query = query.where('storeCategory', isEqualTo: category);
    }
    
    if (isVerified != null) {
      query = query.where('isVerified', isEqualTo: isVerified);
    }
    
    return paginateQuery(
      baseQuery: query,
      pageSize: pageSize,
      lastDocument: lastDocument,
      orderByField: 'storeName',
      descending: false,
    );
  }

  // Get reviews with pagination
  static Query<Map<String, dynamic>> getReviewsPaginated({
    required String storeId,
    int pageSize = defaultPageSize,
    DocumentSnapshot? lastDocument,
  }) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('reviews')
        .where('storeId', isEqualTo: storeId);
    
    return paginateQuery(
      baseQuery: query,
      pageSize: pageSize,
      lastDocument: lastDocument,
      orderByField: 'timestamp',
      descending: true,
    );
  }

  // Get products with pagination
  static Query<Map<String, dynamic>> getProductsPaginated({
    required String storeId,
    int pageSize = defaultPageSize,
    DocumentSnapshot? lastDocument,
    String? category,
  }) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('products')
        .where('ownerId', isEqualTo: storeId);
    
    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }
    
    return paginateQuery(
      baseQuery: query,
      pageSize: pageSize,
      lastDocument: lastDocument,
      orderByField: 'name',
      descending: false,
    );
  }

  // Check if there are more documents
  static bool hasMoreDocuments(QuerySnapshot snapshot, int pageSize) {
    return snapshot.docs.length == pageSize;
  }

  // Get the last document for next page
  static DocumentSnapshot? getLastDocument(QuerySnapshot snapshot) {
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.last;
    }
    return null;
  }

  // Calculate total pages (estimate)
  static int estimateTotalPages(int totalItems, int pageSize) {
    return (totalItems / pageSize).ceil();
  }

  // Validate page size
  static int validatePageSize(int pageSize) {
    if (pageSize <= 0) return defaultPageSize;
    if (pageSize > maxPageSize) return maxPageSize;
    return pageSize;
  }
} 