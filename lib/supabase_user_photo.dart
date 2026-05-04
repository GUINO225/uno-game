import 'package:supabase_flutter/supabase_flutter.dart';

String supabaseUserPhotoUrl(User user) {
  return (user.userMetadata?['avatar_url'] as String?) ??
      (user.userMetadata?['picture'] as String?) ??
      '';
}
