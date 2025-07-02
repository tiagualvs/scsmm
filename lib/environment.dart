import 'dart:convert';

class Environment {
  final String name;
  final String path;

  const Environment({required this.name, required this.path});

  Environment copyWith({
    String? name,
    String? path,
  }) {
    return Environment(
      name: name ?? this.name,
      path: path ?? this.path,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'path': path,
    };
  }

  factory Environment.fromMap(Map<String, dynamic> map) {
    return Environment(
      name: map['name'] as String,
      path: map['path'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory Environment.fromJson(String source) => Environment.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() => 'Environment(name: $name, path: $path)';

  @override
  bool operator ==(covariant Environment other) {
    if (identical(this, other)) return true;

    return other.name == name && other.path == path;
  }

  @override
  int get hashCode => name.hashCode ^ path.hashCode;
}
