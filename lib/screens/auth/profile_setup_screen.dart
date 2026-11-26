import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_state.dart';
import '../../theme/app_theme.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _orgController;
  String _selectedRole = 'Individual';
  bool _isSaving = false;

  static const _roles = [
    'Individual',
    'School',
    'Residential Society',
    'NGO',
    'Municipal',
    'Expert',
  ];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthState>();
    final user = auth.currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _orgController = TextEditingController(text: user?.organisation ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _orgController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final auth = context.read<AuthState>();
    final orgName = _orgController.text.trim();
    final effectiveOrg = orgName.isNotEmpty
        ? '$orgName ($_selectedRole)'
        : _selectedRole;

    await auth.completeProfileSetup(
      name: name,
      organisation: effectiveOrg,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.currentUser;
    final firstName = user?.firstName ?? 'there';
    final photoUrl = user?.photoUrl;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(4),
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: AppColors.forest,
                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                        ? NetworkImage(photoUrl)
                        : null,
                    child: (photoUrl == null || photoUrl.isEmpty)
                        ? Text(
                            user?.initials ?? '?',
                            style: GoogleFonts.lora(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title & Subtitle
              Center(
                child: Text(
                  'Welcome, $firstName!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lora(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Tell us a little about you to personalize your experience.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Name Field
              Text(
                'Full Name *',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. Dr. Maya Lin',
                ),
              ),
              const SizedBox(height: 20),

              // Organisation Field
              Text(
                'Organisation (optional)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _orgController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. Green Earth Foundation',
                ),
              ),
              const SizedBox(height: 24),

              // Who are you? chip group
              Text(
                'Who are you?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: _roles.map((role) {
                  final isSelected = _selectedRole == role;
                  return ChoiceChip(
                    label: Text(role),
                    selected: isSelected,
                    selectedColor: AppColors.forest,
                    backgroundColor: Colors.white,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.ink,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected ? AppColors.forest : AppColors.sageBorder,
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedRole = role;
                        });
                      }
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 36),

              // Continue Button
              FilledButton(
                onPressed: _isSaving ? null : _handleContinue,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Continue'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
