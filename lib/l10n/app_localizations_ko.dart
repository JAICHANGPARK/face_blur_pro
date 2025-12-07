// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '얼굴 흐리게';

  @override
  String get toggleBlurShape => '블러 모양 변경';

  @override
  String get toggleOutlines => '윤곽선 보기/숨기기';

  @override
  String get reset => '초기화';

  @override
  String get share => '공유';

  @override
  String get save => '저장';

  @override
  String get selectAll => '전체 선택';

  @override
  String get deselectAll => '전체 선택 해제';

  @override
  String get uploadPrompt => '사진을 업로드해주세요.';

  @override
  String get openPhotoButton => '사진 열기';

  @override
  String get applyBlurButton => '블러 실행';

  @override
  String get blurComplete => '블러 처리가 완료되었습니다. ✨';

  @override
  String get saveSuccess => '갤러리에 저장되었습니다! ✅';

  @override
  String get saveFailure => '저장에 실패했습니다 😢';
}
