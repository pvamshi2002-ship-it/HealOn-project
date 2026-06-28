import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'documents_module.dart';
import 'resume_upload_stub.dart'
    if (dart.library.html) 'resume_upload_web.dart'
    as resume_upload;

const _inkBlue = Color(0xFF172554);
const _brandBlue = Color(0xFF2563EB);
const _brandTeal = Color(0xFF10B981);
const _lineColor = Color(0xFFE2E8F0);
const _mutedText = Color(0xFF64748B);

String? parseCareerSlugFromUri() {
  if (!kIsWeb) return null;
  final fragment = Uri.base.fragment;
  if (fragment.isEmpty) return null;
  final parts = fragment.split('/').where((part) => part.isNotEmpty).toList();
  if (parts.length >= 2 && parts.first == 'careers') {
    return parts.sublist(1).join('/');
  }
  return null;
}

class CareerApiClient {
  CareerApiClient({
    required this.backendUrl,
    this.token,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  final String backendUrl;
  final String? token;
  final http.Client httpClient;

  Map<String, String> _headers({bool jsonBody = false}) {
    final headers = <String, String>{};
    if (jsonBody) headers['Content-Type'] = 'application/json';
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Token $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> get(String path, {bool auth = true}) async {
    final resp = await httpClient.get(
      Uri.parse('$backendUrl$path'),
      headers: _headers(),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception(_error(resp));
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final resp = await httpClient.post(
      Uri.parse('$backendUrl$path'),
      headers: _headers(jsonBody: true),
      body: jsonEncode(body),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return {};
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception(_error(resp));
  }

  String _error(http.Response resp) {
    try {
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final detail = decoded['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      for (final value in decoded.values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
        if (value is String && value.isNotEmpty) return value;
      }
    } catch (_) {}
    return 'Request failed (${resp.statusCode})';
  }
}

class JobApplicationForm extends StatefulWidget {
  const JobApplicationForm({
    super.key,
    required this.onSubmit,
    this.submitLabel = 'Submit Application',
    this.initialName = '',
    this.initialEmail = '',
  });

  final Future<void> Function(Map<String, dynamic> payload) onSubmit;
  final String submitLabel;
  final String initialName;
  final String initialEmail;

  @override
  State<JobApplicationForm> createState() => _JobApplicationFormState();
}

class _JobApplicationFormState extends State<JobApplicationForm> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final _coverLetterCtrl = TextEditingController();
  String? _resumeFileName;
  String? _resumeData;
  bool _submitting = false;
  bool _pickingResume = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.initialName;
    _emailCtrl.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _experienceCtrl.dispose();
    _skillsCtrl.dispose();
    _coverLetterCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Future<void> _pickResume() async {
    setState(() => _pickingResume = true);
    try {
      final upload = await resume_upload.pickResumeFile();
      if (upload == null) return;
      setState(() {
        _resumeFileName = upload.fileName;
        _resumeData = upload.dataUrl;
      });
    } finally {
      if (mounted) setState(() => _pickingResume = false);
    }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Name and email are required.');
      return;
    }
    if (_resumeData == null || _resumeData!.trim().isEmpty) {
      setState(() => _error = 'Resume upload is required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit({
        'full_name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'experience': _experienceCtrl.text.trim(),
        'skills': _skillsCtrl.text.trim(),
        'cover_letter': _coverLetterCtrl.text.trim(),
        'resume_file_name': _resumeFileName ?? 'resume.pdf',
        'resume_data': _resumeData!,
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        _compactField('Full Name', _nameCtrl),
        _compactField('Email', _emailCtrl),
        _compactField('Phone', _phoneCtrl),
        _compactField('Experience', _experienceCtrl, maxLines: 3),
        _compactField('Skills', _skillsCtrl, maxLines: 2),
        _compactField('Cover Letter', _coverLetterCtrl, maxLines: 3),
        const SizedBox(height: 8),
        const Text('Resume', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: _pickingResume ? null : _pickResume,
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(0, 34),
          ),
          icon: _pickingResume
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file_outlined, size: 16),
          label: Text(
            _resumeFileName ?? 'Upload resume (PDF/DOC/Image)',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: _brandBlue,
            minimumSize: const Size(double.infinity, 36),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.submitLabel, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  Widget _compactField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13),
        decoration: _fieldDecoration(label),
      ),
    );
  }
}

class PublicJobApplyScreen extends StatefulWidget {
  const PublicJobApplyScreen({
    super.key,
    required this.backendUrl,
    required this.slug,
    this.httpClient,
    this.onBackToLogin,
  });

  final String backendUrl;
  final String slug;
  final http.Client? httpClient;
  final VoidCallback? onBackToLogin;

  @override
  State<PublicJobApplyScreen> createState() => _PublicJobApplyScreenState();
}

class _PublicJobApplyScreenState extends State<PublicJobApplyScreen> {
  late final CareerApiClient _client = CareerApiClient(
    backendUrl: widget.backendUrl,
    httpClient: widget.httpClient,
  );
  Map<String, dynamic>? _job;
  bool _loading = true;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _client.get('/api/public/jobs/${widget.slug}/');
      setState(() {
        _job = data['job'] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submitApplication(Map<String, dynamic> payload) async {
    await _client.post('/api/public/jobs/${widget.slug}/apply/', payload);
    setState(() => _success = 'Application submitted successfully.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Job Application'),
        backgroundColor: _brandBlue,
        foregroundColor: Colors.white,
        leading: widget.onBackToLogin == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBackToLogin,
              ),
        actions: [
          if (widget.onBackToLogin != null)
            TextButton(
              onPressed: widget.onBackToLogin,
              child: const Text('Login', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _job == null
                ? Text(_error!, style: const TextStyle(color: Colors.red))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _lineColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _job?['title']?.toString() ?? 'Job Opening',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: _inkBlue,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              [
                                _job?['department_name'],
                                _job?['designation_name'],
                              ].whereType<String>().where((v) => v.isNotEmpty).join(' • '),
                              style: const TextStyle(color: _mutedText, fontSize: 12),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _job?['description']?.toString() ?? '',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_success != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            _success!,
                            style: TextStyle(color: Colors.green.shade800, fontSize: 13),
                          ),
                        ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _lineColor),
                        ),
                        child: JobApplicationForm(
                          submitLabel: 'Submit Application',
                          onSubmit: _success == null ? _submitApplication : (_) async {},
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class EmployeeCareerScreen extends StatefulWidget {
  const EmployeeCareerScreen({
    super.key,
    required this.backendUrl,
    required this.token,
    required this.section,
    required this.onSectionChanged,
    this.httpClient,
    this.onNotify,
    this.employeeName = '',
    this.employeeEmail = '',
  });

  final String backendUrl;
  final String token;
  final String section;
  final ValueChanged<String> onSectionChanged;
  final http.Client? httpClient;
  final void Function(String message, {bool isError})? onNotify;
  final String employeeName;
  final String employeeEmail;

  @override
  State<EmployeeCareerScreen> createState() => _EmployeeCareerScreenState();
}

class _EmployeeCareerScreenState extends State<EmployeeCareerScreen> {
  late final CareerApiClient _client = CareerApiClient(
    backendUrl: widget.backendUrl,
    token: widget.token,
    httpClient: widget.httpClient,
  );

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _exitRequests = [];

  final _resignationDateCtrl = TextEditingController();
  final _lastWorkingDayCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _submittingExit = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EmployeeCareerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      _load();
    }
  }

  @override
  void dispose() {
    _resignationDateCtrl.dispose();
    _lastWorkingDayCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.section == 'Documents') {
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.section == 'Job Openings') {
        final data = await _client.get('/api/employee/jobs/');
        _jobs = (data['jobs'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
      } else {
        final data = await _client.get('/api/employee/exit-requests/');
        _exitRequests = (data['exit_requests'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _submitResignation() async {
    if (_resignationDateCtrl.text.trim().isEmpty ||
        _lastWorkingDayCtrl.text.trim().isEmpty ||
        _reasonCtrl.text.trim().isEmpty) {
      widget.onNotify?.call('Fill all resignation fields.', isError: true);
      return;
    }
    setState(() => _submittingExit = true);
    try {
      await _client.post('/api/employee/exit-requests/', {
        'resignation_date': _resignationDateCtrl.text.trim(),
        'last_working_day': _lastWorkingDayCtrl.text.trim(),
        'reason': _reasonCtrl.text.trim(),
      });
      _resignationDateCtrl.clear();
      _lastWorkingDayCtrl.clear();
      _reasonCtrl.clear();
      widget.onNotify?.call('Resignation submitted successfully.');
      await _load();
    } catch (e) {
      widget.onNotify?.call(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _submittingExit = false);
    }
  }

  Future<void> _copyLink(String? url) async {
    if (url == null || url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    widget.onNotify?.call('Apply link copied to clipboard.');
  }

  void _openApplyDialog(Map<String, dynamic> job) {
    final slug = job['public_slug']?.toString() ?? '';
    if (slug.isEmpty) {
      widget.onNotify?.call('This job does not have a public apply link.', isError: true);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Apply for ${job['title'] ?? 'Job'}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: JobApplicationForm(
              initialName: widget.employeeName,
              initialEmail: widget.employeeEmail,
              submitLabel: 'Apply Now',
              onSubmit: (payload) async {
                await _client.post('/api/public/jobs/$slug/apply/', payload);
                if (ctx.mounted) Navigator.pop(ctx);
                widget.onNotify?.call('Application submitted successfully.');
              },
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Career',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _inkBlue,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Browse internal openings, manage resignation, and view HR documents.',
            style: TextStyle(color: _mutedText, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Job Openings', style: TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                selected: widget.section == 'Job Openings',
                onSelected: (_) => widget.onSectionChanged('Job Openings'),
              ),
              ChoiceChip(
                label: const Text('Resignation', style: TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                selected: widget.section == 'Resignation',
                onSelected: (_) => widget.onSectionChanged('Resignation'),
              ),
              ChoiceChip(
                label: const Text('Documents', style: TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                selected: widget.section == 'Documents',
                onSelected: (_) => widget.onSectionChanged('Documents'),
              ),
              IconButton.filled(
                tooltip: 'Refresh',
                visualDensity: VisualDensity.compact,
                onPressed: widget.section == 'Documents' || _loading ? null : _load,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (widget.section == 'Documents')
            EmployeeDocumentsScreen(
              backendUrl: widget.backendUrl,
              token: widget.token,
              httpClient: widget.httpClient,
              embedded: true,
              onNotify: widget.onNotify,
            )
          else if (_loading)
            const LinearProgressIndicator()
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red))
          else if (widget.section == 'Job Openings')
            _buildJobs()
          else
            _buildResignation(),
        ],
      ),
    );
  }

  Widget _buildJobs() {
    if (_jobs.isEmpty) {
      return const Text('No active job openings right now.', style: TextStyle(color: _mutedText));
    }
    return Column(
      children: _jobs.map((job) {
        final publicUrl = job['public_url']?.toString() ?? '';
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _lineColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job['title']?.toString() ?? 'Job',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _inkBlue,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  job['department_name'],
                  job['designation_name'],
                  '${job['openings_count'] ?? 1} openings',
                ].whereType<String>().join(' • '),
                style: const TextStyle(color: _mutedText, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(job['description']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
              if (publicUrl.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _lineColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 16, color: _mutedText),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Shareable apply link',
                          style: const TextStyle(fontSize: 11, color: _mutedText),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _copyLink(publicUrl),
                        child: const Text('Copy Link', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => _openApplyDialog(job),
                style: FilledButton.styleFrom(
                  backgroundColor: _brandBlue,
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 34),
                ),
                icon: const Icon(Icons.send_outlined, size: 16),
                label: const Text('Apply with Resume', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResignation() {
    final hasActive = _exitRequests.any((item) {
      final status = item['status']?.toString() ?? '';
      return status == 'pending' || status == 'approved';
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasActive) ...[
          Container(
            width: 720,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _lineColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Submit Resignation', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _dateField('Resignation Date', _resignationDateCtrl),
                _dateField('Last Working Day', _lastWorkingDayCtrl),
                _textField('Reason', _reasonCtrl, maxLines: 4),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _submittingExit ? null : _submitResignation,
                  child: _submittingExit
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Submit Resignation'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        const Text('Your Resignation Requests', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (_exitRequests.isEmpty)
          const Text('No resignation requests yet.', style: TextStyle(color: _mutedText))
        else
          ..._exitRequests.map((item) {
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _lineColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['status_label']?.toString() ?? item['status']?.toString() ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: _brandBlue),
                  ),
                  Text('Resignation: ${item['resignation_date']} • LWD: ${item['last_working_day']}'),
                  if ((item['reason']?.toString() ?? '').isNotEmpty)
                    Text(item['reason'].toString()),
                  if ((item['clearance_notes']?.toString() ?? '').isNotEmpty)
                    Text('HR Remarks: ${item['clearance_notes']}', style: const TextStyle(color: _mutedText)),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _dateField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'YYYY-MM-DD',
          filled: true,
          fillColor: const Color(0xFFFAFAFA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _textField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFFAFAFA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
