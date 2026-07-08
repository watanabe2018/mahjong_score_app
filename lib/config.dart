/// アプリ全体の設定値
///
/// 重要: 画像認識APIのキーはここには置きません。
/// PWA(Flutter Web)はビルド後すべてブラウザに配信されるため、
/// APIキーをここに書くとブラウザの開発者ツールから誰でも読み取れてしまいます。
/// 画像認識はFirebase Cloud Functions経由で呼び出し、APIキーはサーバー側(Secret Manager)にのみ保持します。
class AppConfig {
  /// デプロイしたFirebase Cloud FunctionsのURL
  /// 例: https://asia-northeast1-your-project-id.cloudfunctions.net/recognizeTiles
  static const String recognizeTilesEndpoint =
      'https://asia-northeast1-YOUR_PROJECT_ID.cloudfunctions.net/recognizeTiles';

  /// パスワードをローカルに保存する際のキー(SharedPreferences)
  static const String passwordStorageKey = 'app_shared_password';
}
