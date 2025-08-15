import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timex/screens/home/widgets/custom_sliver_appbar.dart';
import '../../models/news_model.dart';
import '../../services/news_service.dart';
import 'news_form_screen.dart';

class MyNewsScreen extends StatefulWidget {
  const MyNewsScreen({super.key});

  @override
  State<MyNewsScreen> createState() => _MyNewsScreenState();
}

class _MyNewsScreenState extends State<MyNewsScreen> {
  final NewsService _newsService = NewsService();
  DateTime _selectedMonth = DateTime.now();
  DateTime? _filterMonth;

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      _filterMonth = _selectedMonth;
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      _filterMonth = _selectedMonth;
    });
  }

  void _clearFilter() {
    setState(() {
      _filterMonth = null;
      _selectedMonth = DateTime.now();
    });
  }

  Future<void> _deleteNews(NewsModel news) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Мэдээ устгах'),
        content: Text('Та "${news.title}" мэдээг устгахдаа итгэлтэй байна уу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Болих'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Устгах'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _newsService.deleteNews(news.id!);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Мэдээ амжилттай устгагдлаа'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Мэдээ устгахад алдаа гарлаа'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showNewsOptions(NewsModel news) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.blue),
            title: const Text('Засах'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NewsFormScreen(news: news),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Устгах'),
            onTap: () {
              Navigator.pop(context);
              _deleteNews(news);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CustomSliverAppBar(
            title: 'Миний мэдээ',
            gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Filter Section
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_list, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        const Text(
                          'Шүүлтүүр:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        // Month filter with arrow icons
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: _previousMonth,
                                icon: const Icon(Icons.arrow_left, color: Color(0xFF10B981)),
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  _filterMonth != null
                                      ? DateFormat('yyyy/MM').format(_selectedMonth)
                                      : 'Бүгд',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                              IconButton(
                                onPressed: _nextMonth,
                                icon: const Icon(Icons.arrow_right, color: Color(0xFF10B981)),
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_filterMonth != null)
                          TextButton(
                            onPressed: _clearFilter,
                            child: const Text('Цэвэрлэх', style: TextStyle(color: Color(0xFF10B981))),
                          ),
                      ],
                    ),
                  ),
                  // const SizedBox(height: 16),
                  // // Add News Button
                  // SizedBox(
                  //   width: double.infinity,
                  //   child: ElevatedButton.icon(
                  //     onPressed: () {
                  //       Navigator.push(
                  //         context,
                  //         MaterialPageRoute(
                  //           builder: (context) => const NewsFormScreen(),
                  //         ),
                  //       );
                  //     },
                  //     icon: const Icon(Icons.add),
                  //     label: const Text('Шинэ мэдээ нэмэх'),
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: const Color(0xFF10B981),
                  //       foregroundColor: Colors.white,
                  //       padding: const EdgeInsets.symmetric(vertical: 12),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
          // News List
          StreamBuilder<List<NewsModel>>(
            stream: _newsService.getUserNews(filterMonth: _filterMonth),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Icon(Icons.error, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('Алдаа гарлаа: ${snapshot.error}'),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final newsList = snapshot.data ?? [];

              if (newsList.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.article_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _filterMonth != null
                                ? 'Энэ сард мэдээ байхгүй байна'
                                : 'Танд мэдээ байхгүй байна',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Эхний мэдээгээ нэмээрэй!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final news = newsList[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                news.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (news.category.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  news.category,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            if (news.description.isNotEmpty) ...[
                              Text(
                                news.description,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              news.content,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (!news.isPublished) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Ноорог',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('yyyy/MM/dd HH:mm').format(news.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                if (news.readingTime.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Text(
                                    news.readingTime,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                                if (news.likes > 0) ...[
                                  const SizedBox(width: 12),
                                  Icon(Icons.favorite, size: 14, color: Colors.red[400]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${news.likes}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                                if (news.comments > 0) ...[
                                  const SizedBox(width: 12),
                                  Icon(Icons.comment, size: 14, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${news.comments}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                                if (news.updatedAt != news.createdAt) ...[
                                  const SizedBox(width: 12),
                                  Icon(Icons.edit, size: 14, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Засагдсан',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () => _showNewsOptions(news),
                        ),
                        onTap: () => _showNewsOptions(news),
                      ),
                    );
                  },
                  childCount: newsList.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}