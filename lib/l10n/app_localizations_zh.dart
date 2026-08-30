// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class SZh extends S {
  SZh([String locale = 'zh']) : super(locale);

  @override
  String get unknownTitle => '未知标题';

  @override
  String episodeNumber(int no) {
    return '第$no集';
  }

  @override
  String get navDownload => '下载';

  @override
  String get aboutVersionUnknown => '未知';

  @override
  String get navHistory => '历史';

  @override
  String get navSettings => '设置';

  @override
  String get historyEmpty => '暂无下载记录';

  @override
  String get urlPlaceholder => '粘贴视频链接';

  @override
  String get analyze => '分析';

  @override
  String get analyzing => '分析中...';

  @override
  String get addToDownload => '加入下载';

  @override
  String get taskList => '任务列表';

  @override
  String get statusQueued => '排队中';

  @override
  String get statusDownloading => '下载中';

  @override
  String get statusCanceling => '正在取消...';

  @override
  String get statusCompleted => '已完成';

  @override
  String statusDone(String path) {
    return '完成：$path';
  }

  @override
  String get statusCanceled => '已取消';

  @override
  String get statusFailed => '失败';

  @override
  String get speedLabel => '速度';

  @override
  String etaLabel(int seconds) {
    return '剩余 ${seconds}s';
  }

  @override
  String get retry => '重试';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get openFolder => '打开文件夹';

  @override
  String get selectAll => '全选';

  @override
  String get invertSelection => '反选';

  @override
  String playlistNotice(String title, int count) {
    return '检测到播放列表「$title」，共 $count 个条目';
  }

  @override
  String selectedCount(int count, int total) {
    return '已选 $count/$total 个条目';
  }

  @override
  String get openFile => '打开文件';

  @override
  String get settingsDownloadDir => '下载目录';

  @override
  String get systemDownloadsFolder => '系统下载文件夹';

  @override
  String get browse => '浏览...';

  @override
  String get settingsCookieFile => 'Cookie 文件';

  @override
  String get cookieFileNotSet => '未设置';

  @override
  String get clearCookieFile => '清除';

  @override
  String get downloadCookieHint =>
      '若视频（如 YouTube）提示需要登录或签名错误，请在设置中导入 Cookie 文件（Netscape 格式），下载与分析都会使用。';

  @override
  String get settingsConcurrency => '同时下载任务数';

  @override
  String get settingsDefaultQuality => '默认画质';

  @override
  String get qualityBest => '最佳画质';

  @override
  String get quality1080p => '1080p';

  @override
  String get quality720p => '720p';

  @override
  String get quality480p => '480p';

  @override
  String get settingsLanguage => '语言';

  @override
  String get errorLogin => '需要登录后才能下载该内容';

  @override
  String get errorGeo => '该内容在当前地区不可用';

  @override
  String get errorUnavailable => '视频不可用：可能已被删除或设为私密';

  @override
  String get errorNetwork => '网络错误：请检查网络连接后重试';

  @override
  String get errorTimeout => '请求超时：请稍后重试';

  @override
  String get errorParse => '解析失败：无法读取视频信息';

  @override
  String errorEngineMissing(String path) {
    return '未找到下载引擎：$path';
  }

  @override
  String get errorOutputMissing => '下载完成但未找到输出文件';

  @override
  String errorUnknown(String detail) {
    return '未知错误：$detail';
  }

  @override
  String get unknownUploader => '未知上传者';

  @override
  String durationSeconds(int count) {
    return '$count 秒';
  }

  @override
  String get downloadFailed => '下载失败';

  @override
  String get aboutTitle => '关于';

  @override
  String get aboutYtDlp => 'yt-dlp 版本';

  @override
  String get disclaimerText =>
      '本工具仅供个人学习研究，下载行为请遵守目标网站服务条款及当地法律法规。请勿将本工具用于商业用途或侵犯他人合法权益。';

  @override
  String get licensesNote => '基于 yt-dlp（Unlicense）与 FFmpeg（LGPL/GPL）构建';

  @override
  String get settingsCheckUpdate => '检查更新';

  @override
  String get updateChecking => '检查中…';

  @override
  String get updateUpToDate => '已是最新版本';

  @override
  String updateUpdated(String component, String version) {
    return '$component 已更新到 $version';
  }

  @override
  String updateBusy(String component) {
    return '$component：请先停止下载任务后再更新';
  }

  @override
  String updateFailed(String component, String detail) {
    return '$component 更新失败：$detail';
  }
}
