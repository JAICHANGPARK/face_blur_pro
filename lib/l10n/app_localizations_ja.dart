// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => '顔ぼかし';

  @override
  String get toggleBlurShape => 'ぼかしの形を切り替え';

  @override
  String get toggleOutlines => '輪郭の表示/非表示';

  @override
  String get reset => 'リセット';

  @override
  String get share => '共有';

  @override
  String get save => '保存';

  @override
  String get selectAll => 'すべて選択';

  @override
  String get deselectAll => '選択をすべて解除';

  @override
  String get uploadPrompt => '写真をアップロードしてください。';

  @override
  String get openPhotoButton => '写真を開く';

  @override
  String get applyBlurButton => 'ぼかしを実行';

  @override
  String get blurComplete => 'ぼかし処理が完了しました。✨';

  @override
  String get saveSuccess => 'ギャラリーに保存しました！✅';

  @override
  String get saveFailure => '保存に失敗しました 😢';

  @override
  String get tutorialOpenPhoto => 'ここをタップしてギャラリーから写真を選択します';

  @override
  String get tutorialSelectFaces => '検出された顔をタップして、ぼかし処理する顔を選択します';

  @override
  String get tutorialDrawMode => '描画モードで手動でぼかし範囲を追加できます';

  @override
  String get tutorialBlurShape => '円形と四角形のぼかしを切り替えることができます';

  @override
  String get tutorialApplyBlur => 'ここをタップして選択した顔にぼかしを適用します';

  @override
  String get tutorialSave => 'ぼかし処理された画像をギャラリーに保存します';

  @override
  String get tutorialSkip => 'スキップ';

  @override
  String get tutorialNext => '次へ';

  @override
  String get tutorialFinish => '完了';
}
