import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '/core/models/api_error.dart';
import 'dart:developer' as developer;

class ApiClient {
  final Dio _dio;
  final String baseUrl;

  ApiClient({required this.baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ) {
    if (kIsWeb) {
      (_dio.httpClientAdapter as dynamic).withCredentials = true;
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          developer.log(
            'HTTP ${options.method} ${options.uri}',
            name: 'ApiClient',
          );
          developer.log(
            'Headers: ${options.headers}',
            name: 'ApiClient',
          );
          if (options.data != null) {
            developer.log(
              'Request data: ${options.data}',
              name: 'ApiClient',
            );
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          developer.log(
            'Response data: ${response.data}',
            name: 'ApiClient',
          );
          return handler.next(response);
        },
        onError: (error, handler) {
          final status = error.response?.statusCode;

          if (status == 401 || status == 403) {
            return handler.next(error);
          }

          developer.log(
            'HTTP Error $status from ${error.requestOptions.uri}',
            name: 'ApiClient',
            error: error.message,
          );

          return handler.next(error);
        },
      ),
    );
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic data) fromJson,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(
          extra: {'withCredentials': true},
        ),
      );
      return fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic data) fromJson,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          extra: {'withCredentials': true},
        ),
      );
      return fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic data) fromJson,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          extra: {'withCredentials': true},
        ),
      );
      return fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<T> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic data) fromJson,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        queryParameters: queryParameters,
        options: Options(
          extra: {'withCredentials': true},
        ),
      );
      return fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    if (e.response != null) {
      if (e.response?.data != null &&
          e.response?.data is Map<String, dynamic>) {
        try {
          final error = ApiError.fromJson(e.response?.data);
          return Exception('${error.code}: ${error.message}');
        } catch (_) {
          return Exception('Ошибка: ${e.response?.statusCode}');
        }
      }
      return Exception('Ошибка: ${e.response?.statusCode}');
    }
    return Exception('Ошибка соединения: ${e.message}');
  }
}
