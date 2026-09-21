import 'package:flutter/material.dart';

/// Lets a screen notice when it becomes visible again after a pushed route
/// on top of it is popped (e.g. the Sportbuddys hub refreshing after the
/// user swipes through candidates or views a profile and comes back).
final routeObserver = RouteObserver<PageRoute<void>>();
