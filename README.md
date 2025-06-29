# SCS Mods Manager

A simple CLI to manage environments in ETS2/ATS. This tool allows you to easily create, delete, and switch between environments.

## Installation

You can install SCS Mods Manager in two ways:

### 1. Via Dart Pub

If you have the Dart SDK installed, you can install it directly from the source code using `pub`:

```shell
dart pub global activate -sgit https://github.com/tiagualvs/scsmm.git
```
> Make sure that `~/.pub-cache/bin` (on macOS/Linux) or `%USERPROFILE%\AppData\Local\Pub\Cache\bin` (on Windows) is in your system's PATH.

### 2. Via Executable

You can download the `scsmm.exe` file from the [releases page](https://github.com/tiagualvs/scsmm/releases) and add it to your system PATH.

## Usage

### Checking the status
Open your terminal and type `scsmm --status` to check if the SCS Mods Manager is installed correctly.
```shell
scsmm --status
```

### Initial Setup
To start using SCS Mods Manager, you need to install it in your game directory.
```shell
scsmm --install
```
> **Note:** This action will create a new directory inside the game folder called `.scsmm` and will create a `config.yaml` file in it. A default environment named `Default` will be created as a folder inside `.scsmm`. This folder will contain every environment you create. Your current mod folder will be moved to `.scsmm/Default` and activated as the default environment. A symlink will be created from the old mod folder location to the current environment. Initially, the symlink will point from `gamedir/mod` to `gamedir/.scsmm/Default`.

### Listing environments
To check the current environment, type `scsmm --status` or `scsmm --list`, which will show a list of available environments and the current environment in use.
```shell
scsmm --status
scsmm --list
```

### Creating an environment
To create a new environment, type `scsmm --create <name>`, which will create a new folder inside `.scsmm` with the specified name.
```shell
scsmm --create EAA
```

### Switching environments
After executing this command, your game will read files from the new environment. The mod folder will be linked to the new environment with the new files inside.
```shell
scsmm --activate EAA
```

### Removing an environment
This command will delete the specified environment and all its files. If the deleted environment is currently active, the `Default` environment will be activated instead.
```shell
scsmm --remove EAA
```

### Uninstalling
This command will delete all environments from the `.scsmm` folder (including the .scsmm folder itself). The `Default` environment will not be deleted but will be moved back to its original path inside the game folder, and the symlink will be removed. Your game will read files from the `mod` directory as before.
```shell
scsmm --uninstall
```