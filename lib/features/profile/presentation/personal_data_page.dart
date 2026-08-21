import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanse/core/utils/expense_notifier.dart';

class PersonalDataPage extends StatefulWidget {
  const PersonalDataPage({super.key});

  @override
  State<PersonalDataPage> createState() => _PersonalDataPageState();
}

class _PersonalDataPageState extends State<PersonalDataPage> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPickingPhoto = false;

  String _profilePhotoPath = '';

  @override
  void initState() {
    super.initState();
    _loadPersonalData();
  }

  Future<void> _loadPersonalData() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final String savedName = preferences.getString('userName')?.trim() ?? '';

    String savedPhotoPath =
        preferences.getString('profilePhotoPath')?.trim() ?? '';

    if (savedPhotoPath.isNotEmpty) {
      final bool photoExists = await File(savedPhotoPath).exists();

      if (!photoExists) {
        await preferences.remove('profilePhotoPath');
        savedPhotoPath = '';
      }
    }

    if (!mounted) {
      return;
    }

    _nameController.text = savedName;

    setState(() {
      _profilePhotoPath = savedPhotoPath;
      _isLoading = false;
    });
  }

  String _getFileExtension(String filePath) {
    final int dotIndex = filePath.lastIndexOf('.');

    if (dotIndex == -1) {
      return '.jpg';
    }

    final String extension = filePath.substring(dotIndex).toLowerCase();

    if (!RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(extension)) {
      return '.jpg';
    }

    return extension;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_isPickingPhoto) {
      return;
    }

    setState(() {
      _isPickingPhoto = true;
    });

    try {
      final XFile? selectedPhoto = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (selectedPhoto == null) {
        return;
      }

      final Directory directory = await getApplicationDocumentsDirectory();

      final String extension = _getFileExtension(selectedPhoto.path);

      final String newPhotoPath =
          '${directory.path}${Platform.pathSeparator}'
          'profile_photo_${DateTime.now().millisecondsSinceEpoch}$extension';

      final File copiedPhoto = await File(
        selectedPhoto.path,
      ).copy(newPhotoPath);

      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final String oldPhotoPath = _profilePhotoPath;

      await preferences.setString('profilePhotoPath', copiedPhoto.path);
      expenseNotifier.value++;

      if (oldPhotoPath.isNotEmpty && oldPhotoPath != copiedPhoto.path) {
        final File oldPhoto = File(oldPhotoPath);

        if (await oldPhoto.exists()) {
          await oldPhoto.delete();
        }
      }

      if (!mounted) {
        return;
      }

      HapticFeedback.mediumImpact();

      setState(() {
        _profilePhotoPath = copiedPhoto.path;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar a foto.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingPhoto = false;
        });
      }
    }
  }

  Future<void> _removePhoto() async {
    final String currentPhotoPath = _profilePhotoPath;

    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await preferences.remove('profilePhotoPath');
    expenseNotifier.value++;

    if (currentPhotoPath.isNotEmpty) {
      final File currentPhoto = File(currentPhotoPath);

      if (await currentPhoto.exists()) {
        await currentPhoto.delete();
      }
    }

    if (!mounted) {
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _profilePhotoPath = '';
    });
  }

  Future<void> _showPhotoOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Escolher da galeria'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _pickPhoto(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Tirar uma foto'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _pickPhoto(ImageSource.camera);
                },
              ),
              if (_profilePhotoPath.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Remover foto'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _removePhoto();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveName() async {
    final String name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite seu nome antes de salvar.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      await preferences.setString('userName', name);
      expenseNotifier.value++;

      HapticFeedback.mediumImpact();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(name);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final String currentName = _nameController.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Dados pessoais')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: <Widget>[
                  Center(
                    child: GestureDetector(
                      onTap: _isPickingPhoto ? null : _showPhotoOptions,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: primaryColor.withValues(
                              alpha: 0.15,
                            ),
                            backgroundImage: _profilePhotoPath.isEmpty
                                ? null
                                : FileImage(File(_profilePhotoPath)),
                            child: _profilePhotoPath.isNotEmpty
                                ? null
                                : Text(
                                    currentName.isEmpty
                                        ? '?'
                                        : currentName
                                              .substring(0, 1)
                                              .toUpperCase(),
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: CircleAvatar(
                              radius: 17,
                              backgroundColor: primaryColor,
                              child: _isPickingPhoto
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Toque na foto para alterar',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    maxLength: 60,
                    onChanged: (_) {
                      setState(() {});
                    },
                    onSubmitted: (_) {
                      if (!_isSaving) {
                        _saveName();
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      hintText: 'Como você quer ser chamado?',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveName,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_isSaving ? 'Salvando...' : 'Salvar dados'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Seu nome e sua foto ficam salvos somente neste aparelho.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
    );
  }
}
