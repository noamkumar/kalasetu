library;

/// KalaSetu AI Image Studio - Image Edit & Voice Command Models
/// Section 7 of Project Specification

class EditOperation {
  final String type;
  final dynamic value;
  final int? width;
  final String? color;
  final Map<String, dynamic>? params;

  const EditOperation({
    required this.type,
    this.value,
    this.width,
    this.color,
    this.params,
  });

  factory EditOperation.fromJson(Map<String, dynamic> json) {
    return EditOperation(
      type: json['type']?.toString() ?? '',
      value: json['value'],
      width: json['width'] as int?,
      color: json['color']?.toString(),
      params: json['params'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'type': type,
    };
    if (value != null) map['value'] = value;
    if (width != null) map['width'] = width;
    if (color != null) map['color'] = color;
    if (params != null) map['params'] = params;
    return map;
  }
}

class EditImageResponse {
  final String status;
  final String imageId;
  final String imageUrl;
  final String originalUrl;
  final List<EditOperation> operations;
  final bool canUndo;
  final bool canRedo;
  final String? message;
  final bool warnProductChange;
  final String? productWarning;
  final bool productChanged;

  const EditImageResponse({
    required this.status,
    required this.imageId,
    required this.imageUrl,
    required this.originalUrl,
    required this.operations,
    required this.canUndo,
    required this.canRedo,
    this.message,
    this.warnProductChange = false,
    this.productWarning,
    this.productChanged = false,
  });

  factory EditImageResponse.fromJson(Map<String, dynamic> json) {
    final opsRaw = (json['operations'] as List<dynamic>?) ?? [];
    final ops = opsRaw
        .map((e) => EditOperation.fromJson(e as Map<String, dynamic>))
        .toList();

    return EditImageResponse(
      status: json['status']?.toString() ?? 'success',
      imageId: json['image_id']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      originalUrl: json['original_url']?.toString() ?? '',
      operations: ops,
      canUndo: json['can_undo'] as bool? ?? false,
      canRedo: json['can_redo'] as bool? ?? false,
      message: json['message']?.toString(),
      warnProductChange: json['warn_product_change'] as bool? ?? false,
      productWarning: json['product_warning']?.toString(),
      productChanged: json['product_changed'] as bool? ?? false,
    );
  }
}

class VoiceCommandResponse {
  final String status;
  final String transcript;
  final List<EditOperation> operations;
  final List<EditOperation> newOperations;
  final String action;
  final String confirmation;
  final bool clarificationNeeded;
  final String? clarifyingQuestion;
  final bool aiEditAvailable;
  final String? imageId;
  final String? imageUrl;
  final String? originalUrl;
  final bool canUndo;
  final bool canRedo;
  final bool warnProductChange;
  final String? productWarning;
  final bool productChanged;

  const VoiceCommandResponse({
    required this.status,
    required this.transcript,
    required this.operations,
    required this.newOperations,
    required this.action,
    required this.confirmation,
    required this.clarificationNeeded,
    this.clarifyingQuestion,
    required this.aiEditAvailable,
    this.imageId,
    this.imageUrl,
    this.originalUrl,
    required this.canUndo,
    required this.canRedo,
    this.warnProductChange = false,
    this.productWarning,
    this.productChanged = false,
  });

  factory VoiceCommandResponse.fromJson(Map<String, dynamic> json) {
    final opsRaw = (json['operations'] as List<dynamic>?) ?? [];
    final ops = opsRaw
        .map((e) => EditOperation.fromJson(e as Map<String, dynamic>))
        .toList();

    final newOpsRaw = (json['new_operations'] as List<dynamic>?) ?? [];
    final newOps = newOpsRaw
        .map((e) => EditOperation.fromJson(e as Map<String, dynamic>))
        .toList();

    return VoiceCommandResponse(
      status: json['status']?.toString() ?? 'success',
      transcript: json['transcript']?.toString() ?? '',
      operations: ops,
      newOperations: newOps,
      action: json['action']?.toString() ?? 'apply',
      confirmation: json['confirmation']?.toString() ?? '',
      clarificationNeeded: json['clarification_needed'] as bool? ?? false,
      clarifyingQuestion: json['clarifying_question']?.toString(),
      aiEditAvailable: json['ai_edit_available'] as bool? ?? false,
      imageId: json['image_id']?.toString(),
      imageUrl: json['image_url']?.toString(),
      originalUrl: json['original_url']?.toString(),
      canUndo: json['can_undo'] as bool? ?? false,
      canRedo: json['can_redo'] as bool? ?? false,
      warnProductChange: json['warn_product_change'] as bool? ?? false,
      productWarning: json['product_warning']?.toString(),
      productChanged: json['product_changed'] as bool? ?? false,
    );
  }
}
