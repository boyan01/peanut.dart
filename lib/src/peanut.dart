import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:io/ansi.dart' as ansi;
import 'package:path/path.dart' as p;

import 'build_runner.dart';
import 'helpers.dart';
import 'options.dart';
import 'peanut_exception.dart';
import 'utils.dart';
import 'webdev.dart';

export 'options.dart';
export 'utils.dart' show printError;
export 'webdev.dart' show PackageException;

Future<void> run({Options options, String workingDir}) async {
  options ??= const Options();
  workingDir ??= p.current;

  if (options.directories.isEmpty) {
    throw PeanutException('At least one directory must be provided.');
  }

  // key: package dir; value: all dirs to build within that package
  final targetDirs = targetDirectories(workingDir, options.directories);

  for (var dir in options.directories) {
    final fullPath = pkgNormalize(workingDir, dir);

    if (p.equals(workingDir, dir)) {
      throw PeanutException(
          '"$dir" is the same as the working directory, which is not allowed.');
    }

    if (!p.isWithin(workingDir, fullPath)) {
      throw PeanutException(
          '"$dir" is not in the working directory "$workingDir".');
    }
  }

  String prettyPkgPath(String pkgPath) => pkgPath == '.' ? workingDir : pkgPath;

  print(ansi.styleBold.wrap('Validating packages:'));
  for (var entry in targetDirs.entries) {
    final entryDir = pkgNormalize(workingDir, entry.key);
    print(ansi.styleBold.wrap('  ${prettyPkgPath(entry.key)}'));
    try {
      await checkPubspecLock(entryDir);
    } on FileSystemException catch (e) {
      throw PeanutException('${e.message} ${e.path}');
    }

    for (var dir in entry.value) {
      final buildDirPath = p.join(entryDir, dir);
      if (FileSystemEntity.typeSync(buildDirPath) ==
          FileSystemEntityType.notFound) {
        stderr.writeln(
          ansi.yellow.wrap(
            'The `$buildDirPath` directory does not exist. This may cause the '
            'build to fail. Try setting the `directory` flag.',
          ),
        );
      }
    }
  }

  if (options.dryRun) {
    print(ansi.wrapWith('\n*** Dry run ***', [ansi.yellow, ansi.styleBold]));
  }

  final outputDirMap = outputDirectoryMap(targetDirs);

  // create a temp dir to dump 'pub build' output to
  //#todo can be config
  final tempDir = Directory('${Directory.current.path}/.peanutOutput/');
  if (tempDir.existsSync()) {
    //delete build #fixme ask first
    tempDir.deleteSync(recursive: true);
  }
  tempDir.createSync();

  try {
    final entriesList = targetDirs.entries.toList(growable: false);
    for (var i = 0; i < entriesList.length; i++) {
      final sourcePkg = entriesList[i];
      final targets = Map<String, String>.fromEntries(outputDirMap.entries
          .where((e) => p.isWithin(sourcePkg.key, e.key))
          .map((e) => MapEntry(
              p.split(e.key).last,
              pkgNormalize(
                  options.dryRun ? 'temp_dir' : tempDir.path, e.value))));

      final pkgPath = prettyPkgPath(sourcePkg.key);

      final countDetails =
          targetDirs.length == 1 ? '' : ' (${i + 1} of ${entriesList.length})';

      print('');
      print(ansi.styleBold.wrap('''
Package:     $pkgPath$countDetails
Directories: ${sourcePkg.value.join(', ')}'''));

      await runBuildRunner(
        pkgNormalize(workingDir, sourcePkg.key),
        targets,
        options,
      );
    }

    if (options.dryRun) {
      print(ansi.wrapWith('*** Dry run ***\n', [ansi.yellow, ansi.styleBold]));
      return;
    }

    if (outputDirMap.length == 1) {
      // TODO(kevmoo): warn if there is no root `index.html` file!
    } else {
      // create root HTML file!
      final links = <String, String>{};

      for (var item in outputDirMap.values) {
        final rootHtmlFilePath = p.join(tempDir.path, item, 'index.html');
        if (FileSystemEntity.isFileSync(rootHtmlFilePath)) {
          links[item] = item;
        } else {
          print('"$item" does not contain an "index.html" file. Skipping.');
          // TODO(kevmoo): search for another file?
        }
      }

      File(p.join(tempDir.path, 'index.html'))
          .writeAsStringSync(_indexFile(links));
    }

    if (options.postBuildDartScript != null) {
      final postBuildScriptPath =
          pkgNormalize(workingDir, options.postBuildDartScript);
      if (!FileSystemEntity.isFileSync(postBuildScriptPath)) {
        throw PeanutException('The provided post-build Dart script does not '
            'exist or is not a file.\n$postBuildScriptPath');
      }

      print(ansi.styleBold.wrap('\nPost-build script: $postBuildScriptPath'));

      await runProcess(
        dartPath,
        [postBuildScriptPath, tempDir.path, jsonEncode(outputDirMap)],
        workingDirectory: workingDir,
      );
      print(ansi.styleBold.wrap('Post-build script: complete\n'));
    }

    var message = options.message;

    if (message == defaultMessage) {
      message = 'Built ${options.directories.join(', ')}';
      if (options.directories.length > 1 && message.length > 72) {
        message = '''
Built ${options.directories.length} directories

Directories:
  ${options.directories.join('\n  ')}
''';
      }
    }
    print('\n build success : ${tempDir.path}');
  } finally {
    // await tempDir.delete(recursive: true);
  }
}

String _indexFile(Map<String, String> links) => '''
<!DOCTYPE html>
<html lang="en">
  <head>
    <title>Examples</title>
    <meta name="generator" content="https://pub.dev/packages/peanut">
    <style>
      html, body { height: 100%; }
      #root {
        display: flex;
        max-width: 900px;
        margin: 0 auto;
        height: 100%;
        max-height: 1000px;
      }
      #toc {
        display: block;
        align-self: center;
        margin: 2ex;
      }
      iframe {
        flex-grow: 1;
        border-style: solid;
        border-width: 1px;
        border-color: lightgray;
        align-self: stretch;
      }
    </style>
  </head>
<body>
  <div id='root'>
  <div id="toc">
${links.entries.map(_linkForEntry).join('\n')}  
  </div>
  <iframe name='example_frame'></iframe>
  </div>
</body>
</html>
''';

final _underscoreOrSlash = RegExp('_|/');

String _prettyName(String input) =>
    input.split(_underscoreOrSlash).where((e) => e.isNotEmpty).map((e) {
      return e.substring(0, 1).toUpperCase() + e.substring(1);
    }).join(' ');

String _linkForEntry(MapEntry<String, String> entry) =>
    '    <p><a href="${entry.key}/" target="example_frame">'
    '${_prettyName(entry.value)}</a></p>';
