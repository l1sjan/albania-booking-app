enum AccountRole { customer, businessOwner, admin }

extension AccountRoleValue on AccountRole {
  String get databaseValue => switch (this) {
    AccountRole.customer => 'customer',
    AccountRole.businessOwner => 'business_owner',
    AccountRole.admin => 'admin',
  };
}

class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.email,
    required this.role,
    this.fullName,
    this.phone,
    this.avatarUrl,
  });

  factory AccountProfile.fromJson(Map<String, dynamic> json) {
    return AccountProfile(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: _optionalText(json['full_name']),
      phone: _optionalText(json['phone']),
      avatarUrl: _optionalText(json['avatar_url']),
      role: switch (json['role']?.toString()) {
        'business_owner' => AccountRole.businessOwner,
        'admin' => AccountRole.admin,
        _ => AccountRole.customer,
      },
    );
  }

  final String id;
  final String email;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final AccountRole role;

  bool get isBusinessOwner => role == AccountRole.businessOwner;

  String get displayName {
    final name = fullName?.trim();
    return name == null || name.isEmpty ? email : name;
  }

  static String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
