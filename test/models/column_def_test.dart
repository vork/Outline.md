import 'package:flutter_test/flutter_test.dart';
import 'package:outline_md/models/column_def.dart';

void main() {
  group('ColumnDef', () {
    test('default width is 150', () {
      final col = ColumnDef(name: 'Status');
      expect(col.width, 150.0);
    });

    test('accepts custom width', () {
      final col = ColumnDef(name: 'Wide', width: 300.0);
      expect(col.width, 300.0);
    });

    group('copyWith', () {
      test('copies name', () {
        final col = ColumnDef(name: 'Old');
        final copy = col.copyWith(name: 'New');
        expect(copy.name, 'New');
        expect(copy.width, 150.0);
      });

      test('copies width', () {
        final col = ColumnDef(name: 'Status', width: 100.0);
        final copy = col.copyWith(width: 200.0);
        expect(copy.name, 'Status');
        expect(copy.width, 200.0);
      });
    });

    group('JSON serialization', () {
      test('toJson produces correct map', () {
        final col = ColumnDef(name: 'Priority', width: 180.0);
        final json = col.toJson();
        expect(json, {'name': 'Priority', 'width': 180.0});
      });

      test('fromJson parses correctly', () {
        final col = ColumnDef.fromJson({'name': 'Status', 'width': 200.0});
        expect(col.name, 'Status');
        expect(col.width, 200.0);
      });

      test('fromJson defaults width to 150 when missing', () {
        final col = ColumnDef.fromJson({'name': 'Status'});
        expect(col.width, 150.0);
      });

      test('round-trip through JSON', () {
        final original = ColumnDef(name: 'Test', width: 175.0);
        final restored = ColumnDef.fromJson(original.toJson());
        expect(restored.name, original.name);
        expect(restored.width, original.width);
      });
    });
  });
}
