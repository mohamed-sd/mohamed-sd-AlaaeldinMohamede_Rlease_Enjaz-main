import 'package:Enjaz/ui/theme/theme.dart';
import 'package:Enjaz/utils/extensions/extensions.dart';
import 'package:Enjaz/utils/helper_utils.dart';
import 'package:flutter/material.dart';

class CustomText extends StatelessWidget {
  const CustomText(
    this.text, {
    super.key,
    this.color,
    this.showLineThrough,
    this.fontWeight,
    this.fontStyle,
    this.fontSize,
    this.textAlign,
    this.maxLines,
    this.height,
    this.showUnderline,
    this.underlineOrLineColor,
    this.letterSpacing,
    this.softWrap,
    this.overflow,
    this.customTextStyle,
    this.firstUpperCaseWidget = false,
  });

  final String text;
  final Color? color;
  final FontWeight? fontWeight;
  final FontStyle? fontStyle;
  final double? fontSize;
  final double? height;
  final TextAlign? textAlign;
  final int? maxLines;
  final bool? showLineThrough;
  final bool? showUnderline;
  final Color? underlineOrLineColor;
  final double? letterSpacing;
  final bool? softWrap;
  final TextOverflow? overflow;
  final bool firstUpperCaseWidget;
  final TextStyle? customTextStyle;

  TextStyle textStyle(BuildContext context) {
    return TextStyle(
      color: color ?? context.color.textDefaultColor,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      fontSize: fontSize,
      decoration: showLineThrough ?? false
          ? TextDecoration.lineThrough
          : showUnderline ?? false
              ? TextDecoration.underline
              : null,
      decorationColor: underlineOrLineColor,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      firstUpperCaseWidget ? text.toCapitalized() : text,
      maxLines: maxLines,
      softWrap: true,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      style: customTextStyle ?? textStyle(context),
      textAlign: textAlign,
      textScaler: TextScaler.noScaling,
    );
  }
}
