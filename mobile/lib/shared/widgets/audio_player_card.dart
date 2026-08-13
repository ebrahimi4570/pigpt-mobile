import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';

class AudioPlayerCard extends StatefulWidget {
  const AudioPlayerCard({super.key, required this.url, this.title = 'خروجی صوتی'});
  final String url;
  final String title;

  @override
  State<AudioPlayerCard> createState() => _AudioPlayerCardState();
}

class _AudioPlayerCardState extends State<AudioPlayerCard> {
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    });
    _player.onPositionChanged.listen((d) {
      if (mounted) setState(() => _pos = d);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total = _dur.inMilliseconds == 0 ? 1.0 : _dur.inMilliseconds.toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: PigptColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PigptColors.borderOf(context)),
      ),
      child: Row(
        children: [
          IconButton.filled(
            onPressed: _toggle,
            icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Slider(
                  value: _pos.inMilliseconds.clamp(0, total.toInt()).toDouble(),
                  max: total,
                  onChanged: (v) => _player.seek(Duration(milliseconds: v.round())),
                ),
                Text(
                  '${_fmt(_pos)} / ${_fmt(_dur)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: PigptColors.mutedOf(context),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'توقف',
            onPressed: () => _player.stop(),
            icon: const Icon(Icons.stop_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

bool looksLikeAudioUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final u = url.toLowerCase();
  return u.contains('/tts') ||
      u.contains('/media/tts') ||
      u.endsWith('.mp3') ||
      u.endsWith('.wav') ||
      u.endsWith('.m4a') ||
      u.endsWith('.ogg') ||
      u.endsWith('.aac');
}
