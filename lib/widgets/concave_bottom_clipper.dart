import 'package:flutter/material.dart';

/// Custom clipper that creates a convex (downward) curve at the bottom
class ConcaveBottomClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // Start from top-left corner
    path.lineTo(0, 0);

    // Draw line to top-right corner
    path.lineTo(size.width, 0);

    // Draw line down the right side (not to full height, leave space for curve)
    path.lineTo(size.width, size.height - 40);

    // Create quadratic bezier curve that curves DOWNWARD in the middle
    // Control point BELOW the edge creates convex (downward) curve
    path.quadraticBezierTo(
      size.width / 2,        // Control point X (center)
      size.height + 20,      // Control point Y (BELOW bottom - creates downward curve)
      0,                     // End point X (left side)
      size.height - 40,      // End point Y (same as right side)
    );

    // Close the path
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
