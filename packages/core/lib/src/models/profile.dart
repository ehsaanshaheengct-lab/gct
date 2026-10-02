import 'enums.dart';

/// The signed-in user's profile row (public.profiles + its tehsil).
class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.tehsilId,
    required this.tehsilCode,
    required this.tehsilName,
    this.username,
    this.phone,
    this.isActive = true,
  });

  final String id;
  final String fullName;
  final String? username;
  final String? phone;
  final UserRole role;
  final String tehsilId;
  final String tehsilCode;
  final String tehsilName;
  final bool isActive;

  /// Expects `select *, tehsil:tehsils(code, name_en)` from public.profiles.
  factory Profile.fromJson(Map<String, dynamic> j) {
    final t = (j['tehsil'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Profile(
      id: j['id'] as String,
      fullName: j['full_name'] as String? ?? '',
      username: j['username'] as String?,
      phone: j['phone'] as String?,
      role: UserRole.fromDb(j['role'] as String?),
      tehsilId: j['tehsil_id'] as String,
      tehsilCode: t['code'] as String? ?? '',
      tehsilName: t['name_en'] as String? ?? '',
      isActive: j['is_active'] as bool? ?? true,
    );
  }
}
