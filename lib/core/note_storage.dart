/*
 * SPDX-FileCopyrightText: 2019-2021 Vishesh Handa <me@vhanda.in>
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import 'dart:convert';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:gitjournal/core/encryption/note_encryption.dart';
import 'package:gitjournal/core/file/file_storage.dart';
import 'package:gitjournal/core/markdown/md_yaml_doc.dart';
import 'package:gitjournal/core/markdown/md_yaml_doc_codec.dart';
import 'package:gitjournal/core/markdown/md_yaml_doc_loader.dart';
import 'package:gitjournal/core/markdown/md_yaml_note_serializer.dart';
import 'package:gitjournal/logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart' as io;

import 'file/file.dart';
import 'folder/notes_folder_fs.dart';
import 'note.dart';
import 'notes/note.dart';

class NoteStorage {
  static final _serializer = MarkdownYAMLCodec();

  static String serialize(Note note) {
    // HACK: This isn't great as the raw editor still shows the note with metadata
    var data = note.data;
    if (!note.canHaveMetadata) {
      // Fix issue 579: If there is no yaml header, the title would get lost unless it is stored somewhere.
      // Hence, store it in the file as a first heading.
      data = MdYamlDoc(
        body: (note.title != null ? "# ${note.title!}\n" : "") + data.body,
      );
    }

    var contents = _serializer.encode(data);
    // Make sure all docs end with a \n
    if (!contents.endsWith('\n')) {
      contents += '\n';
    }

    return contents;
  }

  static Future<Note> save(Note note, {String? encryptionPassword}) async {
    assert(note.filePath.isNotEmpty);
    assert(note.fileName.isNotEmpty);
    assert(note.oid.isEmpty);

    List<int> contents;
    if (note.isEncrypted && encryptionPassword != null) {
      // Re-encrypt the note content before saving
      var plaintext = serialize(note);
      var encryptedText = await NoteEncryption.encrypt(
        plaintext,
        encryptionPassword,
        title: note.title,
      );
      contents = utf8.encode(encryptedText);
    } else {
      contents = utf8.encode(serialize(note));
    }

    assert(note.fullFilePath.startsWith(p.separator));

    var file = io.File(note.fullFilePath);
    await file.writeAsBytes(contents, flush: true);

    var stat = file.statSync();
    note = note.copyWith(
      file: note.file.copyFile(
        fileLastModified: stat.modified,
        oid: GitHash.compute(contents),
        modified: DateTime.now(),
      ),
    );

    return note;
  }

  /// Decrypts an encrypted note and returns a Note with the decrypted content.
  /// The returned note still has isEncrypted=true so it will be re-encrypted
  /// on save.
  static Future<Note> decryptNote(Note note, String password) async {
    if (!note.isEncrypted) {
      throw ArgumentError('Note is not encrypted');
    }

    var encryptedText = note.encryptedBody;
    if (encryptedText == null || encryptedText.isEmpty) {
      // Load from file if not cached
      var file = io.File(note.fullFilePath);
      encryptedText = await file.readAsString();
    }

    var plaintext = await NoteEncryption.decrypt(encryptedText, password);

    // Deserialize the decrypted content
    var parentFolder = note.parent;
    var format = note.fileFormat;

    if (format == NoteFileFormat.Markdown) {
      var data = _serializer.decode(plaintext);
      var settings = NoteSerializationSettings.fromConfig(parentFolder.config);
      var noteSerializer = NoteSerializer.fromConfig(settings);
      var decryptedNote = noteSerializer.decode(
        data: data,
        parent: parentFolder,
        file: note.file,
        fileFormat: format,
      );
      // Preserve encrypted flag and body for re-encryption
      return decryptedNote.copyWith(
        isEncrypted: true,
        encryptedBody: encryptedText,
        file: note.file,
      );
    } else {
      // Txt or Org mode
      return Note.build(
        parent: parentFolder,
        file: note.file,
        title: null,
        body: plaintext,
        noteType: NoteType.Unknown,
        tags: ISet(),
        extraProps: const {},
        fileFormat: format,
        propsList: IList(),
        serializerSettings:
            NoteSerializationSettings.fromConfig(parentFolder.config),
        created: null,
        modified: null,
        isEncrypted: true,
        encryptedBody: encryptedText,
      );
    }
  }

  static final mdYamlDocLoader = MdYamlDocLoader();

  /// Fails with 'NoteReloadNotRequired' if the note doesn't need to be reloaded
  static Future<Note> reload(Note note, FileStorage fileStorage) async {
    var newFile = await fileStorage.load(note.filePath);

    if (note.file == newFile) {
      throw NoteReloadNotRequired();
    }
    Log.d("Note modified: ${note.filePath}");

    return load(newFile, note.parent);
  }

  static Future<Note> load(File file, NotesFolderFS parentFolder) async {
    assert(file.filePath.isNotEmpty);
    assert(!file.filePath.startsWith('/'));
    assert(file.oid.isNotEmpty);

    var filePath = file.fullFilePath;

    // Read raw content first to check for encryption
    var rawContent = await io.File(filePath).readAsString();

    // Check if this is an encrypted note
    if (NoteEncryption.isEncryptedNote(rawContent)) {
      Log.d("Loading encrypted note: ${file.filePath}");
      // Extract title from PEM header (stored in plaintext for list display)
      var title = NoteEncryption.extractTitle(rawContent);
      var note = Note.build(
        parent: parentFolder,
        file: file,
        title: title,
        body: "",
        noteType: NoteType.Unknown,
        tags: ISet(),
        extraProps: const {},
        fileFormat: NoteFileFormat.Markdown,
        propsList: IList(),
        serializerSettings:
            NoteSerializationSettings.fromConfig(parentFolder.config),
        created: null,
        modified: null,
        isEncrypted: true,
        encryptedBody: rawContent,
      );
      return note;
    }

    var format = NoteFileFormatInfo.fromFilePath(filePath);

    if (format == NoteFileFormat.Markdown) {
      var data = _serializer.decode(rawContent);
      var settings = NoteSerializationSettings.fromConfig(parentFolder.config);
      var noteSerializer = NoteSerializer.fromConfig(settings);
      var note = noteSerializer.decode(
        data: data,
        parent: parentFolder,
        file: file,
        fileFormat: format,
      );
      return note;
    } else if (format == NoteFileFormat.Txt) {
      var note = Note.build(
        parent: parentFolder,
        file: file,
        title: null,
        body: rawContent,
        noteType: NoteType.Unknown,
        tags: ISet(),
        extraProps: const {},
        fileFormat: NoteFileFormat.Txt,
        propsList: IList(),
        serializerSettings:
            NoteSerializationSettings.fromConfig(parentFolder.config),
        created: null,
        modified: null,
      );
      return note;
    } else if (format == NoteFileFormat.OrgMode) {
      var note = Note.build(
        parent: parentFolder,
        file: file,
        title: null,
        body: rawContent,
        noteType: NoteType.Unknown,
        tags: ISet(),
        extraProps: const {},
        fileFormat: NoteFileFormat.OrgMode,
        propsList: IList(),
        serializerSettings:
            NoteSerializationSettings.fromConfig(parentFolder.config),
        created: null,
        modified: null,
      );
      return note;
    }

    throw Exception("Unknown Note type. WTF");
  }
}

class NoteReloadNotRequired implements Exception {
  NoteReloadNotRequired();
}
