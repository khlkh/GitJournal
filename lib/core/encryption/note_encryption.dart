/*
 * SPDX-FileCopyrightText: 2024 GitJournal Contributors
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// PEM-like header markers for encrypted note text format.
const String _pemBegin = '-----BEGIN GJ ENCRYPTED NOTE-----';
const String _pemEnd = '-----END GJ ENCRYPTED NOTE-----';

const int _kdfIterations = 100000;
const int _saltLength = 16;
const int _nonceLength = 12;
const int _keyLengthBits = 256;

/// Exception thrown when decryption fails (wrong password or tampered data).
class DecryptionError implements Exception {
  final String message;
  DecryptionError(this.message);

  @override
  String toString() => 'DecryptionError: $message';
}

/// Exception thrown when the encrypted note format is invalid.
class EncryptionFormatError implements Exception {
  final String message;
  EncryptionFormatError(this.message);

  @override
  String toString() => 'EncryptionFormatError: $message';
}

/// Core encryption/decryption utilities for notes.
///
/// Uses AES-256-GCM with PBKDF2-HMAC-SHA256 key derivation.
/// Encrypted notes are stored in a PEM-like text format for easy copy-paste
/// and cross-platform interoperability (e.g., web-based decryption).
class NoteEncryption {
  /// Encrypts [plaintext] with [password] and returns a PEM-formatted string.
  ///
  /// The output contains all metadata (salt, nonce, algorithm info) needed
  /// for decryption, so only the password is required to decrypt.
  static Future<String> encrypt(String plaintext, String password,
      {String? title}) async {
    if (password.isEmpty) {
      throw ArgumentError('Password must not be empty');
    }

    // Generate random salt and nonce
    final salt = _randomBytes(_saltLength);
    final nonce = _randomBytes(_nonceLength);

    // Derive key from password
    final secretKey = await _deriveKey(password, salt);

    // Encrypt
    final algorithm = AesGcm.with256bits();
    final plaintextBytes = utf8.encode(plaintext);
    final secretBox = await algorithm.encrypt(
      plaintextBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    // Combine ciphertext + mac tag
    // GCM tag is appended to ciphertext in the output
    final ciphertextWithTag = Uint8List(
      secretBox.cipherText.length + secretBox.mac.bytes.length,
    );
    ciphertextWithTag.setRange(0, secretBox.cipherText.length, secretBox.cipherText);
    ciphertextWithTag.setRange(
      secretBox.cipherText.length,
      ciphertextWithTag.length,
      secretBox.mac.bytes,
    );

    // Format as PEM-like text
    final buffer = StringBuffer();
    buffer.writeln(_pemBegin);
    buffer.writeln('Version: 1');
    buffer.writeln('Algorithm: AES-256-GCM');
    buffer.writeln('KDF: PBKDF2-SHA256:$_kdfIterations');
    if (title != null && title.isNotEmpty) {
      buffer.writeln('Title: ${base64.encode(utf8.encode(title))}');
    }
    buffer.writeln('Salt: ${base64.encode(salt)}');
    buffer.writeln('Nonce: ${base64.encode(nonce)}');
    buffer.writeln();
    buffer.writeln(base64.encode(ciphertextWithTag));
    buffer.writeln(_pemEnd);

    return buffer.toString();
  }

  /// Decrypts a PEM-formatted [pemText] with [password].
  ///
  /// Throws [DecryptionError] if the password is wrong or data is tampered.
  /// Throws [EncryptionFormatError] if the format is invalid.
  static Future<String> decrypt(String pemText, String password) async {
    if (password.isEmpty) {
      throw ArgumentError('Password must not be empty');
    }

    final header = _parseEncryptedNote(pemText);

    // Derive key
    final secretKey = await _deriveKey(password, header.salt);

    // Decrypt
    final algorithm = AesGcm.with256bits();

    // Split ciphertext and mac tag
    // GCM tag is the last 16 bytes
    if (header.ciphertextWithTag.length < 16) {
      throw EncryptionFormatError('Ciphertext too short');
    }
    final cipherText = header.ciphertextWithTag.sublist(
      0,
      header.ciphertextWithTag.length - 16,
    );
    final macBytes = header.ciphertextWithTag.sublist(
      header.ciphertextWithTag.length - 16,
    );

    final secretBox = SecretBox(
      cipherText,
      nonce: header.nonce,
      mac: Mac(macBytes),
    );

    try {
      final plaintextBytes = await algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      return utf8.decode(plaintextBytes);
    } on SecretBoxAuthenticationError {
      throw DecryptionError('Wrong password or data integrity check failed');
    } catch (e) {
      throw DecryptionError('Decryption failed: $e');
    }
  }

  /// Checks whether [content] is an encrypted note in PEM format.
  static bool isEncryptedNote(String content) {
    final trimmed = content.trim();
    return trimmed.startsWith(_pemBegin) && trimmed.endsWith(_pemEnd);
  }

  /// Extracts the title from an encrypted note without decrypting.
  /// Returns null if no title header is present.
  static String? extractTitle(String pemText) {
    final lines = LineSplitter.split(pemText.trim()).toList();
    for (var i = 1; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) break; // Headers end at blank line
      if (line.startsWith(_pemEnd)) break;

      final colonIndex = line.indexOf(':');
      if (colonIndex > 0) {
        final key = line.substring(0, colonIndex).trim();
        final value = line.substring(colonIndex + 1).trim();
        if (key.toLowerCase() == 'title') {
          try {
            return utf8.decode(base64.decode(value));
          } catch (_) {
            return null;
          }
        }
      }
    }
    return null;
  }

  // --- Internal helpers ---

  static Future<SecretKey> _deriveKey(String password, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _kdfIterations,
      bits: _keyLengthBits,
    );
    return pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  static _EncryptedNoteHeader _parseEncryptedNote(String pemText) {
    final lines = LineSplitter.split(pemText.trim()).toList();
    if (lines.isEmpty || !lines.first.startsWith(_pemBegin)) {
      throw EncryptionFormatError('Missing PEM begin marker');
    }
    if (!lines.last.startsWith(_pemEnd)) {
      throw EncryptionFormatError('Missing PEM end marker');
    }

    String? saltB64;
    String? nonceB64;
    final bodyLines = <String>[];
    var inBody = false;

    for (var i = 1; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        inBody = true;
        continue;
      }
      if (line.startsWith(_pemEnd)) {
        break;
      }
      if (!inBody) {
        // Parse header
        final colonIndex = line.indexOf(':');
        if (colonIndex > 0) {
          final key = line.substring(0, colonIndex).trim();
          final value = line.substring(colonIndex + 1).trim();
          switch (key.toLowerCase()) {
            case 'salt':
              saltB64 = value;
              break;
            case 'nonce':
              nonceB64 = value;
              break;
          }
        }
      } else {
        bodyLines.add(line);
      }
    }

    if (saltB64 == null) {
      throw EncryptionFormatError('Missing Salt header');
    }
    if (nonceB64 == null) {
      throw EncryptionFormatError('Missing Nonce header');
    }
    if (bodyLines.isEmpty) {
      throw EncryptionFormatError('Missing ciphertext body');
    }

    Uint8List salt;
    Uint8List nonce;
    Uint8List ciphertextWithTag;
    try {
      salt = base64.decode(saltB64);
      nonce = base64.decode(nonceB64);
      ciphertextWithTag = base64.decode(bodyLines.join());
    } catch (e) {
      throw EncryptionFormatError('Invalid base64 encoding: $e');
    }

    return _EncryptedNoteHeader(
      salt: salt,
      nonce: nonce,
      ciphertextWithTag: ciphertextWithTag,
    );
  }
}

class _EncryptedNoteHeader {
  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List ciphertextWithTag;

  _EncryptedNoteHeader({
    required this.salt,
    required this.nonce,
    required this.ciphertextWithTag,
  });
}
