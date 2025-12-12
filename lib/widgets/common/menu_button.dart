import 'package:flutter/material.dart';

class MenuButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const MenuButton({
    super.key,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(0, 255, 65, 0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF00FF41)),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 255, 65, 0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Share Tech Mono',
            fontSize: 18,
            color: Color(0xFF00FF41),
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
