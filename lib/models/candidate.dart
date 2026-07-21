import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class CandidateModel {
  final String id;
  String name;
  String position;
  String className;
  String section;
  String rollNumber;
  String? photoPath;
  int votes;
  final DateTime createdAt;

  CandidateModel({
    required this.id,
    required this.name,
    required this.position,
    required this.className,
    required this.section,
    required this.rollNumber,
    this.photoPath,
    this.votes = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Color get photoColor {
    final colors = [
      Colors.blue.shade100,
      Colors.green.shade100,
      Colors.orange.shade100,
      Colors.purple.shade100,
      Colors.teal.shade100,
      Colors.pink.shade100,
      Colors.indigo.shade100,
      Colors.amber.shade100,
    ];
    return colors[id.hashCode % colors.length];
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  CandidateModel copyWith({
    String? id,
    String? name,
    String? position,
    String? className,
    String? section,
    String? rollNumber,
    String? photoPath,
    int? votes,
    DateTime? createdAt,
  }) {
    return CandidateModel(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      className: className ?? this.className,
      section: section ?? this.section,
      rollNumber: rollNumber ?? this.rollNumber,
      photoPath: photoPath ?? this.photoPath,
      votes: votes ?? this.votes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class CandidateModelAdapter extends TypeAdapter<CandidateModel> {
  @override
  final int typeId = 0;

  @override
  CandidateModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return CandidateModel(
      id: fields[0] as String,
      name: fields[1] as String,
      position: fields[2] as String,
      className: fields[3] as String,
      section: fields[4] as String,
      rollNumber: fields[5] as String,
      photoPath: fields[6] as String?,
      votes: fields[7] as int? ?? 0,
      createdAt: fields[8] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, CandidateModel obj) {
    writer.writeByte(9);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.position);
    writer.writeByte(3);
    writer.write(obj.className);
    writer.writeByte(4);
    writer.write(obj.section);
    writer.writeByte(5);
    writer.write(obj.rollNumber);
    writer.writeByte(6);
    writer.write(obj.photoPath);
    writer.writeByte(7);
    writer.write(obj.votes);
    writer.writeByte(8);
    writer.write(obj.createdAt);
  }
}
