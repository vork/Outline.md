class ColumnDef {
  final String name;
  final double width;

  const ColumnDef({required this.name, this.width = 150.0});

  ColumnDef copyWith({String? name, double? width}) {
    return ColumnDef(name: name ?? this.name, width: width ?? this.width);
  }

  Map<String, dynamic> toJson() => {'name': name, 'width': width};

  factory ColumnDef.fromJson(Map<String, dynamic> json) {
    return ColumnDef(
      name: json['name'] as String,
      width: (json['width'] as num?)?.toDouble() ?? 150.0,
    );
  }
}
