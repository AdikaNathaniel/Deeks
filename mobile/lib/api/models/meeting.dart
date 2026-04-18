enum MeetingPlatform { zoom, googleMeet, microsoftTeams }

String meetingPlatformToWire(MeetingPlatform p) {
  switch (p) {
    case MeetingPlatform.zoom:
      return 'zoom';
    case MeetingPlatform.googleMeet:
      return 'google_meet';
    case MeetingPlatform.microsoftTeams:
      return 'microsoft_teams';
  }
}

MeetingPlatform meetingPlatformFromWire(String s) {
  switch (s) {
    case 'zoom':
      return MeetingPlatform.zoom;
    case 'google_meet':
      return MeetingPlatform.googleMeet;
    case 'microsoft_teams':
      return MeetingPlatform.microsoftTeams;
    default:
      throw ArgumentError('Unknown platform: $s');
  }
}

String meetingPlatformLabel(MeetingPlatform p) {
  switch (p) {
    case MeetingPlatform.zoom:
      return 'Zoom';
    case MeetingPlatform.googleMeet:
      return 'Google Meet';
    case MeetingPlatform.microsoftTeams:
      return 'Microsoft Teams';
  }
}

class Meeting {
  final String id;
  final String title;
  final MeetingPlatform platform;
  final String link;
  final String? meetingId;
  final String? passcode;
  final DateTime scheduledAt;
  final String? notes;

  Meeting({
    required this.id,
    required this.title,
    required this.platform,
    required this.link,
    required this.scheduledAt,
    this.meetingId,
    this.passcode,
    this.notes,
  });

  factory Meeting.fromJson(Map<String, dynamic> j) => Meeting(
        id: j['_id'] as String,
        title: j['title'] as String,
        platform: meetingPlatformFromWire(j['platform'] as String),
        link: j['link'] as String,
        meetingId: j['meetingId'] as String?,
        passcode: j['passcode'] as String?,
        scheduledAt: DateTime.parse(j['scheduledAt'] as String).toLocal(),
        notes: j['notes'] as String?,
      );

  Map<String, dynamic> toCreateJson() => {
        'title': title,
        'platform': meetingPlatformToWire(platform),
        'link': link,
        if (meetingId != null && meetingId!.isNotEmpty) 'meetingId': meetingId,
        if (passcode != null && passcode!.isNotEmpty) 'passcode': passcode,
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}
