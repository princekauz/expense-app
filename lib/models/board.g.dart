// Manually-written Hive TypeAdapters. Mirrors what hive_generator would produce.
// typeIds: 1=Board, 2=ExpenseRow, 3=RecurrenceFrequency enum, 4=RecurrenceRule

part of 'board.dart';

class BoardAdapter extends TypeAdapter<Board> {
  @override
  final int typeId = 1;

  @override
  Board read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return Board(
      id: fields[0] as String,
      name: fields[1] as String,
      themeIndex: fields[2] as int,
      styleIndex: fields[3] as int,
      createdAt: fields[4] as DateTime,
      rows: (fields[5] as List?)?.cast<ExpenseRow>() ?? <ExpenseRow>[],
      note: fields[6] as String?,
      budget: fields[7] as double?,
      recurring: (fields[8] as List?)?.cast<RecurringRowTemplate>() ??
          <RecurringRowTemplate>[],
    );
  }

  @override
  void write(BinaryWriter writer, Board obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.themeIndex)
      ..writeByte(3)
      ..write(obj.styleIndex)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.rows)
      ..writeByte(6)
      ..write(obj.note)
      ..writeByte(7)
      ..write(obj.budget)
      ..writeByte(8)
      ..write(obj.recurring);
  }
}

class ExpenseRowAdapter extends TypeAdapter<ExpenseRow> {
  @override
  final int typeId = 2;

  @override
  ExpenseRow read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return ExpenseRow(
      id: fields[0] as String,
      label: fields[1] as String,
      amount: fields[2] as double,
      category: fields[3] as String,
      createdAt: fields[4] as DateTime,
      date: (fields[5] as DateTime?) ?? (fields[4] as DateTime),
      fromRecurringId: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ExpenseRow obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.date)
      ..writeByte(6)
      ..write(obj.fromRecurringId);
  }
}

class RecurrenceFrequencyAdapter extends TypeAdapter<RecurrenceFrequency> {
  @override
  final int typeId = 3;

  @override
  RecurrenceFrequency read(BinaryReader reader) {
    final i = reader.readByte();
    return RecurrenceFrequency
        .values[i.clamp(0, RecurrenceFrequency.values.length - 1)];
  }

  @override
  void write(BinaryWriter writer, RecurrenceFrequency obj) {
    writer.writeByte(obj.index);
  }
}

class RecurrenceRuleAdapter extends TypeAdapter<RecurrenceRule> {
  @override
  final int typeId = 4;

  @override
  RecurrenceRule read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return RecurrenceRule(
      frequency: fields[0] as RecurrenceFrequency,
      startDate: fields[1] as DateTime,
      endDate: fields[2] as DateTime?,
      lastMaterialized: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, RecurrenceRule obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.frequency)
      ..writeByte(1)
      ..write(obj.startDate)
      ..writeByte(2)
      ..write(obj.endDate)
      ..writeByte(3)
      ..write(obj.lastMaterialized);
  }
}

class RecurringRowTemplateAdapter extends TypeAdapter<RecurringRowTemplate> {
  @override
  final int typeId = 5;

  @override
  RecurringRowTemplate read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return RecurringRowTemplate(
      id: fields[0] as String,
      label: fields[1] as String,
      amount: fields[2] as double,
      category: fields[3] as String,
      rule: fields[4] as RecurrenceRule,
    );
  }

  @override
  void write(BinaryWriter writer, RecurringRowTemplate obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.rule);
  }
}
