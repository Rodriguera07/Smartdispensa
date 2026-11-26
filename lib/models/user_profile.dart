import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/formatters.dart';
import 'reminder_settings.dart';

/// Perfil e preferências do usuário.
///
/// Firestore: `users/{uid}`
class UserProfile {
  const UserProfile({
    required this.uid,
    this.name,
    this.email,
    this.autoSendToList = false,
    this.darkMode = true,
    this.scanPeriod,
    this.scanCount = 0,
    this.reminders = const ReminderSettings(),
  });

  final String uid;
  final String? name;
  final String? email;

  /// Quando `true`, item zerado na despensa vai direto para a lista
  /// sem perguntar.
  final bool autoSendToList;

  final bool darkMode;

  /// Mês de referência da contagem de scans ("2026-11").
  final String? scanPeriod;
  final int scanCount;

  /// Lembretes de compra do mês.
  final ReminderSettings reminders;

  /// Scans usados no mês corrente (zera automaticamente na virada do mês).
  int scansUsedThisMonth([DateTime? now]) =>
      scanPeriod == monthKey(now ?? DateTime.now()) ? scanCount : 0;

  String get firstName {
    final n = (name ?? '').trim();
    if (n.isEmpty) return '';
    return n.split(' ').first;
  }

  UserProfile copyWith({
    String? name,
    bool? autoSendToList,
    bool? darkMode,
    String? scanPeriod,
    int? scanCount,
    ReminderSettings? reminders,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      email: email,
      autoSendToList: autoSendToList ?? this.autoSendToList,
      darkMode: darkMode ?? this.darkMode,
      scanPeriod: scanPeriod ?? this.scanPeriod,
      scanCount: scanCount ?? this.scanCount,
      reminders: reminders ?? this.reminders,
    );
  }

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return UserProfile(
      uid: doc.id,
      name: d['name'] as String?,
      email: d['email'] as String?,
      autoSendToList: (d['autoSendToList'] as bool?) ?? false,
      darkMode: (d['darkMode'] as bool?) ?? true,
      scanPeriod: d['scanPeriod'] as String?,
      scanCount: (d['scanCount'] as num?)?.toInt() ?? 0,
      reminders: ReminderSettings.fromMap(
        (d['reminders'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }
}
