import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _oneMinuteWarningId = 1001;
  static const String _gameChannelId = 'game_timer_warning';
  static const String _gameChannelName = 'Avisos de partida';
  static const String _gameChannelDescription =
      'Notificaciones del temporizador de la partida';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        defaultPresentAlert: true,
        defaultPresentBadge: false,
        defaultPresentBanner: true,
        defaultPresentList: true,
        defaultPresentSound: true,
      ),
    );

    await _plugin.initialize(settings: initializationSettings);
    await _createAndroidChannel();
  }

  Future<void> scheduleOneMinuteRemainingWarning({
    required Duration totalDuration,
  }) async {
    await cancelGameNotifications();

    if (totalDuration <= const Duration(minutes: 1)) {
      return;
    }

    await requestPermissions();

    final scheduledAt = tz.TZDateTime.now(
      tz.UTC,
    ).add(totalDuration - const Duration(minutes: 1));

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _gameChannelId,
        _gameChannelName,
        channelDescription: _gameChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      id: _oneMinuteWarningId,
      title: 'Queda 1 minuto',
      body: 'La ronda está por terminar. Prepárense para votar.',
      scheduledDate: scheduledAt,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelGameNotifications() {
    return _plugin.cancel(id: _oneMinuteWarningId);
  }

  Future<void> requestPermissions() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosPlugin?.requestPermissions(alert: true, badge: false, sound: true);
  }

  Future<void> _createAndroidChannel() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) {
      return;
    }

    const channel = AndroidNotificationChannel(
      _gameChannelId,
      _gameChannelName,
      description: _gameChannelDescription,
      importance: Importance.high,
    );

    await androidPlugin.createNotificationChannel(channel);
  }
}
