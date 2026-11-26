import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class ReportConcernScreen extends StatelessWidget {
  const ReportConcernScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Report a Concern',
          style: GoogleFonts.lora(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PulseCard(
                color: AppColors.alertSoft,
                borderColor: AppColors.alert.withValues(alpha: 0.3),
                child: Text(
                  'Note: P.U.L.S.E. records potential risk indicators. It does not detect specific chemicals or pesticide residues and does not constitute laboratory-confirmed contamination.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.alert,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Area Description *',
                  hintText: 'e.g. Flower beds along North perimeter',
                ),
              ),
              const SizedBox(height: 16),
              const TextField(
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Observed Concern Details *',
                  hintText: 'Describe signs of chemical spraying, dumping, or pollution...',
                ),
              ),
              const SizedBox(height: 24),
              PressableScale(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Concern report logged.')),
                  );
                  context.pop();
                },
                child: FilledButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Concern report logged.')),
                    );
                    context.pop();
                  },
                  child: const Text('Submit Report'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
