import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class NewPostScreen extends StatelessWidget {
  const NewPostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Create Community Post',
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
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Post Title *',
                  hintText: 'Share an update or event',
                ),
              ),
              const SizedBox(height: 16),
              const TextField(
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Post Content *',
                  hintText: 'Write your thoughts or announcement here...',
                ),
              ),
              const SizedBox(height: 24),
              PressableScale(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post published successfully!')),
                  );
                  context.pop();
                },
                child: FilledButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Post published successfully!')),
                    );
                    context.pop();
                  },
                  child: const Text('Publish Post'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
