import 'package:flutter/foundation.dart';

/// Domain entity representing the owner's lottery shop (`shops` table, §6.3).
@immutable
class ShopProfile {
  const ShopProfile({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.ownerName,
    required this.phone,
    required this.district,
    this.agentCode,
    this.defaultLanguage = 'ml',
  });

  final String id;
  final String ownerId;
  final String name;
  final String ownerName;
  final String phone;
  final String district;
  final String? agentCode;
  final String defaultLanguage;

  factory ShopProfile.fromJson(Map<String, dynamic> json) {
    return ShopProfile(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      name: json['name'] as String,
      ownerName: (json['owner_name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      district: (json['district'] as String?) ?? '',
      agentCode: json['agent_code'] as String?,
      defaultLanguage: (json['default_language'] as String?) ?? 'ml',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'owner_name': ownerName,
      'phone': phone,
      'district': district,
      'agent_code': agentCode,
      'default_language': defaultLanguage,
    };
  }
}
