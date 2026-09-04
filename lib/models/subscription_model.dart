import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionModel {
  final String status; // active | inactive | expired | canceled
  final String? provider; // stripe | google_play | apple | admin
  final String? plan;
  final DateTime? expiresAt;
  final DateTime? updatedAt;

  const SubscriptionModel({
    required this.status,
    this.provider,
    this.plan,
    this.expiresAt,
    this.updatedAt,
  });

  bool get isActive {
    if (status != 'active') return false;
    if (expiresAt == null) return true;
    return expiresAt!.isAfter(DateTime.now());
  }

  String get expiresLabel {
    if (expiresAt == null) return '';
    final d = expiresAt!;
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  static SubscriptionModel? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    return SubscriptionModel(
      status: (map['status'] as String?) ?? 'inactive',
      provider: map['provider'] as String?,
      plan: map['plan'] as String?,
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'status': status,
    if (provider != null) 'provider': provider,
    if (plan != null) 'plan': plan,
    if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static const SubscriptionModel inactive = SubscriptionModel(status: 'inactive');
}
