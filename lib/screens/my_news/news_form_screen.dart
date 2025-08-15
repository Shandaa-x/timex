import 'package:flutter/material.dart';
import '../../models/news_model.dart';
import '../../services/news_service.dart';

class NewsFormScreen extends StatefulWidget {
  final NewsModel? news; // null for create, non-null for edit

  const NewsFormScreen({super.key, this.news});

  @override
  State<NewsFormScreen> createState() => _NewsFormScreenState();
}

class _NewsFormScreenState extends State<NewsFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _readingTimeController = TextEditingController();
  final NewsService _newsService = NewsService();
  bool _isLoading = false;
  bool _isPublished = false;

  @override
  void initState() {
    super.initState();
    if (widget.news != null) {
      _titleController.text = widget.news!.title;
      _contentController.text = widget.news!.content;
      _categoryController.text = widget.news!.category;
      _descriptionController.text = widget.news!.description;
      _readingTimeController.text = widget.news!.readingTime;
      _isPublished = widget.news!.isPublished;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _readingTimeController.dispose();
    super.dispose();
  }

  Future<void> _saveNews() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    bool success;
    if (widget.news == null) {
      // Create new news
      final newsId = await _newsService.createNews(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        category: _categoryController.text.trim().isNotEmpty ? _categoryController.text.trim() : null,
        description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        readingTime: _readingTimeController.text.trim().isNotEmpty ? _readingTimeController.text.trim() : null,
        isPublished: _isPublished,
      );
      success = newsId != null;
    } else {
      // Update existing news
      success = await _newsService.updateNews(
        newsId: widget.news!.id!,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        category: _categoryController.text.trim().isNotEmpty ? _categoryController.text.trim() : null,
        description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        readingTime: _readingTimeController.text.trim().isNotEmpty ? _readingTimeController.text.trim() : null,
        isPublished: _isPublished,
      );
    }

    setState(() => _isLoading = false);

    if (success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.news == null ? 'Мэдээ амжилттай нэмэгдлээ' : 'Мэдээ амжилттай засагдлаа'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Алдаа гарлаа. Дахин оролдоно уу'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.news == null ? 'Мэдээ нэмэх' : 'Мэдээ засах'),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveNews,
              child: const Text(
                'Хадгалах',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Гарчиг',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Гарчиг оруулна уу';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Ангилал (заавал биш)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Товч тайлбар (заавал биш)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _readingTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Унших хугацаа (жнь: 5 минут)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _isPublished,
                          onChanged: (value) {
                            setState(() {
                              _isPublished = value ?? false;
                            });
                          },
                        ),
                        const Text('Нийтлэх'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _contentController,
                        decoration: const InputDecoration(
                          labelText: 'Агуулга',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.article),
                          alignLabelWithHint: true,
                        ),
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Агуулга оруулна уу';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveNews,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(widget.news == null ? 'Мэдээ нэмэх' : 'Мэдээ засах'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
