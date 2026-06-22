import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

class ExpandablePostText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const ExpandablePostText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  State<ExpandablePostText> createState() => _ExpandablePostTextState();
}

class _ExpandablePostTextState extends State<ExpandablePostText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Standard system font matching the clean aesthetic of your reference image
    final textStyle = widget.style.copyWith(
      fontFamily: 'Roboto', // Or leave blank for default system font (San Francisco/Roboto)
      height: 1.4,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final span = TextSpan(text: widget.text, style: textStyle);
        final tp = TextPainter(
          text: span,
          maxLines: 3,
          textDirection: TextDirection.ltr,
        );
        tp.layout(maxWidth: constraints.maxWidth);

        if (tp.didExceedMaxLines && !_isExpanded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () => setState(() => _isExpanded = true),
                child: Text(
                  "... more",
                  style: textStyle.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        } else {
          // If expanded or short enough, show linkified text
          return Linkify(
            onOpen: (link) async {
              if (await canLaunchUrl(Uri.parse(link.url))) {
                await launchUrl(Uri.parse(link.url));
              }
            },
            text: widget.text,
            style: textStyle,
            linkStyle: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
          );
        }
      },
    );
  }
}