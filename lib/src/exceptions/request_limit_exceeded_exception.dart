import 'package:http/http.dart';

import 'youtube_explode_exception.dart';

/// Exception thrown when a fatal failure occurs.
class RequestLimitExceededException implements YoutubeExplodeException {
  /// Description message
  @override
  final String message;

  /// Initializes an instance of [RequestLimitExceededException]
  RequestLimitExceededException(this.message);

  /// Initializes an instance of [RequestLimitExceeded] with a [Response]
  RequestLimitExceededException.httpRequest(BaseResponse response)
      : message = '''
Failed to perform an HTTP request to YouTube because of rate limiting.
This error indicates that YouTube thinks there were too many requests made from this IP and considers it suspicious.
To resolve this error, please wait some time and try again -or- try injecting an HttpClient that has cookies for an authenticated user.
Unfortunately, there's nothing the library can do to work around this error.
Request: ${response.request}
Response: $response
''';

  @override
  String toString() =>
      '$runtimeType: $message'; // ignore: no_runtimetype_tostring
}
