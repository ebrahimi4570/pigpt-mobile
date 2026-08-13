import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'brand.dart';
import 'token_store.dart';

typedef UnauthorizedHandler = void Function();
typedef ForbiddenHandler = void Function(String message);

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class StreamCancelled implements Exception {
  const StreamCancelled();
}

class ApiClient {
  ApiClient({
    required TokenStore tokenStore,
    UnauthorizedHandler? onUnauthorized,
    ForbiddenHandler? onForbidden,
    String? baseUrl,
  })  : _tokenStore = tokenStore,
        _onUnauthorized = onUnauthorized,
        _onForbidden = onForbidden {
    _dio = Dio(
      BaseOptions(
        baseUrl: '${baseUrl ?? PigptBrand.apiBase}${PigptBrand.apiPrefix}',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Accept': 'application/json',
          'Accept-Language': 'fa',
          'Content-Type': 'application/json',
        },
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStore.read();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          try {
            final info = await PackageInfo.fromPlatform();
            options.headers['X-PiGPT-Client'] =
                '${PigptBrand.clientHeaderPrefix}/${info.version}';
          } catch (_) {
            options.headers['X-PiGPT-Client'] =
                '${PigptBrand.clientHeaderPrefix}/dev';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final code = error.response?.statusCode;
          if (code == 401) {
            await _tokenStore.clear();
            _onUnauthorized?.call();
          } else if (code == 403) {
            final msg = _messageFrom(error.response?.data) ??
                'این قابلیت در پلن شما فعال نیست';
            _onForbidden?.call(msg);
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  final TokenStore _tokenStore;
  final UnauthorizedHandler? _onUnauthorized;
  final ForbiddenHandler? _onForbidden;

  Dio get raw => _dio;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic data)? parser,
  }) async {
    try {
      final res = await _dio.get<dynamic>(path, queryParameters: query);
      return parser != null ? parser(res.data) : res.data as T;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    T Function(dynamic data)? parser,
  }) async {
    try {
      final res =
          await _dio.post<dynamic>(path, data: data, queryParameters: query);
      return parser != null ? parser(res.data) : res.data as T;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<T> patch<T>(
    String path, {
    Object? data,
    T Function(dynamic data)? parser,
  }) async {
    try {
      final res = await _dio.patch<dynamic>(path, data: data);
      return parser != null ? parser(res.data) : res.data as T;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<T> put<T>(
    String path, {
    Object? data,
    T Function(dynamic data)? parser,
  }) async {
    try {
      final res = await _dio.put<dynamic>(path, data: data);
      return parser != null ? parser(res.data) : res.data as T;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> delete(String path, {Object? data}) async {
    try {
      await _dio.delete<dynamic>(path, data: data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Multipart upload to `/uploads`. Returns `{id, ...}`.
  Future<Map<String, dynamic>> uploadFile(
    String filePath, {
    String fieldName = 'file',
    String? filename,
  }) async {
    return postMultipart(
      '/uploads',
      filePath: filePath,
      fieldName: fieldName,
      filename: filename,
    );
  }

  /// Multipart POST to an arbitrary API path (OCR, STT, CSV analyze, …).
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required String filePath,
    String fieldName = 'file',
    String? filename,
    Map<String, dynamic>? fields,
  }) async {
    try {
      final map = <String, dynamic>{
        fieldName: await MultipartFile.fromFile(
          filePath,
          filename: filename,
        ),
        if (fields != null)
          ...fields.map((k, v) => MapEntry(k, v?.toString() ?? '')),
      };
      final form = FormData.fromMap(map);
      final res = await _dio.post<dynamic>(
        path,
        data: form,
        options: Options(
          contentType: 'multipart/form-data',
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );
      if (res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      throw ApiException('پاسخ آپلود نامعتبر بود');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// POST and consume SSE `text/event-stream` body.
  Stream<SseEvent> postSse(
    String path, {
    Object? data,
    CancelToken? cancelToken,
  }) async* {
    try {
      final res = await _dio.post<ResponseBody>(
        path,
        data: data,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
          receiveTimeout: const Duration(minutes: 10),
        ),
      );
      final stream = res.data!.stream;
      var buffer = '';
      await for (final chunk in stream) {
        buffer += utf8.decode(chunk, allowMalformed: true);
        final parts = buffer.split('\n\n');
        buffer = parts.removeLast();
        for (final part in parts) {
          final event = SseEvent.parse(part);
          if (event != null) yield event;
        }
      }
      if (buffer.trim().isNotEmpty) {
        final event = SseEvent.parse(buffer);
        if (event != null) yield event;
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        throw const StreamCancelled();
      }
      throw _mapError(e);
    }
  }

  Future<List<int>> getBytes(String path) async {
    try {
      final res = await _dio.get<List<int>>(
        path,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      return res.data ?? const [];
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  static String? _messageFrom(dynamic data) {
    if (data is Map) {
      final msg = (data['error_message_fa'] ??
              data['message_fa'] ??
              data['detail'] ??
              data['message'])
          ?.toString();
      if (msg == null || msg.isEmpty) return null;
      if (msg.startsWith('{') || msg.startsWith('[')) return null;
      return msg;
    }
    return null;
  }

  ApiException _mapError(DioException e) {
    final data = e.response?.data;
    String msg = 'خطای شبکه';
    final extracted = _messageFrom(data);
    if (extracted != null) {
      msg = extracted;
    } else if (e.response?.statusCode == 403) {
      msg = 'این قابلیت در پلن شما فعال نیست';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      msg = 'زمان اتصال به پایان رسید. دوباره تلاش کنید.';
    } else if (e.type == DioExceptionType.connectionError) {
      msg = 'اتصال استریم قطع شد. دوباره تلاش کنید.';
    }
    if (kDebugMode) {
      debugPrint('API error ${e.response?.statusCode}: $msg');
    }
    return ApiException(msg, statusCode: e.response?.statusCode);
  }
}

class SseEvent {
  SseEvent({required this.event, required this.data});
  final String event;
  final Map<String, dynamic> data;

  static SseEvent? parse(String raw) {
    if (raw.trim().isEmpty) return null;
    var event = 'message';
    final dataLines = <String>[];
    for (final line in raw.split('\n')) {
      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trim());
      }
    }
    if (dataLines.isEmpty) return null;
    try {
      final decoded = jsonDecode(dataLines.join('\n'));
      if (decoded is Map<String, dynamic>) {
        return SseEvent(event: event, data: decoded);
      }
      return SseEvent(event: event, data: {'value': decoded});
    } catch (_) {
      return SseEvent(event: event, data: {'text': dataLines.join('\n')});
    }
  }
}
