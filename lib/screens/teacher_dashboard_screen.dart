import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TeacherDashboardScreen extends StatelessWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final logsStream = FirebaseFirestore.instance
        .collection('student_logs')
        .orderBy('loginTime', descending: true)
        .limit(60)
        .snapshots();

    final notificationStream = FirebaseFirestore.instance
        .collection('teacher_notifications')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Laboratory Dashboard')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 900;
          final map = _LabMap(stream: logsStream);
          final notifications = _Notifications(stream: notificationStream);
          if (narrow) {
            return Column(
              children: [
                Expanded(child: map),
                const Divider(height: 1),
                SizedBox(height: 320, child: notifications),
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 2, child: map),
              const VerticalDivider(width: 1),
              SizedBox(width: 390, child: notifications),
            ],
          );
        },
      ),
    );
  }
}

class _LabMap extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  const _LabMap({required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Unable to load student logs: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final latestByPc = <String, Map<String, dynamic>>{};
        for (final doc in snapshot.data!.docs) {
          final data = doc.data();
          final pc = data['pcNumber']?.toString() ?? 'Unknown PC';
          latestByPc.putIfAbsent(pc, () => data);
        }
        final entries = latestByPc.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        if (entries.isEmpty) {
          return const Center(child: Text('No synchronized student logs yet.'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            childAspectRatio: 1.15,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: entries.length,
          itemBuilder: (_, index) {
            final data = entries[index].value;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.computer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entries[index].key,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    Text('Room ${data['room'] ?? ''}'),
                    const Spacer(),
                    Text(
                      data['studentEmail']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data['sessionStatus']?.toString() ?? 'active',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Notifications extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  const _Notifications({required this.stream});

  Future<void> _markRead(String id) {
    return FirebaseFirestore.instance
        .collection('teacher_notifications')
        .doc(id)
        .update({'status': 'read', 'readAt': FieldValue.serverTimestamp()});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Unable to load notifications: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Text('Problem notifications', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (docs.isEmpty) const Text('No notifications.'),
            ...docs.map((doc) {
              final data = doc.data();
              final unread = data['status'] == 'unread';
              return Card(
                child: ListTile(
                  leading: Icon(unread ? Icons.notification_important : Icons.notifications),
                  title: Text('${data['pcNumber'] ?? 'PC'} • ${data['issueType'] ?? 'Issue'}'),
                  subtitle: Text(
                    'Room ${data['room'] ?? ''}\n${data['description'] ?? ''}',
                  ),
                  isThreeLine: true,
                  trailing: unread
                      ? IconButton(
                          tooltip: 'Mark as read',
                          onPressed: () => _markRead(doc.id),
                          icon: const Icon(Icons.done),
                        )
                      : null,
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
