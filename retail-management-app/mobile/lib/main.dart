import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'dash_board_screen.dart';
import 'login_screen.dart';
import 'schedule_screen.dart';
import 'theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Retail365 Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        primaryColor: AppColors.primaryOrange,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/main': (context) => const MainShellScreen(),
      },
    );
  }
}

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({Key? key}) : super(key: key);

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  // Mặc định mở Tab 0 (Bảng Phân Ca) ngay khi đăng nhập
  int _currentIndex = 0;

  // Thứ tự các màn hình tương ứng từ trái sang phải
  final List<Widget> _screens = const [
    ScheduleScreen(),    // Tab 0: Bảng Phân Ca (Màn hình đầu tiên)
    DashboardQRScreen(), // Tab 1: Chấm Công / QR
    HomeScreen(),        // Tab 2: Profile / Cá Nhân
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppColors.primaryOrange,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Phân Ca Làm',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner_outlined),
            activeIcon: Icon(Icons.qr_code_scanner),
            label: 'Chấm Công',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Cá Nhân',
          ),
        ],
      ),
    );
  }
}