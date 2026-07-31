// Manually-written Hive TypeAdapters (avoids build_runner step)
// Mirrors what hive_generator would produce for Board + ExpenseRow.

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
    );
  }

  @override
  void write(BinaryWriter writer, Board obj) {
    writer
      ..writeByte(7)
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
      ..write(obj.note);
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
    );
  }

  @override
  void write(BinaryWriter writer, ExpenseRow obj) {
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
      ..write(obj.createdAt);
  }
}
