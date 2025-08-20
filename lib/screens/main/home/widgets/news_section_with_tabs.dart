import 'package:flutter/material.dart';
import 'news_list.dart';

class NewsSectionWithTabs extends StatefulWidget {
  final List<Map<String, dynamic>> newsList;

  const NewsSectionWithTabs({
    super.key,
    required this.newsList,
  });

  @override
  State<NewsSectionWithTabs> createState() => _NewsSectionWithTabsState();
}

class _NewsSectionWithTabsState extends State<NewsSectionWithTabs>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Business',
    'Technology',
    'Health',
    'Sports',
    'Entertainment',
    'Politics',
    'Science',
    'Education',
    'Travel',
    'Food',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedCategory = _categories[_tabController.index];
        });
      }
    });
  }

  List<Map<String, dynamic>> get _filteredNews {
    if (_selectedCategory == 'All') {
      return widget.newsList;
    }
    return widget.newsList
        .where((news) => news['category'] == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        const Text(
          'Мэдээ мэдээлэл',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        
        // Category Tabs
        Container(
          height: 40,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: const Color(0xFF2D5A27),
            labelColor: const Color(0xFF2D5A27),
            unselectedLabelColor: Colors.grey[600],
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            tabs: _categories.map((category) {
              return Tab(
                text: category == 'All' ? 'Бүгд' : category,
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        
        // News List
        NewsList(newsList: _filteredNews),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
