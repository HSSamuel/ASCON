import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart'; 
import 'screens/events_screen.dart';
import 'screens/updates_screen.dart';
import 'screens/directory_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/about_screen.dart';
import 'screens/polls_screen.dart';
import 'screens/notification_permission_screen.dart'; 
import 'screens/call_screen.dart'; 
import 'screens/notifications_screen.dart';

// ✅ Global Keys used for Context-less Navigation
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> homeNavKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> eventsNavKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> updatesNavKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> directoryNavKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> profileNavKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    
    GoRoute(
      path: '/notification_permission',
      builder: (context, state) {
        final nextPath = state.extra as String? ?? '/login';
        return NotificationPermissionScreen(nextPath: nextPath);
      },
    ),

    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),

    GoRoute(
      path: '/notifications',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const NotificationsScreen(),
    ),

    // Shell Route Wraps the Bottom Navigation
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return HomeScreen(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          navigatorKey: homeNavKey, 
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const DashboardView(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: eventsNavKey, 
          routes: [
            GoRoute(
              path: '/events',
              builder: (context, state) => const EventsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: updatesNavKey, 
          routes: [
            GoRoute(
              path: '/updates',
              builder: (context, state) => const UpdatesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: directoryNavKey, 
          routes: [
            GoRoute(
              path: '/directory',
              builder: (context, state) => const DirectoryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: profileNavKey, 
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) {
                final name = state.extra as String?;
                return ProfileScreen(userName: name);
              },
            ),
          ],
        ),
      ],
    ),

    GoRoute(
      path: '/chat',
      parentNavigatorKey: rootNavigatorKey, 
      builder: (context, state) => const ChatListScreen(),
    ),
    
    GoRoute(
      path: '/chat_detail',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>;
        return ChatScreen( 
          conversationId: args['conversationId'],
          receiverId: args['receiverId'],
          receiverName: args['receiverName'],
          receiverProfilePic: args['receiverProfilePic'],
          isOnline: args['isOnline'] ?? false,
          lastSeen: args['lastSeen'],
          isGroup: args['isGroup'] ?? false,
          groupId: args['groupId'],
        );
      },
    ),

    GoRoute(
      path: '/about',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const AboutScreen(),
    ),
    
    GoRoute(
      path: '/polls',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const PollsScreen(),
    ),

    // ✅ FIXED CALL ROUTE (using 'args' consistently)
    GoRoute(
      path: '/call',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>;
        return CallScreen(
          remoteName: args['remoteName'] ?? "Unknown",
          remoteId: args['remoteId'] ?? "",
          channelName: args['channelName'] ?? "call_${DateTime.now().millisecondsSinceEpoch}",
          remoteAvatar: args['remoteAvatar'],
          isIncoming: args['isIncoming'] ?? false,
        );
      },
    ),
  ],
);