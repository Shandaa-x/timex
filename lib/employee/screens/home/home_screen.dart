import 'package:flutter/material.dart';
import 'package:timex/index.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  final String? userImage;

  const HomeScreen({
    super.key,
    required this.userName,
    this.userImage,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD4CBE8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Work Schedule Section
              _buildWorkScheduleSection(),

              // Cards Section
              _buildCardsSection(),

              // Banner Section
              _buildBannerSection(),

              // Page indicator
              _buildPageIndicator(),

              // Statistics Section
              _buildStatsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Row(
        children: [
          widget.userImage != null
              ? CircleAvatar(
            radius: 25,
            backgroundImage: NetworkImage(widget.userImage!),
            backgroundColor: const Color(0xFFC6BAE0),
          )
              : const CircleAvatar(
            backgroundColor: Color(0xFFC6BAE0),
            radius: 25,
            child: Icon(Icons.person_outline, color: Color(0xFF3f3f3f), size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                txt('Өглөөний мэнд', style: TxtStl.bodyText1(color: Colors.black, fontSize: 14)),
                txt(widget.userName, style: TxtStl.titleText2()),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.location_on_outlined, color: Colors.black),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkScheduleSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          txt(
            'Ажлын хуваарь',
            style: TxtStl.titleText2(),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCardsSection() {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [_buildScheduleCard('Өнөөдөр', 'Пү', true), const SizedBox(width: 12), _buildScheduleCard('08.01', 'Ба', false), const SizedBox(width: 12), _buildScheduleCard('08.02', 'Мя', false)],
      ),
    );
  }

  Widget _buildScheduleCard(String date, String day, bool isToday) {
    return Container(
      width: 150,
      decoration: BoxDecoration(color: const Color(0xFF3f3f3f), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                txt(
                  '$date $day',
                  style: TxtStl.bodyText1(color: isToday ? Colors.white : Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                txt(
                  '∞',
                  style: TxtStl.bodyText1(color: Color(0xFFFF5722), fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 4),
                txt('Чөлөөт хуваарь', style: TxtStl.bodyText1(color: Color(0xFFFF5722), fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerSection() {
    return Container(
      height: 200,
      margin: const EdgeInsets.all(20),
      child: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        children: [_buildBannerCard('Таны зар Timely аппын нүүр хуудсанд байршиж болно', 'ЭНД ДАРНА УУ', 'timely', const Color(0xFF1E3A8A)), _buildBannerCard('Бичгийн соёлтой залуу үеийг хамтдаа бүтээцгээгээ', '', 'Bolor duran', Colors.white, isSecondBanner: true)],
      ),
    );
  }

  Widget _buildBannerCard(String title, String buttonText, String brand, Color bgColor, {bool isSecondBanner = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSecondBanner)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                        child: txt('✓ Bolor duran', style: TxtStl.bodyText1(color: Colors.white, fontSize: 12)),
                      ),
                      const Spacer(),
                      txt('490007', style: TxtStl.bodyText1(fontSize: 12)),
                    ],
                  ),
                const SizedBox(height: 12),
                txt(
                  title,
                  maxLines: 3,
                  style: TxtStl.bodyText1(color: isSecondBanner ? Colors.black : Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (!isSecondBanner) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: txt(buttonText, style: TxtStl.bodyText1(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
          if (isSecondBanner)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(50), bottomRight: Radius.circular(16)),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 40),
              ),
            ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.visibility, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  txt(isSecondBanner ? '29951' : '43265', style: TxtStl.bodyText1(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: _currentPage == 0 ? const Color(0xFFFF5722) : Colors.grey[300], shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: _currentPage == 1 ? const Color(0xFFFF5722) : Colors.grey[300], shape: BoxShape.circle),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    final List<Map<String, dynamic>> statsData = [
      {
        'icon': Icons.calendar_today,
        'title': 'Цаг бүртгэл',
        'value': '147 ц 57 м',
        'color': Colors.orange,
        'hasArrow': true,
        'bgColor': const Color(0xFFCDC2E4),
        'iconBgColor': const Color(0xFFFFA726),
        'onTap': () {
          // TODO: Handle attendance tracking navigation
          Navigator.pushNamed(context, Routes.timeTrack);
        }
      },
      {
        'icon': Icons.search,
        'title': 'Цагийн хүсэлт',
        'value': '0',
        'color': Colors.orange,
        'hasArrow': false,
        'bgColor': const Color(0xFFCDC2E4),
        'iconBgColor': const Color(0xFF42A5F5),
        'onTap': () {
          // TODO: Handle time request screen
          debugPrint('Tapped: Цагийн хүсэлт');
        }
      },
      {
        'icon': Icons.trending_up,
        'title': 'Цалин',
        'value': '',
        'color': Colors.green,
        'hasArrow': false,
        'bgColor': const Color(0xFFCDC2E4),
        'iconBgColor': const Color(0xFFFFA726),
        'onTap': () {
          // TODO: Handle salary screen
          debugPrint('Tapped: Цалин');
        }
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          txt(
            'Энэ сард',
            style: TxtStl.bodyText1(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 20),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: statsData.length,
            itemBuilder: (context, index) {
              final item = statsData[index];

              return GestureDetector(
                onTap: item['onTap'],
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: item['bgColor'],
                      borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color: item['iconBgColor'],
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(item['icon'],
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            txt(
                              item['title'],
                              style: TxtStl.bodyText1(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black),
                            ),
                            if (item['value'].isNotEmpty)
                              txt(
                                item['value'],
                                style: TxtStl.bodyText1(
                                    fontSize: 14, color: Colors.grey[600]),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            txt(
                              item['value'] == '0'
                                  ? '0'
                                  : (item['value'].isEmpty
                                  ? '+2.11%'
                                  : '+0.28%'),
                              style: TxtStl.bodyText1(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: item['color']),
                            ),
                            const SizedBox(width: 4),
                            if (item['hasArrow'] || item['value'] != '0')
                              Icon(Icons.arrow_upward,
                                  size: 12, color: item['color']),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String title, String value, Color iconColor, {bool hasArrow = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const Spacer(),
              if (hasArrow) Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
          const SizedBox(height: 8),
          txt(title, style: TxtStl.bodyText1(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 4),
          txt(
            value,
            style: TxtStl.bodyText1(color: value == '0' ? Colors.grey : (value.contains('Илгээгээгүй') ? Colors.blue : Colors.orange), fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
