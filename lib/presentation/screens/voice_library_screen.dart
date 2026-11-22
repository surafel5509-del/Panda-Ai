import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/services/api_service.dart';
import '../../data/services/audio_player_service.dart';
import '../../data/services/library_service.dart';
import '../providers/settings_provider.dart';
import '../providers/voice_studio_provider.dart';
import '../widgets/common_widgets.dart';

/// Voice Library — discover real voices from the API, preview them,
/// view details and select one for the Voice Studio.
class VoiceLibraryScreen extends StatefulWidget {
  const VoiceLibraryScreen({super.key});

  @override
  State<VoiceLibraryScreen> createState() => _VoiceLibraryScreenState();
}

class _VoiceLibraryScreenState extends State<VoiceLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _gender = 'all';
  String _query = '';
  bool _loading = false;
  String? _error;
  List<Voice> _voices = <Voice>[];
  String? _previewingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ApiService api = context.read<ApiService>();
      _voices = await api.getVoices(gender: _gender, pageSize: 50);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Voice> get _visible {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return _voices;
    return _voices
        .where((Voice v) =>
            v.name.toLowerCase().contains(q) ||
            v.id.toLowerCase().contains(q) ||
            v.description.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _preview(Voice voice) async {
    setState(() => _previewingId = voice.id);
    try {
      final ApiService api = context.read<ApiService>();
      final SettingsProvider settings = context.read<SettingsProvider>();
      final Uint8List bytes = await api.preview(
        text: ApiConfig.sampleText,
        voiceId: voice.id,
        style: settings.defaultStyle.isNotEmpty
            ? settings.defaultStyle
            : 'natural',
        model: settings.defaultEngine,
        speed: settings.defaultSpeed,
        volume: settings.defaultVolume,
      );
      final String tmpDir =
          (await context.read<LibraryService>().tempDir()).path;
      await context.read<AudioPlayerService>().playBytes(bytes, tempDir: tmpDir);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
    if (mounted) setState(() => _previewingId = null);
  }

  void _select(Voice voice) {
    final VoiceStudioProvider studio = context.read<VoiceStudioProvider>();
    studio.selectVoice(voice);
    context
        .read<SettingsProvider>()
        .setDefaultVoice(voice.id, voice.name);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${voice.name} selected for the Voice Studio')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final VoiceStudioProvider studio = context.watch<VoiceStudioProvider>();
    final List<Voice> list = _visible;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VOICE LIBRARY'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search voices…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (String value) => setState(() => _query = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: <Widget>[
                for (final String g in <String>['all', 'male', 'female'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(Formatters.titleCase(g)),
                      selected: _gender == g,
                      onSelected: (_) {
                        setState(() => _gender = g);
                        _load();
                      },
                    ),
                  ),
                const Spacer(),
                Text('${list.length} voices',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? EmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Could not load voices',
                        subtitle: _error,
                        actionLabel: 'Retry',
                        onAction: _load,
                      )
                    : list.isEmpty
                        ? const EmptyState(
                            icon: Icons.person_search_outlined,
                            title: 'No voices found',
                            subtitle: 'Try a different search or filter.',
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 8, 20, 24),
                              itemCount: list.length,
                              itemBuilder: (BuildContext context, int index) {
                                final Voice voice = list[index];
                                final bool selected =
                                    studio.selectedVoice?.id == voice.id;
                                return _VoiceCard(
                                  voice: voice,
                                  selected: selected,
                                  previewing: _previewingId == voice.id,
                                  onPreview: () => _preview(voice),
                                  onSelect: () => _select(voice),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          VoiceDetailScreen(voiceId: voice.id),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _VoiceCard extends StatelessWidget {
  final Voice voice;
  final bool selected;
  final bool previewing;
  final VoidCallback onPreview;
  final VoidCallback onSelect;
  final VoidCallback onTap;
  const _VoiceCard({
    required this.voice,
    required this.selected,
    required this.previewing,
    required this.onPreview,
    required this.onSelect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(
            color: selected ? p.textPrimary : p.border,
            width: selected ? 1.5 : 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: p.inverseBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.person_outline_rounded,
                    color: p.inverseText, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(voice.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                        if (selected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: p.inverseBackground,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('SELECTED',
                                style: TextStyle(
                                    color: p.inverseText,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      voice.description.isNotEmpty
                          ? voice.description
                          : voice.id,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      <String>[
                        if (voice.gender.isNotEmpty)
                          Formatters.titleCase(voice.gender),
                        if (voice.style.isNotEmpty) voice.style,
                        if (voice.language.isNotEmpty) voice.language,
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 38)),
                          onPressed: previewing ? null : onPreview,
                          icon: previewing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.play_arrow_rounded, size: 16),
                          label: const Text('Preview'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 38)),
                          onPressed: onSelect,
                          child: const Text('Select'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

/// Voice detail screen — fetches GET /api/v1/voices/{voice_id}.
class VoiceDetailScreen extends StatefulWidget {
  final String voiceId;
  const VoiceDetailScreen({super.key, required this.voiceId});

  @override
  State<VoiceDetailScreen> createState() => _VoiceDetailScreenState();
}

class _VoiceDetailScreenState extends State<VoiceDetailScreen> {
  Voice? _voice;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final Voice voice =
          await context.read<ApiService>().getVoiceDetail(widget.voiceId);
      if (mounted) {
        setState(() {
          _voice = voice;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('VOICE DETAILS')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load voice',
                  subtitle: _error,
                  actionLabel: 'Retry',
                  onAction: _load,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: <Widget>[
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: p.inverseBackground,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(Icons.person_outline_rounded,
                          color: p.inverseText, size: 44),
                    ),
                    const SizedBox(height: 16),
                    Text(_voice!.name,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Text(_voice!.id,
                        style: Theme.of(context).textTheme.bodySmall),
                    if (_voice!.description.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      Text(_voice!.description,
                          style: Theme.of(context).textTheme.bodyLarge),
                    ],
                    const SizedBox(height: 20),
                    _DetailRow(label: 'Gender', value: _voice!.gender),
                    _DetailRow(label: 'Style', value: _voice!.style),
                    _DetailRow(label: 'Language', value: _voice!.language),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: () {
                        context
                            .read<VoiceStudioProvider>()
                            .selectVoice(_voice!);
                        context
                            .read<SettingsProvider>()
                            .setDefaultVoice(_voice!.id, _voice!.name);
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Select this voice'),
                    ),
                  ],
                ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(Formatters.titleCase(value),
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
