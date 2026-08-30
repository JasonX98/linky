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
  String get analyze => 'Analyze';

  @override
  String get analyzing => 'Analyzing...';

  @override
  String get addToDownload => 'Add to downloads';

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
      'If videos (e.g. YouTube) ask for sign-in or show signature errors, import a Cookie file (Netscape format) in Settings; both download and analysis will use it.';

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
}
