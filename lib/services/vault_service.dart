import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class VaultFile {
  const VaultFile({
    required this.id,
    required this.name,
    required this.extension,
    required this.category,
    required this.size,
    required this.createdAt,
    required this.storageName,
  });

  final String id;
  final String name;
  final String extension;
  final String category;
  final int size;
  final DateTime createdAt;
  final String storageName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'extension': extension,
        'category': category,
        'size': size,
        'createdAt': createdAt.toIso8601String(),
        'storageName': storageName,
      };

  factory VaultFile.fromJson(Map<String, dynamic> json) => VaultFile(
        id: json['id'] as String,
        name: json['name'] as String,
        extension: json['extension'] as String,
        category: json['category'] as String,
        size: json['size'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        storageName: json['storageName'] as String,
      );
}

class VaultService {
  VaultService._();
  static final VaultService instance = VaultService._();

  static const _saltKey = 'cvv_salt_v1';
  static const _verifierKey = 'cvv_verifier_v1';
  static const _secureStorage = FlutterSecureStorage();
  static const _uuid = Uuid();

  final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 310000,
    bits: 256,
  );
  final _aes = AesGcm.with256bits();
  SecretKey? _sessionKey;
  List<VaultFile> _files = [];
  Directory? _root;
  Directory? _cacheDir;

  bool get isUnlocked => _sessionKey != null;
  List<VaultFile> get files => List.unmodifiable(_files);

  Future<Directory> _vaultDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'codevanta_vault_data'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _root = dir;
    return dir;
  }

  Future<bool> isConfigured() async =>
      await _secureStorage.read(key: _saltKey) != null &&
      await _secureStorage.read(key: _verifierKey) != null;

  Future<SecretKey> _derive(String code, List<int> salt) => _pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(code)),
        nonce: salt,
      );

  Future<void> createVault(String code) async {
    if (code.length < 8) {
      throw ArgumentError('Use at least 8 characters for your secret code.');
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final key = await _derive(code, salt);
    final keyBytes = await key.extractBytes();
    final verifier = await Sha256().hash(keyBytes);
    await _secureStorage.write(key: _saltKey, value: base64Encode(salt));
    await _secureStorage.write(key: _verifierKey, value: base64Encode(verifier.bytes));
    _sessionKey = key;
    _files = [];
    await _vaultDirectory();
    await _saveCatalogue();
  }

  Future<bool> unlock(String code) async {
    final saltText = await _secureStorage.read(key: _saltKey);
    final verifierText = await _secureStorage.read(key: _verifierKey);
    if (saltText == null || verifierText == null) return false;
    final key = await _derive(code, base64Decode(saltText));
    final actual = (await Sha256().hash(await key.extractBytes())).bytes;
    final expected = base64Decode(verifierText);
    if (!_constantTimeEquals(actual, expected)) return false;
    _sessionKey = key;
    await _loadCatalogue();
    return true;
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  Future<Uint8List> _seal(List<int> plain) async {
    final key = _sessionKey;
    if (key == null) throw StateError('Vault is locked.');
    final box = await _aes.encrypt(plain, secretKey: key);
    return Uint8List.fromList([...box.nonce, ...box.mac.bytes, ...box.cipherText]);
  }

  Future<Uint8List> _open(List<int> sealed) async {
    final key = _sessionKey;
    if (key == null) throw StateError('Vault is locked.');
    if (sealed.length < 28) throw const FormatException('Encrypted data is damaged.');
    final nonce = sealed.sublist(0, 12);
    final mac = Mac(sealed.sublist(12, 28));
    final cipherText = sealed.sublist(28);
    final clear = await _aes.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: key,
    );
    return Uint8List.fromList(clear);
  }

  Future<File> _catalogueFile() async =>
      File(p.join((await _vaultDirectory()).path, 'catalogue.cvv'));

  Future<void> _saveCatalogue() async {
    final file = await _catalogueFile();
    final encrypted = await _seal(utf8.encode(jsonEncode(_files.map((f) => f.toJson()).toList())));
    await file.writeAsBytes(encrypted, flush: true);
  }

  Future<void> _loadCatalogue() async {
    final file = await _catalogueFile();
    if (!await file.exists()) {
      _files = [];
      await _saveCatalogue();
      return;
    }
    final clear = await _open(await file.readAsBytes());
    final decoded = jsonDecode(utf8.decode(clear)) as List<dynamic>;
    _files = decoded
        .map((item) => VaultFile.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  String _categoryFor(String ext) {
    const music = {'mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac'};
    const video = {'mp4', 'm4v', 'mov', 'mkv', 'webm', 'avi'};
    if (music.contains(ext)) return 'music';
    if (video.contains(ext)) return 'videos';
    if (ext == 'zip' || ext == 'rar' || ext == '7z' || ext == 'tar' || ext == 'gz') {
      return 'archives';
    }
    return 'other';
  }

  Future<VaultFile> importFile(String sourcePath, String originalName, List<int> bytes) async {
    if (_sessionKey == null) throw StateError('Unlock the vault first.');
    final id = _uuid.v4();
    final ext = p.extension(originalName).replaceFirst('.', '').toLowerCase();
    final storageName = '$id.cvv';
    final dir = await _vaultDirectory();
    final encrypted = await _seal(bytes);
    await File(p.join(dir.path, storageName)).writeAsBytes(encrypted, flush: true);
    final item = VaultFile(
      id: id,
      name: p.basename(originalName),
      extension: ext,
      category: _categoryFor(ext),
      size: bytes.length,
      createdAt: DateTime.now(),
      storageName: storageName,
    );
    _files.insert(0, item);
    try {
      await _saveCatalogue();
    } catch (_) {
      await File(p.join(dir.path, storageName)).delete();
      _files.removeWhere((f) => f.id == id);
      rethrow;
    }
    return item;
  }

  Future<File> decryptToTemporaryFile(VaultFile item) async {
    if (_sessionKey == null) throw StateError('Vault is locked.');
    final dir = await _vaultDirectory();
    final encrypted = await File(p.join(dir.path, item.storageName)).readAsBytes();
    final clear = await _open(encrypted);
    _cacheDir ??= await getTemporaryDirectory();
    final output = File(p.join(_cacheDir!.path, 'cvv_${item.id}_${item.name}'));
    await output.writeAsBytes(clear, flush: true);
    return output;
  }

  Future<void> deleteFile(VaultFile item) async {
    final dir = await _vaultDirectory();
    final stored = File(p.join(dir.path, item.storageName));
    if (await stored.exists()) await stored.delete();
    _files.removeWhere((f) => f.id == item.id);
    await _saveCatalogue();
  }

  Future<void> clearTemporaryFiles() async {
    final dir = _cacheDir;
    if (dir == null || !await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File && p.basename(entity.path).startsWith('cvv_')) {
        try { await entity.delete(); } catch (_) {}
      }
    }
  }

  Future<void> lock() async {
    _sessionKey = null;
    _files = [];
    await clearTemporaryFiles();
  }
}
