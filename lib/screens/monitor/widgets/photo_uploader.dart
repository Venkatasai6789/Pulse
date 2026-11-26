import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../../theme/app_theme.dart';

class PhotoUploader extends StatelessWidget {
  final String assessmentId;
  final List<String> photoPaths;
  final ValueChanged<List<String>> onPhotosChanged;
  final String label;

  const PhotoUploader({
    super.key,
    required this.assessmentId,
    required this.photoPaths,
    required this.onPhotosChanged,
    this.label = 'Add a Photograph (Optional)',
  });

  static const int maxPhotos = 5;

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    Navigator.of(context).pop(); // dismiss bottom sheet
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final folder = Directory('${appDir.path}/photos/$assessmentId');
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
      final filename = '${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      final destinationPath = '${folder.path}/$filename';
      final savedFile = await File(picked.path).copy(destinationPath);

      final updated = List<String>.from(photoPaths)..add(savedFile.path);
      onPhotosChanged(updated);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Permission denied or error accessing camera/gallery.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () {
                Geolocator.openAppSettings();
              },
            ),
          ),
        );
      }
    }
  }

  void _showSourceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.sageBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Upload Photo',
                  style: GoogleFonts.lora(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: AppColors.forest),
                  title: Text('Take photo', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  onTap: () => _pickImage(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: AppColors.forest),
                  title: Text('Choose from gallery', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  onTap: () => _pickImage(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.close_rounded, color: AppColors.muted),
                  title: Text('Cancel', style: GoogleFonts.inter(color: AppColors.muted)),
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _removePhoto(int index) {
    final updated = List<String>.from(photoPaths)..removeAt(index);
    onPhotosChanged(updated);
  }

  void _openFullScreen(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullScreenPhotoGallery(
          photos: photoPaths,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildImageWidget(String path) {
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(Icons.broken_image_outlined, color: AppColors.muted),
        ),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Center(
        child: Icon(Icons.broken_image_outlined, color: AppColors.muted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        if (photoPaths.isEmpty)
          InkWell(
            onTap: () => _showSourceSheet(context),
            borderRadius: BorderRadius.circular(AppRadius.chip),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(
                  color: AppColors.sageBorder,
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_upload_outlined, color: AppColors.leaf, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Upload Image',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forest,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photoPaths.length + (photoPaths.length < maxPhotos ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index < photoPaths.length) {
                  final path = photoPaths[index];
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => _openFullScreen(context, index),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                            border: Border.all(color: AppColors.sageBorder),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _buildImageWidget(path),
                        ),
                      ),
                      Positioned(
                        top: -5,
                        right: -5,
                        child: GestureDetector(
                          onTap: () => _removePhoto(index),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: AppColors.ink,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  // Add tile
                  return InkWell(
                    onTap: () => _showSourceSheet(context),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                        border: Border.all(
                          color: AppColors.sageBorder,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, color: AppColors.leaf, size: 22),
                          SizedBox(height: 2),
                          Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.forest,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ),
      ],
    );
  }
}

class FullScreenPhotoGallery extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;

  const FullScreenPhotoGallery({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<FullScreenPhotoGallery> createState() => _FullScreenPhotoGalleryState();
}

class _FullScreenPhotoGalleryState extends State<FullScreenPhotoGallery> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildImage(String path) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.contain);
    }
    return Image.file(File(path), fit: BoxFit.contain);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${_currentIndex + 1} of ${widget.photos.length}',
          style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photos.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(
              child: _buildImage(widget.photos[index]),
            ),
          );
        },
      ),
    );
  }
}
