import 'package:flutter/material.dart';

import 'document_download_stub.dart'
    if (dart.library.html) 'document_download_web.dart'
    as document_download;
import 'hr_admin_module.dart';

const _inkBlue = Color(0xFF172554);
const _brandBlue = Color(0xFF2563EB);
const _brandTeal = Color(0xFF10B981);
const _lineColor = Color(0xFFE2E8F0);
const _mutedText = Color(0xFF64748B);

const kCandidateStatuses = [
  ('applied', 'Applied'),
  ('shortlisted', 'Shortlisted'),
  ('interview_scheduled', 'Interview Scheduled'),
  ('selected', 'Selected'),
  ('rejected', 'Rejected'),
];

String candidateStatusLabel(String? value) {
  for (final entry in kCandidateStatuses) {
    if (entry.$1 == value) return entry.$2;
  }
  return value ?? 'Applied';
}

class HrCandidatesPipelineScreen extends StatefulWidget {
  const HrCandidatesPipelineScreen({
    super.key,
    required this.client,
  });

  final HrAdminClient client;

  @override
  State<HrCandidatesPipelineScreen> createState() =>
      _HrCandidatesPipelineScreenState();
}

class _HrCandidatesPipelineScreenState extends State<HrCandidatesPipelineScreen> {
  List<Map<String, dynamic>> _candidates = [];
  List<Map<String, dynamic>> _jobOpenings = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  int? _jobFilterId;
  String? _statusFilter;

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
      final jobsData = await widget.client.get('/api/admin/hr/job-openings/');
      final query = <String>[];
      if (_search.trim().isNotEmpty) {
        query.add('q=${Uri.encodeQueryComponent(_search.trim())}');
      }
      if (_jobFilterId != null) {
        query.add('job_opening_id=$_jobFilterId');
      }
      if (_statusFilter != null && _statusFilter!.isNotEmpty) {
        query.add('status=$_statusFilter');
      }
      final path = query.isEmpty
          ? '/api/admin/hr/candidates/'
          : '/api/admin/hr/candidates/?${query.join('&')}';
      final candidatesData = await widget.client.get(path);
      setState(() {
        _jobOpenings =
            (jobsData?['job_openings'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .toList();
        _candidates =
            (candidatesData?['candidates'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _updateStatus(int id, String status) async {
    try {
      await widget.client.patch('/api/admin/hr/candidates/$id/', {'status': status});
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Candidate status updated'),
            backgroundColor: _brandTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openCandidateDetail(Map<String, dynamic> candidate) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _HrCandidateDetailDialog(
        candidate: candidate,
        onStatusChanged: (status) {
          Navigator.pop(ctx);
          _updateStatus(candidate['id'] as int, status);
        },
        onViewResume: () => _viewResume(candidate),
        onDownloadResume: () => _downloadResume(candidate),
      ),
    );
  }

  Future<void> _viewResume(Map<String, dynamic> candidate) async {
    final data = candidate['resume_data']?.toString() ?? '';
    final name = candidate['resume_file_name']?.toString() ?? 'resume.pdf';
    if (data.trim().isEmpty) return;
    await document_download.viewDocumentFile(data, name);
  }

  Future<void> _downloadResume(Map<String, dynamic> candidate) async {
    final data = candidate['resume_data']?.toString() ?? '';
    final name = candidate['resume_file_name']?.toString() ?? 'resume.pdf';
    if (data.trim().isEmpty) return;
    await document_download.downloadDocumentFile(data, name);
  }

  InputDecoration _compactDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Candidates',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _inkBlue,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Applications submitted via job openings. Click a candidate name to view details.',
            style: TextStyle(color: _mutedText, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  style: const TextStyle(fontSize: 13),
                  decoration: _compactDecoration('Search candidates'),
                  onSubmitted: (value) {
                    _search = value;
                    _load();
                  },
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<int?>(
                  value: _jobFilterId,
                  decoration: _compactDecoration('Job opening'),
                  style: const TextStyle(fontSize: 13, color: _inkBlue),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All jobs', style: TextStyle(fontSize: 13)),
                    ),
                    ..._jobOpenings.map((job) {
                      final id = job['id'];
                      if (id is! int) return null;
                      return DropdownMenuItem<int?>(
                        value: id,
                        child: Text(
                          job['title']?.toString() ?? 'Job',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).whereType<DropdownMenuItem<int?>>(),
                  ],
                  onChanged: (value) {
                    setState(() => _jobFilterId = value);
                    _load();
                  },
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  value: _statusFilter,
                  decoration: _compactDecoration('Status'),
                  style: const TextStyle(fontSize: 13, color: _inkBlue),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All statuses', style: TextStyle(fontSize: 13)),
                    ),
                    ...kCandidateStatuses.map(
                      (entry) => DropdownMenuItem<String?>(
                        value: entry.$1,
                        child: Text(entry.$2, style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _statusFilter = value);
                    _load();
                  },
                ),
              ),
              IconButton.filled(
                tooltip: 'Refresh',
                visualDensity: VisualDensity.compact,
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const LinearProgressIndicator()
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red))
          else if (_candidates.isEmpty)
            const Text('No candidates found.', style: TextStyle(color: _mutedText))
          else
            Expanded(
              child: ListView.separated(
                itemCount: _candidates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final candidate = _candidates[index];
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _openCandidateDetail(candidate),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _lineColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    candidate['full_name']?.toString() ?? 'Candidate',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _brandBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      candidate['job_title'],
                                      candidate['email'],
                                    ].whereType<String>().join(' • '),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: _mutedText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _brandTeal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                candidate['status_label']?.toString() ??
                                    candidateStatusLabel(
                                      candidate['status']?.toString(),
                                    ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _brandTeal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _HrCandidateDetailDialog extends StatelessWidget {
  const _HrCandidateDetailDialog({
    required this.candidate,
    required this.onStatusChanged,
    required this.onViewResume,
    required this.onDownloadResume,
  });

  final Map<String, dynamic> candidate;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onViewResume;
  final VoidCallback onDownloadResume;

  @override
  Widget build(BuildContext context) {
    final hasResume =
        candidate['resume_data']?.toString().trim().isNotEmpty == true;
    final currentStatus = candidate['status']?.toString() ?? 'applied';

    return AlertDialog(
      title: Text(candidate['full_name']?.toString() ?? 'Candidate'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Job', candidate['job_title']?.toString() ?? '-'),
              _detailRow('Email', candidate['email']?.toString() ?? '-'),
              _detailRow('Phone', candidate['phone']?.toString() ?? '-'),
              _detailRow('Experience', candidate['experience']?.toString() ?? '-'),
              _detailRow('Skills', candidate['skills']?.toString() ?? '-'),
              _detailRow(
                'Status',
                candidate['status_label']?.toString() ??
                    candidateStatusLabel(currentStatus),
              ),
              if ((candidate['cover_letter']?.toString() ?? '').isNotEmpty)
                _detailRow('Cover Letter', candidate['cover_letter'].toString()),
              if ((candidate['notes']?.toString() ?? '').isNotEmpty)
                _detailRow('HR Notes', candidate['notes'].toString()),
              const SizedBox(height: 12),
              if (hasResume) ...[
                Text(
                  candidate['resume_file_name']?.toString() ?? 'Resume',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: onViewResume,
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('View Resume', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: onDownloadResume,
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: const Text('Download', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ] else
                const Text('No resume uploaded.', style: TextStyle(color: _mutedText)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: kCandidateStatuses.any((e) => e.$1 == currentStatus)
                    ? currentStatus
                    : 'applied',
                decoration: const InputDecoration(
                  labelText: 'Update status',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: kCandidateStatuses
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.$1,
                        child: Text(entry.$2, style: const TextStyle(fontSize: 13)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) onStatusChanged(value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _mutedText,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
