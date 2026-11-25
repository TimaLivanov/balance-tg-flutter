/// Информация о запуске внутри Telegram Mini App.
class TelegramInfo {
  final String initData;
  final String? username;
  final String platform;

  const TelegramInfo({
    required this.initData,
    this.username,
    this.platform = '',
  });
}
