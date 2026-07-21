import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/journal_entry.dart';
import '../providers/journal_provider.dart';
import '../services/media_service.dart';
import '../widgets/tag_chip.dart';

class EntryScreen extends StatefulWidget {
  final JournalEntry? entry;
  final DateTime? entryDate;

  const EntryScreen({super.key, this.entry, this.entryDate});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  late QuillController _quillController;
  final MediaService _mediaService = MediaService();
  final List<String> _mediaPaths = [];
  final List<String> _tags = [];
  final TextEditingController _tagInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _quillController = QuillController.basic();
    if (widget.entry != null) {
      _mediaPaths.addAll(widget.entry!.mediaPaths);
      _tags.addAll(widget.entry!.tags);
      if (widget.entry!.content.isNotEmpty) {
        try {
          final data = jsonDecode(widget.entry!.content);
          if (data is List && data.isNotEmpty) {
            _quillController = QuillController(
              document: Document.fromJson(data),
              selection: const TextSelection.collapsed(offset: 0),
            );
          } else {
            _quillController = QuillController.basic();
            _quillController.document.insert(0, widget.entry!.content);
          }
        } catch (_) {
          _quillController = QuillController.basic();
          _quillController.document.insert(0, widget.entry!.content);
        }
      }
    }
  }

  @override
  void dispose() {
    _quillController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final path = await _mediaService.pickImage(source: source);
    if (path != null) {
      setState(() => _mediaPaths.add(path));
    }
  }

  Future<void> _save() async {
    final content = jsonEncode(_quillController.document.toDelta().toJson());
    final now = DateTime.now();

    final entry = JournalEntry(
      id: widget.entry?.id,
      title: '',
      content: content,
      mediaPaths: _mediaPaths,
      tags: _tags,
      date: widget.entry?.date ??
          (widget.entryDate != null
              ? DateTime(widget.entryDate!.year, widget.entryDate!.month, widget.entryDate!.day, now.hour, now.minute, now.second)
              : now),
      updatedAt: now,
    );

    final journal = context.read<JournalProvider>();
    if (!entry.hasTextContent && _mediaPaths.isEmpty) {
      if (widget.entry != null) {
        await journal.deleteEntry(widget.entry!.id!);
      }
      return;
    }
    if (widget.entry != null) {
      await journal.updateEntry(entry);
    } else {
      await journal.addEntry(entry);
    }
  }

  void _addTag() {
    final tag = _tagInputController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagInputController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) return;
        await _save();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(DateFormat.yMMMMd().format(
              widget.entry?.date ?? widget.entryDate ?? DateTime.now())),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_mediaPaths.isNotEmpty) ...[
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _mediaPaths.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_mediaPaths[index]),
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => setState(() => _mediaPaths.removeAt(index)),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
              QuillSimpleToolbar(
                controller: _quillController,
                config: const QuillSimpleToolbarConfig(
                  showBoldButton: true,
                  showItalicButton: true,
                  showUnderLineButton: true,
                  showStrikeThrough: false,
                  showInlineCode: false,
                  showListBullets: true,
                  showListNumbers: true,
                  showAlignmentButtons: false,
                  showLink: false,
                  showSearchButton: false,
                  showFontFamily: false,
                  showFontSize: false,
                  showColorButton: false,
                  showBackgroundColorButton: false,
                  showClearFormat: false,
                  showCodeBlock: false,
                  showIndent: false,
                  showSuperscript: false,
                  showSubscript: false,
                  showDirection: false,
                  showDividers: false,
                ),
              ),
              SizedBox(
                height: 200,
                child: QuillEditor.basic(
                  controller: _quillController,
                  config: QuillEditorConfig(
                    placeholder: 'Write your thoughts...',
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const Divider(),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ..._tags.map((tag) => TagChip(
                    name: tag,
                    selected: true,
                    onDelete: () => setState(() => _tags.remove(tag)),
                  )),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _tagInputController,
                      decoration: const InputDecoration(
                        hintText: 'Add tag...',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      style: const TextStyle(fontSize: 14),
                      onSubmitted: (_) => _addTag(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo, size: 18),
                    label: const Text('Gallery'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('Camera'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
