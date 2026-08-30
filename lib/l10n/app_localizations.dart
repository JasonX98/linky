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
  /// **'分析'**
  String get analyze;

  /// No description provided for @analyzing.
  ///
  /// In zh, this message translates to:
  /// **'分析中...'**
  String get analyzing;

  /// No description provided for @addToDownload.
  ///
  /// In zh, this message translates to:
  /// **'加入下载'**
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
  /// **'若视频（如 YouTube）提示需要登录或签名错误，请在设置中导入 Cookie 文件（Netscape 格式），下载与分析都会使用。'**
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
  /// **'检查更新'**
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
