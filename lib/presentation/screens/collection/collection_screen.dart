import 'package:flutter/material.dart';

import '../../../data/models/lexipet.dart';
import '../../../shared/providers/mock_data.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pets = MockData.lexipets;
    return Scaffold(
      appBar: AppBar(title: const Text('Collection')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: pets.length,
        itemBuilder: (_, i) => _PetTile(pet: pets[i]),
      ),
    );
  }
}

class _PetTile extends StatelessWidget {
  const _PetTile({required this.pet});
  final Lexipet pet;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          const Expanded(
            child: Center(child: Text('🐣', style: TextStyle(fontSize: 48))),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(pet.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
