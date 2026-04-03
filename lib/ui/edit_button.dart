import 'dart:ui';
import 'package:flutter/material.dart';

enum CreatureIconDetail { none, rna }

class EditButton extends StatelessWidget {
  const EditButton({super.key, required this.onTap, this.detailOption});

  final VoidCallback? onTap;
  final CreatureIconDetail? detailOption;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 40,
        child: Stack(
          children: <Widget>[
            ImageFiltered(
              imageFilter: ImageFilter.dilate(radiusX: 2, radiusY: 2),
              child: Image.asset(
                'assets/creature-icon.png',
                color: Colors.white,
              ),
            ),
            Image.asset('assets/creature-icon.png'),
            switch (detailOption) {
              CreatureIconDetail.none => SizedBox(),
              CreatureIconDetail.rna => Image.asset('assets/creature-rna.png'),
              null => SizedBox(),
            },
          ],
        ),
      ),
    );
  }
}
