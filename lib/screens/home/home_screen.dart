import 'package:flutter/material.dart';
import 'package:timex/screens/home/widgets/custom_sliver_appbar.dart';
import 'package:timex/widgets/custom_drawer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/quick_actions_grid.dart';
import 'widgets/news_section_with_tabs.dart';
import 'widgets/add_news_bottom_sheet.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  List<Map<String, dynamic>> _newsList = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _loadNews();
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      setState(() {
        _errorMessage = 'Мэдээлэл ачаалахад алдаа гарлаа: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNews() async {
    try {
      // Fetch news from both collections simultaneously
      final List<Future<QuerySnapshot>> futures = [
        _firestore
            .collection('news')
            .orderBy('publishedAt', descending: true)
            .get(),
        _firestore
            .collection('_news')
            .orderBy('publishedAt', descending: true)
            .get(),
      ];

      final results = await Future.wait(futures);
      final newsSnapshot = results[0];
      final _newsSnapshot = results[1];

      List<Map<String, dynamic>> allNews = [];

      // Process news from 'news' collection
      for (var doc in newsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['source_collection'] =
            'news'; // Add identifier for source collection
        allNews.add(data);
      }

      // Process news from '_news' collection
      for (var doc in _newsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['source_collection'] =
            '_news'; // Add identifier for source collection
        allNews.add(data);
      }

      // Sort all news by publishedAt in descending order (newest first)
      allNews.sort((a, b) {
        final aTime =
            (a['publishedAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
        final bTime =
            (b['publishedAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      setState(() {
        _newsList = allNews;
      });
      debugPrint(
        'Loaded ${allNews.length} news items (${newsSnapshot.docs.length} from news, ${_newsSnapshot.docs.length} from _news)',
      );
    } catch (e) {
      debugPrint('Error loading news: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: CustomDrawer(
        onNavigateToTab: widget.onNavigateToTab,
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: CustomScrollView(
          slivers: [
            // App Bar
            CustomSliverAppBar(
              leftIcon: Icons.home,
              onLeftTap: () => print("Home tapped"),
              rightIcon: Icons.settings_outlined,
              onRightTap: () => print("Settings tapped"),
              subtitle: "Тавтай морил!",
              title: "TimeX Dashboard",
              gradientColors: [
                const Color(0xFF2D5A27),
                const Color(0xFF4A8B3A),
              ], // Gradient
            ),

            // Content
            SliverPadding(
              padding: const EdgeInsets.all(15),
              sliver: _isLoading
                  ? const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _errorMessage != null
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error,
                              size: 64,
                              color: Color(0xFFEF4444),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadDashboardData,
                              child: const Text('Дахин оролдох'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildListDelegate([
                        QuickActionsGrid(
                          onNavigateToTab: widget.onNavigateToTab,
                        ),
                        const SizedBox(height: 20),
                        // News Section with Tabs
                        NewsSectionWithTabs(newsList: _newsList),
                        const SizedBox(height: 32),
                      ]),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddNewsBottomSheet,
        backgroundColor: const Color(0xFF2D5A27),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddNewsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddNewsBottomSheet(
        onNewsAdded: () {
          _loadDashboardData(); // Refresh the news list
        },
      ),
    );
  }
}
