import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/api_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/services/audio_player_service.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/voice_studio_provider.dart';
import '../widgets/common_widgets.dart';
import 'voice_library_screen.dart';

/// Voice Studio — professional text-to-speech workspace.
/// Text editor on top; voice, style, engine, speed and volume controls
/// below; preview + generate with a live audio player.
class VoiceStudioScreen extends StatefulWidget {
  const VoiceStudioScreen({super.key});

  @override
  State<VoiceStudioScreen> createState() => _VoiceStudioScreenState();
}

class _VoiceStudioScreenState extends State<VoiceStudioScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;

  @override
  void initState() {
    super.initState();
    final VoiceStudioProvider studio = context.read<VoiceStudioProvider>();
    _textController.text = studio.text;
    _textController.addListener(() {
      if (_textController.text != studio.text) {
        studio.setText(_textController.text);
      }
    });
    final AudioPlayerService player = context.read<AudioPlayerService>();
    _stateSub = player.playerStateStream.listen((PlayerState state) {
      if (mounted) {
        setState(() => _playing = state == PlayerState.playing);
        context.read<VoiceStudioProvider>().notifyListeners();
      }
    });
    _positionSub = player.positionStream.listen((Duration d) {
      if (mounted) setState(() => _position = d);
    });
    _durationSub = player.durationStream.listen((Duration d) {
      if (mounted) setState(() => _duration = d);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (studio.voices.isEmpty && !studio.catalogLoading) {
        studio.loadCatalog();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _stateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    super.dispose();
  }

  double get _progress =>
      _duration.inMilliseconds > 0
          ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;

  Future<void> _pasteText() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? pasted = data?.text;
    if (pasted != null && pasted.isNotEmpty) {
      _textController.text = pasted;
      studioSetText(pasted);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty')),
      );
    }
  }

  void studioSetText(String value) {
    context.read<VoiceStudioProvider>().setText(value);
  }

  Future<void> _generate() async {
    final VoiceStudioProvider studio = context.read<VoiceStudioProvider>();
    final LibraryItem? item = await studio.generate();
    if (!mounted) return;
    if (item != null) {
      await context.read<LibraryProvider>().load();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio generated and saved to your library')),
      );
    }
  }

  Future<void> _shareGenerated() async {
    final VoiceStudioProvider studio = context.read<VoiceStudioProvider>();
    final LibraryItem? item = studio.lastSavedItem;
    if (item == null) return;
    await Share.shareXFiles(<XFile>[XFile(item.filePath)],
        text: 'Generated with PANDA AI STUDIO');
  }

  Future<void> _downloadGenerated() async {
    final VoiceStudioProvider studio = context.read<VoiceStudioProvider>();
    final LibraryItem? item = studio.lastSavedItem;
    if (item == null) return;
    // The file is already persisted in the app documents directory and
    // listed in the Library, where it can be shared/exported at any time.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Saved to your library as "${item.title}". Open Library to share or export it.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final ThemeData theme = Theme.of(context);
    final VoiceStudioProvider studio = context.watch<VoiceStudioProvider>();
    final SettingsProvider settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('VOICE STUDIO'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh voices',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: studio.catalogLoading ? null : () => studio.refreshVoices(),
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: <Widget>[
          if (!settings.hasToken)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ErrorBanner(
                message:
                    'No API token saved. Add your token in Settings → API Token to load voices and generate speech.',
                onRetry: null,
              ),
            ),
          if (studio.catalogError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ErrorBanner(
                message: studio.catalogError!,
                retryable: true,
                onRetry: () => studio.loadCatalog(),
                onDismiss: () => studio.clearError(),
              ),
            ),

          // ---- Text editor ----
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Your text', style: theme.textTheme.titleMedium),
              ),
              TextButton.icon(
                onPressed: _pasteText,
                icon: const Icon(Icons.content_paste_rounded, size: 16),
                label: const Text('Paste'),
              ),
              TextButton.icon(
                onPressed: () {
                  _textController.text = ApiConfig.sampleText;
                  studio.setSampleText();
                },
                icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                label: const Text('Sample'),
              ),
              TextButton.icon(
                onPressed: () {
                  _textController.clear();
                  studio.clearText();
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: p.surface,
              border: Border.all(color: p.border),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: _textController,
              maxLines: 7,
              minLines: 5,
              maxLength: ApiConfig.maxTtsChars,
              maxLengthEnforcement: MaxLengthEnforcement.none,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Type or paste the text you want to turn into speech…',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                counterText: '',
                contentPadding: const EdgeInsets.all(18),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Text(
                '${studio.charCount} / ${ApiConfig.maxTtsChars} characters',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: studio.charCount > ApiConfig.maxTtsChars
                      ? p.textPrimary
                      : p.textTertiary,
                  fontWeight: studio.charCount > ApiConfig.maxTtsChars
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
              const Spacer(),
              if (studio.charCount > ApiConfig.maxTtsChars)
                Text('Too long — shorten your text',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 20),

          // ---- Voice selector ----
          Text('Voice', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (studio.catalogLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (studio.voices.isEmpty)
            OutlinedButton.icon(
              onPressed: () => studio.loadCatalog(),
              icon: const Icon(Icons.cloud_off_outlined),
              label: const Text('Voices unavailable — tap to retry'),
            )
          else
            Material(
              color: p.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: p.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _showVoicePicker(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: p.inverseBackground,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.person_outline_rounded,
                            color: p.inverseText, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              studio.selectedVoice?.name ?? 'Select a voice',
                              style: theme.textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              studio.selectedVoice == null
                                  ? 'Tap to choose from ${studio.voices.length} voices'
                                  : '${studio.selectedVoice!.id} · tap to change',
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.expand_more_rounded, color: p.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),

          // ---- Style ----
          Text('Style', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (studio.styles.isEmpty)
            Text('Styles are loading…', style: theme.textTheme.bodySmall)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final VoiceStyle style in studio.styles)
                  ChoiceChip(
                    label: Text(Formatters.titleCase(style.id)),
                    selected: studio.selectedStyle == style.id,
                    onSelected: (_) => studio.selectStyle(style.id),
                  ),
              ],
            ),
          const SizedBox(height: 20),

          // ---- Engine ----
          Text('Engine', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (studio.engines.isEmpty)
            Text('Engines are loading…', style: theme.textTheme.bodySmall)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final Engine engine in studio.engines)
                  ChoiceChip(
                    label: Text(engine.id),
                    selected: studio.selectedEngine == engine.id,
                    onSelected: (_) => studio.selectEngine(engine.id),
                  ),
              ],
            ),
          const SizedBox(height: 20),

          // ---- Speed & volume ----
          Row(
            children: <Widget>[
              Expanded(child: Text('Speed', style: theme.textTheme.titleMedium)),
              Text('${studio.speed.toStringAsFixed(2)}×',
                  style: theme.textTheme.titleMedium),
            ],
          ),
          Slider(
            value: studio.speed,
            min: ApiConfig.minSpeed,
            max: ApiConfig.maxSpeed,
            divisions: 30,
            label: '${studio.speed.toStringAsFixed(2)}×',
            onChanged: studio.setSpeed,
          ),
          Row(
            children: <Widget>[
              Expanded(child: Text('Volume', style: theme.textTheme.titleMedium)),
              Text(studio.volume.toStringAsFixed(1),
                  style: theme.textTheme.titleMedium),
            ],
          ),
          Slider(
            value: studio.volume,
            min: ApiConfig.minVolume,
            max: ApiConfig.maxVolume,
            divisions: 40,
            label: studio.volume.toStringAsFixed(1),
            onChanged: studio.setVolume,
          ),
          const SizedBox(height: 12),

          // ---- Preview player ----
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.inverseBackground,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: p.inverseText,
                        foregroundColor: p.inverseBackground,
                        fixedSize: const Size(52, 52),
                      ),
                      icon: studio.isPreviewLoading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: p.inverseBackground),
                            )
                          : Icon(
                              _playing && studio.previewBytes != null
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 28,
                            ),
                      onPressed: studio.isPreviewLoading
                          ? null
                          : () => studio.playPreview(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Voice preview',
                              style: TextStyle(
                                  color: p.inverseText,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          Text(
                            studio.previewBytes == null
                                ? 'Hear a short sample of the selected voice'
                                : '${Formatters.duration(_duration)} · ${Formatters.duration(_position)} / ${Formatters.duration(_duration)}',
                            style: TextStyle(
                                color: p.inverseText.withOpacity(0.65),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedWaveform(progress: _progress, playing: _playing),
                if (_duration.inMilliseconds > 0)
                  Slider(
                    value: _progress,
                    onChanged: (double v) {
                      context.read<AudioPlayerService>().seek(
                          Duration(
                              milliseconds:
                                  (v * _duration.inMilliseconds).round()));
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- Error ----
          if (studio.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ErrorBanner(
                message: studio.errorMessage!,
                retryable: studio.errorRetryable,
                onRetry: _generate,
                onDismiss: () => studio.clearError(),
              ),
            ),

          // ---- Generate ----
          FilledButton.icon(
            onPressed: studio.canGenerate ? _generate : null,
            icon: studio.isGenerating
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: p.inverseText),
                  )
                : const Icon(Icons.graphic_eq_rounded, size: 20),
            label: Text(studio.isGenerating
                ? 'Generating audio…'
                : 'Generate speech'),
          ),
          const SizedBox(height: 10),
          if (studio.generatedBytes != null && studio.lastSavedItem != null)
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => studio.playGenerated(),
                    icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    label: const Text('Play'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _downloadGenerated,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareGenerated,
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 8),
          Text(
            'Generated audio is saved automatically to your Library.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  void _showVoicePicker(BuildContext context) {
    final VoiceStudioProvider studio = context.read<VoiceStudioProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          builder: (BuildContext context, ScrollController scroll) {
            return Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text('Choose a voice',
                            style: Theme.of(context).textTheme.titleLarge),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const VoiceLibraryScreen()),
                          );
                        },
                        child: const Text('Browse all'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search voices…',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: studio.setVoiceQuery,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: <Widget>[
                      for (final VoiceGenderFilter filter in VoiceGenderFilter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(switch (filter) {
                              VoiceGenderFilter.all => 'All',
                              VoiceGenderFilter.male => 'Male',
                              VoiceGenderFilter.female => 'Female',
                            }),
                            selected: studio.genderFilter == filter,
                            onSelected: (_) => studio.setGenderFilter(filter),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Consumer<VoiceStudioProvider>(
                    builder: (BuildContext context, VoiceStudioProvider s, Widget? child) {
                      final List<Voice> list = s.visibleVoices;
                      if (list.isEmpty) {
                        return const EmptyState(
                          icon: Icons.person_search_outlined,
                          title: 'No voices match',
                          subtitle: 'Try a different search or filter.',
                        );
                      }
                      return ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount: list.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Voice voice = list[index];
                          final bool selected = s.selectedVoice?.id == voice.id;
                          return ListTile(
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: selected
                                    ? context.palette.inverseBackground
                                    : context.palette.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.palette.border),
                              ),
                              child: Icon(
                                voice.isFemale
                                    ? Icons.person_outline_rounded
                                    : Icons.person_outline_rounded,
                                color: selected
                                    ? context.palette.inverseText
                                    : context.palette.textSecondary,
                              ),
                            ),
                            title: Text(voice.name),
                            subtitle: Text(
                              voice.description.isNotEmpty
                                  ? voice.description
                                  : voice.id,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: selected
                                ? Icon(Icons.check_circle_rounded,
                                    color: context.palette.textPrimary)
                                : null,
                            onTap: () {
                              s.selectVoice(voice);
                              Navigator.of(sheetContext).pop();
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
