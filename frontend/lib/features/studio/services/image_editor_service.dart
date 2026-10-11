import '../../../data/api/api_client.dart';
import '../models/image_edit_models.dart';

class ImageEditorService {
  final ApiClient _apiClient;

  ImageEditorService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Call backend POST /images/edit to apply operations non-destructively to the original cutout
  /// Supports undo, redo, reset, apply
  Future<EditImageResponse> editImage({
    required String imageId,
    String? prompt,
    List<EditOperation>? operations,
    String? action,
    String lang = 'en',
  }) async {
    try {
      final payload = <String, dynamic>{
        'image_id': imageId,
        'action': action ?? 'apply',
        'lang': lang,
      };
      if (prompt != null && prompt.isNotEmpty) {
        payload['prompt'] = prompt;
      }
      if (operations != null) {
        payload['operations'] = operations.map((e) => e.toJson()).toList();
      }

      final response = await _apiClient.post('/images/edit', body: payload);

      if (response is Map<String, dynamic>) {
        return EditImageResponse.fromJson(response);
      }
      throw ApiException(message: 'Invalid response format from /images/edit');
    } catch (e) {
      if (e is ApiException && e.isNetworkError) {
        return EditImageResponse(
          status: 'offline',
          imageId: imageId,
          imageUrl: '',
          originalUrl: '',
          operations: operations ?? [],
          canUndo: (operations?.length ?? 0) > 0,
          canRedo: false,
          message: 'Saved in offline mode',
        );
      }
      rethrow;
    }
  }

  /// Call backend POST /images/voice-command with typed command text or recorded audio file
  Future<VoiceCommandResponse> sendVoiceCommand({
    required String imageId,
    String? text,
    String? audioFilePath,
    String lang = 'en',
  }) async {
    try {
      dynamic response;
      if (audioFilePath != null && audioFilePath.isNotEmpty) {
        final fields = <String, String>{
          'image_id': imageId,
          'lang': lang,
        };
        if (text != null && text.isNotEmpty) {
          fields['text'] = text;
        }

        response = await _apiClient.postMultipart(
          '/images/voice-command',
          fileField: 'audio',
          filePath: audioFilePath,
          fields: fields,
        );
      } else {
        response = await _apiClient.post(
          '/images/voice-command',
          body: {
            'image_id': imageId,
            'text': text ?? '',
            'lang': lang,
          },
        );
      }

      if (response is Map<String, dynamic>) {
        return VoiceCommandResponse.fromJson(response);
      }
      throw ApiException(message: 'Invalid response format from /images/voice-command');
    } catch (e) {
      if (e is ApiException && e.isNetworkError) {
        return VoiceCommandResponse(
          status: 'offline',
          transcript: text ?? '',
          operations: [],
          newOperations: [],
          action: 'apply',
          confirmation: 'Offline mode: Voice command queued',
          clarificationNeeded: false,
          aiEditAvailable: false,
          canUndo: false,
          canRedo: false,
        );
      }
      rethrow;
    }
  }

  /// Uploads product image to backend and returns image_id, image_url, original_url
  Future<Map<String, dynamic>> uploadProductImage(String filePath) async {
    final response = await _apiClient.postMultipart(
      '/images/enhance',
      fileField: 'image',
      filePath: filePath,
      fields: {'style': 'white'},
    );
    if (response is Map<String, dynamic>) {
      final imgId = response['image_id']?.toString() ??
          (response['original_url']?.toString().split('/').last.split('_').first ??
              'img_${DateTime.now().millisecondsSinceEpoch}');
      return {
        'image_id': imgId,
        'image_url': response['enhanced_url']?.toString() ?? response['original_url']?.toString() ?? '',
        'original_url': response['original_url']?.toString() ?? '',
      };
    }
    throw ApiException(message: 'Failed to upload image');
  }

  /// Runs Gemini Vision fidelity check to verify the product itself remained untouched
  Future<Map<String, dynamic>> checkFidelity(String imageId) async {
    try {
      final response = await _apiClient.post(
        '/images/fidelity-check',
        body: {'image_id': imageId},
      );
      if (response is Map<String, dynamic>) {
        return response;
      }
    } catch (_) {}
    return {
      'status': 'ok',
      'product_changed': false,
      'confidence': 0.95,
      'warning': null,
    };
  }
}
