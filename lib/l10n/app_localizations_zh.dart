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
  String get analyze => '解析链接';

  @override
  String get analyzing => '正在解析视频信息…';

  @override
  String get addToDownload => '加入下载队列';

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

  @override
  String get versionLabel => '版本';

  @override
  String get downloadTitle => '下载视频';

  @override
  String get downloadSubtitle => '粘贴链接，即刻保存你喜欢的内容';

  @override
  String get newTask => '新建下载任务';

  @override
  String get videoUrl => '视频链接';

  @override
  String get parseHint => '支持 MP4、WebM、音频等多种格式';

  @override
  String get parseSuccess => '解析完成，可选择下载质量';

  @override
  String get parseReady => '链接解析成功';

  @override
  String get readyBadge => 'READY';

  @override
  String get previewPlaceholder => '视频预览';

  @override
  String videoMeta(String source, String duration) {
    return '来源：$source · 时长 $duration';
  }

  @override
  String get qualityLabel => '下载质量';

  @override
  String get activeTasks => '正在下载';

  @override
  String concurrencyLabel(int count) {
    return '当前并发下载数：$count';
  }

  @override
  String taskCount(int count) {
    return '$count 个任务';
  }

  @override
  String get viewAllHistory => '查看全部历史';

  @override
  String get noActiveTasks => '暂无进行中的任务，粘贴链接即可开始';

  @override
  String get historyTitle => '下载历史';

  @override
  String get historySubtitle => '查看与管理你保存过的所有内容';

  @override
  String get allRecords => '全部记录';

  @override
  String recordCount(int count) {
    return '$count 条';
  }

  @override
  String lastUpdated(String time) {
    return '最近更新：$time';
  }

  @override
  String todayAt(String time) {
    return '今天 $time';
  }

  @override
  String yesterdayAt(String time) {
    return '昨天 $time';
  }

  @override
  String get clearHistory => '清空记录';

  @override
  String get clearHistoryTitle => '清空下载历史';

  @override
  String get clearHistoryConfirm => '确定清空全部下载历史吗？此操作不可撤销。';

  @override
  String get filterAll => '全部';

  @override
  String get historyFilterEmpty => '该筛选条件下暂无记录';

  @override
  String get colFileName => '文件名称';

  @override
  String get colFormat => '格式 · 清晰度';

  @override
  String get colTime => '下载时间';

  @override
  String get colStatus => '状态';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSubtitle => '根据你的习惯调整 Linky 的工作方式';

  @override
  String get saveSettings => '保存设置';

  @override
  String get saved => '已保存';

  @override
  String get savedBanner => '设置已保存';

  @override
  String get preferencesGroup => '偏好设置';

  @override
  String get sectionGeneral => '常规';

  @override
  String get sectionGeneralDesc => '应用的基础显示与通知行为';

  @override
  String get sectionDownload => '下载设置';

  @override
  String get sectionDownloadDesc => '文件保存位置与下载策略';

  @override
  String get sectionAbout => '关于与更新';

  @override
  String get sectionAboutDesc => '版本信息与软件更新';

  @override
  String get languageDesc => '选择 Linky 显示的语言';

  @override
  String get notifyOnComplete => '完成后发出通知';

  @override
  String get notifyOnCompleteDesc => '视频下载完成时提醒我';

  @override
  String get qualityDesc => '未手动选择时默认使用的画质';

  @override
  String get downloadDirDesc => '所有下载内容默认保存至此文件夹';

  @override
  String get concurrencyDesc => '同时下载的任务数量，数值越高占用带宽越多';

  @override
  String get chooseFolder => '选择目录';

  @override
  String get chooseFile => '选择文件';

  @override
  String get cookieAdded => '已添加';

  @override
  String get cookieEmpty => '尚未添加 Cookie 文件';

  @override
  String aboutVersionLine(String version) {
    return '版本 $version · Windows 桌面版';
  }

  @override
  String get ffmpegVersion => 'FFmpeg 版本';
}
