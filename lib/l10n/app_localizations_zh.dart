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
  String get edit => '编辑';

  @override
  String get refresh => '刷新';

  @override
  String get submit => '提交';

  @override
  String get preferences => '偏好设置';

  @override
  String get about => '关于';

  @override
  String get aboutSubtitle => '应用详情、版本与许可证';

  @override
  String get aboutDescription => '一款跨平台滑翔伞飞行助手，提供实时升降音、蓝牙低功耗传感器、地图和飞行记录功能。';

  @override
  String get aboutApplicationDetails => '应用详情';

  @override
  String get aboutVersion => '版本';

  @override
  String get aboutBuildNumber => '构建号';

  @override
  String get aboutPackageId => '应用包名';

  @override
  String get aboutPlatform => '运行平台';

  @override
  String get aboutAuthor => '作者';

  @override
  String get aboutPlatformWeb => '网页';

  @override
  String get aboutPlatformAndroid => 'Android';

  @override
  String get aboutPlatformIos => 'iOS';

  @override
  String get aboutPlatformLinux => 'Linux';

  @override
  String get aboutPlatformMacos => 'macOS';

  @override
  String get aboutPlatformWindows => 'Windows';

  @override
  String get aboutPlatformFuchsia => 'Fuchsia';

  @override
  String get aboutOpenSourceLicenses => '开源许可证';

  @override
  String get aboutOpenSourceLicensesSubtitle => '查看本应用及其依赖项的许可证';

  @override
  String get aboutLoading => '正在加载应用详情…';

  @override
  String get aboutSphereTitle => '贡献者';

  @override
  String get aboutSphereHint => '拖动即可旋转 · 球体也会缓慢自动转动';

  @override
  String get aboutSphereSemantics => '可交互的 3D 信息球体。';

  @override
  String get preferencesSectionAccountFlight => '账户与飞行';

  @override
  String get preferencesSectionMapDisplay => '地图与显示';

  @override
  String get preferencesSectionSensorsRecording => '传感器与记录';

  @override
  String get preferencesSectionAudio => '声音与播报';

  @override
  String get interfaceConfiguration => '仪表盘布局';

  @override
  String get interfaceConfigurationImport => '导入仪表盘布局';

  @override
  String get interfaceConfigurationExport => '导出仪表盘布局';

  @override
  String get interfaceConfigurationImportTitle => '替换仪表盘布局？';

  @override
  String get interfaceConfigurationImportConfirmation =>
      '导入的布局将替换所有仪表盘页面和控件；不会更改主题、语言、账户设置或飞行记录。';

  @override
  String get interfaceConfigurationImported => '仪表盘布局已导入。';

  @override
  String get interfaceConfigurationImportFailed => '无法导入此仪表盘布局，请检查文件是否有效且兼容。';

  @override
  String get interfaceConfigurationExported => '仪表盘布局已准备好分享。';

  @override
  String get interfaceConfigurationExportFailed => '无法导出仪表盘布局。';

  @override
  String get units => '单位';

  @override
  String get unitsSubtitle => '选择仪表控件的默认单位';

  @override
  String get displaySettings => '显示设置';

  @override
  String get displaySettingsSubtitle => '配置数值的默认精度';

  @override
  String get defaultPrecision => '默认精度';

  @override
  String get defaultPrecisionDescription =>
      '开启时，GPS 精度、高度、速度、爬升/下降率和风速默认显示 1 位小数；关闭时默认显示整数。自定义精度不受影响。';

  @override
  String get largerFont => '更大字体';

  @override
  String get largerFontDescription => '放大仪表盘数值读数，并缩小控件内部间距。';

  @override
  String get otherSettings => '其他设置';

  @override
  String get otherSettingsSubtitle => '更多偏好设置';

  @override
  String get shareCardFlatDesign => '扁平风格分享卡片';

  @override
  String get shareCardFlatDesignSubtitle => '使用扁平设计，而不是玻璃风格';

  @override
  String get unitAltitude => '高度';

  @override
  String get unitSpeed => '速度';

  @override
  String get unitVerticalSpeed => '垂直速度';

  @override
  String get unitDistance => '距离';

  @override
  String get unitPressure => '气压';

  @override
  String get unitTemperature => '温度';

  @override
  String get settingDisplayUnit => '显示单位';

  @override
  String get settingUnitDefault => '使用偏好设置中的默认值';

  @override
  String get unitMeters => '米（m）';

  @override
  String get unitFeet => '英尺（ft）';

  @override
  String get unitKilometersPerHour => '千米/时（km/h）';

  @override
  String get unitMetersPerSecond => '米/秒（m/s）';

  @override
  String get unitMilesPerHour => '英里/时（mph）';

  @override
  String get unitKnots => '节（kn）';

  @override
  String get unitFeetPerMinute => '英尺/分钟（ft/min）';

  @override
  String get unitAutomaticDistance => '自动（m/km）';

  @override
  String get unitKilometers => '千米（km）';

  @override
  String get unitMiles => '英里（mi）';

  @override
  String get unitHectopascals => '百帕（hPa）';

  @override
  String get unitInchesOfMercury => '英寸汞柱（inHg）';

  @override
  String get unitCelsius => '摄氏度（°C）';

  @override
  String get unitFahrenheit => '华氏度（°F）';

  @override
  String get accounts => '账户';

  @override
  String get accountsSubtitle => '管理 ASFC 和 XContest 账户';

  @override
  String get aircraft => '飞行器';

  @override
  String get aircraftSubtitle => '配置飞行器类型、机型和飞行性能';

  @override
  String get liveTracking => '实时追踪';

  @override
  String get liveTrackingSubtitle => '通过 XContest 分享实时飞行位置';

  @override
  String get liveTrackingEnabled => '启用实时追踪';

  @override
  String get liveTrackingEnabledSubtitle => '将正在进行的飞行发送到 XContest';

  @override
  String get liveTrackingRequiresXContest => '请先登录 XContest 才能启用实时追踪。';

  @override
  String get liveTrackingClaimContest => '认领竞赛飞行';

  @override
  String get liveTrackingClaimContestSubtitle => '将飞行认领到 XContest 竞赛中';

  @override
  String get liveTrackingShowPublic => '显示公开追踪';

  @override
  String get liveTrackingShowPublicSubtitle => '允许他人公开查看实时位置';

  @override
  String get liveTrackingFlightPublic => '公开飞行';

  @override
  String get liveTrackingFlightPublicSubtitle => '在 XContest 发布已完成的飞行';

  @override
  String get liveTrackingTemporaryDisable => '暂时停止分享';

  @override
  String get liveTrackingTemporaryDisableSubtitle => '暂停实时追踪，但不修改主开关';

  @override
  String get liveTrackingTemporarilyDisabled => '实时追踪已暂时暂停。';

  @override
  String get liveTrackingReady => '实时追踪已配置并准备就绪。';

  @override
  String get aircraftFaiClass => 'FAI级别';

  @override
  String get aircraftFaiParaglider => '滑翔伞(FAI-3)';

  @override
  String get aircraftFaiHangGlider => '滑翔翼(FAI-1)';

  @override
  String get aircraftFaiRigidWing => '硬翼（FAI-5）';

  @override
  String get aircraftFaiRigidWingFai2 => '硬翼（FAI-2）';

  @override
  String get aircraftFaiPoweredParagliderFoot => '动力伞 - 助跑起飞(RPF)';

  @override
  String get aircraftFaiPoweredParagliderTrike => '动力伞 - 三轮式启动(RPL)';

  @override
  String get aircraftFaiPoweredAircraft => 'RAL（飞机/操纵杆控制）';

  @override
  String get aircraftFaiRigidWingPowered => 'RWL（飞机/移动重心控制）';

  @override
  String get aircraftFaiRigidWingFootLaunched => 'RWF（助跑起飞/移动重心控制）';

  @override
  String get aircraftFaiRigidGlider => 'RGL（飞机/旋翼机）';

  @override
  String get aircraftCategoryStandard => '标准级';

  @override
  String get aircraftCategoryPerformance => '性能级';

  @override
  String get aircraftCategoryCompetition => '竞赛级';

  @override
  String get aircraftCategoryFlexWing => '柔性翼';

  @override
  String get aircraftCategoryRigidWing => '刚性翼';

  @override
  String get aircraftCategoryClass1 => '1 类';

  @override
  String get aircraftCategoryClass5 => '5 类';

  @override
  String get aircraftManufacturer => '制造商';

  @override
  String get aircraftSelectManufacturer => '选择制造商';

  @override
  String get aircraftModel => '型号';

  @override
  String get aircraftSelectModel => '选择型号';

  @override
  String get aircraftName => '飞行器名称';

  @override
  String get aircraftParagliderCategory => '滑翔伞类别';

  @override
  String get aircraftHangGliderCategory => '滑翔翼类别';

  @override
  String get aircraftTandem => '双人座 / 载客飞行';

  @override
  String get aircraftTandemSubtitle => '该飞行器用于搭载两人';

  @override
  String get aircraftEngineType => '发动机类型';

  @override
  String get aircraftEngineNone => '无';

  @override
  String get aircraftEngineElectric => '电动';

  @override
  String get aircraftEngineInternalCombustion => '内燃机';

  @override
  String get aircraftTrimSpeed => '配平速度（km/h）';

  @override
  String get aircraftGoalGlideRatio => '目标滑翔比';

  @override
  String get aircraftPositiveNumberRequired => '请输入正数。';

  @override
  String get aircraftSave => '保存飞行器';

  @override
  String get flightDetailAircraft => '飞行器';

  @override
  String get flightDetailAircraftEdit => '编辑飞行器';

  @override
  String get flightDetailAircraftClass => 'FAI级别';

  @override
  String get flightDetailAircraftManufacturer => '制造商';

  @override
  String get flightDetailAircraftModel => '型号';

  @override
  String get flightDetailAircraftName => '飞行器名称';

  @override
  String get flightDetailAircraftCategory => '类别';

  @override
  String get flightDetailAircraftTandem => '双人座';

  @override
  String get flightDetailAircraftEngine => '发动机';

  @override
  String get flightDetailAircraftTrimSpeed => '配平速度';

  @override
  String get flightDetailAircraftGlideRatio => '目标滑翔比';

  @override
  String get aircraftTandemYes => '是';

  @override
  String get aircraftTandemNo => '否';

  @override
  String get notSet => '未设置';

  @override
  String get saving => '保存中…';

  @override
  String get asfcAccount => 'ASFC 账户';

  @override
  String get asfcAccountSubtitle => '使用 ASFC / GoFly 账户登录';

  @override
  String get xcontestAccount => 'XContest 账户';

  @override
  String get xcontestAccountSubtitle => '使用 XContest 账户登录';

  @override
  String get xcontestUsername => '用户名';

  @override
  String get xcontestPassword => '密码';

  @override
  String get xcontestUserId => '用户 ID';

  @override
  String get xcontestFullName => '姓名';

  @override
  String get xcontestProfileInformation => '账户信息';

  @override
  String get xcontestSignedIn => '已登录 XContest';

  @override
  String get xcontestCredentialsRequired => '请输入 XContest 用户名和密码。';

  @override
  String get xcontestInvalidCredentials => 'XContest 用户名或密码不正确。';

  @override
  String get xcontestConnectionFailed => '无法连接 XContest，请检查网络后重试。';

  @override
  String get xcontestLoginFailed => 'XContest 登录失败，请重试。';

  @override
  String get asfcUsername => '用户名或手机号';

  @override
  String get asfcPassword => '密码';

  @override
  String get asfcPasswordLogin => '密码登录';

  @override
  String get asfcSmsLogin => '验证码登录';

  @override
  String get asfcMobile => '手机号';

  @override
  String get asfcSmsCode => '短信验证码';

  @override
  String get asfcCaptcha => '图形验证码';

  @override
  String get asfcRefreshCaptcha => '刷新图形验证码';

  @override
  String get asfcSendSmsCode => '发送验证码';

  @override
  String asfcSmsCountdown(int seconds) {
    return '$seconds 秒后重试';
  }

  @override
  String get asfcMobileRequired => '请输入手机号。';

  @override
  String get asfcCaptchaRequired => '请输入图形验证码。';

  @override
  String get asfcSmsCodeRequired => '请输入短信验证码。';

  @override
  String get asfcSmsCredentialsRequired => '请输入手机号和短信验证码。';

  @override
  String get asfcCaptchaLoadFailed => '图形验证码加载失败。';

  @override
  String get asfcSmsCodeSendFailed => '短信验证码发送失败。';

  @override
  String get login => '登录';

  @override
  String get loggingIn => '正在登录…';

  @override
  String get logout => '退出登录';

  @override
  String get asfcSignedIn => '已登录';

  @override
  String get asfcProfileInformation => '账户信息';

  @override
  String get asfcRefreshProfile => '刷新账户信息';

  @override
  String get asfcProfileLoadFailed => '账户信息加载失败。';

  @override
  String get asfcNoProfileInformation => '暂无账户信息。';

  @override
  String get asfcInformationAvailable => '已提供';

  @override
  String get applyForCertificate => '申请证书';

  @override
  String get certificateDetails => '证书详情';

  @override
  String get certificateDetailsView => '详情';

  @override
  String get certificateCardView => '卡片';

  @override
  String get certificateSwipeHint => '左右滑动切换视图';

  @override
  String get certificateCardTitle => '航空运动飞行员执照';

  @override
  String get certificateIssued => '已持有';

  @override
  String get certificatePendingApproval => '待审核';

  @override
  String get certificatePendingApprovalSubtitle => '您的证书申请正在审核中。';

  @override
  String get certificateNumber => '证书编号';

  @override
  String get certificateLevel => '等级';

  @override
  String get certificateSportCode => '运动编码';

  @override
  String get certificateValidityStatus => '证书状态';

  @override
  String get certificateValidity => '有效期';

  @override
  String get certificateIssueDate => '签发日期';

  @override
  String get certificatePhoto => '照片';

  @override
  String get certificateUpgrade => '执照升级';

  @override
  String get certificateSignInList => '签注列表';

  @override
  String get certificateSignInDate => '签注日期';

  @override
  String get certificateReviewUnit => '审核人';

  @override
  String get certificateNoSignIns => '暂无签注记录';

  @override
  String get asfcFlightRecords => 'ASFC 飞行记录';

  @override
  String get asfcFlightSubmit => '提交飞行记录';

  @override
  String get asfcFlightEdit => '编辑飞行记录';

  @override
  String get asfcFlightDetails => '飞行记录详情';

  @override
  String get asfcFlightNoRecords => '暂无 ASFC 飞行记录';

  @override
  String get asfcFlightDate => '训练日期';

  @override
  String get asfcFlightAddress => '训练地点';

  @override
  String get asfcFlightModel => '机型';

  @override
  String get asfcFlightTask => '飞行任务';

  @override
  String get asfcFlightStartTime => '开始时间';

  @override
  String get asfcFlightEndTime => '结束时间';

  @override
  String get asfcFlightTime => '飞行时间';

  @override
  String get asfcFlightSeatType => '座位类型';

  @override
  String get asfcFlightFrontSeat => '前座';

  @override
  String get asfcFlightBackSeat => '后座';

  @override
  String get asfcFlightTakeoffMode => '起飞方式';

  @override
  String get asfcFlightSortie => '起落次数';

  @override
  String get asfcFlightAgency => '培训机构';

  @override
  String get asfcFlightCoach => '教练员';

  @override
  String get asfcFlightSignin => '教练签到备注';

  @override
  String get asfcFlightSelectAgency => '请选择培训机构';

  @override
  String get asfcFlightSelectCoach => '请选择教练员';

  @override
  String get asfcFlightLoading => '加载中…';

  @override
  String get asfcFlightRequired => '此项为必填项。';

  @override
  String get asfcFlightSelectionRequired => '请选择培训机构、教练员和起飞方式。';

  @override
  String get asfcFlightSaveFailed => '飞行记录保存失败。';

  @override
  String get asfcFlightDeleted => '飞行记录已删除。';

  @override
  String get asfcFlightDeleteFailed => '飞行记录删除失败。';

  @override
  String get asfcFlightDeleteTitle => '删除飞行记录？';

  @override
  String get asfcFlightDeleteConfirmation => '此飞行记录将被永久删除。';

  @override
  String get certificateApplication => 'ASFC 证书申请';

  @override
  String get certificateApplicationSubtitle => '通过 ASFC 账户提交伞翼执照申请。';

  @override
  String get certificateFullName => '姓名';

  @override
  String get certificateGender => '性别';

  @override
  String get certificateMale => '男';

  @override
  String get certificateFemale => '女';

  @override
  String get certificateBirthday => '出生日期';

  @override
  String get certificateCountry => '国籍';

  @override
  String get certificateEthnicity => '民族';

  @override
  String get certificateIdNumber => '身份证号';

  @override
  String get certificateMobile => '手机号';

  @override
  String get certificateEmail => '邮箱';

  @override
  String get certificateAddress => '地址';

  @override
  String get certificateArea => '常住地';

  @override
  String get certificateAgency => '培训机构';

  @override
  String get certificateCoachId => '教练 ID（可选）';

  @override
  String get certificateCoach => '教练';

  @override
  String get certificateCoachSelect => '请选择教练（可选）';

  @override
  String get certificateCoachesLoading => '正在加载教练列表…';

  @override
  String get certificateDocuments => '证明材料';

  @override
  String get licensePhoto => '上传执照照片';

  @override
  String get groupPhoto => '上传培训合照';

  @override
  String get licensePhotoUploaded => '执照照片已上传';

  @override
  String get groupPhotoUploaded => '培训合照已上传';

  @override
  String get certificateEmergencyContact => '紧急联系人';

  @override
  String get certificateContactName => '联系人姓名';

  @override
  String get certificateContactPhone => '联系人电话';

  @override
  String get certificateBloodType => '血型';

  @override
  String get certificateRequired => '此项为必填项。';

  @override
  String get certificatePhotoRequired => '请先上传两张证件照片。';

  @override
  String get certificateNotSignedIn => '请先登录 ASFC 账户。';

  @override
  String get certificateImageInvalid => '请选择小于 10 MB 的图片。';

  @override
  String get certificateImageUploadFailed => '图片上传失败。';

  @override
  String get certificateApplicationFailed => '证书申请失败。';

  @override
  String get certificateApplicationSuccess => '证书申请已提交。';

  @override
  String get submitApplication => '提交申请';

  @override
  String get submitting => '提交中…';

  @override
  String get asfcLoginFailed => '登录失败，请检查账户信息。';

  @override
  String asfcLoginFailedWithReason(String reason) {
    return '登录失败：$reason';
  }

  @override
  String get asfcConnectionFailed => '无法连接，请检查网络后重试。';

  @override
  String get asfcCredentialsRequired => '请输入用户名和密码。';

  @override
  String get showPassword => '显示密码';

  @override
  String get hidePassword => '隐藏密码';

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
  String get bluetoothSensor => '传感器';

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
  String get autoDeleteShortFlights => '自动删除短时飞行记录';

  @override
  String get autoDeleteShortFlightsSubtitle => '删除飞行时长短于所选时间的已完成记录';

  @override
  String get shortFlightThreshold => '保留记录的最短飞行时长';

  @override
  String get shortFlightThreshold30Seconds => '30 秒';

  @override
  String get shortFlightThreshold1Minute => '1 分钟';

  @override
  String get shortFlightThreshold2Minutes => '2 分钟';

  @override
  String get shortFlightThreshold5Minutes => '5 分钟';

  @override
  String get deleteExistingShortFlightsTitle => '删除短时飞行记录？';

  @override
  String deleteExistingShortFlightsMessage(int count, String duration) {
    return '现有 $count 条飞行记录的时长短于 $duration。是否立即删除？此操作无法撤销。';
  }

  @override
  String get keep => '保留';

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
  String get tools => '工具';

  @override
  String get weather => '天气';

  @override
  String get weatherSubtitle => '所在位置的天气预报';

  @override
  String get weatherRefresh => '刷新';

  @override
  String get weatherNow => '现在';

  @override
  String get weatherToday => '今天';

  @override
  String get weatherHourly => '未来 24 小时';

  @override
  String get weatherDaily => '5 日预报';

  @override
  String weatherFeelsLike(int temp) {
    return '体感 $temp°';
  }

  @override
  String get weatherWind => '风';

  @override
  String weatherSpeedKmh(int speed) {
    return '$speed 公里/小时';
  }

  @override
  String weatherGustsKmh(int speed) {
    return '阵风 $speed 公里/小时';
  }

  @override
  String weatherGustsShort(int speed) {
    return '阵 $speed';
  }

  @override
  String weatherPrecipProbability(int percent) {
    return '降水概率 $percent%';
  }

  @override
  String get weatherHumidity => '湿度';

  @override
  String get weatherCloudCover => '云量';

  @override
  String get weatherPrecipitation => '降水';

  @override
  String get weatherPressure => '气压';

  @override
  String get weatherNoGps => '尚未获得 GPS 定位。请开启定位服务后重试。';

  @override
  String get weatherLoadFailed => '天气预报加载失败。请检查网络连接后重试。';

  @override
  String get weatherRetry => '重试';

  @override
  String get weatherDataBy => '数据来源 Open-Meteo';

  @override
  String get weatherConditionClear => '晴';

  @override
  String get weatherConditionMainlyClear => '基本晴朗';

  @override
  String get weatherConditionPartlyCloudy => '多云';

  @override
  String get weatherConditionOvercast => '阴';

  @override
  String get weatherConditionFog => '雾';

  @override
  String get weatherConditionDrizzle => '毛毛雨';

  @override
  String get weatherConditionRain => '雨';

  @override
  String get weatherConditionFreezing => '冻雨';

  @override
  String get weatherConditionSnow => '雪';

  @override
  String get weatherConditionShowers => '阵雨';

  @override
  String get weatherConditionThunder => '雷暴';

  @override
  String get weatherConditionUnknown => '未知';

  @override
  String get weatherSearchHint => '搜索城市或地点…';

  @override
  String get weatherSearchFailed => '搜索失败，请检查网络连接。';

  @override
  String get weatherNoResults => '没有匹配的地点';

  @override
  String get weatherTabDaily => '每日';

  @override
  String get weatherRowHours => '时间';

  @override
  String get weatherRowTemperature => '温度';

  @override
  String get weatherRowRain => '雨量';

  @override
  String get weatherRowWind => '风速';

  @override
  String get weatherRowGusts => '阵风';

  @override
  String get weatherRowWindDir => '风向';

  @override
  String get weatherModel => '预报模式';

  @override
  String get weatherPastDays => '历史天数';

  @override
  String get weatherPastDaysOff => '关闭';

  @override
  String weatherPastDaysShort(int days) {
    return '$days 天';
  }

  @override
  String get weatherPickOnMap => '地图选点';

  @override
  String get weatherFavorites => '收藏地点';

  @override
  String get weatherFavoriteAdd => '收藏该位置';

  @override
  String get weatherFavoriteRemove => '取消收藏';

  @override
  String get weatherFavoriteRename => '重命名';

  @override
  String get weatherFavoriteName => '名称';

  @override
  String weatherFavoriteSaved(String name) {
    return '已收藏“$name”';
  }

  @override
  String get weatherFavoriteRemoved => '已从收藏中移除';

  @override
  String get weatherFavoritesEmpty => '还没有收藏的地点';

  @override
  String get weatherFavoritesManage => '管理收藏地点';

  @override
  String get mapPickerTitle => '选择位置';

  @override
  String get mapPickerHint => '拖动地图将十字准心对准目标位置，然后确认。';

  @override
  String get mapPickerConfirm => '使用该位置';

  @override
  String get mapPickerMyLocation => '我的位置';

  @override
  String get weatherUnits => '单位';

  @override
  String get weatherUnitTemperature => '温度';

  @override
  String get weatherUnitWindSpeed => '风速';

  @override
  String get weatherUnitPrecipitation => '降水量';

  @override
  String get weatherSunrise => '日出';

  @override
  String get weatherSunset => '日落';

  @override
  String get weatherVisibility => '能见度';

  @override
  String get weatherSoilTemp => '土壤温度';

  @override
  String get weatherSoilMoisture => '土壤湿度';

  @override
  String get weatherRadiation => '辐射';

  @override
  String get weatherEt0 => 'ET₀ 参考蒸散量';

  @override
  String get weatherCape => 'CAPE 对流能量';

  @override
  String get weatherSnowfall => '降雪';

  @override
  String get weatherRain => '降雨';

  @override
  String get weatherCloudLow => '低云';

  @override
  String get weatherCloudMid => '中云';

  @override
  String get weatherCloudHigh => '高云';

  @override
  String get weatherHourlyDetail => '逐小时详情';

  @override
  String get weatherForecastDaily => '每日预报';

  @override
  String weatherWindSpeedAt(String time) {
    return '风速 · $time';
  }

  @override
  String get weatherUpperWinds => '高空风';

  @override
  String get weatherWind80m => '80 米风';

  @override
  String get weatherWind120m => '120 米风';

  @override
  String weatherAltitudeMeters(int meters) {
    return '$meters 米';
  }

  @override
  String weatherSourceBy(String source) {
    return '数据来源：$source';
  }

  @override
  String weatherFallbackNotice(String source) {
    return '$source 不可用 — 已由备用数据源提供';
  }

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
  String get controlClimbAverage => '平均爬升';

  @override
  String get controlTakeoffWaypoint => '起飞点导航';

  @override
  String get controlDefaultLandingWaypoint => '默认降落点';

  @override
  String get controlLastLandingWaypoint => '最近降落点';

  @override
  String get takeoffPointLabel => '起飞点';

  @override
  String get takeoffDistanceLabel => '距离';

  @override
  String get takeoffAltitudeDifferenceLabel => '高度差';

  @override
  String get waypointBearingLabel => '方位';

  @override
  String get waypointGlideLabel => '滑比';

  @override
  String get waypointEtaLabel => '预计';

  @override
  String get climbAverageLabel => '平均爬升';

  @override
  String get peakLabel => '峰值';

  @override
  String get controlVerticalGraph => '垂直图表';

  @override
  String get controlAltitude => '海拔';

  @override
  String get controlGpsAltitude => 'GPS 高度';

  @override
  String get controlBaroAltitude => '气压高度';

  @override
  String get controlAltitudeAboveTakeoff => '相对起飞点高度';

  @override
  String get controlMaxAltitude => '最高海拔';

  @override
  String get controlThermalGain => '热气流爬升';

  @override
  String get controlLastThermalGain => '上次热气流爬升';

  @override
  String get controlVerticalSpeed => '升降速率';

  @override
  String get controlGroundSpeed => '地速';

  @override
  String get controlGlide => '滑翔比';

  @override
  String get controlHeading => '航向';

  @override
  String get controlGpsAccuracy => 'GPS 精度';

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
  String get controlAirTime => '空中时间';

  @override
  String get controlDistanceToTakeoff => '距起飞点距离';

  @override
  String get controlDistanceToNearestLanding => '距最近降落点距离';

  @override
  String get controlDistanceToDefaultLanding => '距默认降落点距离';

  @override
  String get controlBearingToNearestLanding => '至最近降落点方位';

  @override
  String get controlBearingToDefaultLanding => '至默认降落点方位';

  @override
  String get controlSunrise => '日出';

  @override
  String get controlSunset => '日落';

  @override
  String get controlStatusLine => '状态栏';

  @override
  String get controlCompassWind => '罗盘与风向';

  @override
  String get controlSensorBattery => '传感器电量';

  @override
  String get controlPhoneBattery => '手机电量';

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
  String get controlWindDir => '风向';

  @override
  String get locationNoFix => '无 GPS 定位';

  @override
  String get mapNoBasemap => '无底图';

  @override
  String mapOffline(String filename) {
    return '离线 · $filename';
  }

  @override
  String get mapOfflineNoFilename => '离线';

  @override
  String get mapRecenterTooltip => '重新居中';

  @override
  String get mapZoomInTooltip => '放大';

  @override
  String get mapZoomOutTooltip => '缩小';

  @override
  String get mapCacheTitle => '地图缓存数据';

  @override
  String get mapCacheSubtitle => '按地图源显示已缓存的数据块，并提供汇总。';

  @override
  String get mapCacheSummary => '总计';

  @override
  String get mapCacheLegacySource => '未分类的旧缓存';

  @override
  String get mapCacheClearTitle => '清除地图缓存？';

  @override
  String get mapCacheClearConfirmation => '将删除已下载的在线地图数据块，不会影响 .mbtiles 离线地图。';

  @override
  String get mapCacheCleared => '地图缓存已清除。';

  @override
  String get mapCacheClearFailed => '无法清除地图缓存。';

  @override
  String get mapCacheSizeLoading => '正在统计地图缓存数据…';

  @override
  String get mapCacheSizeUnavailable => '暂时无法读取地图缓存数据';

  @override
  String mapCacheSizeDetails(String size, int tiles, int bytes) {
    return '$size · $tiles 个数据块 · $bytes 字节';
  }

  @override
  String get mapHeading => '航向';

  @override
  String get mapAltitude => '高度';

  @override
  String get mapRequiredGlideRatio => '所需滑翔比';

  @override
  String get varioLegendSink => '下沉';

  @override
  String get varioLegendNeutral => '中性';

  @override
  String get varioLegendLift => '上升';

  @override
  String get gpsNotificationTitle => 'ParaBeacon — 正在记录飞行';

  @override
  String get gpsNotificationText => '屏幕关闭时仍在记录飞行轨迹。点按以返回。';

  @override
  String get gpsNotificationChannel => '飞行记录';

  @override
  String get debugSensorTitle => '传感器调试';

  @override
  String get debugSensorReset => '重置';

  @override
  String get debugSensorVerticalSpeed => '垂直速度';

  @override
  String get debugSensorAltitude => '高度';

  @override
  String get debugSensorGroundSpeed => '地速';

  @override
  String get debugSensorHeading => '航向';

  @override
  String get debugSensorWindSpeed => '风速';

  @override
  String get debugSensorWindDirection => '风向';

  @override
  String get flightButtonStart => '开始';

  @override
  String get flightButtonStop => '停止';

  @override
  String get flightButtonAuto => '自动';

  @override
  String get flightButtonAutoTooltip => '点按切换自动检测；长按设置选项';

  @override
  String get flightAutoSettingsTitle => '自动起飞 / 着陆';

  @override
  String get flightAutoSettingsSubtitle => '调整全局自动起飞与着陆检测设置';

  @override
  String get resetToDefaults => '恢复默认';

  @override
  String get flightAutoTakeoffSpeed => '起飞速度阈值';

  @override
  String get flightAutoLandingMinimumFlight => '着陆检测前的最短飞行时间';

  @override
  String get flightAutoLandingSpeedSensitivity => '着陆速度阈值';

  @override
  String get flightLandingAutomatic => '自动着陆';

  @override
  String get flightLandingAutomaticDescription => '检测到着陆后自动结束飞行';

  @override
  String get flightLandingManual => '手动确认';

  @override
  String get flightLandingManualDescription => '检测到着陆后先询问，再结束飞行';

  @override
  String get flightLandingNoDetection => '不检测着陆';

  @override
  String get flightLandingNoDetectionDescription => '仍自动检测起飞；着陆时手动停止';

  @override
  String get flightLandingDetectedTitle => '检测到着陆';

  @override
  String get flightLandingDetectedBody => '确认着陆并结束本次飞行记录吗？';

  @override
  String get flightLandingConfirm => '刚刚着陆';

  @override
  String get flightLandingStillFlying => '仍在飞行';

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
  String get settingShowVerticalAcceleration => '显示垂直加速度';

  @override
  String get settingVerticalAccelerationFillOpacity => '加速度填充不透明度';

  @override
  String get settingVerticalGraphInterval => '显示时间范围';

  @override
  String get settingVerticalGraphStep => '垂直刻度';

  @override
  String get settingVerticalGraphDotSize => '点大小';

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
  String get settingDecimalPlaces => '小数位数';

  @override
  String get settingDecimalPlacesAuto => '自动';

  @override
  String get settingDecimalPlacesDefault => '默认';

  @override
  String get settingLatitudeDecimals => '纬度小数位数';

  @override
  String get settingLongitudeDecimals => '经度小数位数';

  @override
  String get settingDmsSecondsDecimals => '度分秒中的秒小数位数';

  @override
  String get settingAverageDecimals => '平均值小数位数';

  @override
  String get settingPeakDecimals => '峰值小数位数';

  @override
  String get settingRatioDecimals => '滑翔比小数位数';

  @override
  String get settingVarioDecimals => '升降率小数位数';

  @override
  String get settingHeadingDecimals => '航向小数位数';

  @override
  String get settingWindSpeedDecimals => '风速小数位数';

  @override
  String get settingGroundSpeedDecimals => '地速小数位数';

  @override
  String get settingWindDirectionDecimals => '风向小数位数';

  @override
  String get settingZoomLevelDecimals => '缩放级别小数位数';

  @override
  String get settingGridDistanceDecimals => '网格距离小数位数';

  @override
  String get settingMapScaleDistanceDecimals => '地图比例尺距离小数位数';

  @override
  String get settingVarioMinimumDecimals => '升降率量程下限小数位数';

  @override
  String get settingSinkThresholdDecimals => '下沉阈值小数位数';

  @override
  String get settingLiftThresholdDecimals => '爬升阈值小数位数';

  @override
  String get settingVarioMaximumDecimals => '升降率量程上限小数位数';

  @override
  String get settingAltitudeDecimals => '高度小数位数';

  @override
  String get settingAccelerationDecimals => '加速度小数位数';

  @override
  String get settingDistanceDecimals => '距离小数位数';

  @override
  String get settingAltitudeDifferenceDecimals => '高度差小数位数';

  @override
  String get settingBearingDecimals => '方位角小数位数';

  @override
  String get settingAccuracyDecimals => '精度小数位数';

  @override
  String get settingAltitudeSource => '高度来源';

  @override
  String get settingAltitudeSourceAuto => '自动（优先气压）';

  @override
  String get settingAltitudeSourceGps => 'GPS 高度';

  @override
  String get settingAltitudeSourceBaro => '气压高度';

  @override
  String get settingShowSourceIcon => '显示来源图标';

  @override
  String get settingFormat => '格式';

  @override
  String get settingFormatDegrees => '度数（0-360°）';

  @override
  String get settingFormatCardinal => '方位（N、NE …）';

  @override
  String get settingBearingReference => '方向基准';

  @override
  String get settingBearingAbsolute => '绝对方位（罗盘）';

  @override
  String get settingBearingRelative => '相对方位（相对航向）';

  @override
  String get settingShowSeconds => '显示秒';

  @override
  String get settingShowAutoDetect => '显示自动检测复选框';

  @override
  String get settingShowDistance => '显示距离';

  @override
  String get settingShowBearingMetric => '显示方位';

  @override
  String get settingShowElevation => '显示高度差';

  @override
  String get settingShowGlide => '显示滑翔比';

  @override
  String get settingShowEta => '显示预计到达时间';

  @override
  String get settingShowGps => '显示 GPS 状态';

  @override
  String get settingGpsDetailed => '详细 GPS 状态';

  @override
  String get settingShowBluetooth => '显示蓝牙传感器';

  @override
  String get settingShowSensorBattery => '显示传感器电量';

  @override
  String get settingShowDeviceBattery => '显示设备电量';

  @override
  String get settingShowFlightTimer => '显示飞行计时';

  @override
  String get settingShowClock => '显示时钟';

  @override
  String get settingTimeFormat => '时间格式';

  @override
  String get settingTimeFormat24h => '24 小时制';

  @override
  String get settingTimeFormat12h => '12 小时制（上午/下午）';

  @override
  String get settingGlideAvg => '滑翔比平均';

  @override
  String get settingGlideAvgInstant => '瞬时';

  @override
  String settingGlideAvgSeconds(String seconds) {
    return '$seconds 秒';
  }

  @override
  String get settingGlideLeadingOne => '显示前缀“1:”';

  @override
  String get settingGlideShowVario => '上升时显示升降率';

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
  String get settingShowTakeoffLine => '显示到起飞点的连线';

  @override
  String get settingShowScale => '显示地图比例尺';

  @override
  String get settingShowAirspace => '显示空域';

  @override
  String get settingAirspaceCount => '绘制最近的空域数量';

  @override
  String get settingShowLegend => '显示升降音图例';

  @override
  String get settingShowZoomLevel => '显示缩放级别';

  @override
  String get settingShowAttribution => '显示地图来源标注';

  @override
  String get settingShowStatus => '显示航向/高度与 GPS 状态';

  @override
  String get settingShowTakeoffPoint => '显示起飞点';

  @override
  String get settingShowDefaultLandingPoint => '显示默认降落点';

  @override
  String get settingShowNearestLandingPoint => '显示距离最近的降落点';

  @override
  String get settingShowDefaultLandingLine => '显示到默认降落点的连线';

  @override
  String get settingShowLastLandingLine => '显示到距离最近降落点的连线';

  @override
  String get settingTakeoffPointColor => '起飞点标记颜色';

  @override
  String get settingDefaultLandingPointColor => '默认降落点标记颜色';

  @override
  String get settingLastLandingPointColor => '距离最近降落点标记颜色';

  @override
  String get settingTakeoffLineColor => '起飞点连线颜色';

  @override
  String get settingDefaultLandingLineColor => '默认降落点连线颜色';

  @override
  String get settingLastLandingLineColor => '距离最近降落点连线颜色';

  @override
  String get colorPalettePreferencesTitle => '颜色选择器调色板';

  @override
  String colorPalettePreferencesSubtitle(int count) {
    return '所有选择器显示 $count 种预设颜色';
  }

  @override
  String get colorPaletteSettingsDescription =>
      '最多可选择 20 种预设颜色。高饱和度方案会加入深色和亮色高饱和度颜色；开启开关时，黑、白、灰会自动追加在末尾。';

  @override
  String get colorPaletteIncludeNeutralColors => '包含黑、白、灰';

  @override
  String get colorPaletteIncludeNeutralColorsDescription =>
      '将黑色、白色和灰色追加到每套配色的末尾。';

  @override
  String get colorPaletteSchemeLabel => '配色方案';

  @override
  String get colorPaletteSchemeHighSaturation => '高饱和度';

  @override
  String get colorPaletteSchemeMacaron => '马卡龙';

  @override
  String get colorPaletteSchemeMorandi => '莫兰迪';

  @override
  String get colorPaletteSchemeEarth => '大地';

  @override
  String get colorPaletteSchemeDarkTech => '暗黑科技';

  @override
  String get colorPaletteSchemeMaldivesOcean => '马尔代夫海洋';

  @override
  String get colorPaletteSchemeForest => '森林';

  @override
  String get colorPaletteSchemeSunset => '日落';

  @override
  String get colorPaletteSchemeLavender => '薰衣草';

  @override
  String get colorPaletteSchemeNordic => '北欧';

  @override
  String get colorPaletteSchemeDesert => '沙漠';

  @override
  String get colorPaletteSchemeSakura => '樱花';

  @override
  String get colorPaletteSchemeGlacier => '冰川';

  @override
  String get colorPaletteCountLabel => '预设颜色数量';

  @override
  String colorPaletteSettingsCount(int count) {
    return '$count 种颜色';
  }

  @override
  String get landingPointsTitle => '降落点';

  @override
  String get landingPointsSubtitle => '管理已保存的降落目的地和默认目标。';

  @override
  String get landingPointsEmpty => '尚未保存降落点。可以添加当前位置，或在地图上选择位置。';

  @override
  String get landingPointAddCurrent => '添加当前位置';

  @override
  String get landingPointNoGpsFix => '需要有效的 GPS 定位才能保存当前位置。';

  @override
  String get landingPointAddTitle => '添加降落点';

  @override
  String get landingPointName => '名称';

  @override
  String get landingPointCoordinates => 'GPS 坐标';

  @override
  String get landingPointAltitude => '海拔';

  @override
  String get landingPointNameRequired => '请输入降落点名称。';

  @override
  String get landingPointAltitudeInvalid => '请输入 -12,000 至 100,000 米之间的有效海拔。';

  @override
  String get landingPointGpsAccuracy => 'GPS 精度';

  @override
  String get landingPointCapturedAt => '定位时间';

  @override
  String get landingPointNotes => '备注';

  @override
  String get landingPointSave => '保存降落点';

  @override
  String get landingPointDefault => '默认';

  @override
  String get landingPointLast => '距离最近';

  @override
  String get landingPointActions => '降落点操作';

  @override
  String get landingPointClearDefault => '清除默认降落点';

  @override
  String get landingPointSetDefault => '设为默认降落点';

  @override
  String get landingPointDelete => '删除降落点';

  @override
  String get landingPointPickMapTitle => '在地图上选择位置';

  @override
  String get landingPointPickPrompt => '请在地图上点选降落点位置。';

  @override
  String get landingPointSaved => '降落点已保存';

  @override
  String get mapTakeoffLabel => '起飞点';

  @override
  String get dataMonitorTitle => '数据监视器';

  @override
  String get dataMonitorMinimize => '最小化数据监视器';

  @override
  String get dataMonitorRestore => '还原数据监视器';

  @override
  String get dataMonitorResize => '调整数据监视器大小';

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

  @override
  String get flightsAddRandomDebug => '添加随机飞行（调试）';

  @override
  String get flightsImport => '导入飞行';

  @override
  String get flightsImportLibrary => '导入库（.pbflights.zip）';

  @override
  String get flightsImportXcTrack => '导入 XCTrack 飞行（.igc）';

  @override
  String get flightsImportFileUnreadable => '无法读取所选文件。';

  @override
  String get flightsExportDestinationTitle => '请选择导出方式';

  @override
  String get flightsExportDestinationDownloads => '保存到下载目录';

  @override
  String get flightsExportDestinationShare => '直接分享';

  @override
  String get flightsExportSavedToDownloads => '已保存到 Downloads/ParaBeacon。';

  @override
  String get flightsImportXcTrackPickMode => '你想如何选择航迹文件？';

  @override
  String get flightsImportModeFolder => '选择文件夹';

  @override
  String get flightsImportModeFolderNote => '导入文件夹内的所有 .igc——没有数量限制';

  @override
  String get flightsImportModeFiles => '选择文件';

  @override
  String get flightsImportModeFilesNote => '逐个选择 .igc 文件（最多 100 个）';

  @override
  String get flightsImportXcTrackNote =>
      'XCTrack 的航迹文件存放在：\n/storage/emulated/0/Android/data/org.xcontest.XCTrack/files/Tracklogs\n\n多数手机无法直接打开该目录。请先将其（或其中的 .igc 文件）复制到 Download 目录，再从那里导入。';

  @override
  String get flightsImportingXcTrack => '正在导入 XCTrack 飞行…';

  @override
  String get flightsImportNoIgc => '该文件夹中未找到 .igc 文件。';

  @override
  String get flightsExportLibrary => '导出库（.pbflights.zip）';

  @override
  String get flightsSelectRecords => '选择要导出的飞行';

  @override
  String get flightsExportSelected => '导出所选飞行（.pbflights.zip）';

  @override
  String get flightsClearAll => '全部清除';

  @override
  String get flightsPlaceNameSettings => '地名查询设置';

  @override
  String get flightsNoneRecorded => '尚无飞行记录';

  @override
  String get flightsStartToRecord => '开始一次飞行以记录航迹。';

  @override
  String flightsListSubtitle(String duration, String km, int points) {
    return '$duration · $km km · $points 点';
  }

  @override
  String get flightsReplay => '回放';

  @override
  String get flightsNoPointsToReplay => '没有可回放的航迹点';

  @override
  String get flights3dReplay => '3D 回放';

  @override
  String get flightsShareCardSaved => '分享卡片已保存到相册';

  @override
  String get flightsShareCardSharedFile => '已保存为文件并打开分享面板';

  @override
  String flightsShareCardFailed(String error) {
    return '分享卡片失败：$error';
  }

  @override
  String get flightsSetAmapKeyFirst => '请先在地名设置中填入高德 Key。';

  @override
  String get flightsNoPointsToLocate => '此飞行没有可定位的航迹点。';

  @override
  String get flightsLookingUpSites => '正在查询地名……';

  @override
  String get flightsNoPlaceNames => '未找到这些坐标对应的地名。';

  @override
  String get flightsSiteNamesUpdated => '地名已更新。';

  @override
  String flightsLookupFailed(String error) {
    return '查询失败：$error';
  }

  @override
  String get placeNameLookup => '地名查询';

  @override
  String get placeNameLookupDescription =>
      '使用高德（AutoNavi）Web 服务将起飞/降落坐标反向地理编码为地名。请求仅发送到 restapi.amap.com。';

  @override
  String get placeNameAmapKeyLabel => '高德 Web 服务 Key';

  @override
  String get placeNameAutoLookup => '每次飞行后自动查询';

  @override
  String get placeNameSettingsSaved => '地名设置已保存。';

  @override
  String flightsExportFailed(String label, String error) {
    return '$label 导出失败：$error';
  }

  @override
  String flightsLibraryExportFailed(String error) {
    return '库导出失败：$error';
  }

  @override
  String get flightsLibraryExportSaved => '飞行数据包已保存到设备。';

  @override
  String get flightsExportDoneTitle => '导出完成';

  @override
  String get flightsExportDoneSaved => '飞行数据包已保存到设备。';

  @override
  String get flightsExportDoneShared => '飞行数据包已准备好分享。';

  @override
  String get flightsExportDetailFlights => '飞行数量';

  @override
  String get flightsExportDetailFileName => '文件';

  @override
  String get flightsExportDetailSize => '大小';

  @override
  String get flightsExportDetailLocation => '位置';

  @override
  String flightsImportResult(int added, int skipped) {
    return '已导入 $added · 跳过 $skipped';
  }

  @override
  String flightsImportResultFailed(int added, int skipped, int failed) {
    return '已导入 $added · 跳过 $skipped · 失败 $failed';
  }

  @override
  String flightsImportFailed(String error) {
    return '导入失败：$error';
  }

  @override
  String get flightDetailsTitle => '飞行详情';

  @override
  String get flightDetailDeleteSamples => '删除采样数据';

  @override
  String get flightDetailTrimLog => '裁剪航迹';

  @override
  String get flightDetailTrimDescription => '选择要保留的首尾采样点。至少保留两个点；移除的采样点无法恢复。';

  @override
  String flightDetailTrimFrom(String time) {
    return '保留起始时间：$time';
  }

  @override
  String flightDetailTrimThrough(String time) {
    return '保留结束时间：$time';
  }

  @override
  String flightDetailTrimCounts(int kept, int removed) {
    return '保留 $kept 个采样点 · 移除 $removed 个';
  }

  @override
  String get flightDetailTrimApply => '裁剪';

  @override
  String get flightDetailTrimApplied => '航迹已裁剪。';

  @override
  String get replayTrimUnavailable => '航迹已更改或不可用，请关闭并重新打开回放后再裁剪。';

  @override
  String get flightDetailFlight => '飞行概况';

  @override
  String get flightDetailRoute => '航线';

  @override
  String get flightDetailAltitude => '海拔';

  @override
  String get flightDetailRouteMetrics => '航线数据';

  @override
  String get flightDetailSpeedGlide => '速度与滑翔';

  @override
  String get flightDetailClimbAltitude => '爬升与海拔';

  @override
  String get flightDetailTimeBreakdown => '时间统计';

  @override
  String get flightDetailStart => '开始';

  @override
  String get flightDetailEnd => '结束';

  @override
  String get flightDetailDuration => '时长';

  @override
  String get flightDetailDistance => '距离';

  @override
  String get flightDetailMaxAltitude => '最高海拔';

  @override
  String get flightDetailMinAltitude => '最低海拔';

  @override
  String get flightDetailMaxClimb => '最大爬升';

  @override
  String get flightDetailMaxSink => '最大下沉';

  @override
  String get flightDetailSamples => '采样点';

  @override
  String get flightDetailTakeoff => '起飞';

  @override
  String get flightDetailLanding => '降落';

  @override
  String get flightDetailPilot => '飞行员';

  @override
  String get flightDetailPerformance => '性能';

  @override
  String get flightDetailStraightDistance => '直线距离';

  @override
  String get flightDetailXcDistance => '越野距离';

  @override
  String get flightDetailFaiTriangle => 'FAI 三角';

  @override
  String get flightDetailFaiClosed => '闭合';

  @override
  String get flightDetailFlatTriangle => '平面三角';

  @override
  String get flightDetailThreeTurnpoints => '3 转折点距离';

  @override
  String get flightDetailClosing => '闭合距离';

  @override
  String get flightDetailMaxAltGain => '最大爬升高度';

  @override
  String get flightDetailElevationDrop => '海拔落差';

  @override
  String get flightDetailMaxFromStart => '距起点最远';

  @override
  String get flightDetailAvgGroundSpeed => '平均地速';

  @override
  String get flightDetailAvgCruiseSpeed => '平均巡航速度';

  @override
  String get flightDetailMaxSpeed => '最大速度';

  @override
  String get flightDetailAvgClimb => '平均爬升';

  @override
  String get flightDetailAvgSink => '平均下沉';

  @override
  String get flightDetailAvgGlideRatio => '平均滑翔比';

  @override
  String get flightDetailTrackEfficiency => '航迹效率';

  @override
  String get flightDetailThermals => '热气流';

  @override
  String get flightDetailAltGained => '累计爬升';

  @override
  String get flightDetailAltLost => '累计下降';

  @override
  String get flightDetailClimbTime => '爬升时间';

  @override
  String get flightDetailGlideTime => '滑翔时间';

  @override
  String get flightDetailSinkTime => '下沉时间';

  @override
  String get flightDetailMovingTime => '移动时间';

  @override
  String get flightDetailExport => '导出';

  @override
  String get flightDetailSiteNames => '地名';

  @override
  String get flightExportShareCard => '分享卡片';

  @override
  String get flightShareCardNoTrack => '无航迹';

  @override
  String get flightShareCardNoAltitude => '无海拔数据';

  @override
  String flightShareCardFooter(int points) {
    return '由 ParaBeacon 记录 · $points 个采样点';
  }

  @override
  String get flightReportTitle => 'ParaBeacon 飞行报告';

  @override
  String get flightReportDate => '日期';

  @override
  String get flightReportTrackMap => '航迹';

  @override
  String get flightReportAltitudeProfile => '海拔曲线';

  @override
  String get flightReportSummary => '摘要';

  @override
  String get flightReportDistanceAltitude => '距离与海拔';

  @override
  String get flightReportGeneratedBy => '由 ParaBeacon 生成';

  @override
  String flightReportPage(int current, int total) {
    return '第 $current / $total 页';
  }

  @override
  String get flightsStatistics => '统计';

  @override
  String get flightsStatisticsAll => '统计（全部飞行）';

  @override
  String get flightsStatisticsSelected => '统计（所选飞行）';

  @override
  String get statsTitle => '飞行统计';

  @override
  String statsScopeAll(int count) {
    return '全部飞行 · $count';
  }

  @override
  String statsScopeSelected(int count) {
    return '已选 · $count';
  }

  @override
  String get statsNoData => '没有可统计的飞行';

  @override
  String get statsNoDataHint => '记录或选择飞行后即可查看统计数据。';

  @override
  String get statsPrioritySummary => '优先显示摘要';

  @override
  String get statsPriorityDetailed => '详细统计';

  @override
  String statsComputingDetailed(int completed, int total) {
    return '正在计算详细统计 · $completed / $total 次飞行';
  }

  @override
  String get statsNoDetailedTracks => '没有可用的已记录航迹详情。';

  @override
  String get statsCalculationFailed => '无法计算详细统计，摘要数据仍可查看。';

  @override
  String get statsNotEnoughData => '数据不足';

  @override
  String statsRecordOn(String date) {
    return '于 $date';
  }

  @override
  String statsFlightsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 次飞行',
      zero: '无飞行',
    );
    return '$_temp0';
  }

  @override
  String get statsSectionOverview => '概览';

  @override
  String get statsSectionRecords => '个人纪录';

  @override
  String get statsSectionAverages => '平均值';

  @override
  String get statsSectionTotals => '累计';

  @override
  String get statsSectionByYear => '按年份统计';

  @override
  String get statsSectionByMonth => '季节分布（按月）';

  @override
  String get statsSectionByAircraft => '按翼伞 / 飞行器';

  @override
  String get statsUnknownType => '未知类型';

  @override
  String get statsSectionBySite => '按起飞地点';

  @override
  String get statsFlights => '飞行次数';

  @override
  String get statsTotalAirtime => '总飞行时间';

  @override
  String get statsTotalDistance => '总距离';

  @override
  String get statsTotalXcDistance => '总越野距离';

  @override
  String get statsDateRange => '日期范围';

  @override
  String get statsActiveDays => '飞行天数';

  @override
  String get statsFlightsPerDay => '每飞行日次数';

  @override
  String get statsFirstFlight => '首次飞行';

  @override
  String get statsLastFlight => '最近飞行';

  @override
  String get statsSampledFlights => '含航迹数据的飞行';

  @override
  String get statsLongestFlight => '最长飞行时间';

  @override
  String get statsLongestDistance => '最长航迹距离';

  @override
  String get statsLongestXc => '最长直线距离';

  @override
  String get statsMaxDistanceFromStart => '距起点最远';

  @override
  String get statsHighestAltitude => '最高海拔';

  @override
  String get statsLowestAltitude => '最低海拔';

  @override
  String get statsMaxClimb => '最强爬升';

  @override
  String get statsMaxSink => '最强下沉';

  @override
  String get statsMaxSpeed => '最高速度';

  @override
  String get statsBestGlide => '最佳滑翔比';

  @override
  String get statsBestFaiTriangle => '最佳 FAI 三角';

  @override
  String get statsAvgDuration => '平均飞行时间';

  @override
  String get statsAvgDistance => '平均航迹距离';

  @override
  String get statsAvgXcDistance => '平均直线距离';

  @override
  String get statsAvgMaxAltitude => '平均最高海拔';

  @override
  String get statsAvgSpeed => '平均地速';

  @override
  String get statsAvgGlide => '平均滑翔比';

  @override
  String get statsTotalAltGained => '累计爬升高度';

  @override
  String get statsTotalAltLost => '累计下降高度';

  @override
  String get statsTotalThermals => '热气流爬升次数';

  @override
  String get statsTotalMovingTime => '总移动时间';

  @override
  String get statsTotalSamples => '航迹点数';

  @override
  String get flightsDeleteSamplesTitle => '删除采样数据？';

  @override
  String get flightsDeleteSamplesMessage =>
      '这将删除此飞行的逐点航迹数据（位置/海拔/升降）。飞行及其摘要仍保留在记录中，但将无法再回放。此操作无法撤销。';

  @override
  String get flightsClearAllTitle => '清除所有飞行？';

  @override
  String get flightsClearAllMessage => '这将移除所有已记录的飞行。';

  @override
  String get flightsDeleteTitle => '删除飞行记录？';

  @override
  String get flightsDeleteMessage => '此飞行记录将被永久删除，此操作无法撤销。';

  @override
  String flightsDeleteSelectedTitle(int count) {
    return '删除选中的 $count 条飞行记录？';
  }

  @override
  String get flightsDeleteSelectedMessage => '选中的飞行记录将被永久删除，此操作无法撤销。';

  @override
  String get flightsMerge => '合并飞行记录';

  @override
  String flightsMergeTitle(int count) {
    return '合并 $count 条飞行记录？';
  }

  @override
  String flightsMergeMessage(String start, String end) {
    return '选中的飞行记录将合并为一条飞行记录（$start 至 $end）。飞行记录之间的时间将保留为数据缺失时段，并在回放和 3D 回放中标出。原飞行记录将被替换，此操作无法撤销。';
  }

  @override
  String get flightsMergeConfirm => '合并';

  @override
  String get flightsMergeDone => '已合并为一条飞行记录。';

  @override
  String get flightsMergeNotPossibleTitle => '无法合并这些飞行记录';

  @override
  String flightsMergeConditions(int minutes, String km) {
    return '合并条件：飞行记录需前后相连，从降落到下一次起飞不超过 $minutes 分钟、距离不超过 $km 公里，且使用同一翼型、同一飞行员。';
  }

  @override
  String get flightsMergeIssueTooFew => '请至少选择 2 条飞行记录进行合并。';

  @override
  String flightsMergeIssueRecording(String flight) {
    return '飞行记录 $flight 仍在记录中。';
  }

  @override
  String flightsMergeIssueNotInLog(String flight) {
    return '飞行记录 $flight 已被删除。';
  }

  @override
  String flightsMergeIssueNoSamples(String flight) {
    return '飞行记录 $flight 没有 GPS 轨迹数据。';
  }

  @override
  String flightsMergeIssueNoFix(String flight) {
    return '飞行记录 $flight 没有有效的 GPS 定位。';
  }

  @override
  String flightsMergeIssueOverlap(
    String first,
    String second,
    String duration,
  ) {
    return '$first → $second：两条飞行记录时间重叠 $duration。';
  }

  @override
  String flightsMergeIssueGap(
    String first,
    String second,
    String duration,
    String max,
  ) {
    return '$first → $second：降落到下一次起飞间隔 $duration（上限 $max）。';
  }

  @override
  String flightsMergeIssueDistance(
    String first,
    String second,
    String distance,
    String max,
  ) {
    return '$first → $second：降落点距离下一次起飞点 $distance 公里（上限 $max 公里）。';
  }

  @override
  String flightsMergeIssueAircraft(
    String first,
    String second,
    String previous,
    String next,
  ) {
    return '$first → $second：翼型不同（$previous / $next）。';
  }

  @override
  String flightsMergeIssuePilot(
    String first,
    String second,
    String previous,
    String next,
  ) {
    return '$first → $second：飞行员不同（$previous / $next）。';
  }

  @override
  String replayDataGapBanner(String start, String end, String duration) {
    return '无数据 $start – $end（$duration）';
  }

  @override
  String replayDataGapSummary(int count, String total) {
    return '$count 段数据缺失 · $total';
  }

  @override
  String get replayDataGapNoData => '无数据';

  @override
  String get replayTitle => '回放';

  @override
  String get replayColorBy => '着色依据';

  @override
  String get replayColorVario => '着色：升降';

  @override
  String get replayColorSpeed => '着色：速度';

  @override
  String get replayColorAltitude => '着色：海拔';

  @override
  String get replayNoPointsMessage => '此飞行没有可回放的航迹点。';

  @override
  String get replayRestart => '重新开始';

  @override
  String get replayPause => '暂停';

  @override
  String get replayPlay => '播放';

  @override
  String get replayVarioSoundOn => '升降音开';

  @override
  String get replayVarioSoundOff => '升降音关';

  @override
  String replayReadout(String heading, String altitude, String vario) {
    return '航向 $heading°  ·  海拔 ${altitude}m  ·  $vario m/s';
  }

  @override
  String get replay3dTitle => '3D 回放';

  @override
  String get replay3dResetView => '重置视角';

  @override
  String get replay3dStatAlt => '海拔';

  @override
  String get replay3dStatSpd => '速度';

  @override
  String get replay3dStatVario => '升降';

  @override
  String get sensorTitle => '传感器';

  @override
  String get sensorOptions => '选项';

  @override
  String get sensorEnableBluetooth => '启用蓝牙传感器';

  @override
  String get sensorEnableBluetoothSubtitle => '扫描并连接外部传感器';

  @override
  String get sensorPreferInternal => '优先使用内置传感器';

  @override
  String get sensorPreferInternalSubtitle => '优先使用本设备的内置气压计';

  @override
  String get sensorNoInternalBarometer => '本设备未检测到内置气压计';

  @override
  String get sensorInternalSection => '内置传感器';

  @override
  String get sensorStatus => '状态';

  @override
  String get sensorBarometerNotDetected => '未检测到气压计';

  @override
  String get sensorBarometerConnected => '气压计已连接';

  @override
  String get sensorBarometerNotPreferred => '已检测到气压计（未优先使用）';

  @override
  String get sensorConnection => '连接';

  @override
  String sensorBluetoothState(String state) {
    return '蓝牙：$state';
  }

  @override
  String get sensorLiveDataFields => '实时数据字段';

  @override
  String get sensorNearbyDevices => '附近设备';

  @override
  String get sensorFieldAltitude => '海拔';

  @override
  String get sensorFieldVerticalSpeed => '升降速度';

  @override
  String get sensorFieldPressure => '气压';

  @override
  String get sensorFieldTemperature => '温度';

  @override
  String get sensorFieldHeartRate => '心率';

  @override
  String get sensorFieldBattery => '电量';

  @override
  String get sensorFieldQnh => 'QNH（基准气压）';

  @override
  String get sensorCalibrate => '校准';

  @override
  String get sensorCalibrationReset => '重置';

  @override
  String get sensorCalibrationStandard => '标准基准（1013.25 hPa）';

  @override
  String get sensorCalibrationCalibrated => '已按已知海拔校准';

  @override
  String get sensorCalibrateTitle => '校准海拔';

  @override
  String get sensorCalibrateDescription =>
      '输入当前的已知海拔，将自动调整基准气压（QNH），使气压海拔与之匹配。';

  @override
  String get sensorCalibrateAltitudeLabel => '当前海拔';

  @override
  String get sensorCalibrateInvalid => '请输入有效的海拔';

  @override
  String get sensorCalibrateFailed => '校准失败——没有气压读数或数值超出范围';

  @override
  String get sensorExtCalibrationSection => '外接传感器海拔';

  @override
  String get sensorExtCalibrationCurrent => '校准后海拔';

  @override
  String get sensorFieldAltitudeOffset => '海拔偏移';

  @override
  String get sensorExtCalibrationNone => '未应用偏移（传感器原始海拔）';

  @override
  String get sensorExtCalibrationApplied => '已按已知海拔校准';

  @override
  String get sensorNoDeviceSelected => '未选择设备';

  @override
  String get sensorDevice => '设备';

  @override
  String get sensorConnected => '已连接';

  @override
  String get sensorConnecting => '连接中…';

  @override
  String get sensorDisconnected => '已断开';

  @override
  String get sensorConnect => '连接';

  @override
  String get sensorDisconnect => '断开连接';

  @override
  String get sensorForget => '忘记设备';

  @override
  String get sensorScan => '扫描';

  @override
  String get sensorStop => '停止';

  @override
  String get sensorDevices => '设备';

  @override
  String get sensorTapScan => '点击扫描';

  @override
  String get sensorEnableFirst => '请先启用';

  @override
  String get sensorUnknownDevice => '（未知）';

  @override
  String sensorRssiDbm(int rssi) {
    return '$rssi dBm';
  }

  @override
  String get sensorUnsupported => '蓝牙传感器仅在 iOS 和 Android 上可用。';

  @override
  String get altitudeAnnouncementTitle => '语音播报';

  @override
  String get altitudeAnnouncementSubtitle => '起飞降落、滑翔死区及刷新高度播报';

  @override
  String get altitudeAnnouncementDescription => '选择需要语音播报的飞行事件，每条播报内容均可自定义并预览。';

  @override
  String get altitudeAnnouncementVoiceEnabled => '语音播报';

  @override
  String get altitudeAnnouncementVoiceEnabledDescription => '开启或关闭所有自动语音播报。';

  @override
  String get altitudeAnnouncementSectionVoice => '语音';

  @override
  String get altitudeAnnouncementSectionTakeoffLanding => '起飞与降落';

  @override
  String get altitudeAnnouncementSectionGlide => '滑翔死区';

  @override
  String get altitudeAnnouncementSectionRecord => '最高高度';

  @override
  String get altitudeAnnouncementSectionCustomRules => '数据条件播报';

  @override
  String get altitudeAnnouncementCustomRulesDescription =>
      '飞行期间，当实时数据超过阈值或进入设定范围时播报自定义内容。每条规则都可单独设置重复间隔。';

  @override
  String get altitudeAnnouncementCustomRuleAdd => '添加条件';

  @override
  String get altitudeAnnouncementCustomRuleLimit => '最多可设置 20 条条件。';

  @override
  String get altitudeAnnouncementCustomRuleEmpty => '尚未添加自定义条件。';

  @override
  String get altitudeAnnouncementCustomRuleTitle => '播报条件';

  @override
  String get altitudeAnnouncementCustomMetric => '数据值';

  @override
  String get altitudeAnnouncementCustomCondition => '判断方式';

  @override
  String get altitudeAnnouncementConditionGreater => '大于 (>)';

  @override
  String get altitudeAnnouncementConditionLess => '小于 (<)';

  @override
  String get altitudeAnnouncementConditionRange => '处于范围内';

  @override
  String get altitudeAnnouncementCustomThreshold => '阈值';

  @override
  String get altitudeAnnouncementCustomLower => '最小值';

  @override
  String get altitudeAnnouncementCustomUpper => '最大值';

  @override
  String get altitudeAnnouncementCustomRepeat => '条件持续满足时重复播报';

  @override
  String altitudeAnnouncementCustomRepeatInterval(String seconds) {
    return '每 $seconds 秒重复播报';
  }

  @override
  String get altitudeAnnouncementCustomContent => '播报内容模板';

  @override
  String get altitudeAnnouncementCustomContentRequired => '请输入要播报的文字。';

  @override
  String get altitudeAnnouncementCustomTemplateDescription =>
      '编写播报内容并点击下方占位符插入实时飞行数据。预览使用示例数值。';

  @override
  String get altitudeAnnouncementCustomDelete => '删除条件';

  @override
  String get altitudeAnnouncementMetricAltitude => '海拔';

  @override
  String get altitudeAnnouncementMetricVerticalSpeed => '升降速度';

  @override
  String get altitudeAnnouncementMetricGroundSpeed => '地速';

  @override
  String get altitudeAnnouncementMetricWindSpeed => '风速';

  @override
  String get altitudeAnnouncementMetricTemperature => '温度';

  @override
  String get altitudeAnnouncementMetricPressure => '气压';

  @override
  String get altitudeAnnouncementMetricBattery => '传感器电量';

  @override
  String get altitudeAnnouncementMetricHeartRate => '心率';

  @override
  String get altitudeAnnouncementMetricHeading => '航向';

  @override
  String get altitudeAnnouncementTakeoffLandingEnabled => '起飞/降落播报';

  @override
  String get altitudeAnnouncementTakeoffLandingDescription =>
      '先播放一声“叮”提示音，再在飞行开始或结束时播报。开启自动起降检测后，如果再次起飞合并了上一条飞行记录，则改为播报“继续飞行”。';

  @override
  String get altitudeAnnouncementAutoDetectOff => '自动起降检测已关闭，不会播报“继续飞行”。';

  @override
  String get altitudeAnnouncementEventTakeoff => '起飞';

  @override
  String get altitudeAnnouncementEventContinueFlight => '继续飞行';

  @override
  String get altitudeAnnouncementEventLanding => '降落';

  @override
  String get altitudeAnnouncementEventGlide => '死区';

  @override
  String get altitudeAnnouncementEventAltitudeRecord => '新的最高高度';

  @override
  String get altitudeAnnouncementGlideEnabled => '死区播报';

  @override
  String get altitudeAnnouncementGlideDescription =>
      '垂直速度处于死区时升降音保持静音。飞行中垂直速度在死区内停留设定的延时后播报，之后只要仍在死区内，就按设定的间隔重复播报。';

  @override
  String altitudeAnnouncementGlideRange(String minimum, String maximum) {
    return '死区范围：$minimum 至 $maximum m/s';
  }

  @override
  String altitudeAnnouncementGlideDelay(String seconds) {
    return '进入死区 $seconds 秒后播报';
  }

  @override
  String altitudeAnnouncementGlideRepeat(String seconds) {
    return '停留在死区内时每 $seconds 秒重复播报';
  }

  @override
  String get altitudeAnnouncementRecordEnabled => '新的最高高度播报';

  @override
  String get altitudeAnnouncementRecordDescription =>
      '飞行中高度超过此前记录的最高高度时立即播报。连续刷新最高高度时，两次播报之间至少间隔下方设定的时间。';

  @override
  String altitudeAnnouncementRecordInterval(String seconds) {
    return '两次播报最小间隔：$seconds 秒';
  }

  @override
  String get altitudeAnnouncementRecordScopeFlight => '本次飞行';

  @override
  String get altitudeAnnouncementRecordScopeAll => '全部飞行记录';

  @override
  String get altitudeAnnouncementCustomize => '自定义内容';

  @override
  String get altitudeAnnouncementPlaceholderAgl => '离地高度';

  @override
  String get altitudeAnnouncementPlaceholderTakeoffHeight => '相对起飞点高度';

  @override
  String get altitudeAnnouncementPlaceholderMaxAltitude => '最高高度';

  @override
  String get altitudeAnnouncementPlaceholderGlideRatio => '滑翔比';

  @override
  String get altitudeAnnouncementPlaceholderWindSpeed => '风速';

  @override
  String get altitudeAnnouncementPlaceholderFlightTime => '飞行时间';

  @override
  String get altitudeAnnouncementPlaceholderDistance => '飞行距离';

  @override
  String get altitudeAnnouncementPlaceholderDistanceUnit => '距离单位';

  @override
  String get altitudeAnnouncementPlaceholderTime => '当前时间';

  @override
  String get altitudeAnnouncementTest => '试听播报';

  @override
  String get altitudeAnnouncementTestSuccess => '语音播报工作正常。';

  @override
  String get altitudeAnnouncementUnavailable =>
      '没有可用的语音合成（TTS）声音。请在系统设置中安装或启用带中文或英文语音的语音引擎，并检查媒体音量，然后重新试听。';

  @override
  String get altitudeAnnouncementTemplate => '播报内容';

  @override
  String get altitudeAnnouncementTemplateDescription =>
      '填写要播报的文字，点击下方数值即可插入。包含中文的内容使用中文语音播报，否则使用英文语音。留空则使用默认内容。';

  @override
  String get altitudeAnnouncementTemplateReset => '恢复默认';

  @override
  String altitudeAnnouncementTemplatePreview(String text) {
    return '预览：$text';
  }

  @override
  String get altitudeAnnouncementPlaceholderAltitude => '高度';

  @override
  String get altitudeAnnouncementPlaceholderAltitudeUnit => '高度单位';

  @override
  String get altitudeAnnouncementPlaceholderClimb => '爬升速度';

  @override
  String get altitudeAnnouncementPlaceholderClimbUnit => '爬升速度单位';

  @override
  String get altitudeAnnouncementPlaceholderGroundSpeed => '地速';

  @override
  String get altitudeAnnouncementPlaceholderSpeedUnit => '速度单位';

  @override
  String get altitudeAnnouncementDuckVario => '播报时降低升降音';

  @override
  String altitudeAnnouncementSpeechRate(String rate) {
    return '播报语速：$rate×';
  }

  @override
  String get altitudeAnnouncementSpeechRateNormal => '正常';

  @override
  String altitudeAnnouncementVolume(String percent) {
    return '播报音量：$percent%';
  }

  @override
  String get altitudeAnnouncementDuckVarioDescription =>
      '语音播报期间调低升降音音量，避免升降音过响时听不清播报。';

  @override
  String altitudeAnnouncementDuckLevel(String percent) {
    return '播报时升降音音量：$percent%';
  }

  @override
  String get varioSoundTitle => '升降音设置';

  @override
  String get varioSoundResetTooltip => '恢复默认';

  @override
  String get varioSoundSectionProfile => '升降音配置';

  @override
  String get varioSoundProfileTitle => '升降音配置';

  @override
  String get varioSoundProfileXcTrack => 'XC Track';

  @override
  String get varioSoundProfileCustom => '自定义';

  @override
  String get varioSoundProfileXcTrackDescription => '原版 XCTrack 声音，自定义设置已禁用。';

  @override
  String get varioSoundProfileCustomDescription => '自行调节阈值、音高、波形和关键点。';

  @override
  String get varioSoundPreview => '试听声音';

  @override
  String get varioSoundPreviewLive => '实时';

  @override
  String get varioSoundPreviewMuted => '已静音';

  @override
  String get varioSoundVerticalSpeed => '升降速度';

  @override
  String get varioSoundKeypointsTitle => '升降速度关键点';

  @override
  String get varioSoundKeypointsDescription =>
      '为某个升降速度固定自定义的音高、蜂鸣节奏、音长和波形。关键点之间会线性插值，超出范围时使用默认声音。';

  @override
  String varioSoundKeypointAddAt(String speed) {
    return '在 $speed 添加';
  }

  @override
  String get varioSoundKeypointClearAll => '全部清除';

  @override
  String get varioSoundKeypointsEmpty => '暂无关键点。拖动上方的升降速度滑块并添加一个。';

  @override
  String get varioSoundKeypointsNeedTwo => '至少添加两个关键点才能塑形声音。';

  @override
  String get varioSoundKeypointAudition => '试听';

  @override
  String get varioSoundKeypointDelete => '删除关键点';

  @override
  String get varioSoundKeypointPitch => '音高';

  @override
  String get varioSoundKeypointCycle => '蜂鸣周期';

  @override
  String get varioSoundKeypointDuty => '音长占比';

  @override
  String get varioSoundKeypointContinuous => '连续音';

  @override
  String get varioSoundKeypointWaveform => '波形';

  @override
  String get varioSoundSectionThresholds => '阈值';

  @override
  String get varioSoundLiftThreshold => '上升阈值';

  @override
  String get varioSoundSinkThreshold => '下降阈值';

  @override
  String get varioSoundSectionPitch => '音高';

  @override
  String get varioSoundLiftBasePitch => '上升基准音高';

  @override
  String get varioSoundLiftPitchRange => '上升音高范围';

  @override
  String get varioSoundSinkBasePitch => '下降基准音高';

  @override
  String get varioSoundSectionWaveform => '波形';

  @override
  String get varioSoundLiftWaveform => '上升波形';

  @override
  String get varioSoundSinkWaveform => '下降波形';

  @override
  String get varioSoundSectionOutput => '输出';

  @override
  String get varioSoundVarioSound => '升降音';

  @override
  String get varioSoundVarioSoundDescription => '升降音的总开关。';

  @override
  String get varioSoundVolume => '升降音音量';

  @override
  String get varioSoundMasterGain => '主增益';

  @override
  String get varioSoundSectionBehavior => '行为';

  @override
  String get varioSoundOnlyWhenFlying => '仅在飞行时发声';

  @override
  String get varioSoundOnlyWhenFlyingDescription => '开始飞行前保持静音，之后正常发声。';

  @override
  String get varioSoundOnlyWhenSensorConnected => '仅在传感器连接时发声';

  @override
  String get varioSoundOnlyWhenSensorConnectedDescription => '未连接蓝牙传感器时保持静音。';

  @override
  String get varioSoundSinkZoneCue => '下沉提示区';

  @override
  String varioSoundSinkZoneCueDescription(String sink) {
    return '在下沉阈值（$sink m/s）到 0.0 m/s 之间播放静区提示音，而不是保持静音。';
  }

  @override
  String get varioWaveformTick => '滴答';

  @override
  String get varioWaveformTack => '嗒嗒';

  @override
  String get varioWaveformSquare => '方波';

  @override
  String get varioWaveformLong => '长音';
}
