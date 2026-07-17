enum AppNotificationType {
  bookingRequested,
  bookingConfirmed,
  bookingDeclined,
  bookingCanceled,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.bookingId,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'].toString(),
      bookingId: _optionalText(json['booking_id']),
      type: _type(json['type']),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      isRead: json['is_read'] == true,
      createdAt: DateTime.parse(json['created_at'].toString()).toLocal(),
    );
  }

  final String id;
  final String? bookingId;
  final AppNotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  static AppNotificationType _type(Object? value) {
    return switch (value?.toString()) {
      'booking_requested' => AppNotificationType.bookingRequested,
      'booking_confirmed' => AppNotificationType.bookingConfirmed,
      'booking_declined' => AppNotificationType.bookingDeclined,
      _ => AppNotificationType.bookingCanceled,
    };
  }

  static String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
