class ApiError {
  final String code;
  final String message;

  ApiError({required this.code, required this.message});

  factory ApiError.fromJson(Map<String, dynamic> json) {
    // Популярные варианты формата:
    // { code: 'ERR', message: '...' }
    // { error: { code: 'ERR', message: '...' } }
    // { error: '...', code: '...' }
    // { message: '...' } / { detail: '...' }
    final root = json['error'];

    String extractCode(dynamic v) {
      if (v == null) return 'unknown';
      if (v is String && v.trim().isNotEmpty) return v;
      if (v is num) return v.toString();
      return 'unknown';
    }

    String extractMessage(dynamic v) {
      if (v == null) return 'Неизвестная ошибка';
      if (v is String && v.trim().isNotEmpty) return v;
      if (v is List) return v.join(', ');
      if (v is Map) return v['message']?.toString() ?? v.toString();
      return v.toString();
    }

    if (root is Map) {
      return ApiError(
        code: extractCode(root['code'] ?? json['code']),
        message: extractMessage(
          root['message'] ??
              root['detail'] ??
              json['message'] ??
              json['detail'],
        ),
      );
    }

    return ApiError(
      code: extractCode(json['code']),
      message: extractMessage(json['message'] ?? json['detail'] ?? root),
    );
  }

  Map<String, dynamic> toJson() {
    return {'code': code, 'message': message};
  }

  @override
  String toString() => 'ApiError(code: ' + code + ', message: ' + message + ')';
}
