import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/recruitment_widgets.dart';

/// Renders one dynamic question from `school_vacancies.form_schema`.
class DynamicQuestionField extends StatelessWidget {
  final Map<String, dynamic> question;
  final TextEditingController? controller;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final bool enabled;

  const DynamicQuestionField({
    super.key,
    required this.question,
    required this.onChanged,
    this.controller,
    this.value,
    this.enabled = true,
  });

  String get _type => question['type']?.toString() ?? 'short_answer';
  String get _label => question['label']?.toString() ?? 'Question';
  bool get _required => question['required'] == true;
  String? get _help {
    final h = question['help_text']?.toString();
    return h == null || h.isEmpty ? null : h;
  }

  List<String> get _options {
    final raw = question['options'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    if (_type == 'file_upload') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: RecruitmentNotice(
          text:
              '${_label} is collected in the Documents section below so the administrator can verify it.',
          icon: Icons.attach_file_rounded,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: RecruitmentColors.navy,
              ),
              children: [
                TextSpan(text: _label),
                if (_required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: RecruitmentColors.red),
                  ),
              ],
            ),
          ),
          if (_help != null) ...[
            const SizedBox(height: 2),
            Text(_help!, style: kRecruitmentCaption),
          ],
          const SizedBox(height: 6),
          _buildInput(context),
        ],
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    switch (_type) {
      case 'paragraph':
        return TextFormField(
          controller: controller,
          initialValue: controller == null ? value?.toString() : null,
          enabled: enabled,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          onChanged: enabled ? (v) => onChanged(v) : null,
          decoration: recruitmentFieldDecoration('Your answer'),
        );
      case 'number':
        return TextFormField(
          controller: controller,
          initialValue: controller == null ? value?.toString() : null,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: enabled ? (v) => onChanged(v) : null,
          decoration: recruitmentFieldDecoration('Enter a number'),
        );
      case 'date':
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? () => _pickDate(context) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: enabled ? Colors.white : RecruitmentColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: RecruitmentColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_outlined,
                    size: 18, color: RecruitmentColors.slate),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value == null
                        ? 'Select a date'
                        : recruitmentDate(value),
                    style: TextStyle(
                      fontSize: 12,
                      color: value == null
                          ? RecruitmentColors.slate
                          : RecruitmentColors.navy,
                    ),
                  ),
                ),
                if (value != null && enabled)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onChanged(null),
                    icon: const Icon(Icons.close, size: 16),
                  ),
              ],
            ),
          ),
        );
      case 'multiple_choice':
      case 'dropdown':
        return DropdownButtonFormField<String>(
          value: value is String && _options.contains(value) ? value as String : null,
          decoration: recruitmentFieldDecoration('Choose one'),
          items: _options
              .map((o) => DropdownMenuItem<String>(value: o, child: Text(o)))
              .toList(),
          onChanged: enabled ? (v) => onChanged(v) : null,
        );
      case 'checkboxes':
        final selected = value is List
            ? value.map((e) => e.toString()).toSet()
            : <String>{};
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: RecruitmentColors.border),
          ),
          child: Column(
            children: _options.map((option) {
              final checked = selected.contains(option);
              return CheckboxListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                controlAffinity: ListTileControlAffinity.leading,
                value: checked,
                onChanged: enabled
                    ? (v) {
                        final next = Set<String>.from(selected);
                        if (v == true) {
                          next.add(option);
                        } else {
                          next.remove(option);
                        }
                        onChanged(next.toList());
                      }
                    : null,
                title: Text(
                  option,
                  style: const TextStyle(
                    fontSize: 12,
                    color: RecruitmentColors.navy,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      case 'yes_no':
        final bool selected = value == true || value == 'Yes';
        return Row(
          children: [
            Expanded(
              child: RadioListTile<bool>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: true,
                groupValue: selected,
                onChanged: enabled ? (v) => onChanged(v) : null,
                title: const Text('Yes',
                    style: TextStyle(fontSize: 12)),
              ),
            ),
            Expanded(
              child: RadioListTile<bool>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: false,
                groupValue: selected,
                onChanged: enabled ? (v) => onChanged(v) : null,
                title: const Text('No',
                    style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        );
      default:
        return TextFormField(
          controller: controller,
          initialValue: controller == null ? value?.toString() : null,
          enabled: enabled,
          textCapitalization: TextCapitalization.sentences,
          onChanged: enabled ? (v) => onChanged(v) : null,
          decoration: recruitmentFieldDecoration('Your answer'),
        );
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    DateTime initial = now;
    final parsed = value == null ? null : DateTime.tryParse(value.toString());
    if (parsed != null) initial = parsed;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: now.add(const Duration(days: 365 * 30)),
    );
    if (picked != null) {
      onChanged(DateFormat('yyyy-MM-dd').format(picked));
    }
  }
}
