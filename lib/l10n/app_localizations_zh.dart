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
  String get varioSoundSettingsSubtitle => '音效、音量、阈值、音高与波形';

  @override
  String get gridSize => '网格大小';

  @override
  String get bluetoothSensor => '蓝牙传感器';

  @override
  String get bluetoothSensorSubtitle => '连接外部 BLE 传感器';

  @override
  String get trackRecording => '航迹记录';

  @override
  String trackRecordingSubtitle(String interval, String detail) {
    return '$interval · $detail';
  }

  @override
  String get recordingIntervalEvery1s => '每 1 秒';

  @override
  String get recordingIntervalSmart => '智能';

  @override
  String get recordingDetailFull => '完整数据';

  @override
  String get recordingDetailXcTrack => 'XCTrack 风格';

  @override
  String get debug => '调试';

  @override
  String get simulatedFlightData => '模拟飞行数据';

  @override
  String get simulatedFlightDataSubtitle => '当没有连接 BLE 设备时输入模拟传感器数值';

  @override
  String get fakeGpsInChina => '在中国伪造 GPS 位置';

  @override
  String get fakeGpsInChinaSubtitle => '在中国上空（成都附近）开始模拟飞行';

  @override
  String get trackRecordingSmart => '智能（默认）';

  @override
  String get trackRecordingSmartSubtitle =>
      '至少间隔 1 秒，且仅在移动 ≥ 3 米或高度变化 ≥ 1 米时记录';

  @override
  String get trackRecordingEverySecond => '每 1 秒';

  @override
  String get trackRecordingEverySecondSubtitle => '无论是否移动，每秒记录一个点';

  @override
  String get trackRecordingChooseHint => '选择飞行过程中记录航迹点的频率。';

  @override
  String get recordMoreInformation => '记录更多信息';

  @override
  String get recordMoreInformationFull =>
      '每个点的完整数据：升降速率、风、气压、温度、GPS 精度、卫星数、电量、心率';

  @override
  String get recordMoreInformationXcTrack =>
      'XCTrack 风格：仅位置、气压/GPS 高度、航向、速度与时间';

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

  @override
  String get themeDarkThemes => '深色主题';

  @override
  String get themeLightThemes => '浅色主题';

  @override
  String get themeHighContrast => '高对比度（WCAG AAA）';

  @override
  String get themeApplyNote =>
      '更改立即生效，无需重启。你的选择已保存在本设备上。\n高对比度主题：纯黑/白背景搭配高饱和度点缀色——适合强烈阳光、缓解眼疲劳以及年长用户。';

  @override
  String get themeDarkCyan => '深青色（默认）';

  @override
  String get themeDarkSlate => '深石板灰';

  @override
  String get themeDarkAmber => '深琥珀色（夜视）';

  @override
  String get themeDarkForest => '深森林绿';

  @override
  String get themeDarkOcean => '深海蓝';

  @override
  String get themeLightSky => '浅天空蓝';

  @override
  String get themeLightSand => '浅沙色';

  @override
  String get themeLightMint => '浅薄荷绿';

  @override
  String get themeLightPaper => '浅纸张色';

  @override
  String get themeLightLavender => '浅薰衣草紫';

  @override
  String get themeDarkContrast => '深色高对比度';

  @override
  String get themeLightContrast => '浅色高对比度';

  @override
  String get themeDarkCyanDesc => '深色底 + 青色点缀（经典默认）';

  @override
  String get themeDarkSlateDesc => '商务深灰 + 蓝紫色点缀';

  @override
  String get themeDarkAmberDesc => '驾驶舱琥珀色，长时间夜航更护眼';

  @override
  String get themeDarkForestDesc => '深森林绿 + 金色阳光';

  @override
  String get themeDarkOceanDesc => '深海蓝紫 + 青珊瑚色';

  @override
  String get themeLightSkyDesc => '阳光下高对比度，最适合白天飞行';

  @override
  String get themeLightSandDesc => '温暖沙色底，长时间使用舒适';

  @override
  String get themeLightMintDesc => '清新薄荷绿，护眼';

  @override
  String get themeLightPaperDesc => '航图纸张风格，怀旧目视飞行';

  @override
  String get themeLightLavenderDesc => '柔和薰衣草 + 深紫，温和护眼';

  @override
  String get themeDarkContrastDesc => '纯黑 + 高饱和黄（WCAG AAA）';

  @override
  String get themeLightContrastDesc => '纯白 + 黑 + 深蓝（WCAG AAA）';

  @override
  String get controlKindData => '数据控件';

  @override
  String get controlKindWidget => '组件控件';

  @override
  String get controlAltitude => '海拔';

  @override
  String get controlMaxAltitude => '最高海拔';

  @override
  String get controlVerticalSpeed => '升降速率';

  @override
  String get controlGroundSpeed => '地速';

  @override
  String get controlGlide => '滑翔比';

  @override
  String get controlHeading => '航向';

  @override
  String get controlLocation => '位置';

  @override
  String get controlWindSpeed => '风速';

  @override
  String get controlWindDirection => '风向';

  @override
  String get controlPressure => '气压';

  @override
  String get controlTemperature => '温度';

  @override
  String get controlClock => '时钟';

  @override
  String get controlFlightTime => '飞行时间';

  @override
  String get controlSensorBattery => '传感器电量';

  @override
  String get controlHeartRate => '心率';

  @override
  String get controlVario => '升降音';

  @override
  String get controlDebugSensor => '调试传感器';

  @override
  String get controlDataMonitor => '数据监视器';

  @override
  String get controlMap => '地图';

  @override
  String get controlFlightButton => '飞行按钮';

  @override
  String get controlUnknown => '未知';

  @override
  String controlSettingsTitle(String control) {
    return '$control 设置';
  }

  @override
  String get searchControls => '搜索控件';

  @override
  String get noControlsAvailable => '暂无可用控件';

  @override
  String noControlsMatch(String query) {
    return '没有与“$query”匹配的控件';
  }

  @override
  String get noControlsInDirectory => '此目录中暂无控件';

  @override
  String get settings => '设置';

  @override
  String get duplicate => '复制';

  @override
  String get bringToFront => '移到顶层';

  @override
  String get sendToBack => '移到底层';

  @override
  String get controlNoSettings => '此控件没有可设置项。';

  @override
  String get controlGpsAltitude => 'GPS 高度';

  @override
  String get controlBaroAltitude => '气压高度';

  @override
  String get controlWindDir => '风向';

  @override
  String get locationNoFix => '无 GPS 定位';

  @override
  String get flightButtonStart => '开始';

  @override
  String get flightButtonStop => '停止';

  @override
  String get flightButtonAuto => '自动';

  @override
  String get flightButtonAutoTooltip => '自动检测起飞 / 降落';

  @override
  String flightRecordingReadout(int points, String km) {
    return '记录中 · $points 点 · $km km';
  }

  @override
  String get settingShowTitle => '显示标题';

  @override
  String get settingShowBorder => '显示边框';

  @override
  String get settingBorderColor => '边框颜色';

  @override
  String get settingBorderWidth => '边框宽度';

  @override
  String get settingCornerRadius => '圆角半径';

  @override
  String get settingControlOpacity => '控件不透明度';

  @override
  String get settingBackgroundColor => '背景颜色';

  @override
  String get settingBackgroundOpacity => '背景不透明度';

  @override
  String get settingTextColor => '文字颜色';

  @override
  String get settingScaleMax => '量程（最大值）';

  @override
  String get settingAveragingInterval => '平均时长';

  @override
  String get settingCoordinateFormat => '坐标格式';

  @override
  String get settingCoordinateDecimal => '十进制度';

  @override
  String get settingCoordinateDms => '度 / 分 / 秒';

  @override
  String get settingAltitudeSource => '高度来源';

  @override
  String get settingAltitudeSourceAuto => '自动（优先气压）';

  @override
  String get settingAltitudeSourceGps => 'GPS 高度';

  @override
  String get settingAltitudeSourceBaro => '气压高度';

  @override
  String get settingFormat => '格式';

  @override
  String get settingFormatDegrees => '度数（0-360°）';

  @override
  String get settingFormatCardinal => '方位（N、NE …）';

  @override
  String get settingShowSeconds => '显示秒';

  @override
  String get settingShowAutoDetect => '显示自动检测复选框';

  @override
  String get settingFollowPosition => '跟随位置';

  @override
  String get settingZoom => '缩放';

  @override
  String get settingMapSource => '地图源';

  @override
  String get settingMapSourceNone => '无（无底图）';

  @override
  String get settingMapSourceOsm => 'OpenStreetMap';

  @override
  String get settingMapSourceOsmFr => 'OSM 法国';

  @override
  String get settingMapSourceCartoDark => 'Carto 暗色';

  @override
  String get settingMapSourceCartoVoyager => 'Carto Voyager';

  @override
  String get settingMapSourceAmap => '高德地图';

  @override
  String get settingMapSourceAmapSat => '高德卫星';

  @override
  String get settingRotation => '旋转';

  @override
  String get settingRotationNorth => '上方为北';

  @override
  String get settingRotationTrack => '航向朝上';

  @override
  String get settingShowNorth => '显示北方向';

  @override
  String get settingPilotArrowSize => '飞行员箭头大小';

  @override
  String get settingLineThickness => '线条粗细';

  @override
  String get settingTracklogLength => '航迹长度（0 = 全部）';

  @override
  String get settingLatestThermals => '显示最近 N 个热气流';

  @override
  String get settingPreferOffline => '优先离线地图（.mbtiles）';

  @override
  String get settingShowTrack => '显示飞行航迹';

  @override
  String get settingShowThermal => '显示热气流助手';

  @override
  String get settingWindAlgorithm => '在计算中考虑风';

  @override
  String get settingWindAlgorithmNone => '无';

  @override
  String get settingWindAlgorithmClassic => '经典';

  @override
  String get settingWindAlgorithmParticle => '粒子漂移';

  @override
  String get settingShowWind => '显示风';

  @override
  String get settingShowSun => '显示太阳位置';

  @override
  String get settingShowBearing => '显示方位（航线）线';

  @override
  String get settingShowScale => '显示地图比例尺';

  @override
  String get settingShowAirspace => '显示空域';

  @override
  String get settingShowLegend => '显示升降音图例';

  @override
  String get settingShowZoomLevel => '显示缩放级别';

  @override
  String get settingShowAttribution => '显示地图来源标注';

  @override
  String get settingShowStatus => '显示航向/高度与 GPS 状态';

  @override
  String get dataMonitorTitle => '数据监视器';

  @override
  String get dataMonitorLive => '实时';

  @override
  String get dataMonitorFix => '定位';

  @override
  String get dataMonitorYes => '是';

  @override
  String get dataMonitorNo => '否';

  @override
  String get dataMonitorVerticalSpeed => '升降速率';

  @override
  String get dataMonitorGroundSpeed => '地速';

  @override
  String get dataMonitorAltitude => '海拔';

  @override
  String get dataMonitorBaroAltitude => '气压高度';

  @override
  String get dataMonitorGpsAltitude => 'GPS 高度';

  @override
  String get dataMonitorLatitude => '纬度';

  @override
  String get dataMonitorLongitude => '经度';

  @override
  String get dataMonitorHeading => '航向';

  @override
  String get dataMonitorBearing => '方位';

  @override
  String get dataMonitorGpsAccuracy => 'GPS 精度';

  @override
  String get dataMonitorSatellites => '卫星数';

  @override
  String get dataMonitorWindSpeed => '风速';

  @override
  String get dataMonitorWindDirection => '风向';

  @override
  String get dataMonitorPressure => '气压';

  @override
  String get dataMonitorTemperature => '温度';

  @override
  String get dataMonitorBattery => '电量';

  @override
  String get dataMonitorHeartRate => '心率';

  @override
  String get dataMonitorTimestamp => '时间戳';

  @override
  String get dataMonitorDerived => '衍生数据';

  @override
  String get dataMonitorGlideRatio => '滑翔比';

  @override
  String get dataMonitorWindDir => '风向';

  @override
  String get dataMonitorBaroGpsDelta => '气压−GPS Δ';

  @override
  String get dataMonitorTotalEnergy => '总能量';
}
