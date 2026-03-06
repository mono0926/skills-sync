import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// A utility to manage persistent audit results.
class AuditCache {
  AuditCache._(this._file, this._data);

  final File _file;
  final Map<String, dynamic> _data;

  /// Loads the audit cache from the default location.
  /// Location: ~/.config/skills_sync/audit-cache.json
  static Future<AuditCache> load() async {
    final home = Platform.environment['HOME'] ?? '';
    final file = File(
      p.join(home, '.config', 'skills_sync', 'audit-cache.json'),
    );

    var data = <String, dynamic>{};
    if (file.existsSync()) {
      try {
        final content = await file.readAsString();
        data = jsonDecode(content) as Map<String, dynamic>;
      } on Exception catch (_) {
        // Fallback to empty if corrupt
      }
    }
    return AuditCache._(file, data);
  }

  /// Gets the audit result for a specific skill hash.
  Map<String, dynamic>? getAudit(String hash) {
    return _data[hash] as Map<String, dynamic>?;
  }

  /// Saves the audit cache to disk.
  Future<void> save() async {
    if (!_file.parent.existsSync()) {
      _file.parent.createSync(recursive: true);
    }
    const encoder = JsonEncoder.withIndent('  ');
    await _file.writeAsString(encoder.convert(_data));
  }

  /// Updates or adds an audit result for a specific skill hash.
  ///
  /// [summary] is a brief description of the changes.
  /// [securityStatus] can be 'safe', 'caution', or 'unsafe'.
  /// [details] optional additional information about security risks.
  void updateAudit(
    String hash, {
    required String summary,
    required String securityStatus,
    String? details,
  }) {
    _data[hash] = {
      'summary': summary,
      'securityStatus': securityStatus,
      'details': details,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
}
