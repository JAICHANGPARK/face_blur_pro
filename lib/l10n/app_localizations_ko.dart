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

  @override
  String get tutorialOpenPhoto => '여기를 눌러 갤러리에서 사진을 선택하세요';

  @override
  String get tutorialSelectFaces => '감지된 얼굴을 탭하여 블러 처리할 얼굴을 선택하세요';

  @override
  String get tutorialDrawMode => '그리기 모드로 수동으로 블러 영역을 추가할 수 있어요';

  @override
  String get tutorialBlurShape => '원형과 사각형 블러를 전환할 수 있어요';

  @override
  String get tutorialApplyBlur => '여기를 눌러 선택한 얼굴에 블러를 적용하세요';

  @override
  String get tutorialSave => '블러 처리된 이미지를 갤러리에 저장하세요';

  @override
  String get tutorialSkip => '건너뛰기';

  @override
  String get tutorialNext => '다음';

  @override
  String get tutorialFinish => '알겠어요!';
}
