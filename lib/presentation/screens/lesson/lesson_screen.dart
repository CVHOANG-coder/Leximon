import 'package:flutter/material.dart';

class LessonScreen extends StatelessWidget {
  const LessonScreen({super.key, required this.topicId});
  final String topicId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Lesson · $topicId')),
      body: const Center(
        child: Text('Lesson flow coming soon.'),
      ),
    );
  }
}
