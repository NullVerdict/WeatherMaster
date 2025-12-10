import 'package:flutter/foundation.dart';

/// Utility for running heavy computations in isolates.
///
/// Use this helper for CPU-intensive operations to keep the UI responsive.
/// The project already uses [compute] in `fetch_data.dart` for JSON processing.
///
/// Example usage:
/// ```dart
/// final result = await computeWithErrorHandling(
///   _processData,
///   inputData,
/// );
/// ```

/// Runs a computation in an isolate with error handling.
///
/// Returns the result of [callback] when passed [message].
/// Logs errors to debug console and rethrows for caller handling.
Future<T> computeWithErrorHandling<T, Q>(
  ComputeCallback<Q, T> callback,
  Q message,
) async {
  try {
    return await compute(callback, message);
  } catch (e) {
    debugPrint('Compute error: $e');
    rethrow;
  }
}

/// Runs a computation in an isolate, suppressing errors.
///
/// Returns null if an error occurs instead of throwing.
/// Useful for non-critical background operations.
Future<T?> computeSafe<T, Q>(
  ComputeCallback<Q, T> callback,
  Q message,
) async {
  try {
    return await compute(callback, message);
  } catch (e) {
    debugPrint('Compute error (suppressed): $e');
    return null;
  }
}
