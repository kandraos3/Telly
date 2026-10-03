import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The app-wide Supabase client. `main()` calls `Supabase.initialize` before `runApp`;
/// tests override this provider (there is no silent fallback to a mock).
final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);
