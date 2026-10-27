import 'package:flutter/material.dart';

import '../data/asfc_auth_service.dart';
import '../l10n/app_localizations.dart';

Future<bool?> showAddPilotTrainingRecordSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.96,
      child: _PilotTrainingRecordForm(),
    ),
  );
}

class _PilotTrainingRecordForm extends StatefulWidget {
  const _PilotTrainingRecordForm();

  @override
  State<_PilotTrainingRecordForm> createState() =>
      _PilotTrainingRecordFormState();
}

class _PilotTrainingRecordFormState extends State<_PilotTrainingRecordForm> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AsfcAuthService.instance;
  final _dateController = TextEditingController();
  final _addressController = TextEditingController();
  final _venueHeightController = TextEditingController();
  final _trainingSubjectController = TextEditingController();
  final _airbornePeriodController = TextEditingController();
  late DateTime _trainDate;
  String? _windDirection;
  String? _windSpeed;
  int? _numberOfTimes;
  String? _trainResult;
  bool _saving = false;

  static const _windDirections = <String>[
    '东',
    '东南',
    '南',
    '西南',
    '西',
    '西北',
    '北',
    '东北',
  ];
  static const _windSpeeds = <String>[
    '0m/s',
    '1m/s',
    '2m/s',
    '3m/s',
    '4m/s',
    '5m/s',
    '6m/s',
  ];
  static const _trainingCounts = <int>[
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    28,
    29,
    30,
    31,
    32,
    33,
    34,
    35,
    36,
    37,
    38,
    39,
    40,
    41,
    42,
    43,
    44,
    45,
    46,
    47,
    48,
    49,
    50,
    51,
    52,
    53,
    54,
    55,
    56,
    57,
    58,
    59,
    60,
    61,
    62,
    63,
    64,
    65,
    66,
    67,
    68,
    69,
    70,
    71,
    72,
    73,
    74,
    75,
    76,
    77,
    78,
    79,
    80,
    81,
    82,
    83,
    84,
    85,
    86,
    87,
    88,
    89,
    90,
    91,
    92,
    93,
    94,
    95,
    96,
    97,
    98,
    99,
  ];

  @override
  void initState() {
    super.initState();
    _trainDate = DateUtils.dateOnly(DateTime.now());
    _dateController.text = _formatDate(_trainDate);
  }

  @override
  void dispose() {
    _dateController.dispose();
    _addressController.dispose();
    _venueHeightController.dispose();
    _trainingSubjectController.dispose();
    _airbornePeriodController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _trainDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _trainDate = DateUtils.dateOnly(selected);
      _dateController.text = _formatDate(_trainDate);
    });
  }

  String? _required(String? value, AppLocalizations l10n) {
    return value == null || value.trim().isEmpty
        ? l10n.pilotTrainingRequired
        : null;
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: const OutlineInputBorder(),
    );
  }

  Widget _textField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required AppLocalizations l10n,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.sentences,
      maxLength: 500,
      validator: (value) => _required(value, l10n),
      decoration: _decoration(label, icon),
    );
  }

  String _windDirectionLabel(String value, AppLocalizations l10n) {
    return switch (value) {
      '东' => l10n.pilotTrainingWindEast,
      '东南' => l10n.pilotTrainingWindSouthEast,
      '南' => l10n.pilotTrainingWindSouth,
      '西南' => l10n.pilotTrainingWindSouthWest,
      '西' => l10n.pilotTrainingWindWest,
      '西北' => l10n.pilotTrainingWindNorthWest,
      '北' => l10n.pilotTrainingWindNorth,
      '东北' => l10n.pilotTrainingWindNorthEast,
      _ => value,
    };
  }

  String _trainingResultLabel(String value, AppLocalizations l10n) {
    return switch (value) {
      'FINE' => l10n.pilotTrainingResultFine,
      'STANDARD' => l10n.pilotTrainingResultStandard,
      'NOT_STANDARD' => l10n.pilotTrainingResultNotStandard,
      _ => value,
    };
  }

  Future<void> _submit(AppLocalizations l10n) async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final success = await _auth.addPilotTrainingRecord(
      trainDate: _dateController.text,
      address: _addressController.text,
      venueHeight: _venueHeightController.text,
      windDirection: _windDirection ?? '',
      windSpeed: _windSpeed ?? '',
      trainingSubject: _trainingSubjectController.text,
      numberOfTimes: _numberOfTimes?.toString() ?? '',
      airbornePeriod: _airbornePeriodController.text,
      trainResult: _trainResult ?? '',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.pilotTrainingSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: theme.colorScheme.surface,
        child: Column(
          children: [
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.close,
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                  Expanded(
                    child: Text(
                      l10n.pilotTrainingAdd,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    TextFormField(
                      controller: _dateController,
                      readOnly: true,
                      onTap: _pickDate,
                      validator: (value) => _required(value, l10n),
                      decoration: _decoration(
                        l10n.pilotTrainingDate,
                        Icons.calendar_today_outlined,
                      ).copyWith(suffixIcon: const Icon(Icons.arrow_drop_down)),
                    ),
                    const SizedBox(height: 16),
                    _textField(
                      label: l10n.pilotTrainingLocation,
                      icon: Icons.place_outlined,
                      controller: _addressController,
                      l10n: l10n,
                    ),
                    const SizedBox(height: 16),
                    _textField(
                      label: l10n.pilotTrainingVenueHeight,
                      icon: Icons.terrain_outlined,
                      controller: _venueHeightController,
                      l10n: l10n,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _windDirection,
                      isExpanded: true,
                      decoration: _decoration(
                        l10n.pilotTrainingWindDirection,
                        Icons.explore_outlined,
                      ),
                      hint: Text(l10n.pilotTrainingSelect),
                      items: _windDirections
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_windDirectionLabel(value, l10n)),
                            ),
                          )
                          .toList(growable: false),
                      validator: (value) => _required(value, l10n),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _windDirection = value),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _windSpeed,
                      isExpanded: true,
                      decoration: _decoration(
                        l10n.pilotTrainingWindSpeed,
                        Icons.air_outlined,
                      ),
                      hint: Text(l10n.pilotTrainingSelect),
                      items: _windSpeeds
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(growable: false),
                      validator: (value) => _required(value, l10n),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _windSpeed = value),
                    ),
                    const SizedBox(height: 16),
                    _textField(
                      label: l10n.pilotTrainingSubject,
                      icon: Icons.menu_book_outlined,
                      controller: _trainingSubjectController,
                      l10n: l10n,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: _numberOfTimes,
                      isExpanded: true,
                      decoration: _decoration(
                        l10n.pilotTrainingNumberOfTimes,
                        Icons.repeat_outlined,
                      ),
                      hint: Text(l10n.pilotTrainingSelect),
                      items: _trainingCounts
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text('$value'),
                            ),
                          )
                          .toList(growable: false),
                      validator: (value) => _required(value?.toString(), l10n),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _numberOfTimes = value),
                    ),
                    const SizedBox(height: 16),
                    _textField(
                      label: l10n.pilotTrainingAirbornePeriod,
                      icon: Icons.schedule_outlined,
                      controller: _airbornePeriodController,
                      l10n: l10n,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _trainResult,
                      isExpanded: true,
                      decoration: _decoration(
                        l10n.pilotTrainingResult,
                        Icons.task_alt_outlined,
                      ),
                      hint: Text(l10n.pilotTrainingSelect),
                      items: const ['FINE', 'STANDARD', 'NOT_STANDARD']
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_trainingResultLabel(value, l10n)),
                            ),
                          )
                          .toList(growable: false),
                      validator: (value) => _required(value, l10n),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _trainResult = value),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _submit(l10n),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(l10n.pilotTrainingSubmit),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
