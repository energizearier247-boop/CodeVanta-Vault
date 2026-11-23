
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../main.dart';
import '../services/vault_service.dart';

class VaultHome extends StatefulWidget {
  const VaultHome({super.key});

  @override
  State<VaultHome> createState() => _VaultHomeState();
}

class _VaultHomeState extends State<VaultHome>
    with WidgetsBindingObserver {
  String _category = 'all';
  bool _busy = false;
  DateTime? _backgroundedAt;
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _backgroundedAt = DateTime.now();
      VaultService.instance.lock();
    } else if (state == AppLifecycleState.resumed &&
        _backgroundedAt != null) {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const _RelockScreen(),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _import() async {
    try {
      setState(() {
        _busy = true;
      });

      final result = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: true,
      );

      if (result == null) {
        return;
      }

      for (final picked in result.files) {
        final bytes = picked.bytes;

        if (bytes == null) {
          throw Exception(
            'Could not read ${picked.name}. Please try selecting it again.',
          );
        }

        await VaultService.instance.importFile(
          picked.path ?? '',
          picked.name,
          bytes,
        );
      }

      if (!mounted) {
        return;
      }

      _message('${result.files.length} file(s) added to your vault.');
    } catch (e) {
      if (!mounted) {
        return;
      }

      _message(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _message(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<VaultFile> get _visibleFiles {
    final query = _search.text.toLowerCase();

    return VaultService.instance.files.where((file) {
      final categoryMatch =
          _category == 'all' || file.category == _category;

      return categoryMatch &&
          file.name.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openFile(VaultFile file) async {
    try {
      final clear =
          await VaultService.instance.decryptToTemporaryFile(file);

      if (!mounted) {
        return;
      }

      if (file.category == 'music') {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _AudioSheet(
            file: clear,
            title: file.name,
          ),
        );
      } else if (file.category == 'videos') {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _VideoScreen(
              file: clear,
              title: file.name,
            ),
          ),
        );
      } else {
        _message(
          'Decrypted copy created in temporary app cache: '
          '${p.basename(clear.path)}',
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      _message('Unable to open file: $e');
    }
  }

  Future<void> _delete(VaultFile file) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text(
          'Delete "${file.name}" from CodeVanta Vault? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (!mounted) {
      return;
    }

    if (yes == true) {
      await VaultService.instance.deleteFile(file);

      if (!mounted) {
        return;
      }

      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = _visibleFiles;
    final all = VaultService.instance.files;

    final totalBytes = all.fold<int>(
      0,
      (sum, item) => sum + item.size,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CodeVanta Vault',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            onPressed: CodeVantaVaultApp.of(context).toggleTheme,
            icon: const Icon(Icons.contrast_rounded),
          ),
          IconButton(
            tooltip: 'Lock vault',
            onPressed: () async {
              await VaultService.instance.lock();

              if (!mounted) {
                return;
              }

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => const _RelockScreen(),
                ),
                (route) => false,
              );
            },
            icon: const Icon(Icons.lock_outline_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _import,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.add),
        label: const Text('Add files'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              18,
              8,
              18,
              100,
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF102B50),
                      Color(0xFF071326),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFF1B78C9),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.sd_storage_rounded,
                      color: Color(0xFFBFC9D8),
                      size: 46,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YOUR PRIVATE SPACE',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              letterSpacing: 1.3,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${all.length} protected files',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_formatBytes(totalBytes)} stored on this device',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.verified_user_outlined,
                      color: Color(0xFF168BFF),
                      size: 30,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _search,
                onChanged: (_) {
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: 'Search your files',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filter(
                    'all',
                    'All files',
                    Icons.folder_outlined,
                  ),
                  _filter(
                    'archives',
                    'App & website ZIPs',
                    Icons.archive_outlined,
                  ),
                  _filter(
                    'music',
                    'My music',
                    Icons.headphones_outlined,
                  ),
                  _filter(
                    'videos',
                    'My videos',
                    Icons.movie_outlined,
                  ),
                  _filter(
                    'other',
                    'Other',
                    Icons.insert_drive_file_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _category == 'all'
                          ? 'All files'
                          : _category.toUpperCase(),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Text(
                    '${files.length} items',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (files.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 46),
                  child: Column(
                    children: [
                      Icon(
                        Icons.folder_open_rounded,
                        size: 54,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      const Text('Your vault is empty'),
                      const SizedBox(height: 5),
                      const Text(
                        'Tap Add files to import your first file.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ...files.map(
                  (file) => Card(
                    margin: const EdgeInsets.only(bottom: 9),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      leading: CircleAvatar(
                        backgroundColor:
                            const Color(0xFF168BFF).withValues(
                          alpha: 0.14,
                        ),
                        child: Icon(
                          _iconFor(file.category),
                          color: const Color(0xFF168BFF),
                        ),
                      ),
                      title: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${file.extension.toUpperCase()} • '
                        '${_formatBytes(file.size)}',
                      ),
                      onTap: () {
                        _openFile(file);
                      },
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'open') {
                            _openFile(file);
                          }

                          if (value == 'delete') {
                            _delete(file);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'open',
                            child: Text('Open / Play'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              const Text(
                'Files are encrypted inside this app’s private storage. '
                'Keep a separate backup of important originals.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filter(
    String value,
    String label,
    IconData icon,
  ) {
    return ChoiceChip(
      selected: _category == value,
      onSelected: (_) {
        setState(() {
          _category = value;
        });
      },
      avatar: Icon(icon, size: 17),
      label: Text(label),
    );
  }

  IconData _iconFor(String category) {
    return switch (category) {
      'archives' => Icons.archive_rounded,
      'music' => Icons.music_note_rounded,
      'videos' => Icons.play_circle_outline_rounded,
      _ => Icons.insert_drive_file_outlined,
    };
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _RelockScreen extends StatelessWidget {
  const _RelockScreen();

  @override
  Widget build(BuildContext context) {
    return const _RelockGate();
  }
}

class _RelockGate extends StatefulWidget {
  const _RelockGate();

  @override
  State<_RelockGate> createState() => _RelockGateState();
}

class _RelockGateState extends State<_RelockGate> {
  final TextEditingController _code = TextEditingController();

  String? _error;
  bool _busy = false;

  Future<void> _unlock() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final ok = await VaultService.instance.unlock(_code.text);

    if (!mounted) {
      return;
    }

    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const VaultHome(),
        ),
      );
    } else {
      setState(() {
        _error = 'Incorrect secret code.';
      });
    }

    if (mounted) {
      setState(() {
        _busy = false;
      });
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_rounded,
                size: 64,
                color: Color(0xFF168BFF),
              ),
              const SizedBox(height: 18),
              Text(
                'Vault locked',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _code,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Secret code',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _unlock,
                  child: Text(
                    _busy ? 'UNLOCKING…' : 'UNLOCK',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioSheet extends StatefulWidget {
  const _AudioSheet({
    required this.file,
    required this.title,
  });

  final File file;
  final String title;

  @override
  State<_AudioSheet> createState() => _AudioSheetState();
}

class _AudioSheetState extends State<_AudioSheet> {
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _player.setFilePath(widget.file.path);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.headphones_rounded,
              size: 54,
              color: Color(0xFF168BFF),
            ),
            const SizedBox(height: 12),
            Text(
              widget.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 18),
            StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (context, snapshot) {
                final playing = snapshot.data?.playing ?? false;

                return IconButton.filledTonal(
                  iconSize: 42,
                  onPressed: () {
                    if (playing) {
                      _player.pause();
                    } else {
                      _player.play();
                    }
                  },
                  icon: Icon(
                    playing ? Icons.pause : Icons.play_arrow,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoScreen extends StatefulWidget {
  const _VideoScreen({
    required this.file,
    required this.title,
  });

  final File file;
  final String title;

  @override
  State<_VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<_VideoScreen> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (!mounted) {
          return;
        }

        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            if (_controller.value.isPlaying) {
              _controller.pause();
            } else {
              _controller.play();
            }
          });
        },
        child: Icon(
          _controller.value.isPlaying
              ? Icons.pause
              : Icons.play_arrow,
        ),
      ),
    );
  }
}
