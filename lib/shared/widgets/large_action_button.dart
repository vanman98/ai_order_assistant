import 'package:flutter/material.dart';

class LargeActionButton extends StatelessWidget {
  const LargeActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: double.infinity,
        height: 70,
        child: isPrimary
            ? FilledButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 26),
                label: Text(label),
              )
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 26),
                label: Text(label),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.onSurface,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: colorScheme.outlineVariant),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
      ),
    );
  }
}
