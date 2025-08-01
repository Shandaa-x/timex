import 'package:timex/index.dart';
import 'package:flutter/material.dart';

class TxtStl {
  static TextStyle titleText1({
    Color? color,
    FontWeight? fontWeight,
    double? fontSize,
    double? height,
  }) {
    return TextStyle(
      color: color ?? Colors.black,
      fontSize: fontSize ?? 20,
      fontWeight: fontWeight ?? FontWeight.w700,
      fontFamily: 'Montserrat',
      height: height,
    );
  }

  static TextStyle titleText2({
    Color? color,
    FontWeight? fontWeight,
    double? fontSize,
    double? height,
  }) {
    return TextStyle(
      color: color ?? Colors.black,
      fontSize: fontSize ?? 18,
      fontWeight: fontWeight ?? FontWeight.w500,
      fontFamily: 'Montserrat',
      height: height,
    );
  }

  static TextStyle bodyText1({
    Color? color,
    FontWeight? fontWeight,
    double? fontSize,
    double? height,
  }) {
    return TextStyle(
      color: color ?? Colors.black,
      fontSize: fontSize ?? 13,
      fontWeight: fontWeight ?? FontWeight.w500,
      fontFamily: 'Montserrat',
      height: height,
    );
  }

  static TextStyle bodyText2({
    Color? color,
    FontWeight? fontWeight,
    double? fontSize,
    double? height,
  }) {
    return TextStyle(
      color: color ?? Colors.black,
      fontSize: fontSize ?? 13,
      fontWeight: fontWeight ?? FontWeight.w400,
      fontFamily: 'Montserrat',
      height: height,
    );
  }

  static TextStyle bodyText3({
    Color? color,
    FontWeight? fontWeight,
    double? fontSize,
    double? height,
  }) {
    return TextStyle(
      color: color ?? Colors.black,
      fontSize: fontSize ?? 12,
      fontWeight: fontWeight ?? FontWeight.w400,
      fontFamily: 'Montserrat',
      height: height,
    );
  }

  static TextStyle bodyText4({
    Color? color,
    FontWeight? fontWeight,
    double? fontSize,
    TextDecoration? decoration,
    double? height,
  }) {
    return TextStyle(
      color: color ?? Colors.black,
      fontSize: fontSize ?? 15,
      fontWeight: fontWeight ?? FontWeight.w500,
      fontFamily: 'Montserrat',
      decoration: decoration ?? TextDecoration.none,
      height: height,
    );
  }

  static TextStyle labelText1({
    Color? color,
    FontWeight? fontWeight,
    double? fontSize,
    TextDecoration? decoration,
    double? height,
  }) {
    return TextStyle(
      color: color ?? Colors.black,
      fontSize: fontSize ?? 11,
      fontWeight: fontWeight ?? FontWeight.w500,
      decoration: decoration ?? TextDecoration.none,
      fontFamily: 'Montserrat',
      height: height,
    );
  }

  static TextStyle labelText2({
    Color? color,
    FontWeight? fontWeight,
    double? fontSize,
    TextDecoration? decoration,
    double? height,
  }) {
    return TextStyle(
      color: color ?? Colors.black,
      fontSize: fontSize ?? 12,
      fontWeight: fontWeight ?? FontWeight.w400,
      decoration: decoration ?? TextDecoration.none,
      fontFamily: 'Montserrat',
      height: height,
    );
  }

  static TextStyle labelText3({
    Color? color,
    FontWeight? fontWeight,
    double? fontSize,
    double? height,
  }) {
    return TextStyle(
      color: color ?? Colors.black,
      fontSize: fontSize ?? 11,
      fontWeight: fontWeight ?? FontWeight.w700,
      fontFamily: 'Montserrat',
      height: height,
    );
  }
}

class txt extends StatelessWidget {
  final String? text;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final String? format;
  final String? semLabel;
  final bool hidden;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool softWrap;
  final bool isCapitalized;
  final TextDecoration? decoration;
  final TextStyle? style;

  txt(
      this.text, {
        this.fontSize,
        this.fontWeight = FontWeight.normal,
        this.color,
        this.format,
        this.semLabel = '',
        this.hidden = false,
        this.maxLines,
        this.overflow = TextOverflow.ellipsis,
        this.textAlign,
        this.softWrap = false,
        this.isCapitalized = false,
        this.decoration,
        this.style,
      });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semLabel,
      hidden: hidden,
      child: Text(
        isCapitalized ? text.toString().toUpperCase() : text.toString(),
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}