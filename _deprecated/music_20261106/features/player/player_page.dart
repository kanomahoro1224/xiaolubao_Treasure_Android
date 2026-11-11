import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/models/song.dart';

class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key, this.song});

  final Song? song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentSong = song ?? mockSongs.first;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(CupertinoIcons.chevron_down)),
                  const Spacer(),
                  Text('正在播放', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const Spacer(),
                  IconButton(onPressed: () {}, icon: const Icon(CupertinoIcons.ellipsis)),
                ],
              ),
              const Spacer(),
              Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(38),
                  gradient: const LinearGradient(colors: [Color(0xFFFFB6D1), Color(0xFF91D6FF), Color(0xFF222244)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.24), blurRadius: 44, offset: const Offset(0, 24))],
                ),
                child: const Icon(CupertinoIcons.music_note_2, color: Colors.white, size: 82),
              ),
              const SizedBox(height: 34),
              Text(currentSong.title, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(currentSong.artist, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.62), fontWeight: FontWeight.w600)),
              const SizedBox(height: 32),
              LinearProgressIndicator(value: 0.28, borderRadius: BorderRadius.circular(99)),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(onPressed: () {}, iconSize: 30, icon: const Icon(CupertinoIcons.backward_end_fill)),
                  IconButton.filled(onPressed: () {}, iconSize: 34, icon: const Icon(CupertinoIcons.play_fill)),
                  IconButton(onPressed: () {}, iconSize: 30, icon: const Icon(CupertinoIcons.forward_end_fill)),
                ],
              ),
              const Spacer(),
              Text('PlayerPage.ets 迁移骨架：歌词、播放队列、音质、下载、EQ 后续补齐', textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.48), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
