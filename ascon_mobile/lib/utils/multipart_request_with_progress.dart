import 'dart:async';
import 'package:http/http.dart' as http;

class MultipartRequestWithProgress extends http.MultipartRequest {
  final void Function(int bytes, int totalBytes) onProgress;

  MultipartRequestWithProgress(String method, Uri url, {required this.onProgress})
      : super(method, url);

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    final total = contentLength;
    int bytes = 0;

    final transformer = StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (data, sink) {
        bytes += data.length;
        onProgress(bytes, total);
        sink.add(data);
      },
    );

    return http.ByteStream(byteStream.transform(transformer));
  }
}