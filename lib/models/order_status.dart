import 'package:flutter/material.dart';

enum OrderStatus {
  pending,
  confirmed,
  shippedToPargo,
  arrivedAtPargo,
  readyForCollection,
  collected,
  completed,
  cancelled,
  refunded
}

extension OrderStatusExtension on OrderStatus {
  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.shippedToPargo:
        return 'Shipped to Pickup Point';
      case OrderStatus.arrivedAtPargo:
        return 'Arrived at Pickup Point';
      case OrderStatus.readyForCollection:
        return 'Ready for Collection';
      case OrderStatus.collected:
        return 'Collected';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.refunded:
        return 'Refunded';
    }
  }

  String get description {
    switch (this) {
      case OrderStatus.pending:
        return 'Order is being processed';
      case OrderStatus.confirmed:
        return 'Order confirmed by seller';
      case OrderStatus.shippedToPargo:
        return 'Parcel shipped to pickup point';
      case OrderStatus.arrivedAtPargo:
        return 'Parcel arrived at pickup point';
      case OrderStatus.readyForCollection:
        return 'Ready for collection - bring your order ID';
      case OrderStatus.collected:
        return 'Parcel collected successfully';
      case OrderStatus.completed:
        return 'Order completed';
      case OrderStatus.cancelled:
        return 'Order cancelled';
      case OrderStatus.refunded:
        return 'Order refunded';
    }
  }

  IconData get icon {
    switch (this) {
      case OrderStatus.pending:
        return Icons.schedule;
      case OrderStatus.confirmed:
        return Icons.check_circle;
      case OrderStatus.shippedToPargo:
        return Icons.local_shipping;
      case OrderStatus.arrivedAtPargo:
        return Icons.location_on;
      case OrderStatus.readyForCollection:
        return Icons.store;
      case OrderStatus.collected:
        return Icons.check_circle_outline;
      case OrderStatus.completed:
        return Icons.done_all;
      case OrderStatus.cancelled:
        return Icons.cancel;
      case OrderStatus.refunded:
        return Icons.money_off;
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.shippedToPargo:
        return Colors.purple;
      case OrderStatus.arrivedAtPargo:
        return Colors.indigo;
      case OrderStatus.readyForCollection:
        return Colors.green;
      case OrderStatus.collected:
        return Colors.teal;
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.refunded:
        return Colors.red;
    }
  }

  bool get isCompleted => this == OrderStatus.completed;
  bool get isCancelled => this == OrderStatus.cancelled;
  bool get isRefunded => this == OrderStatus.refunded;
  bool get isActive => !isCompleted && !isCancelled && !isRefunded;
}

// Tracking timeline entry
class TrackingEvent {
  final OrderStatus status;
  final DateTime timestamp;
  final String? description;
  final String? location;
  final String? updatedBy; // 'system', 'seller', 'buyer', 'pargo'

  TrackingEvent({
    required this.status,
    required this.timestamp,
    this.description,
    this.location,
    this.updatedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'location': location,
      'updatedBy': updatedBy,
    };
  }

  factory TrackingEvent.fromMap(Map<String, dynamic> map) {
    return TrackingEvent(
      status: OrderStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => OrderStatus.pending,
      ),
      timestamp: DateTime.parse(map['timestamp']),
      description: map['description'],
      location: map['location'],
      updatedBy: map['updatedBy'],
    );
  }
}

// Pargo pickup details
class PargoPickupDetails {
  final String pickupPointId;
  final String pickupPointName;
  final String pickupPointAddress;
  final double pickupFee;
  final String collectionInstructions;
  final String? trackingNumber;
  final DateTime? estimatedArrival;
  final DateTime? readyForCollection;

  PargoPickupDetails({
    required this.pickupPointId,
    required this.pickupPointName,
    required this.pickupPointAddress,
    required this.pickupFee,
    required this.collectionInstructions,
    this.trackingNumber,
    this.estimatedArrival,
    this.readyForCollection,
  });

  Map<String, dynamic> toMap() {
    return {
      'pickupPointId': pickupPointId,
      'pickupPointName': pickupPointName,
      'pickupPointAddress': pickupPointAddress,
      'pickupFee': pickupFee,
      'collectionInstructions': collectionInstructions,
      'trackingNumber': trackingNumber,
      'estimatedArrival': estimatedArrival?.toIso8601String(),
      'readyForCollection': readyForCollection?.toIso8601String(),
    };
  }

  factory PargoPickupDetails.fromMap(Map<String, dynamic> map) {
    return PargoPickupDetails(
      pickupPointId: map['pickupPointId'] ?? '',
      pickupPointName: map['pickupPointName'] ?? '',
      pickupPointAddress: map['pickupPointAddress'] ?? '',
      pickupFee: (map['pickupFee'] ?? 0.0).toDouble(),
      collectionInstructions: map['collectionInstructions'] ?? '',
      trackingNumber: map['trackingNumber'],
      estimatedArrival: map['estimatedArrival'] != null 
          ? DateTime.parse(map['estimatedArrival']) 
          : null,
      readyForCollection: map['readyForCollection'] != null 
          ? DateTime.parse(map['readyForCollection']) 
          : null,
    );
  }
}
