import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../models/task_model.dart';
import 'task_form_screen.dart';
import 'graph_screen.dart';
import 'archive_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Task> _allTasks = [];
  List<Task> _filteredTasks = [];
  Map<String, dynamic> _analytics = {
    "todo": 0, "in_progress": 0, "done": 0, "extended": 0, "unique_tasks": 0
  };
  
  bool _isLoading = true;
  String? _errorMessage; 
  
  String _searchQuery = '';
  String _statusFilter = 'All';
  bool _sortByImportance = false;
  bool _hideCompleted = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchFullSync();
  }

  // --- NEW: UNIFIED TELEMETRY ENGINE ---
  void _showTelemetry(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded, 
              color: Colors.white, 
              size: 22
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message, 
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.2)
              )
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFF7F1D1D) : const Color(0xFF064E3B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        elevation: 8,
      )
    );
  }

  Future<void> _fetchFullSync() async {
    setState(() { 
      _isLoading = true; 
      _errorMessage = null; 
    });
    
    try {
      final tRes = await http.get(Uri.parse('http://127.0.0.1:8000/tasks'));
      final aRes = await http.get(Uri.parse('http://127.0.0.1:8000/analytics'));
      
      if (tRes.statusCode == 200 && aRes.statusCode == 200) {
        final List<dynamic> data = jsonDecode(tRes.body);
        setState(() {
          _allTasks = data.map((t) => Task.fromJson(t)).toList();
          _analytics = jsonDecode(aRes.body);
          _applyProfessionalFilters();
        });
      } else {
        setState(() => _errorMessage = "System Fault: Workspace engine returned code ${tRes.statusCode}. Manual reset may be required.");
      }
    } catch (e) {
      setState(() => _errorMessage = "Connection Fault: The workspace engine at 127.0.0.1:8000 is currently offline.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyProfessionalFilters() {
    setState(() {
      _filteredTasks = _allTasks.where((task) {
        if (_hideCompleted && task.status == 'Done') {
          bool hasIncompleteChildren = _allTasks.any((t) => t.blockedById == task.id && t.status != 'Done');
          if (!hasIncompleteChildren) return false; 
        }

        final query = _searchQuery.trim().toLowerCase();
        final matchesSearch = task.title.toLowerCase().contains(query) || 
                              task.description.toLowerCase().contains(query) ||
                              task.id.toString() == query;
        
        final matchesStatus = _statusFilter == 'All' || task.status == _statusFilter;
        
        return matchesSearch && matchesStatus;
      }).toList();

      if (_sortByImportance) {
        _filteredTasks.sort((a, b) => b.importance.compareTo(a.importance));
      } else {
        _filteredTasks.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      }
    });
  }

  Future<void> _updateStatus(Task task, String newStatus) async {
    final payload = task.toJson();
    payload['status'] = newStatus;
    
    try {
      final response = await http.put(
        Uri.parse('http://127.0.0.1:8000/tasks/${task.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload)
      );
      
      if (response.statusCode != 200) {
        final msg = jsonDecode(response.body)['detail'];
        _showTelemetry("Workflow Constraint: $msg");
      } else {
        _showTelemetry("State Sync: Intent status updated.", isError: false);
      }
      _fetchFullSync();
    } catch (e) {
      _showTelemetry("Network Exception: Status synchronization failed.");
    }
  }

  Future<void> _deleteTask(int id) async {
    try {
      final response = await http.delete(Uri.parse('http://127.0.0.1:8000/tasks/$id'));
      if (response.statusCode != 200) {
        final msg = jsonDecode(response.body)['detail'];
        _showTelemetry("Purge Violation: $msg");
      } else {
        _showTelemetry("State Sync: Intent purged successfully.", isError: false);
      }
      _fetchFullSync();
    } catch (e) {
      _showTelemetry("Network Exception: Deletion request failed.");
    }
  }

  String _getDisplayDate(String iso) {
    final date = DateTime.parse(iso).toLocal();
    final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return "${date.month}/${date.day} at ${h.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}";
  }

  Widget _buildHighlightedText(String text, TextStyle baseStyle) {
    if (_searchQuery.isEmpty) return Text(text, style: baseStyle);
    final query = _searchQuery.toLowerCase();
    final lowerText = text.toLowerCase();
    final matchIndex = lowerText.indexOf(query);
    if (matchIndex == -1) return Text(text, style: baseStyle);
    
    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: text.substring(0, matchIndex)),
          TextSpan(
            text: text.substring(matchIndex, matchIndex + query.length), 
            style: baseStyle.copyWith(backgroundColor: Colors.yellow[300], color: Colors.black)
          ),
          TextSpan(text: text.substring(matchIndex + query.length)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Workspace Engine', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white, elevation: 0,
        actions: [
          IconButton(
            tooltip: "Toggle Completed",
            icon: Icon(_hideCompleted ? Icons.visibility_off : Icons.visibility, color: Colors.blueGrey),
            onPressed: () { setState(() => _hideCompleted = !_hideCompleted); _applyProfessionalFilters(); },
          ),
          IconButton(
            tooltip: "Graph View",
            icon: const Icon(Icons.account_tree_rounded, color: Colors.blueAccent),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GraphScreen(tasks: _allTasks))),
          ),
          IconButton(
            tooltip: "Archive",
            icon: const Icon(Icons.inventory_2_outlined, color: Colors.teal),
            onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchiveScreen())); _fetchFullSync(); },
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 100, color: Colors.white,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildStatCard("UNIQUE", _analytics['unique_tasks'], Colors.black),
                _buildStatCard("TO-DO", _analytics['todo'], Colors.blueGrey),
                _buildStatCard("ACTIVE", _analytics['in_progress'], Colors.indigo),
                _buildStatCard("DONE", _analytics['done'], Colors.green),
                _buildStatCard("EXTENDED", _analytics['extended'], Colors.orange[900]!),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.black12))),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search intents...",
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true, fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (v) {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();
                      _debounce = Timer(const Duration(milliseconds: 300), () {
                        setState(() => _searchQuery = v);
                        _applyProfessionalFilters();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter, isExpanded: true,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13),
                        items: ['All', 'To-Do', 'In Progress', 'Done'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) { setState(() => _statusFilter = v!); _applyProfessionalFilters(); },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.red[900]),
                          const SizedBox(height: 16),
                          Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[900], fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text("Retry Telemetry Sync"),
                            onPressed: _fetchFullSync,
                          )
                        ],
                      ),
                    ),
                  )
                : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              onReorder: (oldIdx, newIdx) async {
                if (newIdx > oldIdx) newIdx -= 1;
                final item = _filteredTasks.removeAt(oldIdx); _filteredTasks.insert(newIdx, item);
                setState(() {});
                await http.post(Uri.parse('http://127.0.0.1:8000/tasks/reorder'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(_filteredTasks.map((e) => e.id).toList()));
                _fetchFullSync();
              },
              itemCount: _filteredTasks.length,
              itemBuilder: (context, index) {
                final t = _filteredTasks[index];
                final due = DateTime.parse(t.dueDate).toLocal();
                final now = DateTime.now();
                bool isPast = due.isBefore(now) && t.status != 'Done';
                bool isUrgent = !isPast && due.difference(now).inHours < 2 && t.status != 'Done';
                Color stripe = isPast ? const Color(0xFF7F1D1D) : (isUrgent ? Colors.redAccent : Colors.blueAccent);
                Color bg = isPast ? const Color(0xFFFEF2F2) : Colors.white;

                return Container(
                  key: ValueKey(t.id),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(16),
                    border: Border(left: BorderSide(color: stripe, width: 8)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () { 
                                Clipboard.setData(ClipboardData(text: t.id.toString())); 
                                _showTelemetry("Telemetry Sync: Reference ID copied.", isError: false);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.withValues(alpha: 0.2), width: 1.5)),
                                child: Row(
                                  children: [
                                    Text("REF: ${t.id}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.blueAccent)),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.copy_all, size: 14, color: Colors.blueAccent),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            DropdownButton<String>(
                              value: t.status, underline: const SizedBox(),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: stripe),
                              items: ['To-Do', 'In Progress', 'Done'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) => _updateStatus(t, v!),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildHighlightedText(t.title, const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black)),
                        const SizedBox(height: 4),
                        _buildHighlightedText(t.description, const TextStyle(color: Color(0xFF475569), fontSize: 13)),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10, runSpacing: 8,
                          children: [
                            _buildMetaTag(Icons.timer_outlined, _getDisplayDate(t.dueDate), isPast ? Colors.red[900]! : Colors.black87),
                            if (t.extendedCount > 0) _buildMetaTag(Icons.history, "EXT: ${t.extendedCount}x", Colors.orange[900]!),
                            if (t.blockedById != null) _buildMetaTag(Icons.lock_outline, "BLOCKER: ${t.blockedById}", Colors.red[900]!),
                          ],
                        ),
                        const Divider(height: 32, color: Colors.black12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (isPast)
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: Colors.orange[900]),
                                icon: const Icon(Icons.more_time, size: 18),
                                label: const Text("Extend 24h", style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () async {
                                  await http.put(Uri.parse('http://127.0.0.1:8000/tasks/${t.id}/extend'));
                                  _showTelemetry("Chronology Sync: Intent extended.", isError: false);
                                  _fetchFullSync();
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit_note, color: Colors.blueGrey),
                              onPressed: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (_) => TaskFormScreen(taskToEdit: t, allTasks: _allTasks)));
                                _fetchFullSync();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _deleteTask(t.id),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F172A),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("NEW INTENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => TaskFormScreen(allTasks: _allTasks))); _fetchFullSync(); },
      ),
    );
  }

  Widget _buildStatCard(String label, dynamic val, Color col) {
    return Container(
      width: 110, margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: col.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: col.withValues(alpha: 0.1))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(val.toString(), style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 24)),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: col.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _buildMetaTag(IconData icon, String label, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: col.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: col),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: col)),
        ],
      ),
    );
  }
}