import 'package:flutter/material.dart';

import '../data/aircraft_settings.dart';
import '../data/equipment_store.dart';
import '../l10n/app_localizations.dart';

Future<void> showAircraftSettingsSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints.expand(),
    builder: (_) => const _AircraftSettingsSheet(),
  );
}

class _AircraftSettingsSheet extends StatefulWidget {
  const _AircraftSettingsSheet();

  @override
  State<_AircraftSettingsSheet> createState() => _AircraftSettingsSheetState();
}

class _AircraftSettingsSheetState extends State<_AircraftSettingsSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _manufacturerController;
  late final TextEditingController _modelController;
  late final TextEditingController _nameController;
  late final TextEditingController _trimSpeedController;
  late final TextEditingController _goalGlideRatioController;

  String _faiClass = AircraftSettings.instance.faiClass;
  String _paragliderCategory = AircraftSettings.instance.paragliderCategory;
  String _hangGliderCategory = AircraftSettings.instance.hangGliderCategory;
  bool _tandem = AircraftSettings.instance.tandem;
  String _engineType = AircraftSettings.instance.engineType;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final settings = AircraftSettings.instance;
    _manufacturerController = TextEditingController(
      text: settings.manufacturer,
    );
    _modelController = TextEditingController(text: settings.model);
    _nameController = TextEditingController(text: settings.name);
    _trimSpeedController = TextEditingController(
      text: settings.trimSpeedKmh.toStringAsFixed(1),
    );
    _goalGlideRatioController = TextEditingController(
      text: settings.goalGlideRatio.toStringAsFixed(2),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await settings.load();
      if (!mounted) return;
      setState(() {
        _faiClass = settings.faiClass;
        _paragliderCategory = settings.paragliderCategory;
        _hangGliderCategory = settings.hangGliderCategory;
        _tandem = settings.tandem;
        _engineType = settings.engineType;
        _manufacturerController.text = settings.manufacturer;
        _modelController.text = settings.model;
        _nameController.text = settings.name;
        _trimSpeedController.text = settings.trimSpeedKmh.toStringAsFixed(1);
        _goalGlideRatioController.text = settings.goalGlideRatio
            .toStringAsFixed(2);
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _manufacturerController.dispose();
    _modelController.dispose();
    _nameController.dispose();
    _trimSpeedController.dispose();
    _goalGlideRatioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final settings = AircraftSettings.instance;
    final trimSpeed = _parsePositive(_trimSpeedController.text);
    final goalGlideRatio = _parsePositive(_goalGlideRatioController.text);
    if (trimSpeed == null || goalGlideRatio == null) return;

    await settings.save(
      faiClass: _faiClass,
      manufacturer: _manufacturerController.text,
      model: _modelController.text,
      name: _nameController.text,
      paragliderCategory: _paragliderCategory,
      hangGliderCategory: _hangGliderCategory,
      tandem: _tandem,
      engineType: _engineType,
      trimSpeedKmh: trimSpeed,
      goalGlideRatio: goalGlideRatio,
    );
    // Keep the existing flight equipment editor aligned with the active
    // aircraft, while preserving harness and helmet defaults.
    await EquipmentStore.instance.load();
    await EquipmentStore.instance.remember(
      glider: settings.displayName,
      harness: EquipmentStore.instance.harness,
      helmet: EquipmentStore.instance.helmet,
    );
    if (mounted) Navigator.of(context).pop();
  }

  double? _parsePositive(String value) {
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    return parsed != null && parsed > 0 ? parsed : null;
  }

  InputDecoration _decoration(String label, IconData icon) =>
      InputDecoration(labelText: label, prefixIcon: Icon(icon));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final settings = AircraftSettings.instance;
    final isParaglider = const {'3', '11', '12'}.contains(_faiClass);
    final isHangGlider = const {
      '1',
      '2',
      '5',
      '14',
      '15',
      '16',
    }.contains(_faiClass);

    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => Material(
        color: theme.colorScheme.surface,
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 64,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: l10n.close,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                    Expanded(
                      child: Text(
                        l10n.aircraft,
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
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                    children: [
                      Icon(
                        Icons.flight,
                        size: 72,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.aircraft,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.aircraftSubtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      DropdownButtonFormField<String>(
                        key: ValueKey('fai-$_faiClass'),
                        initialValue:
                            AircraftSettings.faiClasses.containsKey(_faiClass)
                            ? _faiClass
                            : '3',
                        decoration: _decoration(
                          l10n.aircraftFaiClass,
                          Icons.category_outlined,
                        ),
                        items: AircraftSettings.faiClasses.entries
                            .map(
                              (entry) => DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(_faiClassLabel(l10n, entry.key)),
                              ),
                            )
                            .toList(),
                        onChanged: _loading
                            ? null
                            : (value) => setState(() {
                                _faiClass = value ?? '3';
                              }),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _manufacturerController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _decoration(
                          l10n.aircraftManufacturer,
                          Icons.business_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _modelController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _decoration(
                          l10n.aircraftModel,
                          Icons.air_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _decoration(
                          l10n.aircraftName,
                          Icons.label_outline,
                        ),
                      ),
                      if (isParaglider) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          key: ValueKey('paraglider-$_paragliderCategory'),
                          initialValue:
                              AircraftSettings.paragliderCategories.contains(
                                _paragliderCategory,
                              )
                              ? _paragliderCategory
                              : null,
                          decoration: _decoration(
                            l10n.aircraftParagliderCategory,
                            Icons.waves_outlined,
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: '',
                              child: Text(l10n.notSet),
                            ),
                            ...AircraftSettings.paragliderCategories.map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(_categoryLabel(l10n, value)),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _paragliderCategory = value ?? ''),
                        ),
                      ],
                      if (isHangGlider) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          key: ValueKey('hang-glider-$_hangGliderCategory'),
                          initialValue:
                              AircraftSettings.hangGliderCategories.contains(
                                _hangGliderCategory,
                              )
                              ? _hangGliderCategory
                              : null,
                          decoration: _decoration(
                            l10n.aircraftHangGliderCategory,
                            Icons.waves_outlined,
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: '',
                              child: Text(l10n.notSet),
                            ),
                            ...AircraftSettings.hangGliderCategories.map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(_categoryLabel(l10n, value)),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _hangGliderCategory = value ?? ''),
                        ),
                      ],
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.aircraftTandem),
                        subtitle: Text(l10n.aircraftTandemSubtitle),
                        value: _tandem,
                        onChanged: _loading
                            ? null
                            : (value) => setState(() => _tandem = value),
                      ),
                      DropdownButtonFormField<String>(
                        key: ValueKey('engine-$_engineType'),
                        initialValue:
                            AircraftSettings.engineTypes.containsKey(
                              _engineType,
                            )
                            ? _engineType
                            : 'T',
                        decoration: _decoration(
                          l10n.aircraftEngineType,
                          Icons.bolt_outlined,
                        ),
                        items: AircraftSettings.engineTypes.entries
                            .map(
                              (entry) => DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(_engineLabel(l10n, entry.key)),
                              ),
                            )
                            .toList(),
                        onChanged: _loading
                            ? null
                            : (value) =>
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
                        validator: (value) =>
                            _parsePositive(value ?? '') == null
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
                        validator: (value) =>
                            _parsePositive(value ?? '') == null
                            ? l10n.aircraftPositiveNumberRequired
                            : null,
                      ),
                      const SizedBox(height: 28),
                      FilledButton.icon(
                        onPressed: _loading || settings.isSaving ? null : _save,
                        icon: settings.isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          settings.isSaving ? l10n.saving : l10n.aircraftSave,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _faiClassLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case '1':
        return l10n.aircraftFaiHangGlider;
      case '2':
      case '5':
        return l10n.aircraftFaiRigidWing;
      case '3':
        return l10n.aircraftFaiParaglider;
      case '11':
        return l10n.aircraftFaiPoweredParagliderFoot;
      case '12':
        return l10n.aircraftFaiPoweredParagliderTrike;
      case '13':
        return l10n.aircraftFaiPoweredAircraft;
      case '14':
      case '15':
        return l10n.aircraftFaiRigidWingPowered;
      case '16':
        return l10n.aircraftFaiRigidGlider;
      default:
        return value;
    }
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
      default:
        return l10n.aircraftEngineNone;
    }
  }
}
