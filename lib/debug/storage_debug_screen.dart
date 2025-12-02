import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Debug screen to check Supabase storage buckets
/// Add this to your app temporarily to debug the storage issue
class StorageDebugScreen extends StatefulWidget {
  const StorageDebugScreen({super.key});

  @override
  State<StorageDebugScreen> createState() => _StorageDebugScreenState();
}

class _StorageDebugScreenState extends State<StorageDebugScreen> {
  String _debugInfo = 'Loading...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkStorage();
  }

  Future<void> _checkStorage() async {
    setState(() {
      _isLoading = true;
      _debugInfo = 'Checking Supabase connection...\n\n';
    });

    try {
      final supabase = Supabase.instance.client;

      // Check if client is initialized
      _addDebugLine('✅ Supabase client initialized');

      // Check authentication
      final user = supabase.auth.currentUser;
      if (user != null) {
        _addDebugLine('✅ User authenticated: ${user.id}');
      } else {
        _addDebugLine('⚠️ No user authenticated');
      }

      // List all buckets
      _addDebugLine('\n📦 Checking Storage Buckets...');
      try {
        final buckets = await supabase.storage.listBuckets();
        _addDebugLine('✅ Found ${buckets.length} buckets:');
        for (var bucket in buckets) {
          _addDebugLine(
              '   - ${bucket.name} (${bucket.public ? 'public' : 'private'})');
        }

        // Check specific buckets
        _addDebugLine('\n🔍 Checking Required Buckets:');
        final requiredBuckets = ['assignments', 'study-materials'];
        for (var bucketName in requiredBuckets) {
          final exists = buckets.any((b) => b.name == bucketName);
          if (exists) {
            _addDebugLine('   ✅ $bucketName - EXISTS');
          } else {
            _addDebugLine('   ❌ $bucketName - NOT FOUND');
          }
        }

        // Try to access assignments bucket
        _addDebugLine('\n🧪 Testing Bucket Access:');
        try {
          final files = await supabase.storage.from('assignments').list();
          _addDebugLine('   ✅ Can access "assignments" bucket');
          _addDebugLine('   📁 Files in bucket: ${files.length}');
        } catch (e) {
          _addDebugLine('   ❌ Cannot access "assignments" bucket');
          _addDebugLine('   Error: $e');
        }

        // Try to access study-materials bucket
        try {
          final files = await supabase.storage.from('study-materials').list();
          _addDebugLine('   ✅ Can access "study-materials" bucket');
          _addDebugLine('   📁 Files in bucket: ${files.length}');
        } catch (e) {
          _addDebugLine('   ❌ Cannot access "study-materials" bucket');
          _addDebugLine('   Error: $e');
        }
      } catch (e) {
        _addDebugLine('❌ Error listing buckets: $e');
      }

      _addDebugLine('\n✅ Debug check complete!');
    } catch (e) {
      _addDebugLine('❌ Fatal error: $e');
    }

    setState(() => _isLoading = false);
  }

  void _addDebugLine(String line) {
    setState(() {
      _debugInfo += '$line\n';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkStorage,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _debugInfo,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
    );
  }
}
