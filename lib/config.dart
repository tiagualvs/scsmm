import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:scsmm/environment.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

class Config {
  final String currentEnvironment;
  final List<Environment> environments;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Config({
    required this.currentEnvironment,
    required this.environments,
    required this.createdAt,
    required this.updatedAt,
  });

  static Future<Config> load(Directory dir) async {
    final config = File(p.join(dir.path, '.scsmm', 'config.yaml'));
    if (!await config.exists()) {
      throw Exception('The SCS Mods Manager is not installed.');
    }
    final yaml = loadYaml(await config.readAsString());
    return Config.fromMap(Map<String, dynamic>.from(yaml));
  }

  static Config create(Directory dir) {
    return Config(
      currentEnvironment: 'Default',
      environments: [Environment(name: 'Default', path: dir.path)],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> save(Directory dir) async {
    final yaml = YamlEditor('');
    final config = copyWith(updatedAt: DateTime.now());
    yaml.update([], config.toMap());
    await File(p.join(dir.path, '.scsmm', 'config.yaml')).writeAsString(yaml.toString(), flush: true);
  }

  Config copyWith({
    String? currentEnvironment,
    List<Environment>? environments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Config(
      currentEnvironment: currentEnvironment ?? this.currentEnvironment,
      environments: environments ?? this.environments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'current_environment': currentEnvironment,
      'environments': environments.map((x) => x.toMap()).toList(),
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Config.fromMap(Map<String, dynamic> map) {
    return Config(
      currentEnvironment: map['current_environment'] as String,
      environments: List<Environment>.from(
        (map['environments'] as List).map<Environment>((x) => Environment.fromMap(Map<String, dynamic>.from(x))),
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  String toJson() => json.encode(toMap());

  factory Config.fromJson(String source) => Config.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'Config(currentEnvironment: $currentEnvironment, environments: $environments, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(covariant Config other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;

    return other.currentEnvironment == currentEnvironment &&
        listEquals(other.environments, environments) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return currentEnvironment.hashCode ^ environments.hashCode ^ createdAt.hashCode ^ updatedAt.hashCode;
  }
}
