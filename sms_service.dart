import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sms_parser.dart';

class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  static const _seenKey = 'gh_seen_sms';

  // Callback when new parsed transactions found (live scan)
  Function(List<ParsedSms>)? onNewTransactions;

  // ── Permission ────────────────────────────────────────────────────────────
  Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<bool> hasPermission() async => await Permission.sms.isGranted;

  // ── Deduplication ─────────────────────────────────────────────────────────
  Future<Set<String>> _getSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_seenKey)?.toSet() ?? {};
  }

  Future<void> _markSeen(List<String> ids) async {
    final prefs   = await SharedPreferences.getInstance();
    final seen    = await _getSeenIds();
    seen.addAll(ids);
    final trimmed = seen.toList();
    if (trimmed.length > 1000) trimmed.removeRange(0, trimmed.length - 1000);
    await prefs.setStringList(_seenKey, trimmed);
  }

  // ── Scan inbox (on app open) ──────────────────────────────────────────────
  Future<List<ParsedSms>> scanInbox() async {
    if (!await hasPermission()) return [];

    try {
      final query = SmsQuery();

      // Get all inbox messages from last 7 days
      final since   = DateTime.now().subtract(const Duration(days: 7));
      final allMsgs = await query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 200,
      );

      // Filter to last 7 days
      final messages = allMsgs.where((m) {
        final date = m.date;
        return date != null && date.isAfter(since);
      }).toList();

      final seen    = await _getSeenIds();
      final results = <ParsedSms>[];
      final newIds  = <String>[];

      for (final msg in messages) {
        final id     = msg.id?.toString() ?? '';
        final sender = msg.sender ?? msg.address ?? '';
        final body   = msg.body ?? '';
        final date   = msg.date ?? DateTime.now();

        if (id.isEmpty || seen.contains(id)) continue;

        final parsed = SmsParser.parse(
          sender: sender,
          body:   body,
          date:   date,
          smsId:  id,
        );

        if (parsed != null) {
          results.add(parsed);
          newIds.add(id);
        }
      }

      if (newIds.isNotEmpty) await _markSeen(newIds);
      return results;
    } catch (e) {
      return [];
    }
  }

  // ── flutter_sms_inbox has no live listener — poll every 30s while open ───
  bool _polling = false;
  DateTime _lastCheck = DateTime.now();

  void startListening() {
    _polling    = true;
    _lastCheck  = DateTime.now();
    _pollLoop();
  }

  void stopListening() => _polling = false;

  Future<void> _pollLoop() async {
    while (_polling) {
      await Future.delayed(const Duration(seconds: 30));
      if (!_polling) break;
      try {
        final newTxs = await _checkNewSince(_lastCheck);
        _lastCheck = DateTime.now();
        if (newTxs.isNotEmpty) onNewTransactions?.call(newTxs);
      } catch (_) {}
    }
  }

  Future<List<ParsedSms>> _checkNewSince(DateTime since) async {
    if (!await hasPermission()) return [];
    final query   = SmsQuery();
    final allMsgs = await query.querySms(kinds: [SmsQueryKind.inbox], count: 20);
    final recent  = allMsgs.where((m) => m.date != null && m.date!.isAfter(since)).toList();

    final seen    = await _getSeenIds();
    final results = <ParsedSms>[];
    final newIds  = <String>[];

    for (final msg in recent) {
      final id     = msg.id?.toString() ?? '';
      final sender = msg.sender ?? msg.address ?? '';
      final body   = msg.body ?? '';
      final date   = msg.date ?? DateTime.now();

      if (id.isEmpty || seen.contains(id)) continue;

      final parsed = SmsParser.parse(sender: sender, body: body, date: date, smsId: id);
      if (parsed != null) {
        results.add(parsed);
        newIds.add(id);
      }
    }

    if (newIds.isNotEmpty) await _markSeen(newIds);
    return results;
  }
}
