import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../ai/ai_service.dart';
import '../../auth/auth_state.dart';
import '../../data/local_db.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _obscureKey = true;
  bool _isSaving = false;
  bool _isValidating = false;
  bool _isConfigured = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    final key = await LocalDb.instance.getGeminiApiKey();
    if (mounted) {
      setState(() {
        if (key != null && key.isNotEmpty) {
          _apiKeyController.text = key;
          _isConfigured = true;
        } else {
          _isConfigured = false;
        }
      });
    }
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid Gemini API key.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    await LocalDb.instance.saveGeminiApiKey(key);
    if (mounted) {
      setState(() {
        _isSaving = false;
        _isConfigured = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gemini API key saved securely in mobile SQLite.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.forest,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a Gemini API key first to test.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isValidating = true);
    try {
      await AiService.instance.testApiKey(key);
      if (mounted) {
        setState(() => _isValidating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Gemini API key verified successfully! Models active.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.forest,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isValidating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.alert,
          ),
        );
      }
    }
  }

  Future<void> _removeApiKey() async {
    await LocalDb.instance.deleteGeminiApiKey();
    if (mounted) {
      setState(() {
        _apiKeyController.clear();
        _isConfigured = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gemini API key removed from local SQLite.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.currentUser;
    final photoUrl = user?.photoUrl;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Profile & Settings',
          style: GoogleFonts.lora(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // User Card
            PulseCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.forest,
                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                        ? NetworkImage(photoUrl)
                        : null,
                    child: (photoUrl == null || photoUrl.isEmpty)
                        ? Text(
                            user?.initials ?? 'JS',
                            style: GoogleFonts.lora(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'User',
                          style: GoogleFonts.lora(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.muted),
                        ),
                        if (user?.organisation != null && user!.organisation!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            user.organisation!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Field Sensor Settings Card (ESP32 hardware)
            const FieldSensorSettingsCard(),
            const SizedBox(height: 20),

            // Gemini AI Settings Card (SQLite backed)
            PulseCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.forest.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.auto_awesome, color: AppColors.forest, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gemini AI Settings',
                              style: GoogleFonts.lora(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              'Stored on this device only',
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isConfigured
                              ? AppColors.forest.withValues(alpha: 0.12)
                              : Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: _isConfigured ? AppColors.forest : Colors.amber.shade800,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isConfigured ? 'Active' : 'No Key',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _isConfigured ? AppColors.forest : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Gemini API Key',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      hintText: 'Enter Google AI Studio Key (AIzaSy...)',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.muted),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.sageBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.sageBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.forest, width: 1.5),
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20,
                              color: AppColors.muted,
                            ),
                            onPressed: () => setState(() => _obscureKey = !_obscureKey),
                          ),
                          if (_apiKeyController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 20, color: AppColors.muted),
                              onPressed: () {
                                _apiKeyController.clear();
                                setState(() {});
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveApiKey,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_outlined, size: 16),
                        label: const Text('Save key'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isValidating ? null : _testConnection,
                        icon: _isValidating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.forest),
                              )
                            : const Icon(Icons.bolt, size: 16),
                        label: const Text('Test Key'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.forest,
                          side: const BorderSide(color: AppColors.forest),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                      if (_isConfigured)
                        TextButton.icon(
                          onPressed: _removeApiKey,
                          icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.alert),
                          label: const Text('Remove Key', style: TextStyle(color: AppColors.alert)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: Text(
                        'Technical details',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.forest,
                        ),
                      ),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.cream,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.sageBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Google AI Studio Working Models: gemini-3.8-flash · gemini-3.6-flash · gemini-3.5-flash-lite · gemini-3.1-flash-lite · gemini-3-flash · gemini-2.5-flash · gemini-2.5-flash-lite',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.forestDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '• Auto-fallback across Gemini 3.8 -> 3.6 -> 3.5 Lite (500 RPD) -> 3.1 Lite -> 3.0 -> 2.5 on quota limits.\n'
                                '• No API keys hardcoded; stored securely on-device in SQLite.\n'
                                '• Quota resets daily at midnight Pacific Time.',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Links
            PulseCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.analytics_outlined, color: AppColors.forest),
                    title: const Text('Reports & Analytics'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/reports'),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: AppColors.forest),
                    title: const Text('About PHI Formula'),
                    subtitle: const Text('Weights, tiers & prototype biological ranges'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('About PHI Formula'),
                          content: const Text(
                            'Pollinator Health Index (PHI):\n\n'
                            '• Activity: 30%\n'
                            '• Habitat Quality: 30%\n'
                            '• Environmental: 20%\n'
                            '• Risk Level: 20%\n\n'
                            'Note: Scoring thresholds are prototype values and not universal biological absolutes.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Got it'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout / Sign Out Button
            PressableScale(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Sign Out', style: TextStyle(color: AppColors.alert)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await context.read<AuthState>().signOut();
                }
              },
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Sign Out'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Sign Out', style: TextStyle(color: AppColors.alert)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await context.read<AuthState>().signOut();
                  }
                },
                icon: const Icon(Icons.logout_rounded, color: AppColors.alert),
                label: const Text('Sign Out', style: TextStyle(color: AppColors.alert)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.alert),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/pulse_logo.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'P.U.L.S.E. v1.0.0',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
