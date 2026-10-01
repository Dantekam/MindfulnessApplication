import 'package:flutter/material.dart';
import 'package:uncw_app/screens/exercises_screen.dart';
import 'package:uncw_app/screens/journal_screen.dart';
import 'package:uncw_app/screens/progress_screen.dart';

class NavigationMenu extends StatefulWidget {
  const NavigationMenu({super.key});

  @override
  State<NavigationMenu> createState() => _NavigationMenuState();
}

class _NavigationMenuState extends State<NavigationMenu> {
  int _selectedIndex = 1; // Default to 'Home' (ProgressScreen)
  String currentJournalId = ''; // Initially set to an empty string

  // Method to navigate to the specific journal screen with dynamic journalId
  void navigateToJournalScreen(String journalId) {
    setState(() {
      currentJournalId = journalId;
      _selectedIndex = 2; // Switch to the journal tab
    });
  }

  void navigateBar(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List<Widget> screens = [
    ExercisesScreen(),
    ProgressScreen(),
    JournalScreen(), // Default empty journalId until selected
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _selectedIndex == 2
              ? JournalScreen(
                //journalId: currentJournalId,
              ) // Pass dynamic journalId
              : screens[_selectedIndex],
      bottomNavigationBar: Container(
        height: 80, // Increase the height of the bottom navigation bar
        decoration: BoxDecoration(
          color: Color.fromARGB(255, 46, 64, 79),
          boxShadow: [
            BoxShadow(
              spreadRadius: 1,
              blurRadius: 10,
              offset: Offset(0, -2),
              color: Colors.white,
            ),
          ], // Add shadow to the bar
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Exercise Tab
            GestureDetector(
              onTap: () => navigateBar(0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.spa_outlined,
                    color:
                        _selectedIndex == 0
                            ? Colors.white
                            : Colors.white70, // White for selected
                  ),
                  Text(
                    'Exercises',
                    style: TextStyle(
                      color:
                          _selectedIndex == 0 ? Colors.white : Colors.white70,
                    ),
                  ),
                  if (_selectedIndex == 0)
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      height: 2,
                      width: 20,
                      color:
                          Colors
                              .white, // Add a small underline for selected tab
                    ),
                ],
              ),
            ),
            // Home Tab
            GestureDetector(
              onTap: () => navigateBar(1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.home,
                    color:
                        _selectedIndex == 1
                            ? Colors.white
                            : Colors.white70, // White for selected
                  ),
                  Text(
                    'Home',
                    style: TextStyle(
                      color:
                          _selectedIndex == 1 ? Colors.white : Colors.white70,
                    ),
                  ),
                  if (_selectedIndex == 1)
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      height: 2,
                      width: 20,
                      color:
                          Colors
                              .white, // Add a small underline for selected tab
                    ),
                ],
              ),
            ),
            // Journal Tab
            GestureDetector(
              onTap: () => navigateBar(2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_stories,
                    color:
                        _selectedIndex == 2
                            ? Colors.white
                            : Colors.white70, // White for selected
                  ),
                  Text(
                    'Journal',
                    style: TextStyle(
                      color:
                          _selectedIndex == 2 ? Colors.white : Colors.white70,
                    ),
                  ),
                  if (_selectedIndex == 2)
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      height: 2,
                      width: 20,
                      color:
                          Colors
                              .white, // Add a small underline for selected tab
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
