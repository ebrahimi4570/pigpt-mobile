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
        archived: j['archived'] == true,
        pinned: j['pinned'] == true,
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
  });

  final String id;
  final String role; // user | assistant | system
  final String content;
  final String? modelId;
  final String? errorFa;
  final DateTime? createdAt;
  final bool streaming;
  final List<String> attachmentIds;

  ChatMessage copyWith({
    String? content,
    String? errorFa,
    bool? streaming,
    String? modelId,
    List<String>? attachmentIds,
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

class QuickStartCard {
  QuickStartCard({
    required this.id,
    required this.title,
    this.description,
    this.kind = 'text',
    this.fields = const [],
    this.qualityOptions = const ['fast'],
  });

  final String id;
  final String title;
  final String? description;
  final String kind;
  final List<QuickStartField> fields;
  final List<String> qualityOptions;

  factory QuickStartCard.fromJson(Map<String, dynamic> j) {
    final fields = <QuickStartField>[];
    final raw = j['fields'];
    if (raw is List) {
      for (final f in raw) {
        if (f is Map) {
          fields.add(QuickStartField.fromJson(Map<String, dynamic>.from(f)));
        }
      }
    }
    final qo = j['quality_options'];
    return QuickStartCard(
      id: '${j['id'] ?? j['card_id']}',
      title: '${j['title'] ?? j['name'] ?? ''}',
      description: j['description']?.toString() ?? j['blurb']?.toString(),
      kind: '${j['kind'] ?? 'text'}',
      fields: fields,
      qualityOptions: qo is List
          ? qo.map((e) => e.toString()).toList()
          : const ['fast', 'balanced', 'best'],
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
  });
  final String id;
  final String label;
  final String? hint;
  final bool required;
  final String type;

  factory QuickStartField.fromJson(Map<String, dynamic> j) => QuickStartField(
        id: '${j['id'] ?? j['key'] ?? j['name']}',
        label: '${j['label'] ?? j['title'] ?? j['id']}',
        hint: j['hint']?.toString() ?? j['placeholder']?.toString(),
        required: j['required'] == true,
        type: '${j['type'] ?? 'text'}',
      );
}

class BillingPlan {
  BillingPlan({
    required this.id,
    required this.name,
    this.price,
    this.description,
    this.current = false,
  });
  final String id;
  final String name;
  final num? price;
  final String? description;
  final bool current;

  factory BillingPlan.fromJson(Map<String, dynamic> j) => BillingPlan(
        id: '${j['id']}',
        name: '${j['name'] ?? j['title'] ?? ''}',
        price: j['price'] as num? ?? j['amount'] as num?,
        description: j['description']?.toString(),
        current: j['current'] == true,
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
