import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/constants/colors.dart';
import '/models/card_model.dart';

class VirtualCardWidget extends StatefulWidget {
  final VirtualCard card;

  const VirtualCardWidget({
    super.key,
    required this.card,
  });

  @override
  State<VirtualCardWidget> createState() => _VirtualCardWidgetState();
}

class _VirtualCardWidgetState extends State<VirtualCardWidget> {
  bool _showCardNumber = false;
  bool _showCVV = false;

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: primaryGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 205,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [primaryGreen, secondaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card type label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TraVQR Virtual Card',
                style: TextStyle(
                  color: Colors.black45,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                Icons.contactless_rounded,
                color: Colors.white30,
                size: 32,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Chip image
          Image.asset(
            'assets/images/chip-logo.png',
            width: 45,
            height: 35,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 12),

          // Card number with toggle
          Row(
            children: [
              GestureDetector(
                onLongPress: () => _copyToClipboard(
                  widget.card.cardNumber.replaceAll(' ', ''),
                  'Card number',
                ),
                child: Text(
                  _showCardNumber
                    ? widget.card.formattedNumber
                    : widget.card.maskedNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => setState(() => _showCardNumber = !_showCardNumber),
                child: Icon(
                  _showCardNumber ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white54,
                  size: 24,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Bottom section: Card details on left, Visa logo on right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Left section: Expiry, CVV, and Cardholder
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Expiry, CVV, and Visa logo row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Expiry
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EXPIRES',
                              style: TextStyle(
                                color: Colors.black45,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.card.expiryDate,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        // CVV with toggle
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CVV',
                              style: TextStyle(
                                color: Colors.black45,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                GestureDetector(
                                  onLongPress: () => _copyToClipboard(widget.card.cvv, 'CVV'),
                                  child: Text(
                                    _showCVV ? widget.card.cvv : '***',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => setState(() => _showCVV = !_showCVV),
                                  child: Icon(
                                    _showCVV ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.white54,
                                    size: 17,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Visa logo
                        Image.asset(
                          'assets/images/visa-logo-png-2020.png',
                          width: 67,
                          height: 40,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
