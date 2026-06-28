import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'document_download_stub.dart'
    if (dart.library.html) 'document_download_web.dart'
    as document_download;

const _inkBlue = Color(0xFF172554);
const _brandBlue = Color(0xFF2563EB);
const _brandTeal = Color(0xFF10B981);
const _lineColor = Color(0xFFE2E8F0);
const _mutedText = Color(0xFF64748B);

const kEmployeeDocumentCategories = <MapEntry<String, String>>[
  MapEntry('offer_letter', 'Offer Letter'),
  MapEntry('appointment_letter', 'Appointment Letter'),
  MapEntry('id_proof', 'ID Proof'),
  MapEntry('address_proof', 'Address Proof'),
  MapEntry('certificate', 'Certificates'),
  MapEntry('experience_letter', 'Experience Letter'),
  MapEntry('contract', 'Contract'),
  MapEntry('policy', 'Policy'),
  MapEntry('other', 'Other'),
];

const kRequiredDocumentCategories = [
  'offer_letter',
  'appointment_letter',
  'id_proof',
  'address_proof',
  'certificate',
];

String documentCategoryLabel(String? value) {
  for (final entry in kEmployeeDocumentCategories) {
    if (entry.key == value) return entry.value;
  }
  return value ?? 'Other';
}

class DocumentsApiClient {
  DocumentsApiClient({
    required this.backendUrl,
    required this.token,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  final String backendUrl;
  final String token;
  final http.Client httpClient;

  Map<String, String> get _headers => {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      };

  Future<Map<String, dynamic>> get(String path) async {
    final resp = await httpClient.get(
      Uri.parse('$backendUrl$path'),
      headers: _headers,
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception(_error(resp));
  }

  String _error(http.Response resp) {
    try {
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final detail = decoded['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    } catch (_) {}
    return 'Request failed (${resp.statusCode})';
  }
}

class EmployeeDocumentsScreen extends StatefulWidget {
  const EmployeeDocumentsScreen({
    super.key,
    required this.backendUrl,
    required this.token,
    this.httpClient,
    this.embedded = false,
    this.onNotify,
  });

  final String backendUrl;
  final String token;
  final http.Client? httpClient;
  final bool embedded;
  final void Function(String message, {bool isError})? onNotify;

  @override
  State<EmployeeDocumentsScreen> createState() => _EmployeeDocumentsScreenState();
}

class _EmployeeDocumentsScreenState extends State<EmployeeDocumentsScreen> {
  late final DocumentsApiClient _client;
  List<Map<String, dynamic>> _documents = [];
  bool _loading = true;
  String? _error;
  String? _categoryFilter;

  static const _maxContentWidth = 640.0;

  @override
  void initState() {
    super.initState();
    _client = DocumentsApiClient(
      backendUrl: widget.backendUrl,
      token: widget.token,
      httpClient: widget.httpClient,
    );
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _client.get('/api/employee/documents/');
      final items = data['documents'] as List<dynamic>? ?? [];
      setState(() {
        _documents = items.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Unable to load documents. Please try again.';
        _loading = false;
      });
    }
  }

  String _documentTitle(Map<String, dynamic> doc) {
    final title = doc['title']?.toString().trim() ?? '';
    if (title.isNotEmpty) return title;
    final fileName = doc['file_name']?.toString().trim() ?? '';
    if (fileName.isNotEmpty) return fileName;
    return 'Document';
  }

  String _documentFileName(Map<String, dynamic> doc) {
    final fileName = doc['file_name']?.toString().trim() ?? '';
    if (fileName.isNotEmpty) return fileName;
    return _documentTitle(doc);
  }

  String _documentType(Map<String, dynamic> doc) {
    return doc['category_label']?.toString() ??
        documentCategoryLabel(doc['category']?.toString());
  }

  bool _hasFile(Map<String, dynamic> doc) {
    return doc['file_data']?.toString().trim().isNotEmpty == true;
  }

  List<Map<String, dynamic>> get _filteredDocuments {
    if (_categoryFilter == null || _categoryFilter!.isEmpty) {
      return _documents;
    }
    return _documents
        .where((doc) => doc['category']?.toString() == _categoryFilter)
        .toList();
  }

  Set<String> get _availableCategories {
    return _documents
        .map((doc) => doc['category']?.toString())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  Future<void> _viewDocument(Map<String, dynamic> doc) async {
    if (!_hasFile(doc)) {
      widget.onNotify?.call('No file attached for this document.', isError: true);
      return;
    }
    try {
      await document_download.viewDocumentFile(
        doc['file_data']!.toString(),
        _documentFileName(doc),
      );
    } catch (_) {
      widget.onNotify?.call('Unable to open document.', isError: true);
    }
  }

  Future<void> _downloadDocument(Map<String, dynamic> doc) async {
    if (!_hasFile(doc)) {
      widget.onNotify?.call('No file attached for this document.', isError: true);
      return;
    }
    try {
      await document_download.downloadDocumentFile(
        doc['file_data']!.toString(),
        _documentFileName(doc),
      );
      widget.onNotify?.call('Download started.');
    } catch (_) {
      widget.onNotify?.call('Unable to download document.', isError: true);
    }
  }

  InputDecoration _compactDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildFilterDropdown() {
    final categories = _availableCategories.toList()..sort();
    return Center(
      child: SizedBox(
        width: 260,
        child: DropdownButtonFormField<String?>(
          value: _categoryFilter,
          decoration: _compactDecoration('Document type'),
          style: const TextStyle(fontSize: 13, color: _inkBlue),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All document types', style: TextStyle(fontSize: 13)),
            ),
            ...categories.map(
              (category) => DropdownMenuItem<String?>(
                value: category,
                child: Text(
                  documentCategoryLabel(category),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _categoryFilter = value),
        ),
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> doc) {
    final typeLabel = _documentType(doc);
    final hasFile = _hasFile(doc);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _lineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _brandBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: _brandBlue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _documentTitle(doc),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _inkBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _brandTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        typeLabel,
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
            ],
          ),
          if (doc['expiry_date'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Expires ${doc['expiry_date']}',
              style: const TextStyle(fontSize: 11, color: _mutedText),
            ),
          ],
          if (doc['notes']?.toString().trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              doc['notes'].toString().trim(),
              style: const TextStyle(fontSize: 12, color: _mutedText, height: 1.35),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: hasFile ? () => _viewDocument(doc) : null,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('View', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: hasFile ? () => _downloadDocument(doc) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _brandBlue,
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Download', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDocuments;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) ...[
          Text(
            'My Documents',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _inkBlue,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'View HR-assigned onboarding and employment documents.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _mutedText, fontSize: 12),
          ),
          const SizedBox(height: 14),
        ],
        if (!_loading && _documents.isNotEmpty) ...[
          _buildFilterDropdown(),
          const SizedBox(height: 12),
        ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Column(
              children: [
                Text(_error!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _loadDocuments,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text('Retry', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          )
        else if (_documents.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _lineColor),
            ),
            child: const Text(
              'No documents have been assigned yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _mutedText, fontSize: 13),
            ),
          )
        else if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _lineColor),
            ),
            child: const Text(
              'No documents match the selected type.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _mutedText, fontSize: 13),
            ),
          )
        else
          ...filtered.map(_buildDocumentCard),
      ],
    );

    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: widget.embedded ? 0 : 16,
          vertical: widget.embedded ? 0 : 20,
        ),
        child: widget.embedded
            ? content
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: content,
                ),
              ),
      ),
    );
  }
}
