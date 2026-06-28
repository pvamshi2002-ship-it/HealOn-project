import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'document_upload_stub.dart'
    if (dart.library.html) 'document_upload_web.dart'
    as document_upload;
import 'documents_module.dart';
import 'recruitment_module.dart';

const _inkBlue = Color(0xFF172554);
const _brandBlue = Color(0xFF2563EB);
const _brandTeal = Color(0xFF10B981);
const _lineColor = Color(0xFFE2E8F0);
const _mutedText = Color(0xFF64748B);

enum HrFieldType { text, number, bool, date, time, textarea, select, employee }

class HrFieldDef {
  const HrFieldDef({
    required this.key,
    required this.label,
    this.type = HrFieldType.text,
    this.required = false,
    this.options = const [],
    this.lookupEndpoint,
    this.lookupKey,
    this.lookupLabelKey = 'name',
    this.lookupValueKey = 'id',
  });

  final String key;
  final String label;
  final HrFieldType type;
  final bool required;
  final List<String> options;
  final String? lookupEndpoint;
  final String? lookupKey;
  final String lookupLabelKey;
  final String lookupValueKey;
}

class HrColumnDef {
  const HrColumnDef(this.key, this.label, {this.valueKey});
  final String key;
  final String label;
  final String? valueKey;
}

class HrAdminClient {
  HrAdminClient({
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

  Future<Map<String, dynamic>?> get(String path) async {
    final resp = await httpClient.get(
      Uri.parse('$backendUrl$path'),
      headers: _headers,
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception(_errorMessage(resp));
  }

  Future<Map<String, dynamic>?> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final resp = await httpClient.post(
      Uri.parse('$backendUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return {};
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception(_errorMessage(resp));
  }

  Future<Map<String, dynamic>?> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final resp = await httpClient.patch(
      Uri.parse('$backendUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return {};
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception(_errorMessage(resp));
  }

  Future<void> delete(String path) async {
    final resp = await httpClient.delete(
      Uri.parse('$backendUrl$path'),
      headers: _headers,
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_errorMessage(resp));
    }
  }

  String _errorMessage(http.Response resp) {
    try {
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final detail = decoded['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      for (final value in decoded.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    } catch (_) {}
    return 'Request failed (${resp.statusCode})';
  }
}

class HrAdminCrudScreen extends StatefulWidget {
  const HrAdminCrudScreen({
    super.key,
    required this.title,
    required this.description,
    required this.client,
    required this.listPath,
    required this.listKey,
    required this.itemKey,
    required this.fields,
    required this.columns,
    this.employees = const [],
    this.lookupProviders = const {},
  });

  final String title;
  final String description;
  final HrAdminClient client;
  final String listPath;
  final String listKey;
  final String itemKey;
  final List<HrFieldDef> fields;
  final List<HrColumnDef> columns;
  final List<Map<String, dynamic>> employees;
  final Map<String, List<Map<String, dynamic>>> lookupProviders;

  @override
  State<HrAdminCrudScreen> createState() => _HrAdminCrudScreenState();
}

class _HrAdminCrudScreenState extends State<HrAdminCrudScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _search = '';
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _formValues = {};
  Map<String, dynamic>? _editing;
  final Map<String, List<Map<String, dynamic>>> _lookups = {};

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      if (field.type == HrFieldType.text ||
          field.type == HrFieldType.textarea ||
          field.type == HrFieldType.number) {
        _controllers[field.key] = TextEditingController();
      }
    }
    _loadLookups();
    _loadItems();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLookups() async {
    for (final field in widget.fields) {
      if (field.lookupEndpoint != null && field.lookupKey != null) {
        try {
          final data = await widget.client.get(field.lookupEndpoint!);
          final items = data?[field.lookupKey!] as List<dynamic>? ?? [];
          _lookups[field.key] = items.whereType<Map<String, dynamic>>().toList();
        } catch (_) {
          _lookups[field.key] = [];
        }
      }
    }
    for (final entry in widget.lookupProviders.entries) {
      _lookups[entry.key] = entry.value;
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadItems() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = _search.isEmpty ? '' : '?q=${Uri.encodeQueryComponent(_search)}';
      final data = await widget.client.get('${widget.listPath}$query');
      final items = data?[widget.listKey] as List<dynamic>? ?? [];
      setState(() {
        _items = items.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _resetForm() {
    _editing = null;
    _formValues.clear();
    for (final field in widget.fields) {
      final controller = _controllers[field.key];
      if (controller != null) {
        controller.clear();
      }
      if (field.type == HrFieldType.bool) {
        _formValues[field.key] = true;
      }
    }
  }

  void _startCreate() {
    _resetForm();
    setState(() {});
  }

  void _startEdit(Map<String, dynamic> item) {
    _editing = item;
    for (final field in widget.fields) {
      final value = item[field.key];
      if (field.type == HrFieldType.text ||
          field.type == HrFieldType.textarea ||
          field.type == HrFieldType.number) {
        _controllers[field.key]?.text = value?.toString() ?? '';
      } else if (field.type == HrFieldType.bool) {
        _formValues[field.key] = value == true;
      } else if (field.type == HrFieldType.select ||
          field.type == HrFieldType.employee) {
        _formValues[field.key] = value;
      } else if (field.type == HrFieldType.date || field.type == HrFieldType.time) {
        _formValues[field.key] = value?.toString() ?? '';
      }
    }
    setState(() {});
  }

  Map<String, dynamic> _collectPayload() {
    final payload = <String, dynamic>{};
    for (final field in widget.fields) {
      dynamic value;
      if (field.type == HrFieldType.text ||
          field.type == HrFieldType.textarea ||
          field.type == HrFieldType.number) {
        value = _controllers[field.key]?.text.trim();
        if (field.type == HrFieldType.number && value != null && value.isNotEmpty) {
          value = int.tryParse(value) ?? double.tryParse(value) ?? value;
        }
      } else {
        value = _formValues[field.key];
      }
      if (field.required && (value == null || '$value'.trim().isEmpty)) {
        throw Exception('${field.label} is required.');
      }
      if (value != null && '$value'.trim().isNotEmpty) {
        payload[field.key] = value;
      } else if (field.type == HrFieldType.bool) {
        payload[field.key] = _formValues[field.key] == true;
      }
    }
    return payload;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = _collectPayload();
      if (_editing != null) {
        final id = _editing!['id'];
        await widget.client.patch('${widget.listPath}$id/', payload);
      } else {
        await widget.client.post(widget.listPath, payload);
      }
      _resetForm();
      await _loadItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editing == null ? 'Record created' : 'Record updated'),
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete record?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.client.delete('${widget.listPath}${item['id']}/');
      await _loadItems();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _cellValue(Map<String, dynamic> item, HrColumnDef column) {
    final labelKey = column.valueKey ?? '${column.key}_label';
    if (item.containsKey(labelKey)) {
      final labelValue = item[labelKey];
      if (labelValue != null && '$labelValue'.isNotEmpty) {
        return '$labelValue';
      }
    }
    final value = item[column.key];
    if (value is bool) return value ? 'Yes' : 'No';
    return value?.toString() ?? '-';
  }

  Widget _buildField(HrFieldDef field) {
    switch (field.type) {
      case HrFieldType.bool:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          value: _formValues[field.key] == true,
          onChanged: (value) => setState(() => _formValues[field.key] = value),
        );
      case HrFieldType.select:
        final lookupItems = _lookups[field.key] ?? [];
        if (lookupItems.isNotEmpty) {
          return DropdownButtonFormField<dynamic>(
            isExpanded: true,
            initialValue: _formValues[field.key],
            decoration: InputDecoration(
              labelText: field.label,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              if (!field.required)
                const DropdownMenuItem<dynamic>(value: null, child: Text('None')),
              ...lookupItems.map((item) {
                final value = item[field.lookupValueKey];
                final label = item[field.lookupLabelKey]?.toString() ?? '$value';
                return DropdownMenuItem<dynamic>(
                  value: value,
                  child: Text(label),
                );
              }),
            ],
            onChanged: (value) => setState(() => _formValues[field.key] = value),
          );
        }
        return DropdownButtonFormField<dynamic>(
          isExpanded: true,
          initialValue: _formValues[field.key],
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          items: field.options
              .map(
                (option) => DropdownMenuItem<dynamic>(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _formValues[field.key] = value),
        );
      case HrFieldType.employee:
        return DropdownButtonFormField<dynamic>(
          isExpanded: true,
          initialValue: _formValues[field.key],
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          items: widget.employees.map((employee) {
            final id = employee['id'];
            final name = employee['name']?.toString() ??
                employee['username']?.toString() ??
                'Employee $id';
            return DropdownMenuItem<dynamic>(value: id, child: Text(name));
          }).toList(),
          onChanged: (value) => setState(() => _formValues[field.key] = value),
        );
      case HrFieldType.textarea:
        return TextField(
          controller: _controllers[field.key],
          maxLines: 3,
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
          ),
        );
      case HrFieldType.date:
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          subtitle: Text(_formValues[field.key]?.toString() ?? 'Select date'),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.tryParse(_formValues[field.key]?.toString() ?? '') ??
                  DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setState(() {
                _formValues[field.key] =
                    '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              });
            }
          },
        );
      case HrFieldType.time:
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          subtitle: Text(_formValues[field.key]?.toString() ?? 'Select time'),
          trailing: const Icon(Icons.schedule),
          onTap: () async {
            final parts = (_formValues[field.key]?.toString() ?? '09:00').split(':');
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(
                hour: int.tryParse(parts.first) ?? 9,
                minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
              ),
            );
            if (picked != null) {
              setState(() {
                _formValues[field.key] =
                    '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
              });
            }
          },
        );
      default:
        return TextField(
          controller: _controllers[field.key],
          keyboardType:
              field.type == HrFieldType.number ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: _inkBlue,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _mutedText),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                tooltip: 'Refresh',
                onPressed: _loading ? null : _loadItems,
                style: IconButton.styleFrom(
                  backgroundColor: _brandBlue,
                  foregroundColor: Colors.white,
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search records',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (value) {
                    _search = value.trim();
                    _loadItems();
                  },
                ),
              ),
              FilledButton.icon(
                onPressed: _startCreate,
                icon: const Icon(Icons.add),
                label: const Text('Add New'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _lineColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _editing == null ? 'Create Record' : 'Edit Record',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _inkBlue,
                      ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: widget.fields
                      .map((field) => SizedBox(width: 280, child: _buildField(field)))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_editing == null ? 'Create' : 'Update'),
                    ),
                    const SizedBox(width: 12),
                    if (_editing != null)
                      OutlinedButton(
                        onPressed: _startCreate,
                        child: const Text('Cancel Edit'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_loading)
            const LinearProgressIndicator()
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red))
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _lineColor),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    ...widget.columns.map((c) => DataColumn(label: Text(c.label))),
                    const DataColumn(label: Text('Actions')),
                  ],
                  rows: _items.map((item) {
                    return DataRow(
                      cells: [
                        ...widget.columns.map(
                          (column) => DataCell(Text(_cellValue(item, column))),
                        ),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _startEdit(item),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deleteItem(item),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class HrAdminTabbedScreen extends StatefulWidget {
  const HrAdminTabbedScreen({
    super.key,
    required this.title,
    required this.description,
    required this.tabLabels,
    required this.tabs,
  });

  final String title;
  final String description;
  final List<String> tabLabels;
  final List<Widget> tabs;

  @override
  State<HrAdminTabbedScreen> createState() => _HrAdminTabbedScreenState();
}

class _HrAdminTabbedScreenState extends State<HrAdminTabbedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: widget.tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: _inkBlue,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(widget.description, style: const TextStyle(color: _mutedText)),
              const SizedBox(height: 16),
              TabBar(
                controller: _controller,
                labelColor: _brandBlue,
                unselectedLabelColor: _mutedText,
                indicatorColor: _brandBlue,
                tabs: widget.tabLabels.map((label) => Tab(text: label)).toList(),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: widget.tabs,
          ),
        ),
      ],
    );
  }
}

class HrDocumentManagementScreen extends StatefulWidget {
  const HrDocumentManagementScreen({
    super.key,
    required this.client,
    required this.employees,
  });

  final HrAdminClient client;
  final List<Map<String, dynamic>> employees;

  @override
  State<HrDocumentManagementScreen> createState() =>
      _HrDocumentManagementScreenState();
}

class _HrDocumentManagementScreenState extends State<HrDocumentManagementScreen> {
  int? _selectedEmployeeId;
  List<Map<String, dynamic>> _documents = [];
  bool _loading = false;
  bool _saving = false;
  bool _showArchived = false;
  String? _error;
  Map<String, dynamic>? _editing;

  final _titleCtrl = TextEditingController();
  final _fileDataCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _category = 'offer_letter';
  bool _isRequired = true;
  String? _selectedFileName;
  bool _isUploadingFile = false;

  static const _sectionMaxWidth = 640.0;
  static const _dropdownWidth = 300.0;

  InputDecoration _compactInputDecoration({
    required String labelText,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _compactCard({required Widget child}) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _lineColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: child,
      ),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _fileDataCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDocumentFile() async {
    setState(() => _isUploadingFile = true);
    try {
      final upload = await document_upload.pickEmployeeDocument();
      if (upload == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No file selected or unsupported file type.'),
            ),
          );
        }
        return;
      }
      setState(() {
        _selectedFileName = upload.fileName;
        _fileDataCtrl.text = upload.dataUrl;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded ${upload.fileName}'),
            backgroundColor: _brandTeal,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingFile = false);
    }
  }

  String _employeeLabel(Map<String, dynamic> employee) {
    final name = employee['full_name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    return employee['username']?.toString() ?? 'Employee';
  }

  Future<void> _loadDocuments() async {
    final employeeId = _selectedEmployeeId;
    if (employeeId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final archived = _showArchived ? 'true' : 'false';
      final data = await widget.client.get(
        '/api/admin/hr/documents/?employee_id=$employeeId&include_archived=$archived',
      );
      final items = data?['documents'] as List<dynamic>? ?? [];
      setState(() {
        _documents = items.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _resetForm() {
    _editing = null;
    _titleCtrl.clear();
    _fileDataCtrl.clear();
    _notesCtrl.clear();
    _selectedFileName = null;
    _category = 'offer_letter';
    _isRequired = true;
  }

  void _startCreateForCategory(String category) {
    _resetForm();
    _category = category;
    _titleCtrl.text = documentCategoryLabel(category);
    setState(() {});
  }

  void _startEdit(Map<String, dynamic> doc) {
    _editing = doc;
    _titleCtrl.text = doc['title']?.toString() ?? '';
    _selectedFileName = doc['file_name']?.toString();
    _fileDataCtrl.text = doc['file_data']?.toString() ?? '';
    _notesCtrl.text = doc['notes']?.toString() ?? '';
    _category = doc['category']?.toString() ?? 'other';
    _isRequired = doc['is_required'] == true;
    setState(() {});
  }

  Future<void> _saveDocument() async {
    final employeeId = _selectedEmployeeId;
    if (employeeId == null) return;
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document title is required.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'employee': employeeId,
        'title': _titleCtrl.text.trim(),
        'category': _category,
        'file_name': _selectedFileName?.trim() ?? '',
        'file_data': _fileDataCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
        'is_required': _isRequired,
        'is_archived': false,
      };
      if (_editing != null) {
        await widget.client.patch(
          '/api/admin/hr/documents/${_editing!['id']}/',
          payload,
        );
      } else {
        await widget.client.post('/api/admin/hr/documents/', payload);
      }
      _resetForm();
      await _loadDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editing == null ? 'Document added' : 'Document updated'),
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _archiveDocument(Map<String, dynamic> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive document?'),
        content: const Text(
          'The document will be hidden from the employee view but kept on record.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.client.delete('/api/admin/hr/documents/${doc['id']}/');
      await _loadDocuments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Set<String> _uploadedCategories() {
    return _documents
        .where((doc) => doc['is_archived'] != true)
        .map((doc) => doc['category']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  Widget _buildRequiredChecklist() {
    final uploaded = _uploadedCategories();
    return _compactCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Required onboarding documents',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: _inkBlue,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          ...kRequiredDocumentCategories.map((category) {
            final done = uploaded.contains(category);
            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              minVerticalPadding: 0,
              leading: Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? _brandTeal : _mutedText,
                size: 18,
              ),
              title: Text(
                documentCategoryLabel(category),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                done ? 'Uploaded' : 'Pending',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: done
                  ? null
                  : TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 28),
                      ),
                      onPressed: () => _startCreateForCategory(category),
                      child: const Text('Add', style: TextStyle(fontSize: 12)),
                    ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDocumentUploadField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Document file',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: _inkBlue,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: _isUploadingFile ? null : _pickDocumentFile,
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(0, 34),
          ),
          icon: _isUploadingFile
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file_outlined, size: 18),
          label: Text(
            _selectedFileName == null || _selectedFileName!.isEmpty
                ? 'Upload document'
                : 'Replace document',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        if (_selectedFileName != null && _selectedFileName!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.insert_drive_file_outlined, size: 16, color: _mutedText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _selectedFileName!,
                  style: const TextStyle(fontSize: 12, color: _mutedText),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Remove file',
                onPressed: () {
                  setState(() {
                    _selectedFileName = null;
                    _fileDataCtrl.clear();
                  });
                },
                icon: const Icon(Icons.close, size: 16),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDocumentForm() {
    return _compactCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _editing == null ? 'Add document' : 'Update document',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: _inkBlue,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: _compactInputDecoration(labelText: 'Document type'),
            style: const TextStyle(fontSize: 13, color: _inkBlue),
            items: kEmployeeDocumentCategories
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value, style: const TextStyle(fontSize: 13)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _category = value);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(fontSize: 13),
            decoration: _compactInputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 8),
          _buildDocumentUploadField(),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            style: const TextStyle(fontSize: 13),
            minLines: 2,
            maxLines: 3,
            decoration: _compactInputDecoration(
              labelText: 'Notes',
              hintText: 'Optional notes',
            ),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Mark as required document',
              style: TextStyle(fontSize: 12),
            ),
            value: _isRequired,
            onChanged: (value) => setState(() => _isRequired = value),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 34),
                  ),
                  onPressed: _saving ? null : _resetForm,
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 34),
                  ),
                  onPressed: _saving ? null : _saveDocument,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _editing == null ? 'Save' : 'Update',
                          style: const TextStyle(fontSize: 12),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Text(_error!, style: const TextStyle(color: Colors.red));
    }
    if (_documents.isEmpty) {
      return const Text('No documents yet for this employee.');
    }
    return Column(
      children: _documents.map((doc) {
        final archived = doc['is_archived'] == true;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _compactCard(
          child: ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: EdgeInsets.zero,
            minVerticalPadding: 0,
            title: Text(
              doc['title']?.toString() ?? 'Document',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              [
                doc['category_label'] ?? documentCategoryLabel(doc['category']?.toString()),
                if (doc['file_name'] != null &&
                    doc['file_name'].toString().trim().isNotEmpty)
                  doc['file_name'].toString(),
                if (doc['expiry_date'] != null) 'Expires ${doc['expiry_date']}',
                if (archived) 'Archived',
              ].join(' • '),
              style: const TextStyle(fontSize: 11),
            ),
            trailing: archived
                ? TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 28),
                    ),
                    onPressed: () async {
                      try {
                        await widget.client.patch(
                          '/api/admin/hr/documents/${doc['id']}/',
                          {'is_archived': false},
                        );
                        await _loadDocuments();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    child: const Text('Restore', style: TextStyle(fontSize: 12)),
                  )
                : PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'edit') {
                        _startEdit(doc);
                      } else if (value == 'archive') {
                        _archiveDocument(doc);
                      }
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit / Replace')),
                      PopupMenuItem(value: 'archive', child: Text('Archive')),
                    ],
                  ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmployeeSelector() {
    return Center(
      child: SizedBox(
        width: _dropdownWidth,
        child: DropdownButtonFormField<int>(
          value: _selectedEmployeeId,
          decoration: _compactInputDecoration(labelText: 'Select employee'),
          style: const TextStyle(fontSize: 13, color: _inkBlue),
          items: widget.employees.map((employee) {
            final id = employee['id'];
            if (id is! int) return null;
            return DropdownMenuItem<int>(
              value: id,
              child: Text(
                _employeeLabel(employee),
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).whereType<DropdownMenuItem<int>>().toList(),
          onChanged: (value) {
            setState(() {
              _selectedEmployeeId = value;
              _resetForm();
            });
            _loadDocuments();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _sectionMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Document Management',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: _inkBlue,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Assign and manage onboarding documents for each employee.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _mutedText, fontSize: 12),
              ),
              const SizedBox(height: 14),
              _buildEmployeeSelector(),
              if (_selectedEmployeeId != null) ...[
                const SizedBox(height: 10),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Show archived documents',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _showArchived,
                  onChanged: (value) {
                    setState(() => _showArchived = value);
                    _loadDocuments();
                  },
                ),
                const SizedBox(height: 8),
                _buildRequiredChecklist(),
                const SizedBox(height: 10),
                _buildDocumentForm(),
                const SizedBox(height: 10),
                Text(
                  'Employee documents',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _inkBlue,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                _buildDocumentsList(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Widget buildHrAdminModuleScreen({
  required String moduleKey,
  required HrAdminClient client,
  required List<Map<String, dynamic>> employees,
  Map<String, List<Map<String, dynamic>>> lookupProviders = const {},
}) {
  switch (moduleKey) {
    case 'Leave Management':
      return HrAdminTabbedScreen(
        title: 'Leave Management',
        description: 'Manage leave types and employee leave requests.',
        tabLabels: const ['Leave Requests', 'Leave Types'],
        tabs: [
          HrAdminCrudScreen(
            title: 'Leave Requests',
            description: 'Create, review, update, and delete leave records.',
            client: client,
            listPath: '/api/admin/hr/leaves/',
            listKey: 'leaves',
            itemKey: 'leave',
            employees: employees,
            lookupProviders: lookupProviders,
            fields: const [
              HrFieldDef(key: 'employee', label: 'Employee', type: HrFieldType.employee, required: true),
              HrFieldDef(key: 'leave_type', label: 'Leave Type', required: true),
              HrFieldDef(key: 'from_date', label: 'From Date', type: HrFieldType.date, required: true),
              HrFieldDef(key: 'to_date', label: 'To Date', type: HrFieldType.date, required: true),
              HrFieldDef(key: 'reason', label: 'Reason', type: HrFieldType.textarea),
              HrFieldDef(
                key: 'status',
                label: 'Status',
                type: HrFieldType.select,
                options: ['pending', 'approved', 'rejected'],
              ),
            ],
            columns: const [
              HrColumnDef('employee_name', 'Employee'),
              HrColumnDef('leave_type', 'Type'),
              HrColumnDef('from_date', 'From'),
              HrColumnDef('to_date', 'To'),
              HrColumnDef('status', 'Status', valueKey: 'status_label'),
              HrColumnDef('total_days', 'Days'),
            ],
          ),
          HrAdminCrudScreen(
            title: 'Leave Types',
            description: 'Configure leave categories and annual quotas.',
            client: client,
            listPath: '/api/admin/hr/leave-types/',
            listKey: 'leave_types',
            itemKey: 'leave_type',
            fields: const [
              HrFieldDef(key: 'name', label: 'Leave Type Name', required: true),
              HrFieldDef(key: 'annual_quota', label: 'Annual Quota', type: HrFieldType.number),
              HrFieldDef(key: 'is_paid', label: 'Paid Leave', type: HrFieldType.bool),
              HrFieldDef(key: 'is_active', label: 'Active', type: HrFieldType.bool),
            ],
            columns: const [
              HrColumnDef('name', 'Name'),
              HrColumnDef('annual_quota', 'Quota'),
              HrColumnDef('is_paid', 'Paid'),
              HrColumnDef('is_active', 'Active'),
            ],
          ),
        ],
      );
    case 'Department Management':
      return HrAdminCrudScreen(
        title: 'Department Management',
        description: 'Create and maintain organizational departments.',
        client: client,
        listPath: '/api/admin/hr/departments/',
        listKey: 'departments',
        itemKey: 'department',
        employees: employees,
        fields: const [
          HrFieldDef(key: 'name', label: 'Department Name', required: true),
          HrFieldDef(key: 'code', label: 'Code'),
          HrFieldDef(key: 'description', label: 'Description', type: HrFieldType.textarea),
          HrFieldDef(key: 'head', label: 'Department Head', type: HrFieldType.employee),
          HrFieldDef(key: 'is_active', label: 'Active', type: HrFieldType.bool),
        ],
        columns: const [
          HrColumnDef('name', 'Name'),
          HrColumnDef('code', 'Code'),
          HrColumnDef('head_name', 'Head'),
          HrColumnDef('employee_count', 'Employees'),
          HrColumnDef('is_active', 'Active'),
        ],
      );
    case 'Designation Management':
      return HrAdminCrudScreen(
        title: 'Designation Management',
        description: 'Manage job designations linked to departments.',
        client: client,
        listPath: '/api/admin/hr/designations/',
        listKey: 'designations',
        itemKey: 'designation',
        lookupProviders: lookupProviders,
        fields: [
          const HrFieldDef(key: 'name', label: 'Designation Name', required: true),
          const HrFieldDef(key: 'code', label: 'Code'),
          HrFieldDef(
            key: 'department',
            label: 'Department',
            type: HrFieldType.select,
            lookupEndpoint: '/api/admin/hr/departments/',
            lookupKey: 'departments',
          ),
          const HrFieldDef(key: 'level', label: 'Level', type: HrFieldType.number),
          const HrFieldDef(key: 'is_active', label: 'Active', type: HrFieldType.bool),
        ],
        columns: const [
          HrColumnDef('name', 'Name'),
          HrColumnDef('department_name', 'Department'),
          HrColumnDef('level', 'Level'),
          HrColumnDef('is_active', 'Active'),
        ],
      );
    case 'Recruitment':
      return HrAdminTabbedScreen(
        title: 'Recruitment',
        description: 'Manage job openings and candidate pipeline.',
        tabLabels: const ['Job Openings', 'Candidates'],
        tabs: [
          HrAdminCrudScreen(
            title: 'Job Openings',
            description: 'Open and close job positions.',
            client: client,
            listPath: '/api/admin/hr/job-openings/',
            listKey: 'job_openings',
            itemKey: 'job_opening',
            lookupProviders: lookupProviders,
            fields: [
              const HrFieldDef(key: 'title', label: 'Job Title', required: true),
              HrFieldDef(
                key: 'department',
                label: 'Department',
                type: HrFieldType.select,
                lookupEndpoint: '/api/admin/hr/departments/',
                lookupKey: 'departments',
              ),
              HrFieldDef(
                key: 'designation',
                label: 'Designation',
                type: HrFieldType.select,
                lookupEndpoint: '/api/admin/hr/designations/',
                lookupKey: 'designations',
              ),
              const HrFieldDef(key: 'openings_count', label: 'Openings', type: HrFieldType.number),
              const HrFieldDef(key: 'description', label: 'Description', type: HrFieldType.textarea),
              const HrFieldDef(
                key: 'status',
                label: 'Status',
                type: HrFieldType.select,
                options: ['open', 'on_hold', 'closed'],
              ),
            ],
            columns: const [
              HrColumnDef('title', 'Title'),
              HrColumnDef('department_name', 'Department'),
              HrColumnDef('status', 'Status', valueKey: 'status_label'),
              HrColumnDef('public_url', 'Public URL'),
              HrColumnDef('candidate_count', 'Candidates'),
              HrColumnDef('openings_count', 'Openings'),
            ],
          ),
          HrCandidatesPipelineScreen(client: client),
        ],
      );
    case 'Exit Management':
      return HrAdminCrudScreen(
        title: 'Exit Management',
        description: 'Process resignations, clearance, and employee offboarding.',
        client: client,
        listPath: '/api/admin/hr/exit-requests/',
        listKey: 'exit_requests',
        itemKey: 'exit_request',
        employees: employees,
        fields: const [
          HrFieldDef(key: 'employee', label: 'Employee', type: HrFieldType.employee, required: true),
          HrFieldDef(key: 'resignation_date', label: 'Resignation Date', type: HrFieldType.date, required: true),
          HrFieldDef(key: 'last_working_day', label: 'Last Working Day', type: HrFieldType.date, required: true),
          HrFieldDef(key: 'reason', label: 'Reason', type: HrFieldType.textarea, required: true),
          HrFieldDef(
            key: 'status',
            label: 'Status',
            type: HrFieldType.select,
            options: ['pending', 'approved', 'rejected', 'completed', 'cancelled'],
          ),
          HrFieldDef(key: 'clearance_notes', label: 'HR Remarks', type: HrFieldType.textarea),
        ],
        columns: const [
          HrColumnDef('employee_name', 'Employee'),
          HrColumnDef('resignation_date', 'Resignation'),
          HrColumnDef('last_working_day', 'LWD'),
          HrColumnDef('status', 'Status', valueKey: 'status_label'),
        ],
      );
    case 'Document Management':
      return HrDocumentManagementScreen(
        client: client,
        employees: employees,
      );
    default:
      return Center(
        child: Text('Module "$moduleKey" is not configured.'),
      );
  }
}
