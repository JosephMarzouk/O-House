class Profile {
  final String id;
  final String name;
  final String? phone;
  final String role; // admin | manager | inspector | cleaner
  final String locale; // en | ar
  final bool active;
  final bool mustChangePassword;

  const Profile({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.locale,
    required this.active,
    required this.mustChangePassword,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String?,
    role: json['role'] as String? ?? 'cleaner',
    locale: json['locale'] as String? ?? 'en',
    active: json['active'] as bool? ?? true,
    mustChangePassword: json['must_change_password'] as bool? ?? false,
  );
}
