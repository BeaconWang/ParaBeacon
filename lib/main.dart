import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'controls/add_control_sheet.dart';
import 'controls/control_catalog.dart';
import 'controls/control_context_menu.dart';
import 'controls/control_settings_sheet.dart';
import 'controls/control_widget.dart';
import 'controls/dash_page.dart';
import 'controls/placed_control.dart';
import 'data/flight_data_provider.dart';
import 'data/flight_data_source.dart';
import 'audio/vario_audio_example.dart';
import 'audio/vario_audio_service.dart';

void main() {
  runApp(const ParaBeaconApp());
}

class ParaBeaconApp extends StatefulWidget {
  const ParaBeaconApp({super.key});

  @override
  State<ParaBeaconApp> createState() => _ParaBeaconAppState();
}

class _ParaBeaconAppState extends State<ParaBeaconApp> {
  // The single, unified flight-data source for the whole app.
  late final FlightDataSource _dataSource;

  // Drives the Vario audio directly from the vertical speed of [_dataSource].
  // Every FlightData update forwards `verticalSpeed` into the audio engine, so
  // the sound is always a function of the current vertical speed.
  late final VarioAudioBridge _varioAudio;

  @override
  void initState() {
    super.initState();
    _dataSource = SimulatedFlightDataSource()..start();
    // Use the shared VarioAudioService singleton so the Preferences panel can
    // control the same engine (mute/volume) without threading it through the
    // widget tree.
    _varioAudio =
        VarioAudioBridge(source: _dataSource, audio: VarioAudioService.instance);
    // Initialize the audio stream and start forwarding vertical speed. Safe to
    // fire-and-forget; forwarding begins as soon as init() completes.
    _varioAudio.attach();
  }

  @override
  void dispose() {
    _varioAudio.dispose();
    _dataSource.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlightDataProvider(
      source: _dataSource,
      child: MaterialApp(
        title: 'ParaBeacon',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const DashGridPage(),
      ),
    );
  }
}

class DashGridPage extends StatefulWidget {
  const DashGridPage({super.key});

  @override
  State<DashGridPage> createState() => _DashGridPageState();
}

class _DashGridPageState extends State<DashGridPage>
    with SingleTickerProviderStateMixin {
  double _gridSize = 48.0;
  bool _menuOpen = false;
  bool _isEditMode = true;

  // Vario audio settings (backed by the shared VarioAudioService singleton).
  bool _varioMuted = VarioAudioService.instance.isMuted;
  double _varioVolume = VarioAudioService.instance.volume;

  // Dashboard pages (tabs). The user swipes horizontally to switch pages in
  // view mode and can add pages in edit mode.
  final List<DashPage> _pages = [DashPage(id: 'page_0')];
  int _currentPage = 0;
  int _pageSeq = 1;
  late final PageController _pageController;

  /// Controls on the currently visible page.
  List<PlacedControl> get _controls => _pages[_currentPage].controls;

  String? _selectedControlId;
  int _controlSeq = 0;

  // Accumulated pixel offset during a control drag (before grid snapping).
  Offset _dragAccum = Offset.zero;
  int _dragStartCol = 0;
  int _dragStartRow = 0;
  int _dragStartCols = 0;
  int _dragStartRows = 0;

  late final AnimationController _menuController;
  late final Animation<double> _menuAnimation;

  // Drag state
  double _dragOffset = 0.0;
  double _menuHeight = 300.0; // measured from the menu panel after layout
  final GlobalKey _menuKey = GlobalKey();

  /// Measures the actual rendered menu-panel height and updates [_menuHeight]
  /// so the slide-in offset matches the content (no blank space below items).
  void _measureMenu() {
    final ctx = _menuKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final h = box.size.height;
    if ((h - _menuHeight).abs() > 0.5) {
      setState(() => _menuHeight = h);
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _menuAnimation = CurvedAnimation(
      parent: _menuController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _menuController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _menuController.dispose();
    super.dispose();
  }

  void _openMenu() {
    _menuOpen = true;
    _menuController.value = (_dragOffset / _menuHeight).clamp(0.0, 1.0);
    _menuController.forward();
  }

  void _closeMenu() {
    _menuOpen = false;
    _menuController.value = (_dragOffset / _menuHeight).clamp(0.0, 1.0);
    _menuController.reverse();
  }

  void _onDragStart(DragStartDetails details) {
    _dragOffset = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, _menuHeight);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragOffset > _menuHeight * 0.4) {
      // Snap open
      _openMenu();
    } else {
      // Snap closed
      _closeMenu();
    }
    _dragOffset = 0.0;
  }

  // --- Drag-to-close (dragging up on the open menu) ---

  void _onCloseDragStart(DragStartDetails details) {
    // Start tracking from the fully-open position.
    _menuOpen = false;
    _menuController.stop();
    _dragOffset = _menuHeight;
    setState(() {});
  }

  void _onCloseDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, _menuHeight);
    });
  }

  void _onCloseDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    // Close on a clear upward fling, or when dragged past the halfway point up.
    if (velocity < -300 || _dragOffset < _menuHeight * 0.6) {
      _closeMenu();
    } else {
      _openMenu();
    }
    _dragOffset = 0.0;
  }

  double get _effectiveMenuOffset {
    if (_menuController.isAnimating || _menuOpen) {
      return _menuHeight * _menuAnimation.value;
    }
    return _dragOffset;
  }

  /// Handles a tap on a menu item.
  Future<void> _onMenuAction(String action) async {
    switch (action) {
      case 'add_control':
        _closeMenu();
        await _addControlFromMenu();
        break;
      case 'add_page':
        _closeMenu();
        _addPage();
        break;
      case 'toggle_edit':
        setState(() {
          _isEditMode = !_isEditMode;
          if (!_isEditMode) _selectedControlId = null;
        });
        break;
      case 'preferences':
        _closeMenu();
        await _openPreferences();
        break;
    }
  }

  /// Adds a new empty page after the current one and navigates to it.
  void _addPage() {
    setState(() {
      final newPage = DashPage(id: 'page_${_pageSeq++}');
      final insertAt = _currentPage + 1;
      _pages.insert(insertAt, newPage);
      _currentPage = insertAt;
      _selectedControlId = null;
      _isEditMode = true;
    });
    // Jump the PageView to the new page after the frame so it exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentPage);
      }
    });
  }

  /// Deletes the current page (keeping at least one page).
  void _deleteCurrentPage() {
    if (_pages.length <= 1) return;
    setState(() {
      _pages.removeAt(_currentPage);
      if (_currentPage >= _pages.length) {
        _currentPage = _pages.length - 1;
      }
      _selectedControlId = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentPage);
      }
    });
  }

  /// Opens the app preferences sheet.
  Future<void> _openPreferences() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // Local state within the sheet, applied back via the parent setState.
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.settings_outlined,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 10),
                        Text('Preferences', style: theme.textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(_Icons.mode,
                          color: theme.colorScheme.primary),
                      title: const Text('Edit mode'),
                      value: _isEditMode,
                      onChanged: (v) {
                        setState(() {
                          _isEditMode = v;
                          if (!v) _selectedControlId = null;
                        });
                        setSheetState(() {});
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        _varioMuted
                            ? Icons.volume_off_outlined
                            : Icons.volume_up_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('Vario sound'),
                      value: !_varioMuted,
                      onChanged: (on) {
                        setState(() => _varioMuted = !on);
                        VarioAudioService.instance.setMuted(_varioMuted);
                        setSheetState(() {});
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.graphic_eq,
                              color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(child: Text('Vario volume')),
                          Text(
                            '${(_varioVolume * 100).round()}%',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Slider(
                      value: _varioVolume,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      label: '${(_varioVolume * 100).round()}%',
                      onChanged: _varioMuted
                          ? null
                          : (v) {
                              setState(() => _varioVolume = v);
                              VarioAudioService.instance.setVolume(v);
                              setSheetState(() {});
                            },
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(_Icons.grid,
                                  color: theme.colorScheme.primary, size: 20),
                              const SizedBox(width: 10),
                              const Expanded(child: Text('Grid size')),
                              Text(
                                '${_gridSize.round()} px',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _gridSize,
                            min: 16.0,
                            max: 120.0,
                            divisions: 26,
                            label: '${_gridSize.round()} px',
                            onChanged: (v) {
                              setState(() => _gridSize = v);
                              setSheetState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_sweep_outlined,
                          color: theme.colorScheme.error),
                      title: Text(
                        'Clear all controls',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                      subtitle: Text('${_controls.length} placed'),
                      enabled: _controls.isNotEmpty,
                      onTap: _controls.isEmpty
                          ? null
                          : () async {
                              final confirmed = await _confirmClearAll(context);
                              if (confirmed == true) {
                                setState(() {
                                  _controls.clear();
                                  _selectedControlId = null;
                                });
                                setSheetState(() {});
                              }
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool?> _confirmClearAll(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all controls?'),
        content: const Text(
            'This removes every control from the dashboard. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  /// Opens the control chooser and, on selection, places the new control on
  /// the grid at the first free spot.
  Future<void> _addControlFromMenu() async {
    final ControlType? type = await showAddControlSheet(context);
    if (type == null || !mounted) return;

    final position = _findFreeCell(type.defaultCols, type.defaultRows);
    setState(() {
      final control = PlacedControl.fromType(
        type,
        instanceId: 'ctrl_${_controlSeq++}',
        col: position.$1,
        row: position.$2,
      );
      _controls.add(control);
      _selectedControlId = control.instanceId;
      // Adding a control implies we want to see/edit it.
      _isEditMode = true;
    });
  }

  /// Finds a grid cell (col, row) where a control of the given size does not
  /// overlap an existing one. Falls back to (0, 0) if the grid is full.
  (int, int) _findFreeCell(int cols, int rows) {
    final size = MediaQuery.of(context).size;
    final maxCols = (size.width / _gridSize).floor();
    final maxRows = (size.height / _gridSize).floor();

    for (int row = 0; row + rows <= maxRows; row++) {
      for (int col = 0; col + cols <= maxCols; col++) {
        if (!_overlapsExisting(col, row, cols, rows)) {
          return (col, row);
        }
      }
    }
    return (0, 0);
  }

  bool _overlapsExisting(int col, int row, int cols, int rows) {
    for (final c in _controls) {
      final overlapX = col < c.col + c.cols && col + cols > c.col;
      final overlapY = row < c.row + c.rows && row + rows > c.row;
      if (overlapX && overlapY) return true;
    }
    return false;
  }

  void _deleteControl(String instanceId) {
    setState(() {
      _controls.removeWhere((c) => c.instanceId == instanceId);
      if (_selectedControlId == instanceId) _selectedControlId = null;
    });
  }

  /// Shows the long-press context menu for [control] and performs the action.
  Future<void> _showControlMenu(PlacedControl control) async {
    setState(() => _selectedControlId = control.instanceId);
    final action = await showControlContextMenu(context, control: control);
    if (action == null || !mounted) return;

    switch (action) {
      case ControlAction.settings:
        await showControlSettingsSheet(
          context,
          control: control,
          onChanged: () => setState(() {}),
        );
        break;
      case ControlAction.duplicate:
        _duplicateControl(control);
        break;
      case ControlAction.bringToFront:
        setState(() {
          _controls.remove(control);
          _controls.add(control);
        });
        break;
      case ControlAction.sendToBack:
        setState(() {
          _controls.remove(control);
          _controls.insert(0, control);
        });
        break;
      case ControlAction.delete:
        _deleteControl(control.instanceId);
        break;
    }
  }

  void _duplicateControl(PlacedControl control) {
    final position = _findFreeCell(control.cols, control.rows);
    setState(() {
      final copy = control.copyAt(
        instanceId: 'ctrl_${_controlSeq++}',
        col: position.$1,
        row: position.$2,
      );
      _controls.add(copy);
      _selectedControlId = copy.instanceId;
      _isEditMode = true;
    });
  }

  void _onControlDragStart(PlacedControl control) {
    _dragAccum = Offset.zero;
    _dragStartCol = control.col;
    _dragStartRow = control.row;
    setState(() => _selectedControlId = control.instanceId);
  }

  void _onControlDragUpdate(PlacedControl control, Offset delta) {
    _dragAccum += delta;
    setState(() {
      final size = MediaQuery.of(context).size;
      final maxCols = (size.width / _gridSize).floor();
      final maxRows = (size.height / _gridSize).floor();

      final colDelta = (_dragAccum.dx / _gridSize).round();
      final rowDelta = (_dragAccum.dy / _gridSize).round();

      control.col = (_dragStartCol + colDelta)
          .clamp(0, (maxCols - control.cols).clamp(0, maxCols));
      control.row = (_dragStartRow + rowDelta)
          .clamp(0, (maxRows - control.rows).clamp(0, maxRows));
    });
  }

  void _onControlResizeStart(PlacedControl control) {
    _dragAccum = Offset.zero;
    _dragStartCols = control.cols;
    _dragStartRows = control.rows;
    setState(() => _selectedControlId = control.instanceId);
  }

  void _onControlResizeUpdate(PlacedControl control, Offset delta) {
    _dragAccum += delta;
    setState(() {
      final size = MediaQuery.of(context).size;
      final maxCols = (size.width / _gridSize).floor();
      final maxRows = (size.height / _gridSize).floor();

      final colDelta = (_dragAccum.dx / _gridSize).round();
      final rowDelta = (_dragAccum.dy / _gridSize).round();

      // At least 1 cell; cannot extend past the grid edge from current origin.
      control.cols = (_dragStartCols + colDelta)
          .clamp(1, (maxCols - control.col).clamp(1, maxCols));
      control.rows = (_dragStartRows + rowDelta)
          .clamp(1, (maxRows - control.row).clamp(1, maxRows));
    });
  }


  @override
  Widget build(BuildContext context) {
    // Measure the real menu height after this frame so the slide offset
    // matches the content exactly (avoids blank space below the last item).
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureMenu());

    return Scaffold(
      body: Stack(
        children: [
          // Pages (tabs). Swipe horizontally to switch pages in view mode;
          // in edit mode swiping is disabled so controls can be dragged.
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              physics: _isEditMode
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              itemCount: _pages.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                  _selectedControlId = null;
                });
              },
              itemBuilder: (context, index) => _buildPageContent(index),
            ),
          ),

          // Page indicator (hidden while the menu is open). Shown with more
          // than one page, or in edit mode so a single page's icon can be
          // customized.
          if ((_pages.length > 1 || _isEditMode) && !_menuOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: (_isEditMode && _selectedControlId == null) ? 84 : 16,
              child: _buildPageIndicator(),
            ),

          // Dim overlay when menu is open
          if (_effectiveMenuOffset > 0 || _menuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeMenu,
                child: Container(color: Colors.black.withAlpha(80)),
              ),
            ),

          // Top swipe menu panel
          Positioned(
            left: 0,
            right: 0,
            top: _effectiveMenuOffset - _menuHeight,
            child: _buildMenuPanel(),
          ),

          // Slider bar at the bottom (only in edit mode, and hidden while a
          // control is selected).
          if (_isEditMode && _selectedControlId == null)
            Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildSliderPanel(),
          ),
        ],
      ),
    );
  }

  /// Builds the content (grid + controls + gesture layer) for one page.
  Widget _buildPageContent(int pageIndex) {
    final page = _pages[pageIndex];
    return Stack(
      children: [
        // Fullscreen main panel: drag down to open menu, tap to dismiss.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (_menuOpen) {
                _closeMenu();
              } else if (_selectedControlId != null) {
                setState(() => _selectedControlId = null);
              }
            },
            onVerticalDragStart: _menuOpen ? null : _onDragStart,
            onVerticalDragUpdate: _menuOpen ? null : _onDragUpdate,
            onVerticalDragEnd: _menuOpen ? null : _onDragEnd,
            child: _isEditMode
                ? CustomPaint(
                    painter: DashGridPainter(gridSize: _gridSize),
                    size: Size.infinite,
                  )
                : const SizedBox.expand(),
          ),
        ),

        // Placed controls layer for this page.
        ..._buildPlacedControls(page.controls),
      ],
    );
  }

  /// A row of page-header icons showing the current page position.
  ///
  /// Tapping an inactive page navigates to it. Tapping the active page in edit
  /// mode opens the icon picker to customize its header icon.
  Widget _buildPageIndicator() {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (i) {
        final active = i == _currentPage;
        final page = _pages[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Material(
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest.withAlpha(200),
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                if (active) {
                  if (_isEditMode) _customizePageIcon(page);
                } else {
                  _pageController.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: active ? 12 : 8,
                  vertical: 6,
                ),
                child: Icon(
                  page.icon,
                  size: 18,
                  color: active
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// Opens a picker to choose the header icon for [page].
  Future<void> _customizePageIcon(DashPage page) async {
    final selected = await showModalBottomSheet<IconData>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Page icon', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kPageHeaderIcons.map((icon) {
                    final isCurrent = icon == page.icon;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(context).pop(icon),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: isCurrent
                              ? Border.all(
                                  color: theme.colorScheme.primary, width: 2)
                              : null,
                        ),
                        child: Icon(
                          icon,
                          color: isCurrent
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => page.icon = selected);
    }
  }

  /// Builds the positioned control widgets for the given [controls], laid out
  /// by grid cell.
  List<Widget> _buildPlacedControls(List<PlacedControl> controls) {
    return controls.map((control) {
      final left = control.col * _gridSize;
      final top = control.row * _gridSize;
      final width = control.cols * _gridSize;
      final height = control.rows * _gridSize;
      final isSelected = _selectedControlId == control.instanceId;

      final child = ControlWidget(
        control: control,
        isEditMode: _isEditMode,
        isSelected: isSelected,
        onTap: _isEditMode
            ? () => setState(() => _selectedControlId = control.instanceId)
            : null,
        onDelete: () => _deleteControl(control.instanceId),
      );

      return Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: _isEditMode
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPress: () => _showControlMenu(control),
                      onPanStart: (_) => _onControlDragStart(control),
                      onPanUpdate: (details) =>
                          _onControlDragUpdate(control, details.delta),
                      child: child,
                    ),
                  ),
                  // Resize handle (bottom-right), shown when selected.
                  if (isSelected)
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (_) => _onControlResizeStart(control),
                        onPanUpdate: (details) =>
                            _onControlResizeUpdate(control, details.delta),
                        child: _ResizeHandle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              )
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: () => _showControlMenu(control),
                child: child,
              ),
      );
    }).toList();
  }

  Widget _buildMenuPanel() {
    final maxMenuHeight = MediaQuery.of(context).size.height * 0.88;
    return Container(
      key: _menuKey,
      constraints: BoxConstraints(maxHeight: maxMenuHeight),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Draggable handle region: drag up (or fling up) to close.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeMenu,
              onVerticalDragStart: _onCloseDragStart,
              onVerticalDragUpdate: _onCloseDragUpdate,
              onVerticalDragEnd: _onCloseDragEnd,
              child: SizedBox(
                height: 48 + MediaQuery.of(context).padding.top,
                width: double.infinity,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(120),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Menu items — wraps content, scrolls only if it exceeds the cap.
            Flexible(
              child: _MenuContent(
                isEditMode: _isEditMode,
                pageIndex: _currentPage,
                pageCount: _pages.length,
                onToggleEditMode: () => _onMenuAction('toggle_edit'),
                onAddControl: () => _onMenuAction('add_control'),
                onAddPage: () => _onMenuAction('add_page'),
                onDeletePage: () {
                  _closeMenu();
                  _deleteCurrentPage();
                },
                onOpenPreferences: () => _onMenuAction('preferences'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Icon(Icons.grid_on, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Slider(
                value: _gridSize,
                min: 16.0,
                max: 120.0,
                divisions: 26, // step = 4px
                label: '${_gridSize.round()} px',
                onChanged: (value) {
                  setState(() {
                    _gridSize = value;
                  });
                },
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                '${_gridSize.round()}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFeatures: const [ui.FontFeature.tabularFigures()],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuContent extends StatelessWidget {
  final bool isEditMode;
  final int pageIndex;
  final int pageCount;
  final VoidCallback onToggleEditMode;
  final VoidCallback onAddControl;
  final VoidCallback onAddPage;
  final VoidCallback onDeletePage;
  final VoidCallback onOpenPreferences;

  const _MenuContent({
    required this.isEditMode,
    required this.pageIndex,
    required this.pageCount,
    required this.onToggleEditMode,
    required this.onAddControl,
    required this.onAddPage,
    required this.onDeletePage,
    required this.onOpenPreferences,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      // Wrap content height so the panel matches the items (no blank space);
      // scrolls only when the items exceed the panel's max height.
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        SwitchListTile(
          secondary: Icon(_Icons.mode, color: theme.colorScheme.primary),
          title: const Text('Edit Mode'),
          subtitle: Text('Page ${pageIndex + 1} of $pageCount'),
          value: isEditMode,
          onChanged: (_) => onToggleEditMode(),
        ),
        // Control- and page-editing items are only meaningful in edit mode.
        if (isEditMode) ...[
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.add_box_outlined, color: theme.colorScheme.primary),
            title: const Text('Add Control'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: onAddControl,
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.note_add_outlined, color: theme.colorScheme.primary),
            title: const Text('Add Page'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: onAddPage,
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: pageCount > 1
                  ? theme.colorScheme.error
                  : theme.disabledColor,
            ),
            title: Text(
              'Delete Page',
              style: TextStyle(
                color: pageCount > 1
                    ? theme.colorScheme.error
                    : theme.disabledColor,
              ),
            ),
            enabled: pageCount > 1,
            onTap: pageCount > 1 ? onDeletePage : null,
          ),
        ],
        const Divider(height: 1),
        _staticItem(context, _Icons.grid, 'Grid Settings'),
        const Divider(height: 1),
        _staticItem(context, _Icons.palette, 'Theme'),
        const Divider(height: 1),
        _staticItem(context, _Icons.layers, 'Layers'),
        const Divider(height: 1),
        _staticItem(context, _Icons.save, 'Save Project'),
        const Divider(height: 1),
        _staticItem(context, _Icons.folder, 'Open Project'),
        const Divider(height: 1),
        ListTile(
          leading: Icon(_Icons.settings, color: theme.colorScheme.primary),
          title: const Text('Preferences'),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: onOpenPreferences,
        ),
      ],
    );
  }

  Widget _staticItem(BuildContext context, IconData icon, String label) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () {
        // Placeholder: menu item tap
      },
    );
  }
}

// Icon aliases for cleaner table definition
const _Icons = (
  mode: Icons.edit_outlined,
  grid: Icons.grid_4x4,
  palette: Icons.palette_outlined,
  layers: Icons.layers_outlined,
  save: Icons.save_outlined,
  folder: Icons.folder_open_outlined,
  settings: Icons.settings_outlined,
);

/// A small draggable handle used to resize a selected control by its
/// bottom-right corner.
class _ResizeHandle extends StatelessWidget {
  final Color color;

  const _ResizeHandle({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.open_in_full,
        size: 16,
        color: Colors.white,
      ),
    );
  }
}

class DashGridPainter extends CustomPainter {
  final double gridSize;

  DashGridPainter({required this.gridSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(40)
      ..strokeWidth = 0.5;

    final dashPaint = Paint()
      ..color = Colors.white.withAlpha(25)
      ..strokeWidth = 0.5;

    // Draw solid grid lines
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw dashed sub-grid lines at half intervals
    if (gridSize >= 30) {
      final half = gridSize / 2;
      for (double x = half; x <= size.width; x += gridSize) {
        _drawDashedLine(canvas, Offset(x, 0), Offset(x, size.height), dashPaint);
      }
      for (double y = half; y <= size.height; y += gridSize) {
        _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), dashPaint);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 4.0;
    const dashGap = 4.0;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final len = dx == 0 ? dy.abs() : dx.abs();
    final dirX = dx == 0 ? 0.0 : dx.sign;
    final dirY = dy == 0 ? 0.0 : dy.sign;

    double drawn = 0;
    while (drawn < len) {
      final segment = (drawn + dashWidth > len) ? len - drawn : dashWidth;
      final from = Offset(start.dx + drawn * dirX, start.dy + drawn * dirY);
      final to = Offset(
        from.dx + segment * dirX,
        from.dy + segment * dirY,
      );
      canvas.drawLine(from, to, paint);
      drawn += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(DashGridPainter oldDelegate) {
    return gridSize != oldDelegate.gridSize;
  }
}
