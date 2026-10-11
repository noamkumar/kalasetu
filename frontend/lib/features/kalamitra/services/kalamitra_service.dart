import '../../../data/api/api_client.dart';
import 'kalamitra_faq_service.dart';

class KalaMitraResponse {
  final String reply;
  final String action;
  final String? route;
  final String? targetLang;
  final List<String> suggestions;
  final String? imageId;
  final String? imageUrl;
  final bool? canUndo;
  final bool? canRedo;

  KalaMitraResponse({
    required this.reply,
    this.action = 'none',
    this.route,
    this.targetLang,
    this.suggestions = const [],
    this.imageId,
    this.imageUrl,
    this.canUndo,
    this.canRedo,
  });

  factory KalaMitraResponse.fromJson(Map<String, dynamic> json) {
    return KalaMitraResponse(
      reply: json['reply']?.toString() ?? 'Namaste! How can I help you today?',
      action: json['action']?.toString() ?? 'none',
      route: json['route']?.toString(),
      targetLang: json['target_lang']?.toString(),
      suggestions: (json['suggestions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      imageId: json['image_id']?.toString(),
      imageUrl: json['image_url']?.toString(),
      canUndo: json['can_undo'] as bool?,
      canRedo: json['can_redo'] as bool?,
    );
  }
}

class KalaMitraService {
  final ApiClient _apiClient;

  KalaMitraService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<KalaMitraResponse> sendMessage({
    required String message,
    required String currentScreen,
    required String language,
    List<Map<String, String>>? history,
    String? imageId,
  }) async {
    // Check creator identity first before calling backend LLM
    await KalaMitraFaqService().ensureLoaded();
    final creatorMatch = KalaMitraFaqService().findCreatorAnswer(message, language);
    if (creatorMatch != null) {
      return creatorMatch;
    }

    try {
      final res = await _apiClient.post(
        '/assistant/chat',
        body: {
          'message': message,
          'current_screen': currentScreen,
          'language': language,
          if (history != null && history.isNotEmpty) 'history': history,
          if (imageId != null) 'image_id': imageId,
        },
      );
      if (res is Map<String, dynamic>) {
        return KalaMitraResponse.fromJson(res);
      }
    } catch (_) {
      // Offline fallback rule-based response
    }

    return offlineFallback(message, currentScreen, language);
  }

  KalaMitraResponse offlineFallback(String message, String currentScreen, String language) {
    // Check localized FAQ in offline mode
    final faqMatch = KalaMitraFaqService().findAnswer(message, language);
    if (faqMatch != null) {
      return faqMatch;
    }

    final lower = message.toLowerCase();

    if (lower.contains('product') || lower.contains('photo') || lower.contains('add') || lower.contains('उत्पाद') || lower.contains('படம்')) {
      return KalaMitraResponse(
        reply: 'Opening AI Image Studio to add your craft product.',
        action: 'navigate',
        route: '/studio',
        suggestions: ['Add product photo', 'Check fair price', 'Explain screen'],
      );
    }

    if (lower.contains('order') || lower.contains('pending') || lower.contains('ऑर्डर') || lower.contains('ஆர்டர்')) {
      return KalaMitraResponse(
        reply: 'Opening Orders to check pending customer requests.',
        action: 'navigate',
        route: '/orders?filter=new',
        suggestions: ['Show all orders', 'Back to catalogue'],
      );
    }

    if (lower.contains('hindi') || lower.contains('हिन्दी')) {
      return KalaMitraResponse(
        reply: 'भाषा हिन्दी में बदली जा रही है।',
        action: 'change_language',
        targetLang: 'hi',
        suggestions: ['नया उत्पाद', 'ऑर्डर देखें'],
      );
    }

    if (lower.contains('tamil') || lower.contains('தமிழ்')) {
      return KalaMitraResponse(
        reply: 'மொழி தமிழுக்கு மாற்றப்படுகிறது.',
        action: 'change_language',
        targetLang: 'ta',
        suggestions: ['புதிய தயாரிப்பு', 'ஆர்டர்கள்'],
      );
    }

    if (lower.contains('explain') || lower.contains('what') || lower.contains('help') || lower.contains('समझाओ')) {
      return KalaMitraResponse(
        reply: 'You are on the $currentScreen screen. You can browse crafts, track orders, or add new listings.',
        action: 'explain',
        suggestions: ['Add product', 'Pending orders', 'Change language'],
      );
    }

    return KalaMitraResponse(
      reply: 'Namaste! I am KalaMitra. You can ask me to add products, check orders, explain this screen, or change languages.',
      action: 'none',
      suggestions: ['Add product', 'Pending orders', 'Explain screen'],
    );
  }
}
