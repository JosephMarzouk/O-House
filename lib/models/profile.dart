class Profile {
  final String id;
  final String name;
  final String? phone;
  final String role; // admin | manager | inspector | cleaner
  // The role's own name from /me's `access.role` (a custom role like "Head of
  // Sports" has no key). Null from an API that predates custom roles.
  final String? roleNameEn;
  final String? roleNameAr;
  final String locale; // en | ar
  final bool active;
  final bool mustChangePassword;

  const Profile({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.roleNameEn,
    this.roleNameAr,
    required this.locale,
    required this.active,
    required this.mustChangePassword,
  });

  /// [json] is /me's profile, with its `access` merged in by profileFetchProvider
  /// so the cached row carries the role name offline too.
  factory Profile.fromJson(Map<String, dynamic> json) {
    final access = json['access'] as Map<String, dynamic>?;
    final accessRole = access?['role'] as Map<String, dynamic>?;
    return Profile(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? 'cleaner',
      roleNameEn: accessRole?['name_en'] as String?,
      roleNameAr: accessRole?['name_ar'] as String?,
      locale: json['locale'] as String? ?? 'en',
      active: json['active'] as bool? ?? true,
      mustChangePassword: json['must_change_password'] as bool? ?? false,
    );
  }
}
