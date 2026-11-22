/// Typed API error with human-readable messages mapped from HTTP status codes.
class ApiException implements Exception {
  final int? statusCode;
  final String message;

  /// True when retrying the same request could plausibly succeed.
  final bool retryable;

  const ApiException(this.message, {this.statusCode, this.retryable = false});

  factory ApiException.fromStatus(int statusCode, String? serverDetail) {
    final String detail =
        (serverDetail != null && serverDetail.trim().isNotEmpty)
            ? serverDetail.trim()
            : '';
    switch (statusCode) {
      case 401:
        return ApiException(
          'Your API token is invalid or has expired. Please check it in '
          'Settings → API Token and try again.',
          statusCode: statusCode,
        );
      case 403:
        return const ApiException(
          'You do not have permission to use this feature. Your plan may '
          'not include it.',
          statusCode: 403,
        );
      case 404:
        return const ApiException(
          'The requested item could not be found.',
          statusCode: 404,
        );
      case 413:
        return const ApiException(
          'Your request is too large. Please shorten the text and try again.',
          statusCode: 413,
        );
      case 422:
        return ApiException(
          detail.isNotEmpty
              ? 'Invalid request: $detail'
              : 'Some of the request parameters are invalid. Please check '
                  'your voice, style, engine and settings.',
          statusCode: statusCode,
        );
      case 429:
        return const ApiException(
          'Your request limit has been reached. Please wait a moment and '
          'try again.',
          statusCode: statusCode,
          retryable: true,
        );
      case 502:
        return const ApiException(
          'The voice provider returned an error. Please retry.',
          statusCode: statusCode,
          retryable: true,
        );
      case 503:
        return const ApiException(
          'The voice service is temporarily unavailable. Please retry in a '
          'moment.',
          statusCode: statusCode,
          retryable: true,
        );
      case 504:
        return const ApiException(
          'The request timed out. Please check your connection and retry.',
          statusCode: statusCode,
          retryable: true,
        );
      default:
        return ApiException(
          detail.isNotEmpty
              ? detail
              : 'Something went wrong (error $statusCode). Please retry.',
          statusCode: statusCode,
          retryable: statusCode >= 500,
        );
    }
  }

  @override
  String toString() => message;
}

/// Thrown when there is no network connectivity at all.
class NetworkException implements Exception {
  final String message;
  const NetworkException(
      [this.message =
          'Unable to connect to Panda AI. Check your connection and try again.']);

  @override
  String toString() => message;
}

/// Thrown when an audio endpoint did not return valid MP3 data.
class InvalidAudioException implements Exception {
  final String message;
  const InvalidAudioException(
      [this.message =
          'The server did not return valid audio. Please retry.']);

  @override
  String toString() => message;
}
