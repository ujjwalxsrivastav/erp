import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';

/// ADMIN ONLY: bulk-import student results from a CSV file.
///
/// The admin picks the class and the exam session (Half Yearly / Final, from
/// `school_exam_sessions`), then uploads a CSV with one row per student and
/// subject. Rows are upserted into `school_marks`, which is exactly what the
/// report card reads — so the imported result shows up immediately.
///
/// Expected CSV (header row required, order does not matter):
///   student_username,student_name,subject,marks_obtained,total_marks
/// `roll_number`, `student_id` and `marks` are accepted as aliases.
class MarksCsvUploadScreen extends StatefulWidget {
  const MarksCsvUploadScreen({super.key});

  @override
  State<MarksCsvUploadScreen> createState() => _MarksCsvUploadScreenState();
}

class _ParsedMark {
  const _ParsedMark({
    required this.studentId,
    required this.studentName,
    required this.subject,
    required this.obtained,
    required this.total,
  });

  final String studentId;
  final String studentName;
  final String subject;
  final double obtained;
  final double total;
}

class _MarksCsvUploadScreenState extends State<MarksCsvUploadScreen> {
  static const Color _accent = Color(0xFF0EA5E9);
  static const Color _ink = Color(0xFF1E293B);
  static const Color _muted = Color(0xFF64748B);
  static const Color _red = Color(0xFFEF4444);
  static const Color _green = Color(0xFF10B981);

  final _schoolService = SchoolService();

  bool _isInitialising = true;
  bool _isRestricted = false;
  bool _isSaving = false;

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _students = [];
  Map<String, Map<String, dynamic>> _studentLookup = {};
  List<String> _examSessions = [];

  Map<String, dynamic>? _selectedClass;
  String _selectedExam = '';

  String _fileName = '';
  List<_ParsedMark> _parsed = [];
  List<String> _errors = [];

  int? _importedCount;
  String? _importError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Results are administered by the school admin only.
    final role = await AuthService().getCurrentUserRole();
    if (role != 'admin' &&
        role != 'sadmin' &&
        role != 'teacher' &&
        role != 'steacher') {
      if (mounted) {
        setState(() {
          _isRestricted = true;
          _isInitialising = false;
        });
      }
      return;
    }

    final classes = await _schoolService.getSchoolClasses();
    final exams = await _schoolService.getExamSessions();

    if (!mounted) return;
    setState(() {
      _classes = classes;
      _selectedClass = classes.isNotEmpty ? classes.first : null;
      _examSessions = exams;
      _selectedExam = exams.isNotEmpty ? exams.first : 'Half Yearly';
      _isInitialising = false;
    });

    await _loadStudents();
  }

  Future<void> _loadStudents() async {
    final selected = _selectedClass;
    if (selected == null) {
      if (mounted) setState(() => _students = []);
      return;
    }

    final classId = selected['id']?.toString() ?? '';
    final className = selected['name']?.toString();
    final students = await _schoolService.getStudentsInClass(
      classId,
      className: className,
    );

    final lookup = <String, Map<String, dynamic>>{};
    for (final s in students) {
      for (final raw in [s['username'], s['id'], s['roll_number']]) {
        final key = raw?.toString().trim().toLowerCase() ?? '';
        if (key.isEmpty) continue;
        lookup.putIfAbsent(key, () => s);
        final number = int.tryParse(key);
        if (number != null) {
          lookup.putIfAbsent(number.toString().padLeft(2, '0'), () => s);
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _students = students;
      _studentLookup = lookup;
      _parsed = [];
      _errors = [];
      _fileName = '';
      _importedCount = null;
      _importError = null;
    });
  }

  String _normalise(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  int _columnIndex(List<String> header, List<String> aliases) =>
      header.indexWhere(aliases.contains);

  String _cell(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index]?.toString().trim() ?? '';
  }

  Future<void> _pickCsv() async {
    if (_selectedClass == null) {
      _showMessage('Select a class first.', isError: true);
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String text = '';
      if (file.bytes != null) {
        text = utf8.decode(file.bytes!, allowMalformed: true);
      } else if (file.path != null) {
        text = await File(file.path!).readAsString();
      }

      if (text.trim().isEmpty) {
        _showMessage('That CSV file is empty.', isError: true);
        return;
      }

      _parseCsv(text, file.name);
    } catch (e) {
      _showMessage('Could not read the CSV file: $e', isError: true);
    }
  }

  void _parseCsv(String text, String fileName) {
    final normalisedText = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final List<List<dynamic>> rows;
    try {
      rows = const CsvToListConverter(
        shouldParseNumbers: false,
        eol: '\n',
      ).convert(normalisedText);
    } catch (_) {
      setState(() {
        _fileName = fileName;
        _parsed = [];
        _errors = ['The file is not valid CSV.'];
      });
      return;
    }

    if (rows.length < 2) {
      setState(() {
        _fileName = fileName;
        _parsed = [];
        _errors = ['The file needs a header row and at least one data row.'];
      });
      return;
    }

    final header =
        rows.first.map((c) => _normalise(c?.toString() ?? '')).toList();
    final studentCol = _columnIndex(header, [
      'studentusername',
      'username',
      'studentid',
      'rollnumber',
      'rollno',
      'roll',
    ]);
    final subjectCol = _columnIndex(header, ['subject']);
    final obtainedCol = _columnIndex(
      header,
      ['marksobtained', 'obtainedmarks', 'marks', 'obtained', 'score'],
    );
    final totalCol = _columnIndex(
      header,
      ['totalmarks', 'maxmarks', 'total', 'outof'],
    );

    final missing = <String>[];
    if (studentCol < 0) missing.add('student_username');
    if (subjectCol < 0) missing.add('subject');
    if (obtainedCol < 0) missing.add('marks_obtained');
    if (missing.isNotEmpty) {
      setState(() {
        _fileName = fileName;
        _parsed = [];
        _errors = [
          'Missing column(s): ${missing.join(', ')}. '
              'Expected header: student_username,student_name,subject,'
              'marks_obtained,total_marks',
        ];
      });
      return;
    }

    final parsed = <_ParsedMark>[];
    final errors = <String>[];
    final seen = <String>{};

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((c) => (c?.toString().trim() ?? '').isEmpty)) continue;

      final rowNumber = i + 1;
      final studentKey = _cell(row, studentCol).toLowerCase();
      final subject = _cell(row, subjectCol);
      final obtainedText = _cell(row, obtainedCol);
      final totalText = totalCol >= 0 ? _cell(row, totalCol) : '';

      if (studentKey.isEmpty) {
        errors.add('Row $rowNumber: student is blank.');
        continue;
      }
      if (subject.isEmpty) {
        errors.add('Row $rowNumber: subject is blank.');
        continue;
      }

      final student = _studentLookup[studentKey];
      if (student == null) {
        errors.add(
            'Row $rowNumber: "$studentKey" is not a student of ${_classLabel()}.');
        continue;
      }

      final obtained = double.tryParse(obtainedText);
      if (obtained == null) {
        errors.add('Row $rowNumber: "$obtainedText" is not a valid mark.');
        continue;
      }
      final total =
          totalText.isEmpty ? 100.0 : (double.tryParse(totalText) ?? 0.0);
      if (total <= 0) {
        errors.add('Row $rowNumber: total marks must be greater than 0.');
        continue;
      }
      if (obtained < 0 || obtained > total) {
        errors.add(
            'Row $rowNumber: mark $obtainedText must be between 0 and ${total.toStringAsFixed(0)}.');
        continue;
      }

      final studentId =
          student['username']?.toString() ?? student['id']?.toString() ?? '';
      final dedupeKey = '$studentId|${subject.toLowerCase()}';
      if (!seen.add(dedupeKey)) {
        errors.add(
            'Row $rowNumber: duplicate ${student['name'] ?? studentId} · $subject.');
        continue;
      }

      parsed.add(_ParsedMark(
        studentId: studentId,
        studentName: student['name']?.toString() ?? studentId,
        subject: subject,
        obtained: obtained,
        total: total,
      ));
    }

    setState(() {
      _fileName = fileName;
      _parsed = parsed;
      _errors = errors;
      _importedCount = null;
      _importError = null;
    });
  }

  Future<void> _importMarks() async {
    final selected = _selectedClass;
    if (selected == null || _parsed.isEmpty || _selectedExam.isEmpty) return;

    setState(() {
      _isSaving = true;
      _importedCount = null;
      _importError = null;
    });

    final classId = selected['id']?.toString() ?? '';
    final className = selected['name']?.toString() ?? '';

    var saved = 0;
    String? failure;
    const chunkSize = 150;

    for (var start = 0; start < _parsed.length; start += chunkSize) {
      final chunk = _parsed.sublist(
        start,
        math.min(start + chunkSize, _parsed.length),
      );
      final rows = chunk
          .map((m) => <String, dynamic>{
                'student_id': m.studentId,
                'student_name': m.studentName,
                'class_id': classId,
                'class_name': className,
                'subject': m.subject,
                'exam_type': _selectedExam,
                'marks_obtained': m.obtained,
                'total_marks': m.total,
              })
          .toList();

      final ok = await _schoolService.saveMarks(rows);
      if (!ok) {
        failure = _schoolService.lastMarksError ?? 'Could not save the marks.';
        break;
      }
      saved += chunk.length;
    }

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _importedCount = saved;
      _importError = failure;
    });

    if (failure == null) {
      _showMessage(
        'Imported $saved result${saved == 1 ? '' : 's'} for $_selectedExam.',
        isError: false,
      );
    } else {
      _showMessage(
        saved > 0
            ? 'Saved $saved of ${_parsed.length} results, then stopped: $failure'
            : failure,
        isError: true,
      );
    }
  }

  String _classLabel() =>
      _selectedClass?['name']?.toString() ??
      _selectedClass?['id']?.toString() ??
      '';

  void _showMessage(String text, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? _red : _green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _copyTemplate() async {
    const template =
        'student_username,student_name,subject,marks_obtained,total_marks\n'
        'sstudent1,Aarav Sharma,Mathematics,92,100';
    await Clipboard.setData(const ClipboardData(text: template));
    if (!mounted) return;
    _showMessage('CSV format copied to clipboard.', isError: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isRestricted) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Upload Results (CSV)'),
          backgroundColor: _accent,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 64, color: Color(0xFF94A3B8)),
                SizedBox(height: 14),
                Text(
                  'Administrator only',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Uploading student results from CSV is restricted to the school admin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: _muted),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Upload Results (CSV)',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0C4A6E), Color(0xFF0284C7), Color(0xFF38BDF8)],
            ),
          ),
        ),
      ),
      body: _isInitialising
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _buildFormatCard(),
                const SizedBox(height: 14),
                _buildSelectors(),
                const SizedBox(height: 14),
                _buildUploadCard(),
                if (_errors.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildErrorCard(),
                ],
                if (_parsed.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildPreviewCard(),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _importMarks,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _green.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload_outlined),
                      label: Text(
                        _isSaving
                            ? 'Importing…'
                            : 'Import ${_parsed.length} result${_parsed.length == 1 ? '' : 's'} for $_selectedExam',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
                if (_importedCount != null || _importError != null) ...[
                  const SizedBox(height: 12),
                  _buildResultCard(),
                ],
              ],
            ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildFormatCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: _accent, size: 20),
              SizedBox(width: 8),
              Text(
                'CSV format',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'One row per student and subject. The header row is required; '
            'column order does not matter. `total_marks` defaults to 100.',
            style: TextStyle(fontSize: 12.5, color: _muted, height: 1.35),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'student_username,student_name,subject,marks_obtained,total_marks\n'
              'sstudent1,Aarav Sharma,Mathematics,92,100',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: Color(0xFF334155),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _copyTemplate,
              icon: const Icon(Icons.copy_all_outlined, size: 16),
              label: const Text('Copy format'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectors() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<Map<String, dynamic>>(
            initialValue: _selectedClass,
            decoration: InputDecoration(
              labelText: 'Class',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: _classes
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c['name']?.toString() ?? ''),
                    ))
                .toList(),
            onChanged: (c) async {
              if (c == null) return;
              setState(() => _selectedClass = c);
              await _loadStudents();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue:
                _examSessions.contains(_selectedExam) ? _selectedExam : null,
            decoration: InputDecoration(
              labelText: 'Result for',
              helperText: 'Exam session shown on the student report card',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: _examSessions
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (e) {
              if (e == null) return;
              setState(() {
                _selectedExam = e;
                _parsed = [];
                _errors = [];
                _fileName = '';
                _importedCount = null;
                _importError = null;
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            '${_students.length} students in ${_classLabel()}',
            style: TextStyle(fontSize: 11.5, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.table_chart_outlined, color: _accent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Choose the CSV file',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              if (_fileName.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_fileName · ${_parsed.length} rows',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0369A1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _pickCsv,
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                side: const BorderSide(color: _accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.file_upload_outlined),
              label: Text(
                _fileName.isEmpty ? 'Select CSV file' : 'Replace CSV file',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_errors.length} row${_errors.length == 1 ? '' : 's'} skipped',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB91C1C),
            ),
          ),
          const SizedBox(height: 6),
          ..._errors.take(8).map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '· $e',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF991B1B),
                      height: 1.35,
                    ),
                  ),
                ),
              ),
          if (_errors.length > 8)
            Text(
              '…and ${_errors.length - 8} more.',
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF991B1B),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    final students = _parsed.map((p) => p.studentId).toSet().length;
    final subjects = _parsed.map((p) => p.subject).toSet().length;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ready to import',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_parsed.length} results · $students students · $subjects subjects',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 12),
          ..._parsed.take(10).map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          p.studentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          p.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                      ),
                      Text(
                        '${p.obtained.toStringAsFixed(p.obtained % 1 == 0 ? 0 : 1)}'
                        ' / ${p.total.toStringAsFixed(p.total % 1 == 0 ? 0 : 1)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          if (_parsed.length > 10)
            Text(
              '…and ${_parsed.length - 10} more.',
              style: TextStyle(fontSize: 11.5, color: _muted),
            ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final failed = _importError != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: failed ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: failed ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            failed ? Icons.error_outline : Icons.check_circle_outline,
            color: failed ? _red : _green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              failed
                  ? '$_importedCount of ${_parsed.length} saved. $_importError'
                  : '${_importedCount ?? 0} results saved to $_selectedExam. '
                      'They now appear on the students’ report cards.',
              style: TextStyle(
                fontSize: 12,
                color:
                    failed ? const Color(0xFF991B1B) : const Color(0xFF065F46),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
