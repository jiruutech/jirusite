class AuthUser {
  final String id;
  final String? organizationId;
  final String fullName;
  final String phoneNumber;
  final String role;
  final String preferredLanguage;

  const AuthUser({
    required this.id,
    this.organizationId,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    required this.preferredLanguage,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    organizationId: json['organization_id'] as String?,
    fullName: json['full_name'] as String,
    phoneNumber: json['phone_number'] as String,
    role: json['role'] as String,
    preferredLanguage: json['preferred_language'] as String? ?? 'am',
  );

  bool get isAuthenticated => id.isNotEmpty;
  bool get hasOrganization => organizationId != null && organizationId!.isNotEmpty;

  bool get canApprove => role == 'owner' || role == 'admin';
  bool get canCreateExpense =>
      role == 'owner' || role == 'admin' || role == 'project_manager' || role == 'site_engineer';
  bool get isViewer => role == 'viewer';
}

class AuthAppState {
  final AuthUser? user;
  final bool isLoading;
  final String? error;

  const AuthAppState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;

  AuthAppState copyWith({AuthUser? user, bool? isLoading, String? error}) =>
      AuthAppState(
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}
