import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_service.dart';
import '../auth/biometric_service.dart';
import 'meetings_screen.dart';
import 'links_screen.dart';
import 'passwords_screen.dart';
import 'notes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  final BiometricService _bio = BiometricService();

  final _titles = const ['Meetings', 'Links', 'Passwords', 'Notes'];

  late final List<Widget> _pages = const [
    MeetingsScreen(),
    LinksScreen(),
    PasswordsScreen(),
    NotesScreen(),
  ];

  Future<void> _onTabTapped(int i) async {
    // Gate Passwords (2) and Notes (3) behind biometric auth on every tap.
    if (i == 2 || i == 3) {
      final ok = await _bio.authenticate(
        reason: 'Unlock ${_titles[i].toLowerCase()}',
      );
      if (!ok) return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => context.read<AuthService>().logout(),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Meetings'),
          BottomNavigationBarItem(icon: Icon(Icons.link), label: 'Links'),
          BottomNavigationBarItem(icon: Icon(Icons.vpn_key), label: 'Passwords'),
          BottomNavigationBarItem(icon: Icon(Icons.note), label: 'Notes'),
        ],
      ),
    );
  }
}
