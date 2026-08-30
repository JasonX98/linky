// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get unknownTitle => 'Unknown title';

  @override
  String episodeNumber(int no) {
    return 'Episode $no';
  }

  @override
  String get navDownload => 'Download';

  @override
  String get aboutVersionUnknown => 'Unknown';

  @override
  String get navHistory => 'History';

  @override
  String get navSettings => 'Settings';

  @override
  String get historyEmpty => 'No download history';

  @override
  String get urlPlaceholder => 'Paste video link';

  @override
  String get analyze => 'Parse link';

  @override
  String get analyzing => 'Parsing video info…';

  @override
  String get addToDownload => 'Add to queue';

  @override
  String get taskList => 'Tasks';

  @override
  String get statusQueued => 'Queued';

  @override
  String get statusDownloading => 'Downloading';

  @override
  String get statusCanceling => 'Canceling...';

  @override
  String get statusCompleted => 'Completed';

  @override
  String statusDone(String path) {
    return 'Done: $path';
  }

  @override
  String get statusCanceled => 'Canceled';

  @override
  String get statusFailed => 'Failed';

  @override
  String get speedLabel => 'Speed';

  @override
  String etaLabel(int seconds) {
    return '${seconds}s left';
  }

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get openFolder => 'Open folder';

  @override
  String get selectAll => 'Select all';

  @override
  String get invertSelection => 'Invert selection';

  @override
  String playlistNotice(String title, int count) {
    return 'Detected playlist \"$title\" with $count entries';
  }

  @override
  String selectedCount(int count, int total) {
    return '$count/$total items selected';
  }

  @override
  String get openFile => 'Open file';

  @override
  String get settingsDownloadDir => 'Download directory';

  @override
  String get systemDownloadsFolder => 'System downloads folder';

  @override
  String get browse => 'Browse...';

  @override
  String get settingsCookieFile => 'Cookie file';

  @override
  String get cookieFileNotSet => 'Not set';

  @override
  String get clearCookieFile => 'Clear';

  @override
  String get downloadCookieHint =>
      'Some video platforms (e.g. YouTube) require sign-in to parse. Import a Cookie file and both download and analysis will use it.';

  @override
  String get settingsConcurrency => 'Concurrent downloads';

  @override
  String get settingsDefaultQuality => 'Default quality';

  @override
  String get qualityBest => 'Best quality';

  @override
  String get quality1080p => '1080p';

  @override
  String get quality720p => '720p';

  @override
  String get quality480p => '480p';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get errorLogin => 'Sign-in is required to download this content';

  @override
  String get cookieHintOnFail =>
      'Link analysis failed? Try importing a Cookie file and retry';

  @override
  String get errorGeo => 'This content is not available in your region';

  @override
  String get errorUnavailable =>
      'Video unavailable: it may have been removed or set to private';

  @override
  String get errorNetwork =>
      'Network error: check your connection and try again';

  @override
  String get errorTimeout => 'Request timed out: please try again later';

  @override
  String get errorParse => 'Failed to parse: could not read video information';

  @override
  String errorEngineMissing(String path) {
    return 'Download engine not found: $path';
  }

  @override
  String get errorOutputMissing =>
      'Download finished but the output file was not found';

  @override
  String errorUnknown(String detail) {
    return 'Unknown error: $detail';
  }

  @override
  String get unknownUploader => 'Unknown uploader';

  @override
  String durationSeconds(int count) {
    return '${count}s';
  }

  @override
  String get downloadFailed => 'Download failed';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutYtDlp => 'yt-dlp version';

  @override
  String get disclaimerText =>
      'This tool is for personal study and research only. When downloading, please comply with the target website\'s terms of service and local laws. Do not use this tool for commercial purposes or to infringe on the rights of others.';

  @override
  String get licensesNote =>
      'Built with yt-dlp (Unlicense) and FFmpeg (LGPL/GPL)';

  @override
  String get settingsCheckUpdate => 'Check for Updates';

  @override
  String get updateChecking => 'Checking…';

  @override
  String get updateUpToDate => 'Up to date';

  @override
  String updateUpdated(String component, String version) {
    return '$component updated to $version';
  }

  @override
  String updateBusy(String component) {
    return '$component: stop downloads first, then update';
  }

  @override
  String updateFailed(String component, String detail) {
    return '$component update failed: $detail';
  }

  @override
  String get updateTimeout =>
      'Update check timed out: network is too slow, please check your connection and try again';

  @override
  String get versionLabel => 'Version';

  @override
  String get downloadTitle => 'Download video';

  @override
  String get downloadSubtitle => 'Paste a link to save what you like';

  @override
  String get newTask => 'New download task';

  @override
  String get videoUrl => 'Video URL';

  @override
  String get parseHint => 'Supports MP4, WebM, audio and more';

  @override
  String get parseSuccess => 'Parsed. Pick a quality to start';

  @override
  String get parseReady => 'Link parsed';

  @override
  String get readyBadge => 'READY';

  @override
  String get previewPlaceholder => 'Preview';

  @override
  String videoMeta(String source, String duration) {
    return 'Source: $source · $duration';
  }

  @override
  String get qualityLabel => 'Quality';

  @override
  String get activeTasks => 'Downloading';

  @override
  String concurrencyLabel(int count) {
    return '$count concurrent downloads';
  }

  @override
  String taskCount(int count) {
    return '$count tasks';
  }

  @override
  String get viewAllHistory => 'View all history';

  @override
  String get noActiveTasks => 'No active tasks — paste a link to start';

  @override
  String get historyTitle => 'Download history';

  @override
  String get historySubtitle => 'Review and manage everything you saved';

  @override
  String get allRecords => 'All records';

  @override
  String recordCount(int count) {
    return '$count records';
  }

  @override
  String lastUpdated(String time) {
    return 'Last updated: $time';
  }

  @override
  String todayAt(String time) {
    return 'Today $time';
  }

  @override
  String yesterdayAt(String time) {
    return 'Yesterday $time';
  }

  @override
  String get clearHistory => 'Clear history';

  @override
  String get clearHistoryTitle => 'Clear download history';

  @override
  String get clearHistoryConfirm =>
      'Clear all download history? This cannot be undone.';

  @override
  String get filterAll => 'All';

  @override
  String get historyFilterEmpty => 'No records match this filter';

  @override
  String get colFileName => 'File name';

  @override
  String get colFormat => 'Format · Quality';

  @override
  String get colTime => 'Downloaded at';

  @override
  String get colStatus => 'Status';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSubtitle => 'Tune Linky to the way you work';

  @override
  String get preferencesGroup => 'Preferences';

  @override
  String get sectionGeneral => 'General';

  @override
  String get sectionGeneralDesc => 'Basic display and notification behavior';

  @override
  String get sectionDownload => 'Downloads';

  @override
  String get sectionDownloadDesc =>
      'Where files are saved and how downloads behave';

  @override
  String get sectionAbout => 'About & updates';

  @override
  String get sectionAboutDesc => 'Version info and updates';

  @override
  String get languageDesc => 'Choose the language Linky displays';

  @override
  String get notifyOnComplete => 'Notify me when finished';

  @override
  String get notifyOnCompleteDesc => 'Remind me when a download completes';

  @override
  String get qualityDesc => 'Quality used when nothing is picked manually';

  @override
  String get downloadDirDesc =>
      'All downloads are saved to this folder by default';

  @override
  String get concurrencyDesc =>
      'Number of simultaneous downloads; higher uses more bandwidth';

  @override
  String get chooseFolder => 'Choose folder';

  @override
  String get chooseFile => 'Choose file';

  @override
  String get cookieAdded => 'Added';

  @override
  String get cookieEmpty => 'No cookie file added';

  @override
  String aboutVersionLine(String version) {
    return 'Version $version · Windows desktop';
  }

  @override
  String get ffmpegVersion => 'FFmpeg version';

  @override
  String get proxyTitle => 'Proxy';

  @override
  String get proxyDesc =>
      'When enabled, all network requests (engine updates, link parsing, etc.) will go through the configured proxy server';

  @override
  String get proxyHost => 'Proxy address';

  @override
  String get proxyPort => 'Port';

  @override
  String get proxyEnabled => 'Use proxy';
}
