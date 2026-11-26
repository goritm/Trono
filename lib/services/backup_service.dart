import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/bathroom_log.dart';

class BackupService {
  static const _uuid = Uuid();

  static Future<void> exportJson(List<BathroomLog> logs) async {
    final payload = {
      'app': 'trono',
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'count': logs.length,
      'logs': logs.map((l) => l.toJson()).toList(),
    };
    final pretty = const JsonEncoder.withIndent('  ').convert(payload);
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().split('T').first;
    final file = File(p.join(dir.path, 'trono_backup_$stamp.json'));
    await file.writeAsString(pretty);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Trono Backup ($stamp)',
      ),
    );
  }

  static Future<void> exportCsv(List<BathroomLog> logs) async {
    final buf = StringBuffer();
    buf.writeln(
      'id,type,timestamp,bristol_type,size,effort,duration_seconds,color,tags,note,share_level,location_kind,latitude,longitude,place_label',
    );
    for (final l in logs) {
      buf.writeln([
        _csvEscape(l.id),
        _csvEscape(l.type.dbValue),
        _csvEscape(l.timestamp.toIso8601String()),
        l.bristolType?.toString() ?? '',
        _csvEscape(l.size?.dbValue ?? ''),
        _csvEscape(l.effort?.dbValue ?? ''),
        l.durationSeconds?.toString() ?? '',
        _csvEscape(l.color?.dbValue ?? ''),
        _csvEscape(l.tags.join(';')),
        _csvEscape(l.note ?? ''),
        _csvEscape(l.shareLevel.dbValue),
        _csvEscape(l.locationKind?.dbValue ?? ''),
        l.latitude?.toString() ?? '',
        l.longitude?.toString() ?? '',
        _csvEscape(l.placeLabel ?? ''),
      ].join(','));
    }

    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().split('T').first;
    final file = File(p.join(dir.path, 'trono_export_$stamp.csv'));
    await file.writeAsString(buf.toString());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Trono CSV ($stamp)',
      ),
    );
  }

  static Future<List<BathroomLog>?> pickAndParseBackup() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json', 'csv'],
    );
    if (picked == null || picked.path == null) return null;

    final file = File(picked.path!);
    final raw = await file.readAsString();
    final ext = p.extension(picked.path!).toLowerCase();

    if (ext == '.csv' || !raw.trimLeft().startsWith('{') && !raw.trimLeft().startsWith('[')) {
      return _parseCsv(raw);
    }
    return _parseJson(raw);
  }

  static List<BathroomLog> _parseJson(String raw) {
    final decoded = jsonDecode(raw);
    final List<dynamic> items;
    if (decoded is Map<String, dynamic> && decoded['logs'] is List) {
      items = decoded['logs'] as List<dynamic>;
    } else if (decoded is List) {
      items = decoded;
    } else {
      throw const FormatException('Unrecognized Trono JSON format');
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map((m) {
          final parsed = BathroomLog.fromJson(m);
          if (parsed.id.isEmpty) {
            return parsed.copyWith(id: _uuid.v4());
          }
          return parsed;
        })
        .toList();
  }

  static List<BathroomLog> _parseCsv(String raw) {
    final lines = const LineSplitter()
        .convert(raw)
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.length < 2) return [];

    final logs = <BathroomLog>[];
    for (int i = 1; i < lines.length; i++) {
      final cols = _splitCsvLine(lines[i]);
      if (cols.length < 3) continue;
      final id = cols[0].trim().isEmpty ? _uuid.v4() : cols[0].trim();
      final type = BathroomType.fromDb(cols[1].trim());
      final ts = DateTime.tryParse(cols[2].trim()) ?? DateTime.now();
      final bristol = cols.length > 3 ? int.tryParse(cols[3].trim()) : null;
      final size = cols.length > 4 ? PoopSize.fromDb(cols[4].trim()) : null;
      final effort =
          cols.length > 5 ? EffortLevel.fromDb(cols[5].trim()) : null;
      final dur = cols.length > 6 ? int.tryParse(cols[6].trim()) : null;
      final color = cols.length > 7 ? StoolColor.fromDb(cols[7].trim()) : null;
      final tags = cols.length > 8
          ? cols[8]
              .split(';')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : <String>[];
      final note = cols.length > 9 && cols[9].trim().isNotEmpty ? cols[9] : null;
      final share = cols.length > 10
          ? ShareLevel.fromDb(cols[10].trim())
          : ShareLevel.summaryOnly;
      final locKind = cols.length > 11
          ? LocationKind.fromDb(cols[11].trim())
          : null;
      final lat = cols.length > 12 ? double.tryParse(cols[12].trim()) : null;
      final lng = cols.length > 13 ? double.tryParse(cols[13].trim()) : null;
      final placeLabel =
          cols.length > 14 && cols[14].trim().isNotEmpty ? cols[14] : null;

      logs.add(
        BathroomLog(
          id: id,
          type: type,
          timestamp: ts,
          bristolType: bristol,
          size: size,
          effort: effort,
          durationSeconds: dur,
          color: color,
          tags: tags,
          note: note,
          locationKind: locKind,
          latitude: lat,
          longitude: lng,
          placeLabel: placeLabel,
          shareLevel: share,
          createdAt: ts,
          updatedAt: DateTime.now(),
        ),
      );
    }
    return logs;
  }

  static String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final current = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (inQuotes) {
        if (char == '"' && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else if (char == '"') {
          inQuotes = false;
        } else {
          current.write(char);
        }
      } else {
        if (char == '"') {
          inQuotes = true;
        } else if (char == ',') {
          result.add(current.toString());
          current.clear();
        } else {
          current.write(char);
        }
      }
    }
    result.add(current.toString());
    return result;
  }
}
