import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/services/audio_player_service.dart';
import '../providers/chat_provider.dart';
import '../providers/library_provider.dart';
import '../widgets/common_widgets.dart';

/// Library — generated audio (search, sort, play, share, delete)
/// and past conversations.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final TextEditingController _searchController = TextEditingController();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _playingPath;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    final AudioPlayerService player = context.read<AudioPlayerService>();
    _stateSub = player.playerStateStream.listen((PlayerState state) {
      if (mounted) {
        setState(() {
          _playingPath = state == PlayerState.playing
              ? player.currentPath
              : (state == PlayerState.paused ? _playingPath : null);
        });
      }
    });
    _positionSub = player.positionStream
        .listen((Duration d) => mounted ? setState(() => _position = d) : null);
    _durationSub = player.durationStream
        .listen((Duration d) => mounted ? setState(() => _duration = d) : null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryProvider>().load();
      context.read<ChatProvider>().loadRemoteSessions();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    _stateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    super.dispose();
  }

  Future<void> _togglePlay(LibraryItem item) async {
    final AudioPlayerService player = context.read<AudioPlayerService>();
    if (_playingPath == item.filePath &&
        player.state == PlayerState.playing) {
      await player.pause();
      return;
    }
    if (_playingPath == item.filePath &&
        player.state == PlayerState.paused) {
      await player.resume();
      return;
    }
    setState(() {
      _playingPath = item.filePath;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    await player.playFile(item.filePath);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: const Text('LIBRARY'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: p.textPrimary,
          unselectedLabelColor: p.textTertiary,
          indicatorColor: p.textPrimary,
          tabs: const <Widget>[
            Tab(icon: Icon(Icons.graphic_eq_outlined, size: 18), text: 'Audio'),
            Tab(icon: Icon(Icons.chat_bubble_outline_rounded, size: 18), text: 'Chats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: <Widget>[_buildAudioTab(context), _buildChatsTab(context)],
      ),
    );
  }

  Widget _buildAudioTab(BuildContext context) {
    final LibraryProvider library = context.watch<LibraryProvider>();
    final List<LibraryItem> items = library.visibleItems;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search audio…',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: library.setQuery,
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<LibrarySort>(
                icon: const Icon(Icons.sort_rounded),
                tooltip: 'Sort',
                onSelected: library.setSort,
                itemBuilder: (BuildContext context) => <PopupMenuEntry<LibrarySort>>[
                  const PopupMenuItem<LibrarySort>(
                    value: LibrarySort.newest,
                    child: Text('Newest first'),
                  ),
                  const PopupMenuItem<LibrarySort>(
                    value: LibrarySort.oldest,
                    child: Text('Oldest first'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: library.isLoading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? const EmptyState(
                      icon: Icons.folder_open_outlined,
                      title: 'Your library is empty',
                      subtitle:
                          'Audio you generate in the Voice Studio will be saved here automatically.',
                    )
                  : RefreshIndicator(
                      onRefresh: library.load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: items.length,
                        itemBuilder: (BuildContext context, int index) {
                          final LibraryItem item = items[index];
                          final bool isPlaying = _playingPath == item.filePath;
                          final double progress = isPlaying &&
                                  _duration.inMilliseconds > 0
                              ? (_position.inMilliseconds /
                                      _duration.inMilliseconds)
                                  .clamp(0.0, 1.0)
                              : 0.0;
                          return _AudioTile(
                            item: item,
                            isPlaying: isPlaying,
                            progress: progress,
                            onPlay: () => _togglePlay(item),
                            onShare: () => Share.shareXFiles(
                                <XFile>[XFile(item.filePath)],
                                text: item.title),
                            onDelete: () async {
                              final bool confirmed = await showConfirmDialog(
                                context,
                                title: 'Delete audio?',
                                message:
                                    '"${item.title}" will be permanently removed from this device.',
                              );
                              if (confirmed) {
                                await library.deleteItem(item.id);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Audio deleted')),
                                  );
                                }
                              }
                            },
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildChatsTab(BuildContext context) {
    final ChatProvider chat = context.watch<ChatProvider>();
    if (chat.sessionsLoading && chat.remoteSessions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (chat.remoteSessions.isEmpty) {
      return const EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No conversations yet',
        subtitle: 'Your AI chats will appear here.',
      );
    }
    return RefreshIndicator(
      onRefresh: chat.loadRemoteSessions,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        itemCount: chat.remoteSessions.length,
        itemBuilder: (BuildContext context, int index) {
          final ChatSession session = chat.remoteSessions[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: context.palette.border),
              ),
              leading: const Icon(Icons.chat_bubble_outline_rounded),
              title: Text(session.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: session.createdAt == null
                  ? null
                  : Text(Formatters.relativeDate(session.createdAt!)),
              trailing: IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  final bool confirmed = await showConfirmDialog(
                    context,
                    title: 'Delete conversation?',
                    message: '"${session.title}" will be permanently deleted.',
                  );
                  if (confirmed) {
                    await chat.deleteConversation(session.id);
                  }
                },
              ),
              onTap: () => chat.openSession(session),
            ),
          );
        },
      ),
    );
  }
}

class _AudioTile extends StatelessWidget {
  final LibraryItem item;
  final bool isPlaying;
  final double progress;
  final VoidCallback onPlay;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  const _AudioTile({
    required this.item,
    required this.isPlaying,
    required this.progress,
    required this.onPlay,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: p.inverseBackground,
                  foregroundColor: p.inverseText,
                  fixedSize: const Size(46, 46),
                ),
                icon: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 24),
                onPressed: onPlay,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${item.voiceName} · ${item.style} · ${Formatters.relativeDate(item.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Share',
                icon: const Icon(Icons.share_outlined, size: 20),
                onPressed: onShare,
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
          if (isPlaying) ...<Widget>[
            const SizedBox(height: 10),
            Waveform(progress: progress, active: true, height: 36),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
