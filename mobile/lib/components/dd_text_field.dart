import 'package:flutter/material.dart';
import '../core/theme/dd_colors.dart';
import '../core/theme/dd_spacing.dart';
import '../core/theme/dd_typography.dart';

/// DDTextField — styled text input with validation states
class DDTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool enabled;
  final Widget? prefix;
  final Widget? suffix;
  final int? maxLength;
  final int? maxLines;
  final TextInputAction? textInputAction;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;

  const DDTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.enabled = true,
    this.prefix,
    this.suffix,
    this.maxLength,
    this.maxLines = 1,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  State<DDTextField> createState() => _DDTextFieldState();
}

class _DDTextFieldState extends State<DDTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final isPassword = widget.obscureText;

    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      keyboardType: widget.keyboardType,
      obscureText: isPassword && _obscure,
      enabled: widget.enabled,
      maxLength: widget.maxLength,
      maxLines: isPassword ? 1 : widget.maxLines,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      style: DDTypography.bodyLg,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.prefix != null
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: DDSpacing.sm),
                child: widget.prefix,
              )
            : null,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: DDColors.textSecondary,
                  size: DDSpacing.iconSize,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : widget.suffix != null
                ? Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: DDSpacing.sm),
                    child: widget.suffix,
                  )
                : null,
        counterText: '',
      ),
    );
  }
}
