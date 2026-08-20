/// Cursor-like live status: one surface, specific Persian verbs, self-correcting.
/// Connectivity banner stays the offline surface — do not duplicate «آفلاین» here.
enum LivePhase {
  idle,
  waiting,
  thinking,
  writing,
  searching,
  imaging,
  reading,
  queued,
  generating,
  listening,
  transcribing,
  uploading,
  attached,
  ready,
  done,
  error,
}

class LiveStatus {
  const LiveStatus({
    this.phase = LivePhase.idle,
    this.errorFa,
    this.percent,
  });

  final LivePhase phase;
  final String? errorFa;
  /// Real API progress only (0–100). Never invent a percentage.
  final int? percent;

  bool get isIdle => phase == LivePhase.idle;
  bool get isActive =>
      !isIdle &&
      phase != LivePhase.ready &&
      phase != LivePhase.done &&
      phase != LivePhase.attached &&
      phase != LivePhase.error;

  String get label {
    if (phase == LivePhase.error) {
      final e = errorFa?.trim() ?? '';
      if (e.isNotEmpty) return e;
      return 'پاسخ دریافت نشد';
    }
    final verb = _verbFa[phase] ?? '';
    if (percent != null &&
        percent! >= 0 &&
        percent! <= 100 &&
        (phase == LivePhase.generating || phase == LivePhase.queued)) {
      return '$verb $percent٪';
    }
    return verb;
  }

  LiveStatus copyWith({
    LivePhase? phase,
    String? errorFa,
    int? percent,
    bool clearError = false,
    bool clearPercent = false,
  }) =>
      LiveStatus(
        phase: phase ?? this.phase,
        errorFa: clearError ? null : (errorFa ?? this.errorFa),
        percent: clearPercent ? null : (percent ?? this.percent),
      );

  static const _verbFa = <LivePhase, String>{
    LivePhase.idle: '',
    LivePhase.waiting: 'در انتظار پاسخ',
    LivePhase.thinking: 'در حال فکر کردن',
    LivePhase.writing: 'در حال نوشتن',
    LivePhase.searching: 'در حال جستجو',
    LivePhase.imaging: 'در حال ساخت تصویر',
    LivePhase.reading: 'در حال خواندن فایل',
    LivePhase.queued: 'در صف',
    LivePhase.generating: 'در حال تولید',
    LivePhase.listening: 'در حال گوش دادن',
    LivePhase.transcribing: 'در حال تبدیل به متن',
    LivePhase.uploading: 'در حال آپلود',
    LivePhase.attached: 'پیوست شد',
    LivePhase.ready: 'آماده',
    LivePhase.done: 'تمام شد',
    LivePhase.error: 'خطا',
  };
}

/// Map SSE/tool payload → a verb. Unknown tools stay null (keep current phase).
LivePhase? livePhaseFromTool(Map<String, dynamic> data) {
  final raw = [
    data['tool'],
    data['name'],
    data['kind'],
    data['type'],
    data['action'],
    data['needs_tool'],
  ].map((e) => '${e ?? ''}'.toLowerCase()).join(' ');
  if (raw.trim().isEmpty) return null;
  if (RegExp(r'search|web_search|browse|google|bing').hasMatch(raw)) {
    return LivePhase.searching;
  }
  if (RegExp(r'image|imagine|dall|picture|generate_image').hasMatch(raw)) {
    return LivePhase.imaging;
  }
  if (RegExp(r'file|read|document|pdf|upload|artifact|create_file').hasMatch(raw)) {
    return LivePhase.reading;
  }
  return null;
}

LivePhase? livePhaseFromJobStatus(String status, {int? percent}) {
  switch (status) {
    case 'queued':
    case 'pending':
      return LivePhase.queued;
    case 'running':
    case 'processing':
    case 'generating':
      return LivePhase.generating;
    case 'succeeded':
    case 'completed':
    case 'done':
      return LivePhase.ready;
    case 'failed':
    case 'error':
      return LivePhase.error;
    default:
      return null;
  }
}

int? realPercentOf(dynamic raw) {
  if (raw is num) {
    final n = raw.toInt();
    if (n >= 0 && n <= 100) return n;
  }
  if (raw is String) {
    final n = int.tryParse(raw.replaceAll('%', '').trim());
    if (n != null && n >= 0 && n <= 100) return n;
  }
  return null;
}
