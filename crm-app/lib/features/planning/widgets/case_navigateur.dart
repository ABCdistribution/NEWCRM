import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// Case à cocher native du navigateur avec son libellé (`<label><input type="checkbox"> …</label>` dans `.cases`) :
/// carré de 13 px au bord gris, bleu `#0075FF` une fois coché ; un appui sur le libellé coche aussi.
class CaseNavigateur extends StatelessWidget {
  const CaseNavigateur({
    super.key,
    required this.label,
    required this.cochee,
    required this.onChanged,
  });

  final String label;
  final bool cochee;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    const bleu = Color(0xFF0075FF);
    return Semantics(
      checked: cochee,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!cochee),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 13,
              height: 13,
              margin: const EdgeInsets.fromLTRB(4, 3, 3, 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cochee ? bleu : Colors.white,
                borderRadius: BorderRadius.circular(2.5),
                border: Border.all(
                  color: cochee ? bleu : const Color(0xFF767676),
                ),
              ),
              child: cochee
                  ? const Icon(Icons.check, size: 11, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 6),
            Text(label, style: AppText.t(14)),
          ],
        ),
      ),
    );
  }
}
