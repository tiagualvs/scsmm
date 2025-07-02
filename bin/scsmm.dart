import 'dart:ffi';
import 'dart:io';

import 'package:args/args.dart';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:scsmm/config.dart';
import 'package:scsmm/environment.dart';
import 'package:win32/win32.dart';
import 'package:yaml/yaml.dart';

const String version = '0.0.1+5';

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
      return await install(dir);
    } else if (results.wasParsed('uninstall')) {
      return await uninstall(dir);
    } else if (results.wasParsed('status')) {
      return await status(dir);
    } else if (results.wasParsed('list')) {
      return await list(dir);
    } else if (results.wasParsed('create')) {
      return await create(dir, results['create'] as String);
    } else if (results.wasParsed('remove')) {
      return await remove(dir, results['remove'] as String);
    } else if (results.wasParsed('activate')) {
      return await activate(dir, results['activate'] as String);
    }
  } on Exception catch (e) {
    return stdout.writeln(e.toString().replaceFirst('Exception: ', ''));
  }
}

Future<void> status(Directory dir) async {
  final config = File(p.join(dir.path, '.scsmm', 'config.yaml'));
  if (!await config.exists()) {
    stdout.writeln('The SCS Mods Manager is not installed.');
  } else {
    final yaml = loadYaml(await config.readAsString());
    stdout.writeln(
      'The SCS Mods Manager is installed.\nThe current environment is ${p.basename(yaml['current_environment'])}.',
    );
  }
}

Future<void> install(Directory dir) async {
  stdout.writeln(
    '''This action will create a new directory inside the game folder called `.scsmm` and will create a `config.yaml` file in it.
  A default environment named `Default` will be created as a folder inside `.scsmm`.
  This folder will contain every environment you create.
  Your current mod folder will be moved to `.scsmm/Default` and activated as the default environment.
  A symlink will be created from the old mod folder location to the current environment.
  Initially, the symlink will point from `gamedir/mod` to `gamedir/.scsmm/Default`.''',
  );
  stdout.write('Do you want to continue? (y/N) ');
  final option = stdin.readLineSync() ?? 'n';
  if (option.toLowerCase() != 'y') {
    stdout.writeln('Action cancelled.');
    return;
  }
  stdout.writeln('Installing...');
  final mod = Directory(p.join(dir.path, 'mod'));
  final scsmm = Directory(p.join(dir.path, '.scsmm'));
  if (!await scsmm.exists()) await scsmm.create(recursive: true);
  final defaultEnv = Directory(p.join(scsmm.path, 'Default'));
  if (!await defaultEnv.exists()) await defaultEnv.create(recursive: true);
  if (await mod.exists()) {
    if (mod.listSync().where((f) => f.statSync().type == FileSystemEntityType.directory).isNotEmpty) {
      throw Exception('You have a folder in your mod directory. Please remove it and try again.');
    }

    for (final file in mod.listSync().map((f) => File(f.path))) {
      await file.copy(p.join(defaultEnv.path, p.join(defaultEnv.path, p.basename(file.path))));
    }
  }
  await link(mod, defaultEnv);
  final config = Config.create(defaultEnv);
  await config.save(dir);
  stdout.writeln('The SCS Mods Manager has been installed.');
}

Future<void> create(Directory dir, String name) async {
  if (name.isEmpty) {
    stdout.writeln('Environment name cannot be empty.');
    return;
  }
  Config config = await Config.load(dir);
  if (config.environments.any((env) => env.name == name)) {
    stdout.writeln('Environment $name already exists. Please choose a different name.');
    return;
  }
  final newEnv = Directory(p.join(dir.path, '.scsmm', name));
  await newEnv.create(recursive: true);
  config = config.copyWith(
    environments: [
      ...config.environments,
      Environment(name: name, path: newEnv.path),
    ],
  );
  await config.save(dir);
  stdout.writeln('The environment $name has been created.');
}

Future<void> list(Directory dir) async {
  final config = await Config.load(dir);
  stdout.writeln('-' * 80);
  stdout.writeln(
    'The SCS Mods Manager has ${config.environments.length} environment${config.environments.length <= 1 ? '' : 's'}.',
  );
  stdout.writeln('-' * 80);
  for (final environment in config.environments) {
    stdout.writeln('${environment.name}${environment.name == config.currentEnvironment ? ' (active)' : ''}');
  }
}

Future<void> activate(Directory dir, String envName) async {
  Config config = await Config.load(dir);
  final index = config.environments.indexWhere((env) => env.name == envName);
  if (index == -1) {
    stdout.writeln('Environment $envName does not exist. Please choose a different name.');
    return;
  }
  final newEnv = config.environments[index];
  config = config.copyWith(currentEnvironment: newEnv.name);
  await link(Directory(p.join(dir.path, 'mod')), Directory(newEnv.path));
  await config.save(dir);
  stdout.writeln('The environment $envName has been activated.');
}

Future<void> remove(Directory dir, String envName) async {
  if (envName == 'Default') {
    stdout.writeln(
      'You cannot remove the default environment. If you want to uninstall use --uninstall instead to remove all enviroments.',
    );
    return;
  }
  Config config = await Config.load(dir);
  final index = config.environments.indexWhere((env) => env.name == envName);
  if (index == -1) {
    stdout.writeln('Environment $envName does not exist. Please choose a different name.');
    return;
  }
  final currentEnv = config.environments[index];
  stdout.writeln(
    'You are about to remove the environment $envName. This action cannot be undone and all mods in the environment will be deleted.',
  );
  stdout.write('Are you sure you want to continue? [y/N] ');
  final option = stdin.readLineSync() ?? 'n';
  if (option.toLowerCase() == 'y') {
    if (currentEnv.name == config.currentEnvironment) {
      await activate(dir, 'Default');
      config = await Config.load(dir);
    }
    await Directory(currentEnv.path).delete(recursive: true);
    config = config.copyWith(
      environments: config.environments.where((env) => env.name != envName).toList(),
      updatedAt: DateTime.now(),
    );
    await config.save(dir);
    stdout.writeln('The environment $envName has been removed.');
    return;
  } else {
    stdout.writeln('Action cancelled.');
    return;
  }
}

Future<void> uninstall(Directory dir) async {
  stdout.writeln(
    'This will delete all enviroments with every mod in them. The Default environment will not be deleted, it will be moved to the original path inside the game folder.',
  );
  stdout.write('This action cannot be undone. Are you sure you want to continue? [y/N] ');
  final option = stdin.readLineSync() ?? 'n';
  if (option.toLowerCase() == 'y') {
    stdout.writeln('Uninstalling...');
    final mod = Directory(p.join(dir.path, 'mod'));
    await mod.delete(recursive: true);
    final defaultEnv = Directory(p.join(dir.path, '.scsmm', 'Default'));
    await mod.create(recursive: true);
    for (final file in defaultEnv.listSync().map((f) => File(f.path))) {
      await file.copy(p.join(mod.path, p.basename(file.path)));
    }
    final scsmmDir = Directory(p.join(dir.path, '.scsmm'));
    await scsmmDir.delete(recursive: true);
    stdout.writeln('The SCS Mods Manager has been uninstalled.');
    return;
  } else {
    stdout.writeln('Action cancelled.');
    return;
  }
}

Future<void> link(Directory from, Directory to) async {
  try {
    if (await from.exists()) await from.delete(recursive: true);
    await Process.runSync('mklink', ['/D', from.path, to.path], runInShell: true);
  } on Exception catch (e) {
    stdout.writeln('Error: ${e.toString()}');
  }
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
