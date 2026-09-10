// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'ParaBeacon';

  @override
  String get close => '关闭';

  @override
  String get cancel => '取消';

  @override
  String get clear => '清除';

  @override
  String get delete => '删除';

  @override
  String get save => '保存';

  @override
  String get done => '完成';

  @override
  String get add => '添加';

  @override
  String get preferences => '偏好设置';

  @override
  String get theme => '主题';

  @override
  String get language => '语言';

  @override
  String get varioSoundSettings => '升降音设置';

  @override
  String get gridSize => '网格大小';

  @override
  String get bluetoothSensor => '蓝牙传感器';

  @override
  String get bluetoothSensorSubtitle => '连接外部 BLE 传感器';

  @override
  String get trackRecording => '航迹记录';

  @override
  String get debug => '调试';

  @override
  String get simulatedFlightData => '模拟飞行数据';

  @override
  String get fakeGpsInChina => '在中国伪造 GPS 位置';

  @override
  String get trackRecordingSmart => '智能（默认）';

  @override
  String get trackRecordingEverySecond => '每 1 秒';

  @override
  String get recordMoreInformation => '记录更多信息';

  @override
  String get clearAllControlsTitle => '清除所有控件？';

  @override
  String get clearAllControlsMessage => '这将从仪表盘中移除所有控件，且无法撤销。';

  @override
  String get editMode => '编辑模式';

  @override
  String pageOfPages(int current, int total) {
    return '第 $current 页，共 $total 页';
  }

  @override
  String get addControl => '添加控件';

  @override
  String get addPage => '添加页面';

  @override
  String get deletePage => '删除页面';

  @override
  String get clearAllControls => '清除所有控件';

  @override
  String controlsPlaced(int count) {
    return '已放置 $count 个';
  }

  @override
  String get flights => '飞行记录';

  @override
  String get flightsSubtitle => '已记录的飞行';

  @override
  String get pageIcon => '页面图标';

  @override
  String gridSizePx(int value) {
    return '$value 像素';
  }

  @override
  String get languageSystemDefault => '跟随系统';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChineseSimplified => '简体中文';

  @override
  String get languageSystemDescription => '跟随设备语言';

  @override
  String get languageEnglishDescription => '英语';

  @override
  String get languageChineseSimplifiedDescription => '简体中文';

  @override
  String get languageApplyNote => '更改立即生效，无需重启。你的选择已保存在本设备上。';
}
