class Task {
  final int id;
  final String title;
  final String description;
  final String dueDate;
  final String status;
  final int? blockedById;
  final String recurring;
  final int sortOrder;
  final String taskType;
  final int importance;
  final int extendedCount;
  final int version;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.status,
    this.blockedById,
    required this.recurring,
    required this.sortOrder,
    required this.taskType,
    required this.importance,
    required this.extendedCount,
    required this.version,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    // --- ENTERPRISE TIMEZONE PERSISTENCE FIX ---
    // If the backend date string lacks a 'Z' or '+', we append 'Z' 
    // to force the parser to treat it as UTC, which .toLocal() 
    // then shifts correctly to the user's IST or local time.
    String rawDate = json['due_date'] ?? '';
    if (rawDate.isNotEmpty && !rawDate.contains('Z') && !rawDate.contains('+')) {
      rawDate = "${rawDate}Z";
    }

    return Task(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      dueDate: rawDate,
      status: json['status'] ?? 'To-Do',
      blockedById: json['blocked_by_id'],
      recurring: json['recurring'] ?? 'None',
      sortOrder: json['sort_order'] ?? 0,
      taskType: json['task_type'] ?? 'Other',
      importance: json['importance'] ?? 1,
      extendedCount: json['extended_count'] ?? 0,
      version: json['version'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "title": title,
      "description": description,
      "due_date": dueDate,
      "status": status,
      "blocked_by_id": blockedById,
      "recurring": recurring,
      "sort_order": sortOrder,
      "task_type": taskType,
      "importance": importance,
      "extended_count": extendedCount,
      "version": version,
    };
  }
}