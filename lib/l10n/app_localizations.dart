import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S)!;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @unknownTitle.
  ///
  /// In zh, this message translates to:
  /// **'未知标题'**
  String get unknownTitle;

  /// No description provided for @episodeNumber.
  ///
  /// In zh, this message translates to:
  /// **'第{no}集'**
  String episodeNumber(int no);

  /// No description provided for @navDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get navDownload;

  /// No description provided for @aboutVersionUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get aboutVersionUnknown;

  /// No description provided for @navHistory.
  ///
  /// In zh, this message translates to:
  /// **'历史'**
  String get navHistory;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navSettings;

  /// No description provided for @historyEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无下载记录'**
  String get historyEmpty;

  /// No description provided for @urlPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'粘贴视频链接'**
  String get urlPlaceholder;

  /// No description provided for @analyze.
  ///
  /// In zh, this message translates to:
  /// **'解析链接'**
  String get analyze;

  /// No description provided for @analyzing.
  ///
  /// In zh, this message translates to:
  /// **'正在解析视频信息…'**
  String get analyzing;

  /// No description provided for @addToDownload.
  ///
  /// In zh, this message translates to:
  /// **'加入下载队列'**
  String get addToDownload;

  /// No description provided for @taskList.
  ///
  /// In zh, this message translates to:
  /// **'任务列表'**
  String get taskList;

  /// No description provided for @statusQueued.
  ///
  /// In zh, this message translates to:
  /// **'排队中'**
  String get statusQueued;

  /// No description provided for @statusDownloading.
  ///
  /// In zh, this message translates to:
  /// **'下载中'**
  String get statusDownloading;

  /// No description provided for @statusCanceling.
  ///
  /// In zh, this message translates to:
  /// **'正在取消...'**
  String get statusCanceling;

  /// No description provided for @statusCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get statusCompleted;

  /// No description provided for @statusDone.
  ///
  /// In zh, this message translates to:
  /// **'完成：{path}'**
  String statusDone(String path);

  /// No description provided for @statusCanceled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get statusCanceled;

  /// No description provided for @statusFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get statusFailed;

  /// No description provided for @speedLabel.
  ///
  /// In zh, this message translates to:
  /// **'速度'**
  String get speedLabel;

  /// No description provided for @etaLabel.
  ///
  /// In zh, this message translates to:
  /// **'剩余 {seconds}s'**
  String etaLabel(int seconds);

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @openFolder.
  ///
  /// In zh, this message translates to:
  /// **'打开文件夹'**
  String get openFolder;

  /// No description provided for @selectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get selectAll;

  /// No description provided for @invertSelection.
  ///
  /// In zh, this message translates to:
  /// **'反选'**
  String get invertSelection;

  /// No description provided for @playlistNotice.
  ///
  /// In zh, this message translates to:
  /// **'检测到播放列表「{title}」，共 {count} 个条目'**
  String playlistNotice(String title, int count);

  /// No description provided for @selectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count}/{total} 个条目'**
  String selectedCount(int count, int total);

  /// No description provided for @openFile.
  ///
  /// In zh, this message translates to:
  /// **'打开文件'**
  String get openFile;

  /// No description provided for @settingsDownloadDir.
  ///
  /// In zh, this message translates to:
  /// **'下载目录'**
  String get settingsDownloadDir;

  /// No description provided for @systemDownloadsFolder.
  ///
  /// In zh, this message translates to:
  /// **'系统下载文件夹'**
  String get systemDownloadsFolder;

  /// No description provided for @browse.
  ///
  /// In zh, this message translates to:
  /// **'浏览...'**
  String get browse;

  /// No description provided for @settingsCookieFile.
  ///
  /// In zh, this message translates to:
  /// **'Cookie 文件'**
  String get settingsCookieFile;

  /// No description provided for @cookieFileNotSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get cookieFileNotSet;

  /// No description provided for @clearCookieFile.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get clearCookieFile;

  /// No description provided for @downloadCookieHint.
  ///
  /// In zh, this message translates to:
  /// **'部分视频平台（如 YouTube）需要登录才能解析，导入 Cookie 文件后下载与分析都会使用。'**
  String get downloadCookieHint;

  /// No description provided for @settingsConcurrency.
  ///
  /// In zh, this message translates to:
  /// **'同时下载任务数'**
  String get settingsConcurrency;

  /// No description provided for @settingsDefaultQuality.
  ///
  /// In zh, this message translates to:
  /// **'默认画质'**
  String get settingsDefaultQuality;

  /// No description provided for @qualityBest.
  ///
  /// In zh, this message translates to:
  /// **'最佳画质'**
  String get qualityBest;

  /// No description provided for @quality1080p.
  ///
  /// In zh, this message translates to:
  /// **'1080p'**
  String get quality1080p;

  /// No description provided for @quality720p.
  ///
  /// In zh, this message translates to:
  /// **'720p'**
  String get quality720p;

  /// No description provided for @quality480p.
  ///
  /// In zh, this message translates to:
  /// **'480p'**
  String get quality480p;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguage;

  /// No description provided for @errorLogin.
  ///
  /// In zh, this message translates to:
  /// **'需要登录后才能下载该内容'**
  String get errorLogin;

  /// No description provided for @cookieHintOnFail.
  ///
  /// In zh, this message translates to:
  /// **'链接解析失败？尝试导入 Cookie 文件后重试'**
  String get cookieHintOnFail;

  /// No description provided for @errorGeo.
  ///
  /// In zh, this message translates to:
  /// **'该内容在当前地区不可用'**
  String get errorGeo;

  /// No description provided for @errorUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'视频不可用：可能已被删除或设为私密'**
  String get errorUnavailable;

  /// No description provided for @errorNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络错误：请检查网络连接后重试'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In zh, this message translates to:
  /// **'请求超时：请稍后重试'**
  String get errorTimeout;

  /// No description provided for @errorParse.
  ///
  /// In zh, this message translates to:
  /// **'解析失败：无法读取视频信息'**
  String get errorParse;

  /// No description provided for @errorEngineMissing.
  ///
  /// In zh, this message translates to:
  /// **'未找到下载引擎：{path}'**
  String errorEngineMissing(String path);

  /// No description provided for @errorOutputMissing.
  ///
  /// In zh, this message translates to:
  /// **'下载完成但未找到输出文件'**
  String get errorOutputMissing;

  /// No description provided for @errorUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知错误：{detail}'**
  String errorUnknown(String detail);

  /// No description provided for @unknownUploader.
  ///
  /// In zh, this message translates to:
  /// **'未知上传者'**
  String get unknownUploader;

  /// No description provided for @durationSeconds.
  ///
  /// In zh, this message translates to:
  /// **'{count} 秒'**
  String durationSeconds(int count);

  /// No description provided for @downloadFailed.
  ///
  /// In zh, this message translates to:
  /// **'下载失败'**
  String get downloadFailed;

  /// No description provided for @aboutTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get aboutTitle;

  /// No description provided for @aboutYtDlp.
  ///
  /// In zh, this message translates to:
  /// **'yt-dlp 版本'**
  String get aboutYtDlp;

  /// No description provided for @disclaimerText.
  ///
  /// In zh, this message translates to:
  /// **'本工具仅供个人学习研究，下载行为请遵守目标网站服务条款及当地法律法规。请勿将本工具用于商业用途或侵犯他人合法权益。'**
  String get disclaimerText;

  /// No description provided for @licensesNote.
  ///
  /// In zh, this message translates to:
  /// **'基于 yt-dlp（Unlicense）与 FFmpeg（LGPL/GPL）构建'**
  String get licensesNote;

  /// No description provided for @settingsCheckUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查引擎更新'**
  String get settingsCheckUpdate;

  /// No description provided for @updateChecking.
  ///
  /// In zh, this message translates to:
  /// **'检查中…'**
  String get updateChecking;

  /// No description provided for @updateUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get updateUpToDate;

  /// No description provided for @updateUpdated.
  ///
  /// In zh, this message translates to:
  /// **'{component} 已更新到 {version}'**
  String updateUpdated(String component, String version);

  /// No description provided for @updateBusy.
  ///
  /// In zh, this message translates to:
  /// **'{component}：请先停止下载任务后再更新'**
  String updateBusy(String component);

  /// No description provided for @updateFailed.
  ///
  /// In zh, this message translates to:
  /// **'{component} 更新失败：{detail}'**
  String updateFailed(String component, String detail);

  /// No description provided for @updateTimeout.
  ///
  /// In zh, this message translates to:
  /// **'检查更新超时：网络响应过慢，请检查网络后重试'**
  String get updateTimeout;

  /// No description provided for @appUpdateTitle.
  ///
  /// In zh, this message translates to:
  /// **'应用更新'**
  String get appUpdateTitle;

  /// No description provided for @appUpdateTitleDesc.
  ///
  /// In zh, this message translates to:
  /// **'检测 GitHub 上是否有应用新版本'**
  String get appUpdateTitleDesc;

  /// No description provided for @settingsCheckAppUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查应用更新'**
  String get settingsCheckAppUpdate;

  /// No description provided for @appUpdateChecking.
  ///
  /// In zh, this message translates to:
  /// **'正在检查应用更新…'**
  String get appUpdateChecking;

  /// No description provided for @appUpdateUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'应用已是最新版本'**
  String get appUpdateUpToDate;

  /// No description provided for @appUpdateAvailable.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本 {latest}（当前 {current}）'**
  String appUpdateAvailable(String latest, String current);

  /// No description provided for @appUpdateGoUpdate.
  ///
  /// In zh, this message translates to:
  /// **'前往更新'**
  String get appUpdateGoUpdate;

  /// No description provided for @appUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'应用更新检查失败：{detail}'**
  String appUpdateFailed(String detail);

  /// No description provided for @appUpdateTimeout.
  ///
  /// In zh, this message translates to:
  /// **'检查应用更新超时：网络响应过慢，请检查网络后重试'**
  String get appUpdateTimeout;

  /// No description provided for @versionLabel.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get versionLabel;

  /// No description provided for @downloadTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载视频'**
  String get downloadTitle;

  /// No description provided for @downloadSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'粘贴链接，即刻保存你喜欢的内容'**
  String get downloadSubtitle;

  /// No description provided for @newTask.
  ///
  /// In zh, this message translates to:
  /// **'新建下载任务'**
  String get newTask;

  /// No description provided for @videoUrl.
  ///
  /// In zh, this message translates to:
  /// **'视频链接'**
  String get videoUrl;

  /// No description provided for @parseHint.
  ///
  /// In zh, this message translates to:
  /// **'支持 MP4、WebM、音频等多种格式'**
  String get parseHint;

  /// No description provided for @parseSuccess.
  ///
  /// In zh, this message translates to:
  /// **'解析完成，可选择下载质量'**
  String get parseSuccess;

  /// No description provided for @parseReady.
  ///
  /// In zh, this message translates to:
  /// **'链接解析成功'**
  String get parseReady;

  /// No description provided for @readyBadge.
  ///
  /// In zh, this message translates to:
  /// **'READY'**
  String get readyBadge;

  /// No description provided for @previewPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'视频预览'**
  String get previewPlaceholder;

  /// No description provided for @videoMeta.
  ///
  /// In zh, this message translates to:
  /// **'来源：{source} · 时长 {duration}'**
  String videoMeta(String source, String duration);

  /// No description provided for @qualityLabel.
  ///
  /// In zh, this message translates to:
  /// **'下载质量'**
  String get qualityLabel;

  /// No description provided for @activeTasks.
  ///
  /// In zh, this message translates to:
  /// **'正在下载'**
  String get activeTasks;

  /// No description provided for @concurrencyLabel.
  ///
  /// In zh, this message translates to:
  /// **'当前并发下载数：{count}'**
  String concurrencyLabel(int count);

  /// No description provided for @taskCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个任务'**
  String taskCount(int count);

  /// No description provided for @viewAllHistory.
  ///
  /// In zh, this message translates to:
  /// **'查看全部历史'**
  String get viewAllHistory;

  /// No description provided for @noActiveTasks.
  ///
  /// In zh, this message translates to:
  /// **'暂无进行中的任务，粘贴链接即可开始'**
  String get noActiveTasks;

  /// No description provided for @historyTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载历史'**
  String get historyTitle;

  /// No description provided for @historySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查看与管理你保存过的所有内容'**
  String get historySubtitle;

  /// No description provided for @allRecords.
  ///
  /// In zh, this message translates to:
  /// **'全部记录'**
  String get allRecords;

  /// No description provided for @recordCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条'**
  String recordCount(int count);

  /// No description provided for @lastUpdated.
  ///
  /// In zh, this message translates to:
  /// **'最近更新：{time}'**
  String lastUpdated(String time);

  /// No description provided for @todayAt.
  ///
  /// In zh, this message translates to:
  /// **'今天 {time}'**
  String todayAt(String time);

  /// No description provided for @yesterdayAt.
  ///
  /// In zh, this message translates to:
  /// **'昨天 {time}'**
  String yesterdayAt(String time);

  /// No description provided for @clearHistory.
  ///
  /// In zh, this message translates to:
  /// **'清空记录'**
  String get clearHistory;

  /// No description provided for @clearHistoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'清空下载历史'**
  String get clearHistoryTitle;

  /// No description provided for @clearHistoryConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定清空全部下载历史吗？此操作不可撤销。'**
  String get clearHistoryConfirm;

  /// No description provided for @filterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get filterAll;

  /// No description provided for @historyFilterEmpty.
  ///
  /// In zh, this message translates to:
  /// **'该筛选条件下暂无记录'**
  String get historyFilterEmpty;

  /// No description provided for @colFileName.
  ///
  /// In zh, this message translates to:
  /// **'文件名称'**
  String get colFileName;

  /// No description provided for @colFormat.
  ///
  /// In zh, this message translates to:
  /// **'格式 · 清晰度'**
  String get colFormat;

  /// No description provided for @colTime.
  ///
  /// In zh, this message translates to:
  /// **'下载时间'**
  String get colTime;

  /// No description provided for @colStatus.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get colStatus;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'根据你的习惯调整 Linky 的工作方式'**
  String get settingsSubtitle;

  /// No description provided for @preferencesGroup.
  ///
  /// In zh, this message translates to:
  /// **'偏好设置'**
  String get preferencesGroup;

  /// No description provided for @sectionGeneral.
  ///
  /// In zh, this message translates to:
  /// **'常规'**
  String get sectionGeneral;

  /// No description provided for @sectionGeneralDesc.
  ///
  /// In zh, this message translates to:
  /// **'应用的基础显示与通知行为'**
  String get sectionGeneralDesc;

  /// No description provided for @sectionDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载设置'**
  String get sectionDownload;

  /// No description provided for @sectionDownloadDesc.
  ///
  /// In zh, this message translates to:
  /// **'文件保存位置与下载策略'**
  String get sectionDownloadDesc;

  /// No description provided for @sectionAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于与更新'**
  String get sectionAbout;

  /// No description provided for @sectionAboutDesc.
  ///
  /// In zh, this message translates to:
  /// **'版本信息与软件更新'**
  String get sectionAboutDesc;

  /// No description provided for @languageDesc.
  ///
  /// In zh, this message translates to:
  /// **'选择 Linky 显示的语言'**
  String get languageDesc;

  /// No description provided for @notifyOnComplete.
  ///
  /// In zh, this message translates to:
  /// **'完成后发出通知'**
  String get notifyOnComplete;

  /// No description provided for @notifyOnCompleteDesc.
  ///
  /// In zh, this message translates to:
  /// **'视频下载完成时提醒我'**
  String get notifyOnCompleteDesc;

  /// No description provided for @qualityDesc.
  ///
  /// In zh, this message translates to:
  /// **'未手动选择时默认使用的画质'**
  String get qualityDesc;

  /// No description provided for @downloadDirDesc.
  ///
  /// In zh, this message translates to:
  /// **'所有下载内容默认保存至此文件夹'**
  String get downloadDirDesc;

  /// No description provided for @concurrencyDesc.
  ///
  /// In zh, this message translates to:
  /// **'同时下载的任务数量，数值越高占用带宽越多'**
  String get concurrencyDesc;

  /// No description provided for @chooseFolder.
  ///
  /// In zh, this message translates to:
  /// **'选择目录'**
  String get chooseFolder;

  /// No description provided for @chooseFile.
  ///
  /// In zh, this message translates to:
  /// **'选择文件'**
  String get chooseFile;

  /// No description provided for @cookieAdded.
  ///
  /// In zh, this message translates to:
  /// **'已添加'**
  String get cookieAdded;

  /// No description provided for @cookieEmpty.
  ///
  /// In zh, this message translates to:
  /// **'尚未添加 Cookie 文件'**
  String get cookieEmpty;

  /// No description provided for @aboutVersionLine.
  ///
  /// In zh, this message translates to:
  /// **'版本 {version} · Windows 桌面版'**
  String aboutVersionLine(String version);

  /// No description provided for @ffmpegVersion.
  ///
  /// In zh, this message translates to:
  /// **'FFmpeg 版本'**
  String get ffmpegVersion;

  /// No description provided for @settingsCloseBehavior.
  ///
  /// In zh, this message translates to:
  /// **'点击关闭按钮时'**
  String get settingsCloseBehavior;

  /// No description provided for @settingsCloseBehaviorDesc.
  ///
  /// In zh, this message translates to:
  /// **'点击右上角关闭按钮后的行为，首次会弹出选择'**
  String get settingsCloseBehaviorDesc;

  /// No description provided for @closeBehaviorAsk.
  ///
  /// In zh, this message translates to:
  /// **'每次询问'**
  String get closeBehaviorAsk;

  /// No description provided for @closeBehaviorExit.
  ///
  /// In zh, this message translates to:
  /// **'直接退出'**
  String get closeBehaviorExit;

  /// No description provided for @closeBehaviorTray.
  ///
  /// In zh, this message translates to:
  /// **'退出到托盘'**
  String get closeBehaviorTray;

  /// No description provided for @closeDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭 Linky'**
  String get closeDialogTitle;

  /// No description provided for @closeDialogMessage.
  ///
  /// In zh, this message translates to:
  /// **'点击「关闭」后，你希望应用如何运行？'**
  String get closeDialogMessage;

  /// No description provided for @closeExit.
  ///
  /// In zh, this message translates to:
  /// **'直接退出'**
  String get closeExit;

  /// No description provided for @closeExitDesc.
  ///
  /// In zh, this message translates to:
  /// **'立即关闭应用，不再在后台运行'**
  String get closeExitDesc;

  /// No description provided for @closeTray.
  ///
  /// In zh, this message translates to:
  /// **'退出到系统托盘'**
  String get closeTray;

  /// No description provided for @closeTrayDesc.
  ///
  /// In zh, this message translates to:
  /// **'隐藏窗口，继续在后台运行'**
  String get closeTrayDesc;

  /// No description provided for @trayToolTip.
  ///
  /// In zh, this message translates to:
  /// **'Linky 链可'**
  String get trayToolTip;

  /// No description provided for @trayMenuShow.
  ///
  /// In zh, this message translates to:
  /// **'打开主界面'**
  String get trayMenuShow;

  /// No description provided for @trayMenuQuit.
  ///
  /// In zh, this message translates to:
  /// **'退出应用'**
  String get trayMenuQuit;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
    case 'zh':
      return SZh();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
