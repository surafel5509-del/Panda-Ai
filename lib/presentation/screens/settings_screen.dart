import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/services/api_service.dart';
import '../../data/services/library_service.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/common_widgets.dart';

/// Settings — appearance, API token panel, audio defaults, chat
/// preferences, storage management and about.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _storageBytes = 0;
  int _audioCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshStorage();
  }

  Future<void> _refreshStorage() async {
    final LibraryProvider library = context.read<LibraryProvider>();
    final int bytes = await library.totalBytes();
    if (mounted) {
      setState(() {
        _storageBytes = bytes;
        _audioCount = library.items.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: <Widget>[
          // Header
          Row(
            children: <Widget>[
              const PandaMark(size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('PANDA AI STUDIO',
                        style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800, letterSpacing: 1)),
                    Text('Your Voice. Your Intelligence.',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const _ApiTokenPanel(),
          const SizedBox(height: 24),

          Text('APPEARANCE', style: _sectionStyle(context)),
          const SizedBox(height: 8),
          const _AppearanceSection(),
          const SizedBox(height: 24),

          Text('AUDIO DEFAULTS', style: _sectionStyle(context)),
          const SizedBox(height: 8),
          const _AudioDefaultsSection(),
          const SizedBox(height: 24),

          Text('CHAT', style: _sectionStyle(context)),
          const SizedBox(height: 8),
          const _ChatSection(),
          const SizedBox(height: 24),

          Text('STORAGE', style: _sectionStyle(context)),
          const SizedBox(height: 8),
          _StorageSection(
            bytes: _storageBytes,
            count: _audioCount,
            onChanged: _refreshStorage,
          ),
          const SizedBox(height: 24),

          Text('ABOUT', style: _sectionStyle(context)),
          const SizedBox(height: 8),
          const _AboutSection(),
        ],
      ),
    );
  }

  TextStyle _sectionStyle(BuildContext context) {
    return Theme.of(context)
        .textTheme
        .bodySmall!
        .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.4);
  }
}

// ---------------------------------------------------------------------------
// API token panel
// ---------------------------------------------------------------------------

class _ApiTokenPanel extends StatefulWidget {
  const _ApiTokenPanel();

  @override
  State<_ApiTokenPanel> createState() => _ApiTokenPanelState();
}

class _ApiTokenPanelState extends State<_ApiTokenPanel> {
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;
  bool _initialized = false;

  @override
  void dispose() {
    _tokenController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveToken() async {
    final String token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste your API token first')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<SettingsProvider>().saveToken(token);
      _tokenController.clear();
      setState(() {
        _testResult = 'Token saved securely on this device.';
        _testOk = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API token saved')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _removeToken() async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Remove API token?',
      message:
          'Your saved token will be deleted from this device. You will need to add it again to use voices, speech generation and chat.',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
    await context.read<SettingsProvider>().removeToken();
    setState(() {
      _testResult = null;
      _testOk = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API token removed')),
      );
    }
  }

  Future<void> _testToken() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final Map<String, dynamic> account =
          await context.read<SettingsProvider>().testToken();
      final String summary = account.isEmpty
          ? 'Connection successful — token is valid.'
          : 'Connected. Account data received from the server.';
      setState(() {
        _testResult = summary;
        _testOk = true;
      });
    } catch (e) {
      setState(() {
        _testResult = e.toString();
        _testOk = false;
      });
    }
    if (mounted) setState(() => _testing = false);
  }

  Future<void> _saveBaseUrl() async {
    final String url = _baseUrlController.text.trim();
    if (url.isEmpty) return;
    await context.read<SettingsProvider>().setBaseUrl(url);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API base URL saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final ThemeData theme = Theme.of(context);
    final SettingsProvider settings = context.watch<SettingsProvider>();

    if (!_initialized) {
      _baseUrlController.text = settings.baseUrl;
      _initialized = true;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.inverseBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.key_rounded, color: p.inverseText, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text('API TOKEN',
                    style: TextStyle(
                        color: p.inverseText,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: p.inverseText.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  settings.hasToken ? 'CONNECTED' : 'NOT SET',
                  style: TextStyle(
                      color: p.inverseText,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Your Panda Voice AI API token is stored only in this device\'s secure storage (Keychain / Keystore) and sent as the X-API-Key header. It is never hard-coded in the app.',
            style: TextStyle(
                color: p.inverseText.withOpacity(0.7),
                fontSize: 12.5,
                height: 1.45),
          ),
          const SizedBox(height: 14),
          if (settings.hasToken) ...<Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: p.inverseText.withOpacity(0.35)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      settings.maskedToken ?? '',
                      style: TextStyle(
                          color: p.inverseText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1),
                    ),
                  ),
                  TextButton(
                    onPressed: _removeToken,
                    child: Text('Remove',
                        style: TextStyle(color: p.inverseText)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _tokenController,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            style: TextStyle(color: p.inverseText),
            decoration: InputDecoration(
              hintText: settings.hasToken
                  ? 'Paste a new token to replace the saved one…'
                  : 'Paste your Panda API token…',
              hintStyle: TextStyle(color: p.inverseText.withOpacity(0.5)),
              filled: true,
              fillColor: p.inverseText.withOpacity(0.1),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: p.inverseText.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: p.inverseText, width: 1.5),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: p.inverseText),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: p.inverseText,
                    foregroundColor: p.inverseBackground,
                  ),
                  onPressed: _saving ? null : _saveToken,
                  child: _saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: p.inverseBackground),
                        )
                      : const Text('Save token'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.inverseText,
                    side: BorderSide(color: p.inverseText.withOpacity(0.5)),
                  ),
                  onPressed: _testing ? null : _testToken,
                  child: _testing
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: p.inverseText),
                        )
                      : const Text('Test connection'),
                ),
              ),
            ],
          ),
          if (_testResult != null) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                    _testOk
                        ? Icons.check_circle_outline_rounded
                        : Icons.error_outline_rounded,
                    size: 18,
                    color: p.inverseText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _testResult!,
                    style: TextStyle(
                        color: p.inverseText.withOpacity(0.85),
                        fontSize: 12.5,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Divider(color: p.inverseText.withOpacity(0.25)),
          const SizedBox(height: 12),
          Text('API BASE URL',
              style: TextStyle(
                  color: p.inverseText,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          TextField(
            controller: _baseUrlController,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.url,
            style: TextStyle(color: p.inverseText, fontSize: 13),
            decoration: InputDecoration(
              hintText: ApiConfig.defaultBaseUrl,
              hintStyle: TextStyle(color: p.inverseText.withOpacity(0.5)),
              filled: true,
              fillColor: p.inverseText.withOpacity(0.1),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: p.inverseText.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: p.inverseText, width: 1.5),
              ),
              suffixIcon: IconButton(
                icon: Icon(Icons.save_outlined, color: p.inverseText),
                tooltip: 'Save base URL',
                onPressed: _saveBaseUrl,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Default: ${ApiConfig.defaultBaseUrl}',
            style: TextStyle(
                color: p.inverseText.withOpacity(0.55), fontSize: 11),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ---------------------------------------------------------------------------
// Appearance
// ---------------------------------------------------------------------------

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final SettingsProvider settings = context.watch<SettingsProvider>();
    return _Card(
      child: Column(
        children: <Widget>[
          _ThemeOption(
            mode: ThemeMode.system,
            icon: Icons.brightness_auto_outlined,
            title: 'System',
            subtitle: 'Follow your device theme',
            selected: settings.themeMode == ThemeMode.system,
            onTap: () => settings.setThemeMode(ThemeMode.system),
          ),
          _ThemeOption(
            mode: ThemeMode.light,
            icon: Icons.light_mode_outlined,
            title: 'Light',
            subtitle: 'White background, black text',
            selected: settings.themeMode == ThemeMode.light,
            onTap: () => settings.setThemeMode(ThemeMode.light),
          ),
          _ThemeOption(
            mode: ThemeMode.dark,
            icon: Icons.dark_mode_outlined,
            title: 'Dark',
            subtitle: 'Black background, white text',
            selected: settings.themeMode == ThemeMode.dark,
            onTap: () => settings.setThemeMode(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final ThemeMode mode;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeOption({
    required this.mode,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
      ),
      selected: selected,
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Audio defaults
// ---------------------------------------------------------------------------

class _AudioDefaultsSection extends StatelessWidget {
  const _AudioDefaultsSection();

  @override
  Widget build(BuildContext context) {
    final SettingsProvider settings = context.watch<SettingsProvider>();
    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(child: Text('Default speed')),
                Text('${settings.defaultSpeed.toStringAsFixed(2)}×',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            Slider(
              value: settings.defaultSpeed,
              min: ApiConfig.minSpeed,
              max: ApiConfig.maxSpeed,
              divisions: 30,
              onChanged: settings.setDefaultSpeed,
            ),
            Row(
              children: <Widget>[
                const Expanded(child: Text('Default volume')),
                Text(settings.defaultVolume.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            Slider(
              value: settings.defaultVolume,
              min: ApiConfig.minVolume,
              max: ApiConfig.maxVolume,
              divisions: 40,
              onChanged: settings.setDefaultVolume,
            ),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.graphic_eq_outlined),
              title: const Text('Default engine'),
              subtitle: Text(settings.defaultEngine ?? 'Not set'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _pickEngine(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Default voice'),
              subtitle: Text(settings.defaultVoiceName ?? 'Not set'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _pickVoice(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickEngine(BuildContext context) async {
    final SettingsProvider settings = context.read<SettingsProvider>();
    List<String> engines = ApiConfig.documentedEngines;
    try {
      final List<dynamic> fetched =
          await context.read<ApiService>().getEngines().then(
                (List<dynamic> e) => e,
              );
      if (fetched.isNotEmpty) {
        engines = fetched.map((dynamic e) => e.id.toString()).toList();
      }
    } catch (_) {
      // Keep documented engines when the API is unreachable.
    }
    if (!context.mounted) return;
    final String? picked = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: const Text('Default engine'),
        children: <Widget>[
          for (final String engine in engines)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(engine),
              child: Text(engine),
            ),
        ],
      ),
    );
    if (picked != null) {
      await settings.setDefaultEngine(picked);
    }
  }

  Future<void> _pickVoice(BuildContext context) async {
    final SettingsProvider settings = context.read<SettingsProvider>();
    List<VoiceSummary> voices = <VoiceSummary>[];
    try {
      final dynamic fetched =
          await context.read<ApiService>().getVoices(pageSize: 50);
      voices = (fetched as List<dynamic>)
          .map((dynamic v) => VoiceSummary(
                id: v.id.toString(),
                name: v.name.toString(),
              ))
          .toList();
    } catch (_) {
      // Leave empty — the dialog will show an empty state.
    }
    if (!context.mounted) return;
    final VoiceSummary? picked = await showDialog<VoiceSummary>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: const Text('Default voice'),
        children: voices.isEmpty
            ? <Widget>[
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                      'No voices available. Check your API token and connection.'),
                ),
              ]
            : <Widget>[
                for (final VoiceSummary voice in voices)
                  SimpleDialogOption(
                    onPressed: () => Navigator.of(context).pop(voice),
                    child: Text(voice.name),
                  ),
              ],
      ),
    );
    if (picked != null) {
      await settings.setDefaultVoice(picked.id, picked.name);
    }
  }
}

class VoiceSummary {
  final String id;
  final String name;
  const VoiceSummary({required this.id, required this.name});
}

// ---------------------------------------------------------------------------
// Chat preferences
// ---------------------------------------------------------------------------

class _ChatSection extends StatelessWidget {
  const _ChatSection();

  static const Map<String, String> _languages = <String, String>{
    '': 'Auto (follow my language)',
    'en': 'English',
    'ar': 'Arabic',
    'es': 'Spanish',
    'la': 'Latin',
  };

  @override
  Widget build(BuildContext context) {
    final SettingsProvider settings = context.watch<SettingsProvider>();
    return _Card(
      child: Column(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: const Text('Chat language'),
            subtitle: Text(_languages[settings.chatLanguage] ?? 'Auto'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final String? picked = await showDialog<String>(
                context: context,
                builder: (BuildContext context) => SimpleDialog(
                  title: const Text('Chat language'),
                  children: <Widget>[
                    for (final MapEntry<String, String> e in _languages.entries)
                      SimpleDialogOption(
                        onPressed: () => Navigator.of(context).pop(e.key),
                        child: Text(e.value),
                      ),
                  ],
                ),
              );
              if (picked != null) {
                await settings.setChatLanguage(picked);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: const Text('Manage conversations'),
            subtitle: const Text('View and delete chats in the Chat tab'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Open the Chat tab → history icon to manage conversations')),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Storage
// ---------------------------------------------------------------------------

class _StorageSection extends StatelessWidget {
  final int bytes;
  final int count;
  final VoidCallback onChanged;
  const _StorageSection({
    required this.bytes,
    required this.count,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final LibraryProvider library = context.read<LibraryProvider>();
    final LibraryService libraryService = context.read<LibraryService>();
    return _Card(
      child: Column(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('Saved audio'),
            subtitle: Text('$count item${count == 1 ? '' : 's'} · ${Formatters.fileSize(bytes)} on this device'),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Clear temporary files'),
            subtitle: const Text('Removes preview audio caches'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              await libraryService.clearTempFiles();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Temporary files cleared')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: const Text('Delete all saved audio'),
            subtitle: const Text('Removes every generated file from this device'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final bool confirmed = await showConfirmDialog(
                context,
                title: 'Delete all saved audio?',
                message:
                    'All $count generated audio file${count == 1 ? '' : 's'} will be permanently deleted from this device.',
                confirmLabel: 'Delete all',
              );
              if (confirmed) {
                await library.clearAll();
                onChanged();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All saved audio deleted')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// About
// ---------------------------------------------------------------------------

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: <Widget>[
          const ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('PANDA AI STUDIO'),
            subtitle: Text('Version 1.0.0+1 · Your Voice. Your Intelligence.'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy policy'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showInfo(
              context,
              'Privacy policy',
              'PANDA AI STUDIO stores your API token only in your device\'s secure storage and your generated audio and chat history only on your device. Text you send for speech generation or chat is transmitted to the Panda Voice AI service over HTTPS so it can be processed. No audio or chat content is sold or shared for advertising.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of service'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showInfo(
              context,
              'Terms of service',
              'By using PANDA AI STUDIO you agree to use the Panda Voice AI service in accordance with its terms, including its usage limits and fair-use policies. You are responsible for keeping your API token confidential and for the content you generate. Generated audio is provided for lawful personal and commercial use subject to the service terms.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline_rounded),
            title: const Text('Help and support'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showInfo(
              context,
              'Help and support',
              'Getting started: 1) Open Settings and paste your Panda API token, then tap Save token. 2) Tap Test connection to verify it works. 3) Open the Voice Studio, pick a voice and generate speech. 4) Use AI Chat to talk with Panda AI. If something fails, check your connection and token, then retry — error messages in the app explain what went wrong.',
            ),
          ),
        ],
      ),
    );
  }

  void _showInfo(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared card
// ---------------------------------------------------------------------------

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}
