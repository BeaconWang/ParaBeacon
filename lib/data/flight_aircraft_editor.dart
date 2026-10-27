import 'package:flutter/material.dart';

import 'aircraft_settings.dart';
import 'flight_recorder.dart';
import '../l10n/aircraft_l10n.dart';
import '../l10n/app_localizations.dart';

Future<FlightAircraftDraft?> showFlightAircraftEditor(
  BuildContext context,
  FlightTrack track,
) async {
  final settings = AircraftSettings.instance;
  await Future.wait([settings.load(), settings.loadPresets()]);
  if (!context.mounted) return null;

  return showDialog<FlightAircraftDraft>(
    context: context,
    builder: (_) => _FlightAircraftEditor(
      initial: FlightAircraftDraft.fromTrack(track, settings),
    ),
  );
}

class FlightAircraftDraft {
  const FlightAircraftDraft({
    required this.faiClass,
    required this.manufacturer,
    required this.model,
    required this.category,
    required this.tandem,
    required this.engineType,
    required this.trimSpeedKmh,
    required this.goalGlideRatio,
  });

  final String faiClass;
  final String manufacturer;
  final String model;
  final String category;
  final bool tandem;
  final String engineType;
  final double trimSpeedKmh;
  final double goalGlideRatio;

  factory FlightAircraftDraft.fromTrack(
    FlightTrack track,
    AircraftSettings settings,
  ) {
    final faiClass = track.aircraftFaiClass ?? settings.faiClass;
    final category =
        track.aircraftCategory ??
        (const {'3', '11', '12'}.contains(faiClass)
            ? settings.paragliderCategory
            : const {'1', '2', '5', '14', '15', '16'}.contains(faiClass)
            ? settings.hangGliderCategory
            : '');
    return FlightAircraftDraft(
      faiClass: faiClass,
      manufacturer: track.aircraftManufacturer ?? settings.manufacturer,
      model: track.aircraftModel ?? settings.model,
      category: category,
      tandem: track.aircraftTandem ?? settings.tandem,
      engineType: track.aircraftEngineType ?? settings.engineType,
      trimSpeedKmh: track.aircraftTrimSpeedKmh ?? settings.trimSpeedKmh,
      goalGlideRatio: track.aircraftGoalGlideRatio ?? settings.goalGlideRatio,
    );
  }
}

class _FlightAircraftEditor extends StatefulWidget {
  const _FlightAircraftEditor({required this.initial});

  final FlightAircraftDraft initial;

  @override
  State<_FlightAircraftEditor> createState() => _FlightAircraftEditorState();
}

class _FlightAircraftEditorState extends State<_FlightAircraftEditor> {
  final _formKey = GlobalKey<FormState>();
  late String _manufacturer;
  late String _model;
  late final TextEditingController _categoryController;
  late final TextEditingController _trimSpeedController;
  late final TextEditingController _goalGlideRatioController;

  late String _faiClass;
  late String _category;
  late String _engineType;
  late bool _tandem;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _faiClass = initial.faiClass;
    _category = initial.category;
    _engineType = initial.engineType;
    _tandem = initial.tandem;
    _manufacturer = initial.manufacturer;
    _model = initial.model;
    _categoryController = TextEditingController(text: initial.category);
    _trimSpeedController = TextEditingController(
      text: initial.trimSpeedKmh.toStringAsFixed(1),
    );
    _goalGlideRatioController = TextEditingController(
      text: initial.goalGlideRatio.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _trimSpeedController.dispose();
    _goalGlideRatioController.dispose();
    super.dispose();
  }

  bool get _isParaglider => const {'3', '11', '12'}.contains(_faiClass);

  bool get _isHangGlider =>
      const {'1', '2', '5', '14', '15', '16'}.contains(_faiClass);

  int _categoryKind(String faiClass) {
    if (const {'3', '11', '12'}.contains(faiClass)) return 1;
    if (const {'1', '2', '5', '14', '15', '16'}.contains(faiClass)) return 2;
    return 0;
  }

  List<String> _categoryOptions() {
    final options = _isHangGlider
        ? [...AircraftSettings.hangGliderCategories]
        : [...AircraftSettings.paragliderCategories];
    if (_category.isNotEmpty && !options.contains(_category)) {
      options.add(_category);
    }
    return options;
  }

  double? _parsePositive(String value) {
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    return parsed != null && parsed.isFinite && parsed > 0 ? parsed : null;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final trimSpeed = _parsePositive(_trimSpeedController.text);
    final glideRatio = _parsePositive(_goalGlideRatioController.text);
    if (trimSpeed == null || glideRatio == null) return;

    Navigator.of(context).pop(
      FlightAircraftDraft(
        faiClass: _faiClass,
        manufacturer: _manufacturer,
        model: _model,
        category: _category,
        tandem: _tandem,
        engineType: _engineType,
        trimSpeedKmh: trimSpeed,
        goalGlideRatio: glideRatio,
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) =>
      InputDecoration(labelText: label, prefixIcon: Icon(icon));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = AircraftSettings.instance;
    final faiClasses = AircraftSettings.faiClasses.keys.toList();
    if (!faiClasses.contains(_faiClass)) faiClasses.add(_faiClass);
    final engineTypes = AircraftSettings.engineTypes.keys.toList();
    if (!engineTypes.contains(_engineType)) engineTypes.add(_engineType);
    final categoryOptions = _categoryOptions();

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: l10n.cancel,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
          title: Text(l10n.flightDetailAircraft),
          actions: [
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(l10n.save),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey('flight-fai-$_faiClass'),
                  initialValue: _faiClass,
                  decoration: _decoration(
                    l10n.aircraftFaiClass,
                    Icons.category_outlined,
                  ),
                  items: faiClasses
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(aircraftFaiClassLabel(l10n, value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      if (_categoryKind(_faiClass) != _categoryKind(value)) {
                        _category = '';
                        _categoryController.clear();
                      }
                      _faiClass = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Autocomplete<String>(
                  key: const ValueKey('flight-manufacturer'),
                  initialValue: TextEditingValue(text: _manufacturer),
                  optionsBuilder: (textEditingValue) {
                    final query = textEditingValue.text.toLowerCase();
                    return settings.manufacturers.where(
                      (value) => value.toLowerCase().contains(query),
                    );
                  },
                  onSelected: (value) => setState(() {
                    _manufacturer = value;
                    _model = '';
                  }),
                  fieldViewBuilder:
                      (
                        context,
                        controller,
                        focusNode,
                        onFieldSubmitted,
                      ) => TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: _decoration(
                          l10n.aircraftManufacturer,
                          Icons.business_outlined,
                        ).copyWith(hintText: l10n.aircraftSelectManufacturer),
                        onChanged: (value) {
                          if (_manufacturer == value) return;
                          setState(() {
                            _manufacturer = value;
                            _model = '';
                          });
                        },
                      ),
                ),
                const SizedBox(height: 16),
                Autocomplete<String>(
                  key: ValueKey('flight-model-$_manufacturer'),
                  initialValue: TextEditingValue(text: _model),
                  optionsBuilder: (textEditingValue) {
                    if (_manufacturer.isEmpty) return const [];
                    final query = textEditingValue.text.toLowerCase();
                    return settings
                        .modelsFor(_manufacturer)
                        .where((value) => value.toLowerCase().contains(query));
                  },
                  onSelected: (value) => setState(() => _model = value),
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) =>
                          TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            enabled: _manufacturer.isNotEmpty,
                            decoration: _decoration(
                              l10n.aircraftModel,
                              Icons.air_outlined,
                            ).copyWith(hintText: l10n.aircraftSelectModel),
                            onChanged: (value) => _model = value,
                          ),
                ),
                if (_isHangGlider)
                  DropdownButtonFormField<String>(
                    key: ValueKey('flight-category-$_faiClass-$_category'),
                    initialValue: _category,
                    decoration: _decoration(
                      l10n.aircraftHangGliderCategory,
                      Icons.waves_outlined,
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: '',
                        child: Text(l10n.notSet),
                      ),
                      ...categoryOptions.map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(_categoryLabel(l10n, value)),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _category = value ?? ''),
                  )
                else if (!_isParaglider)
                  TextFormField(
                    controller: _categoryController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _decoration(
                      l10n.flightDetailAircraftCategory,
                      Icons.waves_outlined,
                    ),
                    onChanged: (value) => _category = value,
                  ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.aircraftTandem),
                  subtitle: Text(l10n.aircraftTandemSubtitle),
                  value: _tandem,
                  onChanged: (value) => setState(() => _tandem = value),
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey('flight-engine-$_engineType'),
                  initialValue: _engineType,
                  decoration: _decoration(
                    l10n.aircraftEngineType,
                    Icons.bolt_outlined,
                  ),
                  items: engineTypes
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(_engineLabel(l10n, value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _engineType = value ?? 'T'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _trimSpeedController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _decoration(
                    l10n.aircraftTrimSpeed,
                    Icons.speed_outlined,
                  ),
                  validator: (value) => _parsePositive(value ?? '') == null
                      ? l10n.aircraftPositiveNumberRequired
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _goalGlideRatioController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _decoration(
                    l10n.aircraftGoalGlideRatio,
                    Icons.trending_up,
                  ),
                  validator: (value) => _parsePositive(value ?? '') == null
                      ? l10n.aircraftPositiveNumberRequired
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _categoryLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'Standard':
        return l10n.aircraftCategoryStandard;
      case 'Performance':
        return l10n.aircraftCategoryPerformance;
      case 'Competition':
        return l10n.aircraftCategoryCompetition;
      case 'Flex wing':
        return l10n.aircraftCategoryFlexWing;
      case 'Rigid wing':
        return l10n.aircraftCategoryRigidWing;
      case 'Class 1':
        return l10n.aircraftCategoryClass1;
      case 'Class 5':
        return l10n.aircraftCategoryClass5;
      default:
        return value;
    }
  }

  String _engineLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'E':
        return l10n.aircraftEngineElectric;
      case 'I':
        return l10n.aircraftEngineInternalCombustion;
      case 'T':
        return l10n.aircraftEngineNone;
      default:
        return value;
    }
  }
}
