import 'package:flutter/material.dart';

class OnboardingCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onButtonPressed;
  final VoidCallback? onSkipPressed;
  final Color? buttonColor;
  final int pageIndex;
  final int activeIndex;
  final int totalPages;
  final Widget? image;

  const OnboardingCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onButtonPressed,
    this.onSkipPressed,
    this.buttonColor,
    required this.pageIndex,
    required this.activeIndex,
    this.totalPages = 4,
    this.image,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(),
          if (image != null) SizedBox(height: 240, child: Center(child: image)),
          Column(
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              // move the page indicator just below the subtitle with small spacing
              SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalPages, (i) {
                  final bool active = (i == activeIndex);
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 250),
                    margin: EdgeInsets.symmetric(horizontal: 6),
                    width: active ? 18 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.orange
                          : Colors.orange.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }),
              ),
            ],
          ),
          Column(
            children: [
              SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onButtonPressed,
                  child: Text(buttonText.toUpperCase()),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    backgroundColor:
                        buttonColor ?? Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 8),
              TextButton(
                onPressed: onSkipPressed ?? () {},
                style: TextButton.styleFrom(foregroundColor: Color(0xFF646982)),
                child: Text('Skip'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
