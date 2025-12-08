// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Face Blur';

  @override
  String get toggleBlurShape => 'Toggle Blur Shape';

  @override
  String get toggleOutlines => 'Toggle Outlines';

  @override
  String get reset => 'Reset';

  @override
  String get share => 'Share';

  @override
  String get save => 'Save';

  @override
  String get selectAll => 'Select All';

  @override
  String get deselectAll => 'Deselect All';

  @override
  String get uploadPrompt => 'Please upload a photo.';

  @override
  String get openPhotoButton => 'Open Photo';

  @override
  String get applyBlurButton => 'Apply Blur';

  @override
  String get blurComplete => 'Blur processing is complete. ✨';

  @override
  String get saveSuccess => 'Saved to gallery! ✅';

  @override
  String get saveFailure => 'Failed to save 😢';

  @override
  String get tutorialOpenPhoto =>
      'Tap here to select a photo from your gallery';

  @override
  String get tutorialSelectFaces =>
      'Tap on detected faces to select them for blurring';

  @override
  String get tutorialDrawMode =>
      'Use drawing mode to manually add blur regions';

  @override
  String get tutorialBlurShape =>
      'Switch between circular and rectangular blur';

  @override
  String get tutorialApplyBlur => 'Tap here to apply blur to selected faces';

  @override
  String get tutorialSave => 'Save the blurred image to your gallery';

  @override
  String get tutorialSkip => 'Skip';

  @override
  String get tutorialNext => 'Next';

  @override
  String get tutorialFinish => 'Got it!';
}
