import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/services/api_service.dart';
import '../providers/chat_provider.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/common_widgets.dart';
import 'voice_library_screen.dart';

/// Home dashboard: hero, quick actions, recent generations,
/// recent conversations and live usage info (only when the API
/// actually returns it — no fabricated statistics).
class HomeScreen extends StatefulWidget {
  final void Function(int tabIndex) onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _account;
  Map<String, dynamic>? _limits;
  bool _usageLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryProvider>().load();
      context.read<ChatProvider>().loadRemoteSessions();
      _loadUsage();
    });
  }

  Future<void> _loadUsage() async {
    final SettingsProvider settings = context.read<SettingsProvider>();
    if (!settings.hasToken) return;
    setState(() => _usageLoading = true);
    try {
      final ApiService api = _apiFromContext();
      final List<dynamic> results = await Future.wait(<Future<dynamic>>[
        api.getAccount(),
        api.getLimits(),
      ]);
      if (mounted) {
        setState(() {
          _account = results[0] as Map<String, dynamic>;
          _limits = results[1] as Map<String, dynamic>;
        });
      }
    } catch (_) {
      // Usage info is optional — hide the card when unavailable.
    }
    if (mounted) setState(() => _usageLoading = false);
  }

  ApiService _apiFromContext() {
    // ApiService is provided at the app root.
    return context.read<ApiService>();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final SettingsProvider settings = context.watch<SettingsProvider>();
    final LibraryProvider library = context.watch<LibraryProvider>();
    final ChatProvider chat = context.watch<ChatProvider>();
    final ThemeData theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait(<Future<dynamic>>[
          library.load(),
          chat.loadRemoteSessions(),
          _loadUsage(),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: <Widget>[
          // Header
          Row(
            children: <Widget>[
              const PandaMark(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('PANDA AI STUDIO',
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    Text('Your Voice. Your Intelligence.',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Toggle theme',
                icon: Icon(settings.themeMode == ThemeMode.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined),
                onPressed: () => settings.setThemeMode(
                    settings.themeMode == ThemeMode.dark
                        ? ThemeMode.light
                        : ThemeMode.dark),
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => widget.onNavigate(4),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Hero
          Text('Create Something\nExtraordinary.',
              style: theme.textTheme.displayLarge)
              .animate()
              .fadeIn(duration: 450.ms)
              .slideY(begin: 0.12, end: 0, duration: 450.ms),
          const SizedBox(height: 10),
          Text(
            'Turn your words into natural speech and explore the power of AI.',
            style: theme.textTheme.bodyMedium,
          ).animate().fadeIn(duration: 450.ms, delay: 80.ms),
          const SizedBox(height: 24),

          // Token nudge
          if (!settings.hasToken)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.inverseBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.key_rounded, color: p.inverseText, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Add your Panda API token in Settings to unlock voices, speech generation and AI chat.',
                      style: TextStyle(color: p.inverseText, fontSize: 13.5, height: 1.4),
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigate(4),
                    child: Text('Add token',
                        style: TextStyle(color: p.inverseText, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),
          if (!settings.hasToken) const SizedBox(height: 20),

          // Quick actions
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: <Widget>[
              _ActionCard(
                icon: Icons.graphic_eq_rounded,
                title: 'CREATE VOICE',
                description: 'Transform text into natural AI speech.',
                onTap: () => widget.onNavigate(1),
                delay: 0,
              ),
              _ActionCard(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'TALK TO AI',
                description: 'Chat with your intelligent AI assistant.',
                onTap: () => widget.onNavigate(2),
                delay: 60,
              ),
              _ActionCard(
                icon: Icons.audio_file_outlined,
                title: 'EXPLORE VOICES',
                description: 'Discover available AI voices.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const VoiceLibraryScreen()),
                ),
                delay: 120,
              ),
              _ActionCard(
                icon: Icons.folder_open_outlined,
                title: 'YOUR LIBRARY',
                description: 'Access your generated audio and conversations.',
                onTap: () => widget.onNavigate(3),
                delay: 180,
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Usage (real API data only)
          if (_usageLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!_usageLoading && (_account != null || _limits != null))
            _UsageCard(account: _account, limits: _limits),
          if (!_usageLoading && (_account != null || _limits != null))
            const SizedBox(height: 28),

          // Recent generations
          const SectionHeader(title: 'Recent generations'),
          const SizedBox(height: 10),
          if (library.items.isEmpty)
            const EmptyState(
              icon: Icons.graphic_eq_outlined,
              title: 'No audio yet',
              subtitle: 'Generate your first voice in the Voice Studio.',
            )
          else
            ...library.items.take(3).map((LibraryItem item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RecentAudioTile(item: item),
                )),
          const SizedBox(height: 20),

          // Recent conversations
          SectionHeader(
            title: 'Recent conversations',
            actionLabel: 'Open chat',
            onAction: () => widget.onNavigate(2),
          ),
          const SizedBox(height: 10),
          if (chat.remoteSessions.isEmpty)
            const EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No conversations yet',
              subtitle: 'Start a conversation with Panda AI.',
            )
          else
            ...chat.remoteSessions.take(3).map((ChatSession s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RecentChatTile(
                    session: s,
                    onTap: () {
                      chat.openSession(s);
                      widget.onNavigate(2);
                    },
                  ),
                )),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final int delay;
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: p.inverseBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: p.inverseText),
              ),
              const SizedBox(height: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
              const SizedBox(height: 4),
              Text(description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: delay.ms).slideY(begin: 0.1, end: 0, duration: 400.ms, delay: delay.ms);
  }
}

class _UsageCard extends StatelessWidget {
  final Map<String, dynamic>? account;
  final Map<String, dynamic>? limits;
  const _UsageCard({this.account, this.limits});

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final Map<String, dynamic> data = <String, dynamic>{
      ...?account,
      ...?limits,
    };
    final List<MapEntry<String, dynamic>> entries = data.entries
        .where((MapEntry<String, dynamic> e) =>
            e.value is num || e.value is String || e.value is bool)
        .take(6)
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.inverseBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('ACCOUNT',
              style: TextStyle(
                  color: p.inverseText,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final MapEntry<String, dynamic> e in entries)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: p.inverseText.withOpacity(0.35)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${Formatters.titleCase(e.key)}: ${e.value}',
                    style: TextStyle(color: p.inverseText, fontSize: 12.5),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentAudioTile extends StatelessWidget {
  final LibraryItem item;
  const _RecentAudioTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: p.inverseBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.play_arrow_rounded, color: p.inverseText, size: 22),
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
                  '${item.voiceName} · ${Formatters.relativeDate(item.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentChatTile extends StatelessWidget {
  final ChatSession session;
  final VoidCallback onTap;
  const _RecentChatTile({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              Icon(Icons.chat_bubble_outline_rounded, size: 20, color: p.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium),
                    if (session.preview != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(session.preview!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: p.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
