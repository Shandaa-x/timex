import 'package:flutter/material.dart';
import 'package:timex/widgets/custom_drawer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/home_app_bar.dart';
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
      // Fetch news from the public 'news' collection only
      final newsSnapshot = await _firestore.collection('news').orderBy('publishedAt', descending: true).get();
      List<Map<String, dynamic>> allNews = [];
      for (var doc in newsSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        allNews.add(data);
      }
      setState(() {
        _newsList = allNews;
      });
      debugPrint('Loaded ${allNews.length} news items');
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
        currentScreen: DrawerScreenType.home,
        onNavigateToTab: widget.onNavigateToTab,
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: CustomScrollView(
          slivers: [
            // App Bar
            const HomeAppBar(),

            // Content
            SliverPadding(
              padding: const EdgeInsets.all(15),
              sliver: _isLoading
                  ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
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
                            QuickActionsGrid(onNavigateToTab: widget.onNavigateToTab),
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
