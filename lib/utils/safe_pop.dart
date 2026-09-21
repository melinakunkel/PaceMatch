import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Pops the current route if there's something to pop back to; otherwise
/// navigates to [fallback]. Guards screens registered as a top-level
/// [GoRoute] (directly URL-addressable) against a reload or bookmark visit
/// leaving nothing on the stack, which makes a plain `context.pop()`
/// silently do nothing.
void safeBack(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}
