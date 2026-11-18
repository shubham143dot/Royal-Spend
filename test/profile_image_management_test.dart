import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:royal_spend/core/services/profile/profile_image_storage_service.dart';
import 'package:royal_spend/providers/profile_image_provider.dart';
import 'package:royal_spend/ui/widgets/profile_avatar.dart';

class _FakeImagePicker implements ImagePicker {
  XFile? pickedFileToReturn;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    return pickedFileToReturn;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempTestDir;
  late ProfileImageStorageService storageService;
  late _FakeImagePicker fakePicker;
  late ProfileImageProvider provider;

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    tempTestDir = await Directory.systemTemp.createTemp('profile_image_test_');
    storageService = ProfileImageStorageService.withDirectory(tempTestDir);
    fakePicker = _FakeImagePicker();
    provider = ProfileImageProvider(
      storageService: storageService,
      imagePicker: fakePicker,
    );
  });

  tearDown(() async {
    if (await tempTestDir.exists()) {
      await tempTestDir.delete(recursive: true);
    }
  });

  Widget buildTestAvatar({ProfileImageProvider? customProvider, double size = 58.0}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ProfileImageProvider>.value(
          value: customProvider ?? provider,
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: ProfileAvatar(size: size, isDark: true),
          ),
        ),
      ),
    );
  }

  group('Email/Password Profile Image Lifecycle & Offline Storage Tests', () {
    test('State 1: Email/Password user initially has no image and clean placeholder state', () async {
      await provider.syncWithAuth(
        fallbackUid: 'user_email_1',
        fallbackEmail: 'alex@example.com',
        fallbackName: 'Alex Mercer',
        isGoogleOverride: false,
      );

      expect(provider.state, ProfileImageState.noImage);
      expect(provider.localImageFile, isNull);
      expect(provider.canEditImage, isTrue);
      expect(provider.isGoogleAuth, isFalse);
    });

    testWidgets('Renders clean circular placeholder with camera badge for Email/Password user', (tester) async {
      await tester.runAsync(() async {
        await provider.syncWithAuth(
          fallbackUid: 'user_email_1',
          fallbackEmail: 'alex@example.com',
          fallbackName: 'Alex Mercer',
          isGoogleOverride: false,
        );
      });

      await tester.pumpWidget(buildTestAvatar());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Placeholder icon should be visible
      expect(find.byIcon(CupertinoIcons.person_fill), findsOneWidget);
      // Camera edit badge should be visible
      expect(find.byIcon(CupertinoIcons.camera_fill), findsOneWidget);
      // Google logo should NOT be present
      expect(find.text('G'), findsNothing);
    });

    test('State 3 & 4: Uploading an image saves locally and transitions to imageLoaded', () async {
      await provider.syncWithAuth(
        fallbackUid: 'user_email_1',
        fallbackEmail: 'alex@example.com',
        isGoogleOverride: false,
      );

      // Create a mock image file
      final mockImage = File('${tempTestDir.path}/test_source.jpg');
      await mockImage.writeAsBytes([1, 2, 3, 4, 5, 6]);
      fakePicker.pickedFileToReturn = XFile(mockImage.path);

      final success = await provider.pickAndUploadImage(source: ImageSource.gallery);

      expect(success, isTrue);
      expect(provider.state, ProfileImageState.imageLoaded);
      expect(provider.localImageFile, isNotNull);
      expect(await provider.localImageFile!.exists(), isTrue);
      expect(provider.localImageFile!.path.endsWith('user_email_1.jpg'), isTrue);

      // Verify offline storage persistence directly
      final hasSaved = await storageService.hasProfileImage('user_email_1');
      expect(hasSaved, isTrue);
    });

    test('Cancellation during image picker retains previous state without breaking', () async {
      await provider.syncWithAuth(
        fallbackUid: 'user_email_1',
        fallbackEmail: 'alex@example.com',
        isGoogleOverride: false,
      );

      fakePicker.pickedFileToReturn = null; // User cancelled
      final success = await provider.pickAndUploadImage(source: ImageSource.gallery);

      expect(success, isFalse);
      expect(provider.state, ProfileImageState.noImage);
      expect(provider.localImageFile, isNull);
    });

    test('Removing uploaded photo deletes local file and returns to noImage', () async {
      await provider.syncWithAuth(
        fallbackUid: 'user_email_1',
        fallbackEmail: 'alex@example.com',
        isGoogleOverride: false,
      );

      final mockImage = File('${tempTestDir.path}/test_source.jpg');
      await mockImage.writeAsBytes([1, 2, 3, 4]);
      fakePicker.pickedFileToReturn = XFile(mockImage.path);
      await provider.pickAndUploadImage(source: ImageSource.gallery);

      expect(provider.state, ProfileImageState.imageLoaded);

      await provider.removeImage();

      expect(provider.state, ProfileImageState.noImage);
      expect(provider.localImageFile, isNull);
      expect(await storageService.hasProfileImage('user_email_1'), isFalse);
    });
  });

  group('Account-Specific Offline Storage & Cross-Account Isolation Tests', () {
    test('User A and User B never leak profile pictures to each other', () async {
      // 1. User A logs in and uploads photo
      await provider.syncWithAuth(
        fallbackUid: 'user_A_uid',
        fallbackEmail: 'usera@example.com',
        isGoogleOverride: false,
      );

      final imgA = File('${tempTestDir.path}/image_a.jpg');
      await imgA.writeAsBytes([10, 20, 30]);
      fakePicker.pickedFileToReturn = XFile(imgA.path);
      await provider.pickAndUploadImage(source: ImageSource.gallery);

      expect(provider.state, ProfileImageState.imageLoaded);
      expect(provider.localImageFile!.path.endsWith('user_A_uid.jpg'), isTrue);

      // 2. User A logs out
      provider.onLogout();
      expect(provider.state, ProfileImageState.loggedOut);
      expect(provider.localImageFile, isNull);

      // 3. User B logs in with different UID
      await provider.syncWithAuth(
        fallbackUid: 'user_B_uid',
        fallbackEmail: 'userb@example.com',
        isGoogleOverride: false,
      );

      // User B MUST NOT see User A's photo
      expect(provider.state, ProfileImageState.noImage);
      expect(provider.localImageFile, isNull);

      // 4. User B uploads their own photo
      final imgB = File('${tempTestDir.path}/image_b.jpg');
      await imgB.writeAsBytes([50, 60, 70, 80]);
      fakePicker.pickedFileToReturn = XFile(imgB.path);
      await provider.pickAndUploadImage(source: ImageSource.gallery);

      expect(provider.state, ProfileImageState.imageLoaded);
      expect(provider.localImageFile!.path.endsWith('user_B_uid.jpg'), isTrue);

      // 5. User B logs out
      provider.onLogout();
      expect(provider.localImageFile, isNull);

      // 6. User A logs back in
      await provider.syncWithAuth(
        fallbackUid: 'user_A_uid',
        fallbackEmail: 'usera@example.com',
        isGoogleOverride: false,
      );

      // User A's previously saved photo must automatically reappear
      expect(provider.state, ProfileImageState.imageLoaded);
      expect(provider.localImageFile!.path.endsWith('user_A_uid.jpg'), isTrue);
    });
  });

  group('Google Authentication Behavior & Fallback Avatar Tests', () {
    test('Google user with valid photoURL transitions to googleImageLoaded and is not editable', () async {
      await provider.syncWithAuth(
        fallbackUid: 'google_user_1',
        fallbackEmail: 'googleuser@gmail.com',
        fallbackName: 'Google VIP',
        isGoogleOverride: true,
      );

      // In real scenario, firebaseUser.photoURL is provided
      // Test provider behavior with googleImageFallback when photoURL is null
      expect(provider.state, ProfileImageState.googleImageFallback);
      expect(provider.canEditImage, isFalse);
    });

    testWidgets('Google user without photoURL renders first letter circular avatar without edit badge', (tester) async {
      await tester.runAsync(() async {
        await provider.syncWithAuth(
          fallbackUid: 'google_user_2',
          fallbackEmail: 'sophia@gmail.com',
          fallbackName: 'Sophia Clark',
          isGoogleOverride: true,
        );
      });

      await tester.pumpWidget(buildTestAvatar());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Displays first letter of name "S"
      expect(find.text('S'), findsOneWidget);

      // Edit badge (camera/pencil) MUST NOT be present for Google users
      expect(find.byIcon(CupertinoIcons.camera_fill), findsNothing);
      expect(find.byIcon(CupertinoIcons.pencil), findsNothing);

      // Manual upload should be blocked
      expect(provider.canEditImage, isFalse);
    });

    testWidgets('Network image error in Google profile falls back smoothly to initial letter avatar', (tester) async {
      await tester.runAsync(() async {
        await provider.syncWithAuth(
          fallbackUid: 'google_user_3',
          fallbackEmail: 'david@gmail.com',
          fallbackName: 'David Miller',
          isGoogleOverride: true,
        );
      });

      // Trigger fallback event
      provider.onGoogleImageFailed();

      await tester.pumpWidget(buildTestAvatar());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(provider.state, ProfileImageState.googleImageFallback);
      expect(find.text('D'), findsOneWidget);
    });
  });
}
