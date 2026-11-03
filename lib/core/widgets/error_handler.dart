import 'package:flutter/material.dart';

/// Global error handler widget that catches errors and shows user-friendly messages
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace? stackTrace)? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
  }

  void _retry() {
    setState(() {
      _error = null;
      _stackTrace = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.onError != null) {
        return widget.onError!(_error!, _stackTrace);
      }
      return ErrorDisplay(
        error: _error!,
        onRetry: _retry,
      );
    }

    return widget.child;
  }
}

/// Standard error display widget
class ErrorDisplay extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final String? customMessage;
  final IconData icon;

  const ErrorDisplay({
    super.key,
    required this.error,
    this.onRetry,
    this.customMessage,
    this.icon = Icons.error_outline,
  });

  String get _userFriendlyMessage {
    if (customMessage != null) return customMessage!;

    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'No internet connection. Please check your network.';
    }
    if (errorStr.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    if (errorStr.contains('401') || errorStr.contains('unauthorized')) {
      return 'Please login again.';
    }
    if (errorStr.contains('404') || errorStr.contains('not found')) {
      return 'The requested data was not found.';
    }
    if (errorStr.contains('500') || errorStr.contains('server')) {
      return 'Server error. Please try again later.';
    }

    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _userFriendlyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state widget
class EmptyState extends StatelessWidget {
  final String message;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.message,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading state with optional message
class LoadingState extends StatelessWidget {
  final String? message;

  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Async data builder that handles loading, error, and empty states
class AsyncDataBuilder<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T data) builder;
  final String? loadingMessage;
  final String? emptyMessage;
  final bool Function(T data)? isEmpty;
  final VoidCallback? onRetry;

  const AsyncDataBuilder({
    super.key,
    required this.future,
    required this.builder,
    this.loadingMessage,
    this.emptyMessage,
    this.isEmpty,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LoadingState(message: loadingMessage);
        }

        if (snapshot.hasError) {
          return ErrorDisplay(
            error: snapshot.error!,
            onRetry: onRetry,
          );
        }

        if (!snapshot.hasData) {
          return EmptyState(
            message: emptyMessage ?? 'No data available',
          );
        }

        final data = snapshot.data as T;

        // Check if data is empty
        if (isEmpty != null && isEmpty!(data)) {
          return EmptyState(
            message: emptyMessage ?? 'No data available',
          );
        }

        // Check for list types
        if (data is List && data.isEmpty) {
          return EmptyState(
            message: emptyMessage ?? 'No items found',
          );
        }

        return builder(data);
      },
    );
  }
}
