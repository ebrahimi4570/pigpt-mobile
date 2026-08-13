import 'package:equatable/equatable.dart';

class AuthMethods {
  AuthMethods({
    required this.emailPassword,
    required this.google,
    required this.otpSms,
  });
  final bool emailPassword;
  final bool google;
  final bool otpSms;

  factory AuthMethods.fromJson(Map<String, dynamic> j) => AuthMethods(
        emailPassword: j['email_password'] == true,
        google: j['google'] == true,
        otpSms: j['otp_sms'] == true,
      );
}

class UserMe extends Equatable {
  const UserMe({
    required this.id,
    required this.email,
    this.displayName,
    this.phone,
    this.emailVerified = true,
    this.role,
    this.balance = 0,
    this.canGenerate = true,
    this.freeRemaining,
    this.freeDailyRemaining,
    this.freeDailyCap,
    this.dailyTokenLimit,
    this.dailyTokensUsed,
    this.dailyTokensRemaining,
    this.planId,
    this.planName,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? phone;
  final bool emailVerified;
  final String? role;
  final num balance;
  final bool canGenerate;
  final num? freeRemaining;
  final num? freeDailyRemaining;
  final num? freeDailyCap;
  final num? dailyTokenLimit;
  final num? dailyTokensUsed;
  final num? dailyTokensRemaining;
  final String? planId;
  final String? planName;

  factory UserMe.fromJson(Map<String, dynamic> j) {
    final wallet = j['wallet'] is Map
        ? Map<String, dynamic>.from(j['wallet'] as Map)
        : j;
    return UserMe(
      id: '${j['id'] ?? j['user_id'] ?? ''}',
      email: '${j['email'] ?? ''}',
      displayName: j['display_name']?.toString() ?? j['name']?.toString(),
      phone: j['phone']?.toString(),
      emailVerified: j['email_verified'] != false,
      role: j['role']?.toString(),
      balance: wallet['balance'] as num? ?? j['balance'] as num? ?? 0,
      canGenerate: wallet['can_generate'] != false && j['can_generate'] != false,
      freeRemaining: wallet['free_remaining'] as num? ?? j['free_remaining'] as num?,
      freeDailyRemaining: wallet['free_daily_remaining'] as num? ??
          j['free_daily_remaining'] as num?,
      freeDailyCap:
          wallet['free_daily_cap'] as num? ?? j['free_daily_cap'] as num?,
      dailyTokenLimit: wallet['daily_token_limit'] as num? ??
          j['daily_token_limit'] as num?,
      dailyTokensUsed: wallet['daily_tokens_used'] as num? ??
          j['daily_tokens_used'] as num?,
      dailyTokensRemaining: wallet['daily_tokens_remaining'] as num? ??
          j['daily_tokens_remaining'] as num?,
      planId: j['plan_id']?.toString() ?? j['current_plan_id']?.toString(),
      planName: j['plan_name']?.toString(),
    );
  }

  String get greetingName =>
      (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!.trim()
          : email.split('@').first;

  @override
  List<Object?> get props => [id, email, balance, canGenerate];
}

class AiModel {
  AiModel({
    required this.id,
    required this.name,
    this.description,
    this.vendor,
    this.enabled = true,
  });
  final String id;
  final String name;
  final String? description;
  final String? vendor;
  final bool enabled;

  factory AiModel.fromJson(Map<String, dynamic> j) => AiModel(
        id: '${j['id'] ?? j['model_id']}',
        name: '${j['name'] ?? j['display_name'] ?? j['id']}',
        description: j['description']?.toString(),
        vendor: j['vendor']?.toString() ?? j['provider']?.toString(),
        enabled: j['enabled'] != false,
      );
}

class Conversation {
  Conversation({
    required this.id,
    this.title,
    this.modelId,
    this.updatedAt,
    this.archived = false,
    this.pinned = false,
  });
  final String id;
  final String? title;
  final String? modelId;
  final DateTime? updatedAt;
  final bool archived;
  final bool pinned;

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: '${j['id']}',
        title: j['title']?.toString(),
        modelId: j['model_id']?.toString(),
        updatedAt: j['updated_at'] != null
            ? DateTime.tryParse(j['updated_at'].toString())
            : null,
        archived: j['archived'] == true || j['archived_at'] != null,
        pinned: j['pinned'] == true || j['is_pinned'] == true,
      );
}

class PendingAttachment {
  const PendingAttachment({
    required this.id,
    required this.name,
    this.localPath,
  });
  final String id;
  final String name;
  final String? localPath;
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.modelId,
    this.errorFa,
    this.createdAt,
    this.streaming = false,
    this.attachmentIds = const [],
    this.localPath,
  });

  final String id;
  final String role; // user | assistant | system
  final String content;
  final String? modelId;
  final String? errorFa;
  final DateTime? createdAt;
  final bool streaming;
  final List<String> attachmentIds;
  final String? localPath;

  ChatMessage copyWith({
    String? content,
    String? errorFa,
    bool? streaming,
    String? modelId,
    List<String>? attachmentIds,
    String? localPath,
  }) =>
      ChatMessage(
        id: id,
        role: role,
        content: content ?? this.content,
        modelId: modelId ?? this.modelId,
        errorFa: errorFa ?? this.errorFa,
        createdAt: createdAt,
        streaming: streaming ?? this.streaming,
        attachmentIds: attachmentIds ?? this.attachmentIds,
        localPath: localPath ?? this.localPath,
      );

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final raw = j['attachment_ids'];
    final ids = <String>[];
    if (raw is List) {
      for (final e in raw) {
        ids.add('$e');
      }
    }
    return ChatMessage(
      id: '${j['id'] ?? j['message_id'] ?? DateTime.now().microsecondsSinceEpoch}',
      role: '${j['role'] ?? 'assistant'}',
      content: '${j['content'] ?? j['text'] ?? ''}',
      modelId: j['model_id']?.toString(),
      errorFa: j['error_message_fa']?.toString() ?? j['error_fa']?.toString(),
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'].toString())
          : null,
      attachmentIds: ids,
    );
  }
}

class AgentMission {
  AgentMission({
    required this.id,
    required this.goal,
    this.status = 'draft',
    this.modelId,
    this.steps = const [],
    this.createdAt,
  });

  final String id;
  final String goal;
  final String status;
  final String? modelId;
  final List<AgentStep> steps;
  final DateTime? createdAt;

  factory AgentMission.fromJson(Map<String, dynamic> j) {
    final rawSteps = j['steps'];
    final steps = <AgentStep>[];
    if (rawSteps is List) {
      for (final s in rawSteps) {
        if (s is Map) steps.add(AgentStep.fromJson(Map<String, dynamic>.from(s)));
      }
    }
    return AgentMission(
      id: '${j['id']}',
      goal: '${j['goal'] ?? j['title'] ?? ''}',
      status: '${j['status'] ?? 'draft'}',
      modelId: j['model_id']?.toString(),
      steps: steps,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'].toString())
          : null,
    );
  }

  String get statusFa {
    switch (status) {
      case 'draft':
        return 'پیش‌نویس';
      case 'planning':
        return 'برنامه‌ریزی';
      case 'running':
        return 'در حال اجرا';
      case 'awaiting_confirm':
        return 'منتظر تأیید';
      case 'completed':
        return 'تکمیل‌شده';
      case 'failed':
        return 'ناموفق';
      case 'cancelled':
        return 'لغو شده';
      default:
        return status;
    }
  }
}

class AgentStep {
  AgentStep({
    required this.id,
    required this.title,
    this.status,
    this.detail,
  });
  final String id;
  final String title;
  final String? status;
  final String? detail;

  factory AgentStep.fromJson(Map<String, dynamic> j) => AgentStep(
        id: '${j['id'] ?? j['step_id'] ?? ''}',
        title: '${j['title'] ?? j['name'] ?? j['summary'] ?? 'قدم'}',
        status: j['status']?.toString(),
        detail: j['detail']?.toString() ?? j['output']?.toString(),
      );
}

class QuickStartOpt {
  const QuickStartOpt({required this.value, required this.label});
  final String value;
  final String label;

  factory QuickStartOpt.fromJson(Map<String, dynamic> j) {
    final value = '${j['value'] ?? j['id'] ?? j['label_fa'] ?? j['label'] ?? ''}'.trim();
    final label =
        '${j['label_fa'] ?? j['label'] ?? j['title'] ?? j['value'] ?? value}'.trim();
    return QuickStartOpt(value: value, label: label.isEmpty ? value : label);
  }
}

class QuickStartCard {
  QuickStartCard({
    required this.id,
    required this.title,
    this.description,
    this.kind = 'text',
    this.fields = const [],
    this.qualityOptions = const ['fast'],
    this.qualityLabels = const {},
  });

  final String id;
  final String title;
  final String? description;
  final String kind;
  final List<QuickStartField> fields;
  final List<String> qualityOptions;
  final Map<String, String> qualityLabels;

  factory QuickStartCard.fromJson(Map<String, dynamic> j) {
    final fields = <QuickStartField>[];
    final raw = j['fields'] ?? j['steps'];
    if (raw is List) {
      for (final f in raw) {
        if (f is Map) {
          fields.add(QuickStartField.fromJson(Map<String, dynamic>.from(f)));
        }
      }
    }
    final qo = j['quality_options'];
    final ids = <String>[];
    final labels = <String, String>{};
    if (qo is List) {
      for (final e in qo) {
        if (e is Map) {
          final m = Map<String, dynamic>.from(e);
          final id = '${m['id'] ?? m['value'] ?? ''}'.trim();
          if (id.isEmpty) continue;
          ids.add(id);
          labels[id] = '${m['label_fa'] ?? m['label'] ?? id}';
        } else {
          final id = e.toString().trim();
          if (id.isEmpty) continue;
          ids.add(id);
          labels[id] = id == 'fast'
              ? 'سریع'
              : id == 'quality'
                  ? 'باکیفیت‌تر'
                  : id;
        }
      }
    }
    return QuickStartCard(
      id: '${j['id'] ?? j['card_id']}',
      title: '${j['title'] ?? j['name'] ?? j['title_fa'] ?? ''}',
      description: j['description']?.toString() ??
          j['description_fa']?.toString() ??
          j['blurb_fa']?.toString() ??
          j['blurb']?.toString(),
      kind: '${j['kind'] ?? 'text'}',
      fields: fields,
      qualityOptions: ids.isNotEmpty ? ids : const ['fast', 'quality'],
      qualityLabels: labels,
    );
  }
}

class QuickStartField {
  QuickStartField({
    required this.id,
    required this.label,
    this.hint,
    this.required = false,
    this.type = 'text',
    this.multi = false,
    this.defaultValue,
    this.suggestions = const [],
    this.options = const [],
  });
  final String id;
  final String label;
  final String? hint;
  final bool required;
  final String type;
  final bool multi;
  final String? defaultValue;
  final List<QuickStartOpt> suggestions;
  final List<QuickStartOpt> options;

  List<QuickStartOpt> get chips {
    final src = suggestions.isNotEmpty ? suggestions : options;
    final seen = <String>{};
    final out = <QuickStartOpt>[];
    for (final o in src) {
      if (o.value.isEmpty || seen.contains(o.value)) continue;
      seen.add(o.value);
      out.add(o);
    }
    return out;
  }

  static List<QuickStartOpt> _parseOpts(dynamic raw) {
    if (raw is! List) return const [];
    final out = <QuickStartOpt>[];
    for (final e in raw) {
      if (e is Map) {
        final o = QuickStartOpt.fromJson(Map<String, dynamic>.from(e));
        if (o.value.isNotEmpty) out.add(o);
      } else {
        final s = e.toString().trim();
        if (s.isNotEmpty) out.add(QuickStartOpt(value: s, label: s));
      }
    }
    return out;
  }

  factory QuickStartField.fromJson(Map<String, dynamic> j) => QuickStartField(
        id: '${j['id'] ?? j['key'] ?? j['name']}',
        label: '${j['label'] ?? j['label_fa'] ?? j['title'] ?? j['id']}',
        hint: j['hint']?.toString() ??
            j['hint_fa']?.toString() ??
            j['placeholder_fa']?.toString() ??
            j['placeholder']?.toString(),
        required: j['required'] == true,
        type: '${j['type'] ?? 'text'}',
        multi: j['multi'] == true,
        defaultValue: j['default']?.toString() ?? j['default_value']?.toString(),
        suggestions: _parseOpts(j['suggestions']),
        options: _parseOpts(j['options']),
      );
}

class BillingPlan {
  BillingPlan({
    required this.id,
    required this.name,
    this.price,
    this.priceRial,
    this.description,
    this.current = false,
    this.tokensGranted,
    this.capabilityCount,
  });
  final String id;
  final String name;
  final num? price;
  final num? priceRial;
  final String? description;
  final bool current;
  final num? tokensGranted;
  final int? capabilityCount;

  factory BillingPlan.fromJson(Map<String, dynamic> j) {
    final caps = j['allow_capabilities'];
    return BillingPlan(
      id: '${j['id']}',
      name: '${j['name_fa'] ?? j['name'] ?? j['title'] ?? ''}',
      price: j['price'] as num? ?? j['amount'] as num?,
      priceRial: j['price_rial'] as num?,
      description:
          j['description_fa']?.toString() ?? j['description']?.toString(),
      current: j['current'] == true,
      tokensGranted: j['platform_tokens_granted'] as num?,
      capabilityCount: caps is List ? caps.length : null,
    );
  }
}

class TokenPackage {
  TokenPackage({
    required this.id,
    required this.name,
    required this.tokensGranted,
    this.priceRial,
    this.description,
    this.code,
  });
  final String id;
  final String name;
  final num tokensGranted;
  final num? priceRial;
  final String? description;
  final String? code;

  factory TokenPackage.fromJson(Map<String, dynamic> j) => TokenPackage(
        id: '${j['id']}',
        name: '${j['name_fa'] ?? j['name'] ?? j['title'] ?? ''}',
        tokensGranted: j['tokens_granted'] as num? ?? j['tokens'] as num? ?? 0,
        priceRial: j['price_rial'] as num? ?? j['price'] as num?,
        description:
            j['description_fa']?.toString() ?? j['description']?.toString(),
        code: j['code']?.toString(),
      );
}

class BillingWallet {
  BillingWallet({
    required this.balance,
    this.freeRemaining,
    this.paidAvailable,
    this.freeDailyCap,
    this.freeDailyRemaining,
    this.canGenerate = true,
  });
  final num balance;
  final num? freeRemaining;
  final num? paidAvailable;
  final num? freeDailyCap;
  final num? freeDailyRemaining;
  final bool canGenerate;

  factory BillingWallet.fromJson(Map<String, dynamic> j) {
    final w = j['wallet'] is Map
        ? Map<String, dynamic>.from(j['wallet'] as Map)
        : j;
    return BillingWallet(
      balance: w['balance'] as num? ?? 0,
      freeRemaining: w['free_remaining'] as num?,
      paidAvailable: w['paid_available'] as num?,
      freeDailyCap: w['free_daily_cap'] as num?,
      freeDailyRemaining: w['free_daily_remaining'] as num?,
      canGenerate: w['can_generate'] != false,
    );
  }
}

class ImagePreset {
  ImagePreset({required this.id, required this.name});
  final String id;
  final String name;

  factory ImagePreset.fromJson(Map<String, dynamic> j) => ImagePreset(
        id: '${j['id'] ?? j['code'] ?? ''}',
        name: '${j['name_fa'] ?? j['name'] ?? j['id'] ?? ''}',
      );
}

class WritingTemplate {
  WritingTemplate({
    required this.id,
    required this.name,
    this.description,
    this.steps = const [],
  });
  final String id;
  final String name;
  final String? description;
  final List<WritingStep> steps;

  factory WritingTemplate.fromJson(Map<String, dynamic> j) {
    final steps = <WritingStep>[];
    final raw = j['steps'];
    if (raw is List) {
      for (final s in raw) {
        if (s is Map) {
          steps.add(WritingStep.fromJson(Map<String, dynamic>.from(s)));
        }
      }
    }
    return WritingTemplate(
      id: '${j['id']}',
      name: '${j['name_fa'] ?? j['name'] ?? ''}',
      description:
          j['description_fa']?.toString() ?? j['description']?.toString(),
      steps: steps,
    );
  }
}

class WritingStep {
  WritingStep({required this.id, required this.name});
  final String id;
  final String name;

  factory WritingStep.fromJson(Map<String, dynamic> j) => WritingStep(
        id: '${j['id']}',
        name: '${j['name_fa'] ?? j['name'] ?? j['id']}',
      );
}

class StudioToolDef {
  const StudioToolDef({
    required this.id,
    required this.href,
    required this.label,
    required this.blurb,
    required this.capability,
    required this.categoryId,
    this.secondary = false,
    this.routeName,
  });

  final String id;
  final String href;
  final String label;
  final String blurb;
  final String capability;
  final String categoryId;
  final bool secondary;
  final String? routeName;
}

class StudioCategoryDef {
  const StudioCategoryDef({
    required this.id,
    required this.label,
    required this.description,
    required this.accent,
    required this.tools,
  });
  final String id;
  final String label;
  final String description;
  final String accent;
  final List<StudioToolDef> tools;
}
