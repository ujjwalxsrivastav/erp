import 'dart:io';
import 'package:supabase/supabase.dart';
import 'package:dotenv/dotenv.dart';

void main() async {
  var env = DotEnv(includePlatformEnvironment: true)..load();
  final supabaseUrl = env['SUPABASE_URL']!;
  final supabaseKey = env['SUPABASE_ANON_KEY']!;
  final client = SupabaseClient(supabaseUrl, supabaseKey);

  final res = await client.from('transport_buses').select('bus_number, current_occupancy, capacity, route_id').order('bus_number', ascending: true);
  print(res);
  exit(0);
}
