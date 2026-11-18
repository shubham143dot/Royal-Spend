import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/haptic_helper.dart';
import '../../providers/profile_image_provider.dart';

/// Premium Apple iOS-inspired Circular Profile Avatar.
///
/// Automatically reflects authentication provider states:
/// - Google Authentication: Displays Google photoURL or vibrant initial letter fallback. No edit badge.
/// - Email/Password Authentication: Starts with a clean circular placeholder, allows native photo picking,
///   and displays account-specific locally saved pictures with an elegant camera badge.
class ProfileAvatar extends StatelessWidget {
  final double size;
  final bool showEditBadge;
  final bool isDark;
  final VoidCallback? onTap;

  const ProfileAvatar({
    super.key,
    this.size = 58.0,
    this.showEditBadge = true,
    this.isDark = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileImageProvider>(
      builder: (context, controller, child) {
        final canEdit = controller.canEditImage;
        final hasImage = controller.localImageFile != null;

        return GestureDetector(
          onTap: () {
            if (onTap != null) {
              onTap!();
            } else if (canEdit) {
              _showImageActionSheet(context, controller, hasImage);
            }
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Perfectly circular avatar container
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.royalGold.withValues(alpha: isDark ? 0.70 : 0.85),
                    width: size > 44 ? 2.0 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.royalGold.withValues(alpha: isDark ? 0.25 : 0.18),
                      blurRadius: size > 44 ? 10 : 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: _buildAvatarContent(context, controller),
                  ),
                ),
              ),

              // 2. Subtle camera/edit indicator badge (Only for Email/Password when editable)
              if (showEditBadge && canEdit)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: (size * 0.38).clamp(20.0, 26.0),
                    height: (size * 0.38).clamp(20.0, 26.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isDark
                          ? const LinearGradient(
                              colors: [Color(0xFF0A84FF), Color(0xFF0071E3)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : AppColors.royalGradient,
                      border: Border.all(
                        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        hasImage ? CupertinoIcons.pencil : CupertinoIcons.camera_fill,
                        size: (size * 0.19).clamp(10.0, 13.0),
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatarContent(BuildContext context, ProfileImageProvider controller) {
    switch (controller.state) {
      case ProfileImageState.googleImageLoaded:
        if (controller.googlePhotoUrl != null) {
          return Image.network(
            controller.googlePhotoUrl!,
            key: ValueKey(controller.googlePhotoUrl),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              controller.onGoogleImageFailed();
              return _buildGoogleFallbackAvatar(controller);
            },
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return _buildLoadingAvatar();
            },
          );
        }
        return _buildGoogleFallbackAvatar(controller);

      case ProfileImageState.googleImageFallback:
        return _buildGoogleFallbackAvatar(controller);

      case ProfileImageState.googleImageLoading:
      case ProfileImageState.loading:
        return _buildLoadingAvatar();

      case ProfileImageState.uploading:
      case ProfileImageState.imageReplacing:
        return Stack(
          alignment: Alignment.center,
          children: [
            if (controller.localImageFile != null && controller.localImageFile!.existsSync())
              Opacity(
                opacity: 0.4,
                child: Image.file(
                  controller.localImageFile!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                ),
              )
            else
              _buildCleanPlaceholder(),
            _buildLoadingAvatar(),
          ],
        );

      case ProfileImageState.imageLoaded:
        if (controller.localImageFile != null && controller.localImageFile!.existsSync()) {
          return Image.file(
            controller.localImageFile!,
            key: ValueKey(controller.localImageFile!.path),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildCleanPlaceholder(),
          );
        }
        return _buildCleanPlaceholder();

      case ProfileImageState.noImage:
      case ProfileImageState.imageError:
      case ProfileImageState.loggedOut:
      case ProfileImageState.accountSwitched:
        return _buildCleanPlaceholder();
    }
  }

  /// Clean, premium circular placeholder for Email/Password users without an image.
  Widget _buildCleanPlaceholder() {
    return Container(
      key: const ValueKey('clean_placeholder'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
      ),
      child: Center(
        child: Icon(
          CupertinoIcons.person_fill,
          size: size * 0.52,
          color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366),
        ),
      ),
    );
  }

  /// Subtle iOS-style loading avatar.
  Widget _buildLoadingAvatar() {
    final isTesting = Platform.environment.containsKey('FLUTTER_TEST');
    return Container(
      width: size,
      height: size,
      color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
      child: Center(
        child: CupertinoActivityIndicator(
          radius: (size * 0.18).clamp(8.0, 16.0),
          color: AppColors.royalGold,
          animating: !isTesting,
        ),
      ),
    );
  }

  /// Circular Google Initial Avatar displaying the first letter of user's name/email.
  Widget _buildGoogleFallbackAvatar(ProfileImageProvider controller) {
    final rawName = controller.displayName ?? controller.currentEmail ?? 'R';
    final initial = rawName.trim().isNotEmpty ? rawName.trim().substring(0, 1).toUpperCase() : 'R';

    // Generate consistent vibrant gradient colors based on initial letter
    final colorPair = _getAvatarGradientForInitial(initial);

    return Container(
      key: ValueKey('google_initial_$initial'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colorPair,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.44,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }

  List<Color> _getAvatarGradientForInitial(String letter) {
    final code = letter.codeUnits.first;
    switch (code % 5) {
      case 0:
        return const [Color(0xFF4285F4), Color(0xFF1967D2)]; // Google Blue
      case 1:
        return const [Color(0xFF34A853), Color(0xFF137333)]; // Google Green
      case 2:
        return const [Color(0xFFFBBC05), Color(0xFFE37400)]; // Google Amber
      case 3:
        return const [Color(0xFFEA4335), Color(0xFFC5221F)]; // Google Red
      case 4:
      default:
        return const [Color(0xFF7C3AED), Color(0xFF5B21B6)]; // Purple / Royal Indigo
    }
  }

  /// Presents the iOS-style Action Sheet for profile picture management.
  void _showImageActionSheet(BuildContext context, ProfileImageProvider controller, bool hasExistingImage) {
    HapticHelper.mediumImpact();

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Profile Photo', style: TextStyle(fontWeight: FontWeight.w700)),
        message: const Text('Select a photo for your Royal Spend account'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _handleImagePick(context, controller, ImageSource.camera);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.camera, size: 20),
                SizedBox(width: 8),
                Text('Take Photo'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _handleImagePick(context, controller, ImageSource.gallery);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo_on_rectangle, size: 20),
                SizedBox(width: 8),
                Text('Choose from Library'),
              ],
            ),
          ),
          if (hasExistingImage)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.of(ctx).pop();
                HapticHelper.heavyImpact();
                await controller.removeImage();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Profile picture removed'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.trash, size: 20, color: CupertinoColors.destructiveRed),
                  SizedBox(width: 8),
                  Text('Remove Photo'),
                ],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _handleImagePick(
    BuildContext context,
    ProfileImageProvider controller,
    ImageSource source,
  ) async {
    final success = await controller.pickAndUploadImage(source: source);
    if (!context.mounted) return;

    if (success) {
      HapticHelper.selectionClick();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile picture updated successfully'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: AppColors.appleGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(controller.errorMessage!),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: AppColors.appleRed,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
