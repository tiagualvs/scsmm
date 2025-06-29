import 'dart:ffi';
import 'dart:io';

import 'package:args/args.dart';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

const String version = '0.0.2';

ArgParser buildParser() {
  return ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    )
    ..addOption(
      'game',
      abbr: 'g',
      allowed: ['ets2', 'ats'],
      defaultsTo: 'ets2',
      help: 'The game to use.',
    )
    ..addFlag(
      'status',
      abbr: 's',
      negatable: false,
      help: 'Print the status of the SCS Mods Manager.',
    )
    ..addFlag(
      'install',
      abbr: 'i',
      negatable: false,
      help: 'Install the SCS Mods Manager.',
    )
    ..addFlag(
      'uninstall',
      abbr: 'u',
      negatable: false,
      help: 'Uninstall the SCS Mods Manager.',
    )
    ..addFlag(
      'list',
      abbr: 'l',
      negatable: false,
      help: 'List the available environments.',
    )
    ..addOption(
      'create',
      abbr: 'c',
      help: 'Create a new environment. Eg: scsmm --create EAA or scsmm -c "Pro Mods"',
    )
    ..addOption(
      'remove',
      abbr: 'r',
      help: 'Remove an environment. Eg: scsmm --remove EAA or scsmm -r "Pro Mods"',
    )
    ..addOption(
      'activate',
      abbr: 'a',
      help: 'Activate the environment as default. Eg: scsmm --activate Default or scsmm -a Default',
    )
    ..addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Prits the version of the SCS Mods Manager.',
    );
}

void printUsage(ArgParser argParser) {
  stdout.writeln('Usage: dart scsmm <flags> [arguments]');
  stdout.writeln(argParser.usage);
}

void main(List<String> arguments) async {
  final ArgParser argParser = buildParser();
  try {
    final ArgResults results = argParser.parse(arguments);
    final game = results['game'] as String;
    final dir = await getRootDirectory(game);

    if (results.wasParsed('help')) {
      return printUsage(argParser);
    } else if (results.wasParsed('version')) {
      return stdout.writeln('SCS Mods Manager: $version');
    } else if (results.wasParsed('install')) {
      return install(dir);
    } else if (results.wasParsed('uninstall')) {
      return uninstall(dir);
    } else if (results.wasParsed('status')) {
      return status(dir);
    } else if (results.wasParsed('list')) {
      return list(dir);
    } else if (results.wasParsed('create')) {
      return create(dir, results['create'] as String);
    } else if (results.wasParsed('remove')) {
      return remove(dir, results['remove'] as String);
    } else if (results.wasParsed('activate')) {
      return activate(dir, results['activate'] as String);
    }
  } on Exception catch (e) {
    return stdout.writeln(e.toString().replaceFirst('Exception: ', ''));
  }
}

void status(Directory dir) {
  final config = File(p.join(dir.path, '.scsmm', 'config.yaml'));
  if (!config.existsSync()) {
    stdout.writeln('The SCS Mods Manager is not installed.');
  } else {
    final yaml = loadYaml(config.readAsStringSync());
    stdout.writeln(
      'The SCS Mods Manager is installed.\nThe current environment is ${p.basename(yaml['current_environment'])}.',
    );
  }
}

void install(Directory dir) {
  final mod = Directory(p.join(dir.path, 'mod'));
  final scsmm = Directory(p.join(dir.path, '.scsmm'));
  if (!scsmm.existsSync()) scsmm.createSync(recursive: true);
  final defaultEnv = Directory(p.join(scsmm.path, 'Default'));
  if (!defaultEnv.existsSync()) defaultEnv.createSync(recursive: true);
  if (mod.existsSync()) {
    if (mod.listSync().where((f) => f.statSync().type == FileSystemEntityType.directory).isNotEmpty) {
      throw Exception('You have a folder in your mod directory. Please remove it and try again.');
    }

    for (final file in mod.listSync().map((f) => File(f.path))) {
      file.copySync(p.join(defaultEnv.path, p.join(defaultEnv.path, p.basename(file.path))));
    }
  }
  link(mod, defaultEnv);
  final config = <String, dynamic>{
    'current_environment': defaultEnv.path,
    'environments': [defaultEnv.path],
    'created_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  };
  final yaml = YamlEditor('');
  yaml.update([], config);
  File(p.join(scsmm.path, 'config.yaml')).writeAsStringSync(yaml.toString(), flush: true);
  stdout.writeln('The SCS Mods Manager has been installed.');
}

void create(Directory dir, String name) {
  if (name.isEmpty) {
    stdout.writeln('Environment name cannot be empty.');
    return;
  }
  final config = getConfig(dir);
  final envs = (config['environments'] as List).cast<String>();
  if (envs.contains(name)) {
    stdout.writeln('Environment $name already exists. Please choose a different name.');
    return;
  }
  final newEnv = Directory(p.join(dir.path, '.scsmm', name));
  newEnv.createSync(recursive: true);
  config.update(
    'environments',
    (envs) => [...envs, newEnv.path],
    ifAbsent: () => [newEnv.path],
  );
  setConfig(dir, config);
  stdout.writeln('The environment $name has been created.');
}

void list(Directory dir) {
  final config = getConfig(dir);
  final current = config['current_environment'];
  final envs = (config['environments'] as List).cast<String>();
  stdout.writeln('-' * 80);
  stdout.writeln('The SCS Mods Manager has ${envs.length} environment${envs.length <= 1 ? '' : 's'}.');
  stdout.writeln('-' * 80);
  for (final env in envs) {
    stdout.writeln('${p.basename(env)}${current == env ? '*' : ''}');
  }
}

void activate(Directory dir, String envName) {
  final config = getConfig(dir);
  final envs = (config['environments'] as List).cast<String>();
  if (!envs.any((env) => p.basename(env) == envName)) {
    stdout.writeln('Environment $envName does not exist. Please choose a different name.');
    return;
  }
  final newEnv = envs.firstWhere((env) => p.basename(env) == envName);
  config.update('current_environment', (_) => newEnv);
  link(Directory(p.join(dir.path, 'mod')), Directory(newEnv));
  setConfig(dir, config);
  stdout.writeln('The environment $envName has been activated.');
}

void remove(Directory dir, String envName) {
  if (envName == 'Default') {
    stdout.writeln(
      'You cannot remove the default environment. If you want to uninstall use --uninstall instead to remove all enviroments.',
    );
    return;
  }
  final config = getConfig(dir);
  final envs = (config['environments'] as List).cast<String>();
  if (!envs.any((env) => p.basename(env) == envName)) {
    stdout.writeln('Environment $envName does not exist. Please choose a different name.');
    return;
  }
  final currentEnv = envs.firstWhere((env) => p.basename(env) == envName);
  stdout.writeln(
    'You are about to remove the environment $envName. This action cannot be undone and all mods in the environment will be deleted.',
  );
  stdout.write('Are you sure you want to continue? [y/N] ');
  final option = stdin.readLineSync() ?? 'n';
  if (option.toLowerCase() == 'y') {
    if (currentEnv == config['current_environment']) {
      config['current_environment'] = envs.firstWhere((env) => p.basename(env) == 'Default');
    }
    Directory(currentEnv).deleteSync(recursive: true);
    config.update(
      'environments',
      (_) => envs.where((env) => p.basename(env) != envName).toList(),
      ifAbsent: () => [],
    );
    setConfig(dir, config);
    stdout.writeln('The environment $envName has been removed.');
    return;
  } else {
    stdout.writeln('Action cancelled.');
    return;
  }
}

void uninstall(Directory dir) {
  getConfig(dir);
  stdout.writeln(
    'This will delete all enviroments with every mod in them. The Default environment will not be deleted, it will be moved to the original path inside the game folder.',
  );
  stdout.write('This action cannot be undone. Are you sure you want to continue? [y/N] ');
  final option = stdin.readLineSync() ?? 'n';
  if (option.toLowerCase() == 'y') {
    final mod = Directory(p.join(dir.path, 'mod'));
    mod.deleteSync(recursive: true);
    final defaultEnv = Directory(p.join(dir.path, '.scsmm', 'Default'));
    mod.createSync(recursive: true);
    for (final file in defaultEnv.listSync().map((f) => File(f.path))) {
      file.copySync(p.join(mod.path, p.basename(file.path)));
    }
    final scsmmDir = Directory(p.join(dir.path, '.scsmm'));
    scsmmDir.deleteSync(recursive: true);
    stdout.writeln('The SCS Mods Manager has been uninstalled.');
    return;
  } else {
    stdout.writeln('Action cancelled.');
    return;
  }
}

void link(Directory from, Directory to) {
  try {
    if (from.existsSync()) from.deleteSync(recursive: true);
    Process.runSync('mklink', ['/D', from.path, to.path], runInShell: true);
  } on Exception catch (e) {
    stdout.writeln('Error: ${e.toString()}');
  }
}

Map<String, dynamic> getConfig(Directory dir) {
  final config = File(p.join(dir.path, '.scsmm', 'config.yaml'));
  if (!config.existsSync()) {
    throw Exception('The SCS Mods Manager is not installed.');
  } else {
    final yaml = loadYaml(config.readAsStringSync());
    return Map.from(yaml);
  }
}

void setConfig(Directory dir, Map<String, dynamic> config) {
  final yaml = YamlEditor('');
  config.update('updated_at', (_) => DateTime.now().toIso8601String());
  yaml.update([], config);
  File(p.join(dir.path, '.scsmm', 'config.yaml')).writeAsStringSync(yaml.toString(), flush: true);
}

Future<Directory> getRootDirectory([String game = 'ets2']) async {
  final documents = getDocumentsPath();
  final gameName = switch (game) {
    'ets2' => 'Euro Truck Simulator 2',
    'ats' => 'American Truck Simulator',
    _ => 'Euro Truck Simulator 2',
  };
  final generic = Directory(p.join(documents, gameName));
  final oneDrive = Directory(p.join(documents, 'OneDrive', gameName));
  if (await generic.exists()) {
    return generic;
  } else if (await oneDrive.exists()) {
    return oneDrive;
  } else {
    throw Exception('Could not find documents directory');
  }
}

String getDocumentsPath() {
  final pathPtr = calloc<Pointer<Utf16>>();
  final result = SHGetKnownFolderPath(
    GUIDFromString(FOLDERID_Documents),
    0,
    NULL,
    pathPtr,
  );

  if (result != S_OK) {
    throw WindowsException(result);
  }

  final path = pathPtr.value.toDartString();
  calloc.free(pathPtr);
  return path;
}
