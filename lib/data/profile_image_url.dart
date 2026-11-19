import 'parabeacon_server_config.dart';

abstract final class ProfileImageUrl {
  static final RegExp _pathPattern = RegExp(
    r'^/api/v1/profile-images/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static Uri? resolve(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = Uri.tryParse(value);
    if (parsed == null ||
        parsed.hasScheme ||
        parsed.hasAuthority ||
        parsed.hasFragment ||
        !_pathPattern.hasMatch(parsed.path) ||
        parsed.hasQuery) {
      return null;
    }
    return ParaBeaconServerConfig.apiBaseUri.resolveUri(parsed);
  }
}
