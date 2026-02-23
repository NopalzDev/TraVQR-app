import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import '/constants/colors.dart';
import '/utils/account_number_generator.dart';
import '/screens/confirmation_page.dart';

class QrPaymentPage extends StatefulWidget {
  const QrPaymentPage({super.key});

  @override
  State<QrPaymentPage> createState() => _QrPaymentPageState();
}

class _QrPaymentPageState extends State<QrPaymentPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'QR Payment',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryGreen,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        //Gradient Wrapper
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryGreen, secondaryGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.qr_code_rounded),
              text: 'My QR Code',
            ),
            Tab(
              icon: Icon(Icons.qr_code_scanner_rounded),
              text: 'Scan QR',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          GenerateQrTab(),
          ScanQrTab(),
        ],
      ),
    );
  }
}

// Tab 1: Generate QR Code (Simplified - No amount needed)
class GenerateQrTab extends StatefulWidget {
  const GenerateQrTab({super.key});

  @override
  State<GenerateQrTab> createState() => _GenerateQrTabState();
}

class _GenerateQrTabState extends State<GenerateQrTab> {
  String? _qrData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateQrCode();
  }

  Future<Map<String, dynamic>?> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return doc.data();
  }

  void _generateQrCode() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final userData = await _getUserData();
      if (userData == null) throw Exception('User data not found');

      // Create QR data with only user information (no amount)
      final qrPayload = {
        'userId': user.uid,
        'userName': userData['name'] ?? 'User',
        'type': 'receive_payment',
      };

      setState(() {
        _qrData = jsonEncode(qrPayload);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _copyAccountNumber(String accountNumber) {
    Clipboard.setData(ClipboardData(text: accountNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account number copied!'),
        backgroundColor: primaryGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[100]!, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: primaryGreen)
            : SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    // Modern Header with Icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.qr_code_2_rounded,
                          size: 28,
                          color: Colors.black,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Your QR Code',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Show this to receive payment instantly',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Premium QR Card with Gradient Border
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Gradient border container
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [secondaryGreen, primaryGreen],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Container(
                              height: 350,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(19),
                              ),
                            ),
                          ),
                          // Overlaid content (name + QR code)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Name badge with purple gradient
                                FutureBuilder<Map<String, dynamic>?>(
                                  future: _getUserData(),
                                  builder: (context, snapshot) {
                                    final userName = snapshot.data?['name'] ?? 'User';
                                    final bool nameIsLong = userName.length > 20;
                                    final double verticalPadding = nameIsLong ? 15 : 10;

                                    return Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: verticalPadding,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [secondaryGreen, primaryGreen],
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        userName,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),
                                // QR code with purple gradient
                                _qrData != null
                                    ? ShaderMask(
                                        blendMode: BlendMode.srcIn,
                                        shaderCallback: (Rect bounds) {
                                          return const LinearGradient(
                                            colors: [secondaryGreen, primaryGreen],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ).createShader(bounds);
                                        },
                                        child: QrImageView(
                                          data: _qrData!,
                                          version: QrVersions.auto,
                                          size: 220.0,
                                          backgroundColor: Colors.transparent,
                                          eyeStyle: const QrEyeStyle(
                                            eyeShape: QrEyeShape.square,
                                            color: Colors.black,
                                          ),
                                          dataModuleStyle: const QrDataModuleStyle(
                                            dataModuleShape: QrDataModuleShape.square,
                                            color: Colors.black,
                                          ),
                                        ),
                                      )
                                    : const SizedBox(
                                        width: 220,
                                        height: 220,
                                        child: Center(child: Text('Unable to generate QR')),
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Account Number Card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: FutureBuilder<Map<String, dynamic>?>(
                        future: _getUserData(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SizedBox(
                              height: 50,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: primaryGreen,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }

                          final accountNumber = snapshot.data?['account_number'] ?? '';
                          final formattedAccountNumber = accountNumber.isNotEmpty
                              ? AccountNumberGenerator.format(accountNumber)
                              : 'xxxx-xxxx-xxxx';

                          return Row(
                            children: [
                              // Account icon
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: secondaryGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.credit_card,
                                  color: secondaryGreen,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Account number text
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Account Number',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formattedAccountNumber,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Copy button
                              IconButton(
                                onPressed: () => _copyAccountNumber(accountNumber),
                                icon: const Icon(Icons.copy_rounded),
                                color: secondaryGreen,
                                iconSize: 24,
                                tooltip: 'Copy account number',
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }
}

// Tab 2: Scan QR Code with OCR Verification
class ScanQrTab extends StatefulWidget {
  const ScanQrTab({super.key});

  @override
  State<ScanQrTab> createState() => _ScanQrTabState();
}

// Spatial positioning data structures
class SpatialBounds {
  final Rect boundingBox;
  final double centerX;
  final double centerY;

  SpatialBounds(this.boundingBox)
      : centerX = (boundingBox.left + boundingBox.right) / 2,
        centerY = (boundingBox.top + boundingBox.bottom) / 2;

  double get top => boundingBox.top;
  double get bottom => boundingBox.bottom;
  double get left => boundingBox.left;
  double get right => boundingBox.right;
  double get width => boundingBox.width;
  double get height => boundingBox.height;
}

class TextCandidate {
  final String text;
  final SpatialBounds bounds;
  final double confidence;

  TextCandidate({
    required this.text,
    required this.bounds,
    required this.confidence,
  });
}

class _ScanQrTabState extends State<ScanQrTab> {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isProcessing = false;

  // ML Kit instances
  final _textRecognizer = TextRecognizer();
  final _barcodeScanner = BarcodeScanner();

  // Spatial positioning configuration
  static const double verticalSearchDistance = 200.0; // pixels above QR (increased for multi-line names)
  static const double horizontalAlignmentTolerance = 100.0; // horizontal tolerance
  static const double minNameConfidenceScore = 0.5; // minimum confidence (lowered to catch both lines)
  static const int minNameLength = 2;
  static const int maxNameLength = 100; // increased to handle long combined names

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // Get available cameras
      final cameras = await availableCameras();
      final camera = cameras.first; // Use back camera

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera initialization error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _captureAndVerify() async {
    if (_isProcessing || _cameraController == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Capture image
      final XFile imageFile = await _cameraController!.takePicture();
      final InputImage inputImage = InputImage.fromFilePath(imageFile.path);

      // 2. Extract text using OCR
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      // 3. Detect QR code
      final List<Barcode> barcodes = await _barcodeScanner.processImage(inputImage);

      if (barcodes.isEmpty) {
        throw Exception('No QR code detected in image');
      }

      final qrData = barcodes.first.rawValue;
      if (qrData == null) {
        throw Exception('QR code is empty');
      }

      // 4. Parse QR code data
      final data = jsonDecode(qrData) as Map<String, dynamic>;
      final qrName = (data['userName'] as String).toLowerCase().trim();
      final receiverUserId = data['userId'] as String;

      // 5. Extract printed name from OCR results using spatial positioning
      String? printedName = _extractNameFromTextSpatial(recognizedText, barcodes.first);

      if (printedName == null) {
        throw Exception(
          'Could not detect printed name above QR code.\n\n'
          'Please ensure:\n'
          '• Name is clearly visible\n'
          '• Name is positioned directly above QR code\n'
          '• Good lighting conditions'
        );
      }

      // 6. Compare names
      if (printedName.toLowerCase().trim() != qrName) {
        throw Exception(
          'Name mismatch!\nPrinted: $printedName\nQR: ${data['userName']}\n\nPossible fraud attempt!'
        );
      }

      // 7. Verify not paying self
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');
      if (currentUser.uid == receiverUserId) {
        throw Exception('Cannot pay yourself');
      }

      // 8. Navigate to payment confirmation
      if (!mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentAmountEntryScreen(
            receiverUserId: receiverUserId,
            receiverUserName: data['userName'],
          ),
        ),
      );

      if (result == true && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // ========== SPATIAL POSITIONING METHODS ==========

  /// Defines the spatial region of interest for name detection
  /// Returns a Rect representing the search area above the QR code
  Rect _calculateNameSearchROI(SpatialBounds qrBounds) {
    // ROI is a rectangular region above the QR code
    // Width: Same as QR code width + horizontal tolerance on each side
    // Height: verticalSearchDistance pixels above QR code

    final roiLeft = qrBounds.left - horizontalAlignmentTolerance;
    final roiRight = qrBounds.right + horizontalAlignmentTolerance;
    final roiTop = qrBounds.top - verticalSearchDistance;
    final roiBottom = qrBounds.top; // Top edge of QR code

    return Rect.fromLTRB(
      roiLeft.clamp(0.0, double.infinity),
      roiTop.clamp(0.0, double.infinity),
      roiRight,
      roiBottom,
    );
  }

  /// Checks if a text block is positioned above the QR code
  /// Returns true if the text's bottom edge is above the QR's top edge
  bool _isTextAboveQrCode(SpatialBounds textBounds, SpatialBounds qrBounds) {
    // Text must be entirely above the QR code
    // With a small buffer to account for slight overlaps
    const double overlapBuffer = 10.0;

    return textBounds.bottom <= (qrBounds.top + overlapBuffer);
  }

  /// Checks if a text block falls within the defined ROI
  /// Returns true if the text's center point is inside the ROI
  bool _isTextInROI(SpatialBounds textBounds, Rect roi) {
    // Check if the center point of the text is within ROI
    return roi.contains(Offset(textBounds.centerX, textBounds.centerY));
  }

  /// Calculates how well a text block is horizontally aligned with QR code
  /// Returns a score between 0.0 (poor alignment) and 1.0 (perfect alignment)
  double _calculateHorizontalAlignmentScore(
    SpatialBounds textBounds,
    SpatialBounds qrBounds,
  ) {
    // Perfect alignment: text center X matches QR center X
    final centerXDifference = (textBounds.centerX - qrBounds.centerX).abs();

    // Normalize the difference
    // 0 difference = 1.0 score
    // horizontalAlignmentTolerance difference = 0.0 score
    final score = 1.0 - (centerXDifference / horizontalAlignmentTolerance);

    return score.clamp(0.0, 1.0);
  }

  /// Calculates how close a text block is to the QR code vertically
  /// Returns a score between 0.0 (far) and 1.0 (close)
  double _calculateVerticalProximityScore(
    SpatialBounds textBounds,
    SpatialBounds qrBounds,
  ) {
    // Calculate distance from text bottom to QR top
    final verticalDistance = (qrBounds.top - textBounds.bottom).abs();

    // Normalize: closer text gets higher score
    // 0 distance (touching) = 1.0 score
    // verticalSearchDistance = 0.0 score
    final score = 1.0 - (verticalDistance / verticalSearchDistance);

    return score.clamp(0.0, 1.0);
  }

  /// Calculates overall confidence score for a text candidate
  /// Combines horizontal alignment and vertical proximity
  double _calculateConfidenceScore(
    SpatialBounds textBounds,
    SpatialBounds qrBounds,
  ) {
    final horizontalScore = _calculateHorizontalAlignmentScore(textBounds, qrBounds);
    final verticalScore = _calculateVerticalProximityScore(textBounds, qrBounds);

    // Weighted average: horizontal alignment is more important (60%)
    const double horizontalWeight = 0.6;
    const double verticalWeight = 0.4;

    return (horizontalScore * horizontalWeight) + (verticalScore * verticalWeight);
  }

  // ========== ENHANCED NAME VALIDATION METHODS ==========

  /// Enhanced keyword filtering to exclude UI elements and common false positives
  bool _isLikelyUIText(String text) {
    final lowerText = text.toLowerCase().trim();

    // Expanded list of UI keywords to filter out
    final uiKeywords = [
      'scan', 'qr', 'code', 'pay', 'payment', 'camera', 'capture',
      'verify', 'confirm', 'cancel', 'back', 'next', 'submit',
      'account', 'balance', 'transaction', 'transfer', 'send',
      'receive', 'wallet', 'bank', 'card', 'tap', 'here',
      'position', 'frame', 'align', 'center', 'focus', 'your',
      'show', 'this', 'instant', 'number', 'copy',
    ];

    for (final keyword in uiKeywords) {
      if (lowerText.contains(keyword)) {
        return true;
      }
    }

    return false;
  }

  /// Detects if text is likely an account number
  /// Account numbers are formatted like "1234-5678-9012"
  bool _isLikelyAccountNumber(String text) {
    final cleaned = text.replaceAll(' ', '').replaceAll('-', '');

    // Check if it's mostly digits
    final digitCount = cleaned.replaceAll(RegExp(r'[^0-9]'), '').length;
    final totalLength = cleaned.length;

    // If more than 70% digits, likely an account number
    if (totalLength > 0 && (digitCount / totalLength) > 0.7) {
      return true;
    }

    // Check for common account number patterns
    if (RegExp(r'^\d{4}[-\s]?\d{4}[-\s]?\d{4}$').hasMatch(text)) {
      return true;
    }

    return false;
  }

  /// Validates if text matches expected name patterns
  /// Returns true if text looks like a valid name
  bool _isValidNamePattern(String text) {
    final cleaned = text.trim();

    // Length validation
    if (cleaned.length < minNameLength || cleaned.length > maxNameLength) {
      return false;
    }

    // Must contain at least one letter
    if (!RegExp(r'[a-zA-Z]').hasMatch(cleaned)) {
      return false;
    }

    // Should be primarily letters and spaces
    // Allow some special characters for names like "O'Brien", "Jean-Paul"
    final validNamePattern = RegExp(r"^[a-zA-Z\s\-'\.]+$");
    if (!validNamePattern.hasMatch(cleaned)) {
      return false;
    }

    // Should not be ALL CAPS (likely a header/label)
    // Unless it's a short name (2-3 chars)
    if (cleaned.length > 3 && cleaned == cleaned.toUpperCase()) {
      return false;
    }

    // Should not be a single character repeated
    if (RegExp(r'^(.)\1+$').hasMatch(cleaned)) {
      return false;
    }

    return true;
  }

  // ========== SPATIAL-AWARE NAME EXTRACTION ==========

  /// Extracts name from OCR text using spatial positioning
  /// Uses RecognizedText and Barcode objects for spatial analysis
  String? _extractNameFromTextSpatial(
    RecognizedText recognizedText,
    Barcode qrBarcode,
  ) {
    // 1. Get QR code spatial bounds
    final qrBoundingBox = qrBarcode.boundingBox;

    final qrBounds = SpatialBounds(qrBoundingBox);
    print('QR Bounds: top=${qrBounds.top}, bottom=${qrBounds.bottom}, left=${qrBounds.left}, right=${qrBounds.right}');

    // 2. Calculate region of interest
    final roi = _calculateNameSearchROI(qrBounds);
    print('ROI: top=${roi.top}, bottom=${roi.bottom}, left=${roi.left}, right=${roi.right}');

    // 3. Extract and filter text candidates
    final List<TextCandidate> candidates = [];
    print('Total text blocks: ${recognizedText.blocks.length}');

    for (final block in recognizedText.blocks) {
      final blockBounds = SpatialBounds(block.boundingBox);

      // Spatial filtering: must be above QR code and in ROI
      if (!_isTextAboveQrCode(blockBounds, qrBounds)) {
        continue;
      }

      if (!_isTextInROI(blockBounds, roi)) {
        continue;
      }

      // Process each line in the block for finer granularity
      for (final line in block.lines) {
        final lineText = line.text.trim();
        final lineBounds = SpatialBounds(line.boundingBox);

        print('  Checking line: "$lineText"');

        // Name Candidate Validation Section
        // ✅ = Success/Accepted
        // ❌ = Rejected/Failed
        // ⚖️ = Scoring/Evaluation

        // Content validation with detailed logging
        if (_isLikelyUIText(lineText)) {
          print('    ❌ Rejected: Likely UI text');
          continue;
        }

        if (_isLikelyAccountNumber(lineText)) {
          print('    ❌ Rejected: Likely account number');
          continue;
        }

        if (!_isValidNamePattern(lineText)) {
          print('    ❌ Rejected: Invalid name pattern');
          continue;
        }

        // Calculate confidence score
        final confidence = _calculateConfidenceScore(lineBounds, qrBounds);

        print('    ⚖️  Confidence score: ${confidence.toStringAsFixed(2)} (threshold: $minNameConfidenceScore)');

        // Only consider candidates above minimum confidence threshold
        if (confidence >= minNameConfidenceScore) {
          candidates.add(TextCandidate(
            text: lineText,  
            bounds: lineBounds,
            confidence: confidence,
          ));
          print('    ✅ Accepted as candidate');
        } else {
          print('    ❌ Rejected: Confidence too low');
        }
      }
    }

    // 4. Combine multi-line names
    final combinedCandidates = _combineMultiLineNames(candidates, qrBounds);

    // 5. Select best candidate
    if (combinedCandidates.isEmpty) {
      print('No valid name candidates found in ROI');
      return null;
    }

    // Sort by confidence score (highest first)
    combinedCandidates.sort((a, b) => b.confidence.compareTo(a.confidence));

    final bestCandidate = combinedCandidates.first;
    print('Selected name: "${bestCandidate.text}" (confidence: ${bestCandidate.confidence.toStringAsFixed(2)})');

    return bestCandidate.text;
  }

  /// Combines text lines that are vertically stacked (multi-line names)
  /// Returns a new list with single-line and combined multi-line candidates
  List<TextCandidate> _combineMultiLineNames(
    List<TextCandidate> candidates,
    SpatialBounds qrBounds,
  ) {
    if (candidates.isEmpty) return candidates;
    if (candidates.length == 1) return candidates;

    final List<TextCandidate> combined = [];
    final List<bool> used = List.filled(candidates.length, false);

    // Helper function to check if two candidates should be combined
    bool shouldCombine(TextCandidate a, TextCandidate b) {
      // Calculate vertical distance between the two candidates
      final gap1 = (b.bounds.top - a.bounds.bottom).abs();
      final gap2 = (a.bounds.top - b.bounds.bottom).abs();
      final verticalGap = gap1 < gap2 ? gap1 : gap2;

      // Increased threshold to 80 pixels for better multi-line detection
      final isVerticallyClose = verticalGap < 80.0;

      // Check horizontal alignment - centers should be roughly aligned
      final horizontalAlignment = (a.bounds.centerX - b.bounds.centerX).abs();
      final isHorizontallyAligned = horizontalAlignment < 120.0;

      return isVerticallyClose && isHorizontallyAligned;
    }

    // Build groups of related candidates
    for (int i = 0; i < candidates.length; i++) {
      if (used[i]) continue;

      final List<TextCandidate> group = [candidates[i]];
      used[i] = true;

      // Recursively find all related candidates
      bool foundMore = true;
      while (foundMore) {
        foundMore = false;

        for (int j = 0; j < candidates.length; j++) {
          if (used[j]) continue;

          // Check if this candidate should be grouped with any in the current group
          for (final member in group) {
            if (shouldCombine(member, candidates[j])) {
              group.add(candidates[j]);
              used[j] = true;
              foundMore = true;
              break;
            }
          }

          if (foundMore) break;
        }
      }

      // Sort group by vertical position (top to bottom)
      group.sort((a, b) => a.bounds.top.compareTo(b.bounds.top));

      // Combine text
      if (group.length > 1) {
        // Combine with space, handling potential extra spaces
        final combinedText = group.map((c) => c.text.trim()).join(' ');

        // Calculate combined bounding box
        final minLeft = group.map((c) => c.bounds.left).reduce((a, b) => a < b ? a : b);
        final minTop = group.map((c) => c.bounds.top).reduce((a, b) => a < b ? a : b);
        final maxRight = group.map((c) => c.bounds.right).reduce((a, b) => a > b ? a : b);
        final maxBottom = group.map((c) => c.bounds.bottom).reduce((a, b) => a > b ? a : b);

        final combinedBounds = SpatialBounds(
          Rect.fromLTRB(minLeft, minTop, maxRight, maxBottom),
        );

        // Recalculate confidence for combined text
        final confidence = _calculateConfidenceScore(combinedBounds, qrBounds);

        combined.add(TextCandidate(
          text: combinedText,
          bounds: combinedBounds,
          confidence: confidence,
        ));

        print('Combined multi-line name: "$combinedText" (${group.length} lines, confidence: ${confidence.toStringAsFixed(2)})');
      } else {
        // Single line, add as-is
        combined.add(group.first);
      }
    }

    return combined;
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _cameraController == null) {
      return const Center(
        child: CircularProgressIndicator(color: primaryGreen),
      );
    }

    return Stack(
      children: [
        // Full screen camera preview
        SizedBox.expand(
          child: CameraPreview(_cameraController!),
        ),

        // Visual positioning guide overlay
        Positioned.fill(
          child: CustomPaint(
            painter: QrScanGuide(),
          ),
        ),

        // Overlay UI
        Center(
          child: Column(
            children: [
              const Spacer(),

              // Capture button
              GestureDetector(
                onTap: _isProcessing ? null : _captureAndVerify,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isProcessing ? Colors.grey : Colors.white,
                    border: Border.all(color: primaryGreen, width: 4),
                  ),
                  child: _isProcessing
                      ? const Padding(
                          padding: EdgeInsets.all(15),
                          child: CircularProgressIndicator(
                            color: primaryGreen,
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt,
                          color: primaryGreen,
                          size: 35,
                        ),
                ),
              ),

              const SizedBox(height: 30),

              // Instruction container
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.center_focus_strong, color: primaryGreen, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Align name and QR in guide',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Name directly above QR code\n'
                      '• Keep both within guide boxes\n'
                      '• Ensure good lighting',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 50),
            ],
          ),
        ),

        // Processing overlay
        if (_isProcessing)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircularProgressIndicator(color: primaryGreen),
                      SizedBox(height: 20),
                      Text(
                        'Verifying QR code...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Visual guide overlay for QR scanning
class QrScanGuide extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final dashedPaint = Paint()
      ..color = primaryGreen.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Calculate guide rectangle in center
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final guideWidth = size.width * 0.7;
    final guideHeight = size.width * 0.7; // Square

    // QR code guide box
    final qrRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: guideWidth,
      height: guideHeight,
    );

    // Name region box (above QR)
    final nameRect = Rect.fromCenter(
      center: Offset(centerX, centerY - guideHeight * 0.7),
      width: guideWidth,
      height: guideHeight * 0.3,
    );

    // Draw QR guide
    canvas.drawRect(qrRect, paint);

    // Draw name region with dashed border
    _drawDashedRect(canvas, nameRect, dashedPaint);

    // Add labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // "Name Here" label
    textPainter.text = const TextSpan(
      text: 'Name Here',
      style: TextStyle(
        color: primaryGreen,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(centerX - textPainter.width / 2, nameRect.center.dy - textPainter.height / 2),
    );
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    const dashWidth = 10.0;
    const dashSpace = 5.0;

    // Top
    _drawDashedLine(canvas, rect.topLeft, rect.topRight, dashWidth, dashSpace, paint);
    // Right
    _drawDashedLine(canvas, rect.topRight, rect.bottomRight, dashWidth, dashSpace, paint);
    // Bottom
    _drawDashedLine(canvas, rect.bottomRight, rect.bottomLeft, dashWidth, dashSpace, paint);
    // Left
    _drawDashedLine(canvas, rect.bottomLeft, rect.topLeft, dashWidth, dashSpace, paint);
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    double dashWidth,
    double dashSpace,
    Paint paint,
  ) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = sqrt(dx * dx + dy * dy);
    final dashCount = (distance / (dashWidth + dashSpace)).floor();

    final unitX = dx / distance;
    final unitY = dy / distance;

    for (int i = 0; i < dashCount; i++) {
      final startX = start.dx + (unitX * (dashWidth + dashSpace) * i);
      final startY = start.dy + (unitY * (dashWidth + dashSpace) * i);
      final endX = startX + (unitX * dashWidth);
      final endY = startY + (unitY * dashWidth);

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// New Screen: Payment Amount Entry
class PaymentAmountEntryScreen extends StatefulWidget {
  final String receiverUserId;
  final String receiverUserName;

  const PaymentAmountEntryScreen({
    super.key,
    required this.receiverUserId,
    required this.receiverUserName,
  });

  @override
  State<PaymentAmountEntryScreen> createState() => _PaymentAmountEntryScreenState();
}

class _PaymentAmountEntryScreenState extends State<PaymentAmountEntryScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  double? _senderBalance;
  double? _selectedQuickAmount;

  // Helper method to get initials from name
  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _loadSenderBalance();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadSenderBalance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (mounted) {
      setState(() {
        _senderBalance = ((doc.data()?['account_balance'] ?? 0.0) as num).toDouble();
      });
    }
  }

  Future<void> _confirmPayment() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (_senderBalance != null && amount > _senderBalance!) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance')),
      );
      return;
    }

    // Navigate to approval page
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionConfirmationPage(
          recipientName: widget.receiverUserName,
          recipientUserId: widget.receiverUserId,
          amount: amount,
          senderBalance: _senderBalance!,
          transactionType: TransactionType.qrPayment,
          note: _noteController.text.isNotEmpty ? _noteController.text : null,
        ),
      ),
    );

    // If payment was successful, pop back to main page
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Enter Amount',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryGreen,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        //Gradient Wrapper
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryGreen, secondaryGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Recipient Info Card - Modern Compact Design
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Avatar with initials
                  Stack(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [secondaryGreen, primaryGreen],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(widget.receiverUserName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Verified badge
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Recipient info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Paying to',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.receiverUserName,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Amount Input Card - Modern Design
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Amount Buttons
                  const Text(
                    'Quick Select',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [10, 20, 50, 100].map((amount) {
                      final isSelected = _selectedQuickAmount == amount.toDouble();
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedQuickAmount = amount.toDouble();
                                _amountController.text = amount.toString();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? const LinearGradient(
                                        colors: [secondaryGreen, primaryGreen],
                                      )
                                    : null,
                                color: isSelected ? null : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'RM $amount',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : Colors.grey[700],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  // Amount Input
                  const Text(
                    'Enter Amount',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      setState(() {
                        _selectedQuickAmount = double.tryParse(value);
                      });
                    },
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: secondaryGreen,
                    ),
                    decoration: InputDecoration(
                      prefixText: 'RM ',
                      prefixStyle: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: secondaryGreen,
                      ),
                      hintText: '0.00',
                      hintStyle: TextStyle(color: Colors.grey[300]),
                      border: InputBorder.none,
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[200]!, width: 2),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: secondaryGreen, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Balance Progress Bar
                  if (_senderBalance != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Available Balance',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'RM ${_senderBalance!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: secondaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: (_amountController.text.isNotEmpty && _senderBalance! > 0)
                            ? (double.tryParse(_amountController.text) ?? 0) / _senderBalance!
                            : 0,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          (double.tryParse(_amountController.text) ?? 0) > _senderBalance!
                              ? Colors.red
                              : secondaryGreen,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Note Field
                  const Text(
                    'Add Note (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'E.g., Lunch, Movie tickets...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: secondaryGreen, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Confirm Button - Modern Gradient Design
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _confirmPayment,
                child: Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [secondaryGreen, primaryGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: secondaryGreen.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Confirm Payment',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Cancel Button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}