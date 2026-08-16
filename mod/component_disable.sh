#!/system/bin/sh
# 组件禁用层 v2.1 — 多App广告组件禁用 (移植自"去广告-特别版")
# v2.1: 修复$变量展开bug(各段独立单引号变量, 最后合并)
# 原理: pm disable 广告 Activity/Service/Provider, 广告代码无法运行, 无黑窗口
# 容错: 组件不存在(App未安装/更新改名)时 failed 跳过, 不影响其他组件
MODDIR="${0%/*}/.."
LOG="$MODDIR/module.log"

# ===== 段1: 123云盘 74组件 =====
list1='
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$RequestInstallPermissionActivity
com.mfcloudcalculate.networkdisk/com.qq.e.comm.GDTFileProvider
com.mfcloudcalculate.networkdisk/com.meishu.sdk.activity.SdkInterstitialActivity
com.mfcloudcalculate.networkdisk/com.meishu.sdk.activity.GdtPrivacyActivity
com.mfcloudcalculate.networkdisk/com.meishu.sdk.activity.MeishuDownloadDetailActivity
com.mfcloudcalculate.networkdisk/com.meishu.sdk.activity.MeishuRewardVideoPlayerActivity
com.mfcloudcalculate.networkdisk/com.meishu.sdk.activity.MeishuWebviewActivity
com.mfcloudcalculate.networkdisk/com.meishu.sdk.core.webview.TaskCenterWebActivity
com.mfcloudcalculate.networkdisk/com.meishu.sdk.meishu_ad.view.DownLoadDialogActivity
com.mfcloudcalculate.networkdisk/com.meishu.sdk.activity.MeishuAlertDialogActivity
com.mfcloudcalculate.networkdisk/com.meishu.sdk.activity.MeishuDetailActivity
com.mfcloudcalculate.networkdisk/com.beizi.ad.DownloadService
com.mfcloudcalculate.networkdisk/com.baidu.mobads.sdk.api.BdFileProvider
com.mfcloudcalculate.networkdisk/com.baidu.mobads.sdk.api.AppActivity
com.mfcloudcalculate.networkdisk/com.baidu.mobads.sdk.api.MobRewardVideoActivity
com.mfcloudcalculate.networkdisk/com.baidu.mobads.sdk.api.MobCPUDramaActivity
com.mfcloudcalculate.networkdisk/com.baidu.mobads.sdk.api.BdShellActivity
com.mfcloudcalculate.networkdisk/com.qq.e.comm.DownloadService
com.mfcloudcalculate.networkdisk/com.qq.e.ads.ADActivity
com.mfcloudcalculate.networkdisk/com.qq.e.ads.PortraitADActivity
com.mfcloudcalculate.networkdisk/com.qq.e.ads.LandscapeADActivity
com.mfcloudcalculate.networkdisk/com.qq.e.ads.RewardvideoPortraitADActivity
com.mfcloudcalculate.networkdisk/com.qq.e.ads.RewardvideoLandscapeADActivity
com.mfcloudcalculate.networkdisk/com.qq.e.ads.DialogActivity
com.mfcloudcalculate.networkdisk/com.bytedance.sdk.openadsdk.stub.activity.Stub_Standard_Activity
com.mfcloudcalculate.networkdisk/com.bytedance.sdk.openadsdk.stub.activity.Stub_Standard_Portrait_Activity
com.mfcloudcalculate.networkdisk/com.bytedance.sdk.openadsdk.stub.activity.Stub_Standard_Activity_T
com.mfcloudcalculate.networkdisk/com.bytedance.sdk.openadsdk.stub.activity.Stub_Standard_Landscape_Activity
com.mfcloudcalculate.networkdisk/com.bytedance.sdk.openadsdk.stub.activity.Stub_Activity
com.mfcloudcalculate.networkdisk/com.bytedance.sdk.openadsdk.stub.activity.Stub_SingleTask_Activity_T
com.mfcloudcalculate.networkdisk/com.bytedance.sdk.openadsdk.stub.activity.Stub_SingleTask_Activity
com.mfcloudcalculate.networkdisk/com.bytedance.sdk.openadsdk.stub.server.DownloaderServerManager
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.AdWebViewActivity
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.KsFullScreenVideoActivity
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.KsFullScreenLandScapeVideoActivity
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.KsRewardVideoActivity
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.KSRewardLandScapeVideoActivity
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.FeedDownloadActivity
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$KsTrendsActivity
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$ProfileHomeActivity
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$ProfileVideoDetailActivity
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$TubeProfileActivity
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$ChannelDetailActivity
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$TubeDetailActivity
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$EpisodeDetailActivity
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$FragmentActivity1
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$GoodsPlayBackActivity
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$FragmentActivity2
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$FragmentActivity3
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$FragmentActivity4
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$FragmentActivity5
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$FragmentActivity6
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$FragmentActivity7
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$FragmentActivity8
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$FragmentActivity9
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$FragmentActivity10
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$FragmentActivitySingleTop1
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$FragmentActivitySingleTop2
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$FragmentActivitySingleInstance1
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$FragmentActivitySingleInstance2
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$DeveloperConfigActivity
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$LandscapeFragmentActivity
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$LandscapeFragmentActivitySingleTop1
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$LandscapeFragmentActivitySingleTop2
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$LandscapeFragmentActivitySingleTask1
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$LandscapeFragmentActivitySingleTask2
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$LandscapeFragmentActivitySingleInstance1
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.BaseFragmentActivity$LandscapeFragmentActivitySingleInstance2
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.FileDownloadService$SharedMainProcessService
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.FileDownloadService$SeparateProcessService
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.DownloadService
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.ServiceProxyRemote
com.mfcloudcalculate.networkdisk/com.kwad.sdk.api.proxy.app.AdSdkFileProvider
com.mfcloudcalculate.networkdisk/com.alipay.mobile.logmonitor.ClientMonitorExtReceiver
'

# ===== 段2: 番茄小说 com.dragon.read 100组件 (IFW转pm) =====
list2='
com.dragon.read/com.dragon.read.ad.dark.ui.AdSubmitDialogActivity
com.dragon.read/com.ss.android.downloadlib.activity.AppInfoDialogActivity
com.dragon.read/com.dragon.read.reader.speech.detail.AudioCatalogActivity
com.dragon.read/com.dragon.read.social.paragraph.ui.DialogActivity
com.dragon.read/com.dragon.read.ad.dark.ui.NewAdSubmitDialogActivity
com.dragon.read/com.dragon.read.pages.main.PermissionGuidanceDialogActivity
com.dragon.read/com.bytedance.praisedialoglib.ui.PraiseDialogActivity
com.dragon.read/com.dragon.read.pages.debug.queuedialog.QueueDialogActivity
com.dragon.read/com.ss.android.ShowDialogActivity
com.dragon.read/com.dragon.read.ad.dark.ui.AdLandingActivity
com.dragon.read/com.dragon.read.ad.dark.ui.NewAdLandingActivity
com.dragon.read/com.dragon.read.ad.dark.ui.TextLinkAdLandingActivity
com.dragon.read/com.dragon.read.ad.lynxweb.AdLynxActivity
com.dragon.read/com.dragon.read.pages.splash.ad.NormalAdLandingActivity
com.dragon.read/com.taobao.agoo.AgooCommondReceiver
com.dragon.read/com.taobao.accs.EventReceiver
com.dragon.read/com.taobao.accs.ServiceReceiver
com.dragon.read/com.ss.android.push.DefaultReceiver
com.dragon.read/com.bytedance.push.notification.NotificationDeleteBroadcastReceiver
com.dragon.read/com.huawei.hms.support.api.push.PushMsgReceiver
com.dragon.read/com.huawei.hms.support.api.push.PushReceiver
com.dragon.read/com.vivo.VivoPushMessageReceiver
com.dragon.read/com.bytedance.applog.collector.Collector
com.dragon.read/com.taobao.accs.ChannelService
com.dragon.read/com.taobao.accs.data.MsgDistributeService
com.dragon.read/com.taobao.accs.internal.AccsJobService
com.dragon.read/com.taobao.accs.ChannelService$KernelService
com.dragon.read/com.ss.android.message.log.LogService
com.dragon.read/com.bytedance.common.process.service.CrossProcessServiceForPush
com.dragon.read/com.bytedance.common.process.service.CrossProcessServiceForPushService
com.dragon.read/com.bytedance.privacy.proxy.ipc.DeviceInfoRemoteService
com.dragon.read/com.ss.android.message.NotifyService
com.dragon.read/com.bytedance.common.wschannel.server.WsChannelService
com.dragon.read/com.vivo.push.sdk.service.CommandClientService
com.dragon.read/com.heytap.msp.push.service.CompatibleDataMessageCallbackService
com.dragon.read/com.heytap.msp.push.service.DataMessageCallbackService
com.dragon.read/com.ss.android.push.DefaultService
com.dragon.read/com.huawei.hms.support.api.push.service.HmsMsgService
com.dragon.read/com.dragon.read.push.PushMessageHandler
com.dragon.read/com.ss.android.newmedia.redbadge.RedBadgePushProcessService
com.dragon.read/com.bytedance.push.alliance.partner.Service2
com.dragon.read/com.bytedance.push.alliance.partner.Service3
com.dragon.read/com.tt.miniapphost.feedback.FeedbackRecordService
com.dragon.read/com.minigame.miniapphost.feedback.FeedbackRecordService
com.dragon.read/com.tt.miniapphost.process.base.HostCrossProcessCallService
com.dragon.read/com.bytedance.minigame.bdpbase.ipc.extention.MainDefaultIpcService
com.dragon.read/com.tt.miniapphost.placeholder.MiniappService0
com.dragon.read/com.minigame.miniapphost.placeholder.MiniappService0
com.dragon.read/com.tt.miniapphost.placeholder.MiniappService1
com.dragon.read/com.minigame.miniapphost.placeholder.MiniappService1
com.dragon.read/com.tt.miniapphost.placeholder.MiniappService2
com.dragon.read/com.minigame.miniapphost.placeholder.MiniappService2
com.dragon.read/com.tt.miniapphost.placeholder.MiniappService3
com.dragon.read/com.minigame.miniapphost.placeholder.MiniappService3
com.dragon.read/com.tt.miniapphost.placeholder.MiniappService4
com.dragon.read/com.minigame.miniapphost.placeholder.MiniappService4
com.dragon.read/org.android.agoo.accs.AgooService
com.dragon.read/com.amap.api.location.APSService
com.dragon.read/com.ss.android.socialbase.downloader.impls.DownloadHandleService
com.dragon.read/com.ss.android.socialbase.appdownloader.DownloadHandlerService
com.dragon.read/com.ss.android.socialbase.downloader.downloader.DownloadService
com.dragon.read/com.dragon.read.proxy.MainProcessWsChannelService
com.dragon.read/com.bytedance.mira.am.KeepAlive$InnerService
com.dragon.read/com.bytedance.mira.am.KeepAlive
com.dragon.read/com.ss.android.socialbase.downloader.downloader.IndependentProcessDownloadService
com.dragon.read/com.huawei.MessageService
com.dragon.read/com.ss.android.newmedia.redbadge.RedbadgeHandler
com.dragon.read/com.bytedance.mira.stub.RedirectService
com.dragon.read/com.ss.android.socialbase.appdownloader.RetryJobSchedulerService
com.dragon.read/com.bytedance.org.chromium.content.app.SandboxedProcessService2
com.dragon.read/com.bytedance.org.chromium.content.app.SandboxedProcessService3
com.dragon.read/com.bytedance.org.chromium.content.app.SandboxedProcessService4
com.dragon.read/com.bytedance.org.chromium.content.app.SandboxedProcessService1
com.dragon.read/com.bytedance.org.chromium.content.app.SandboxedProcessService5
com.dragon.read/com.bytedance.org.chromium.content.app.SandboxedProcessService6
com.dragon.read/com.bytedance.org.chromium.content.app.SandboxedProcessService7
com.dragon.read/com.bytedance.org.chromium.content.app.SandboxedProcessService8
com.dragon.read/com.bytedance.org.chromium.content.app.SandboxedProcessService9
com.dragon.read/com.huawei.agconnect.core.ServiceDiscovery
com.dragon.read/com.ss.android.socialbase.downloader.downloader.SqlDownloadCacheService
com.dragon.read/com.bytedance.mira.stub.p1.StubService1
com.dragon.read/com.bytedance.mira.stub.p0.StubService2
com.dragon.read/com.bytedance.mira.stub.p1.StubService2
com.dragon.read/com.bytedance.mira.stub.p0.StubService3
com.dragon.read/com.bytedance.mira.stub.p0.StubService4
com.dragon.read/com.bytedance.bdp.unitycontainer.service.UcAppService200
com.dragon.read/com.bytedance.bdp.unitycontainer.service.UcAppService201
com.dragon.read/com.bytedance.bdp.unitycontainer.service.UcAppService202
com.dragon.read/com.bytedance.bdp.unitycontainer.service.UcAppService203
com.dragon.read/com.umeng.UmengMessageHandler
com.dragon.read/com.umeng.message.UmengMessageIntentReceiverService
com.dragon.read/com.umeng.message.UmengMessageCallbackHandlerService
com.dragon.read/com.bytedance.common.wschannel.client.WsClientService
com.dragon.read/com.a.a.XmFgService21
com.dragon.read/com.a.a.XmFgService22
com.dragon.read/com.a.a.XmFgService23
com.dragon.read/com.bytedance.bdp.unitycontainer.download.SCDownloadService
com.dragon.read/com.bytedance.bdp.unitycontainer.download.SCMainProcessService
com.dragon.read/androidx.room.MultiInstanceInvalidationService
com.dragon.read/com.ss.android.socialbase.downloader.notification.DownloadNotificationService
'

# ===== 段3: 抖音 com.ss.android.ugc.aweme 67组件 (IFW转pm) =====
list3='
com.ss.android.ugc.aweme/com.bytedance.apm6.traffic.TrafficTransportService
com.ss.android.ugc.aweme/com.ss.android.message.NotifyService
com.ss.android.ugc.aweme/com.bytedance.common.process.service.CrossProcessServiceForPushService
com.ss.android.ugc.aweme/com.bytedance.org.chromium.content.app.SandboxedProcessService6
com.ss.android.ugc.aweme/com.a.a.XmFgService21
com.ss.android.ugc.aweme/com.bytedance.org.chromium.content.app.SandboxedProcessService7
com.ss.android.ugc.aweme/com.bytedance.common.wschannel.client.WsClientService
com.ss.android.ugc.aweme/com.bytedance.org.chromium.content.app.SandboxedProcessService4
com.ss.android.ugc.aweme/com.bytedance.org.chromium.content.app.SandboxedProcessService5
com.ss.android.ugc.aweme/com.bytedance.org.chromium.content.app.SandboxedProcessService8
com.ss.android.ugc.aweme/com.bytedance.org.chromium.content.app.SandboxedProcessService9
com.ss.android.ugc.aweme/com.bytedance.common.process.service.CrossProcessServiceForMain
com.ss.android.ugc.aweme/com.bytedance.org.chromium.content.app.SandboxedProcessService2
com.ss.android.ugc.aweme/com.bytedance.org.chromium.content.app.SandboxedProcessService3
com.ss.android.ugc.aweme/com.amap.api.location.APSService
com.ss.android.ugc.aweme/com.bytedance.org.chromium.content.app.SandboxedProcessService0
com.ss.android.ugc.aweme/com.a.a.XmFgService23
com.ss.android.ugc.aweme/com.bytedance.org.chromium.content.app.SandboxedProcessService1
com.ss.android.ugc.aweme/com.a.a.XmFgService22
com.ss.android.ugc.aweme/com.ss.android.newmedia.redbadge.RedbadgeHandler
com.ss.android.ugc.aweme/.impl.downgrade.notice.MainProcessWsChannelService
com.ss.android.ugc.aweme/com.ss.android.push.daemon.PushService
com.ss.android.ugc.aweme/com.umeng.message.UmengIntentService
com.ss.android.ugc.aweme/com.taobao.accs.ChannelService$KernelService
com.ss.android.ugc.aweme/com.bytedance.common.wschannel.server.WsChannelService
com.ss.android.ugc.aweme/com.taobao.accs.internal.AccsJobService
com.ss.android.ugc.aweme/com.bytedance.common.process.service.CrossProcessServiceForSmp
com.ss.android.ugc.aweme/com.taobao.accs.data.MsgDistributeService
com.ss.android.ugc.aweme/com.bytedance.common.process.service.CrossProcessServiceForPush
com.ss.android.ugc.aweme/com.taobao.accs.ChannelService
com.ss.android.ugc.aweme/org.android.agoo.accs.AgooService
com.ss.android.ugc.aweme/.player.plugin.mediasession.common.MediaSessionService
com.ss.android.ugc.aweme/com.ss.android.newmedia.redbadge.RedBadgePushProcessService
com.ss.android.ugc.aweme/com.ss.android.push.window.oppo.ScreenReceiver
com.ss.android.ugc.aweme/.ushlib.os.receiver.NotificationBroadcastReceiver
com.ss.android.ugc.aweme/.push_lib.message.ScreenReceiver
com.ss.android.ugc.aweme/.video.EarPhoneUnplugReceiver
com.ss.android.ugc.aweme/.search.widget.appwidget.SearchWidgetWordWithHotspotProvider
com.ss.android.ugc.aweme/com.meizu.cloud.pushsdk.SystemReceiver
com.ss.android.ugc.aweme/com.ss.android.ugc.rhea.receiver.ControllerReceiver
com.ss.android.ugc.aweme/.search.widget.appwidget.SearchWidgetWordWithToolsProvider
com.ss.android.ugc.aweme/.common.net.NetWorkStateReceiver
com.ss.android.ugc.aweme/.search.widget.appwidget.SearchWidgetWordProvider
com.ss.android.ugc.aweme/com.bytedance.android.xr.business.manager.ring.XrBackgroundNotificationClickReceiver
com.ss.android.ugc.aweme/com.xiaomi.push.service.receivers.NetworkStatusReceiver
com.ss.android.ugc.aweme/com.ss.android.push.daemon.PushReceiver
com.ss.android.ugc.aweme/com.bytedance.android.ug.expore.widget.provider.FriendFakeIconWidgetProvider
com.ss.android.ugc.aweme/.push_lib.message.ScreenOnPushActionReceiver
com.ss.android.ugc.aweme/.share.systemshare.SystemShareTargetChosenReceiver
com.ss.android.ugc.aweme/.common.net.NetworkReceiver
com.ss.android.ugc.aweme/com.a.b.SmpReceiver2
com.ss.android.ugc.aweme/com.a.b.SmpReceiver1
com.ss.android.ugc.aweme/com.alibaba.sdk.android.push.SystemEventReceiver
com.ss.android.ugc.aweme/.search.widget.appwidget.SearchWidgetWordWithToolsProvider3
com.ss.android.ugc.aweme/.closefriends.widget.CloseFriendsWidgetLargeProvider
com.ss.android.ugc.aweme/.search.widget.appwidget.SearchWidgetWordWithToolsProvider2
com.ss.android.ugc.aweme/com.taobao.accs.ServiceReceiver
com.ss.android.ugc.aweme/com.bytedance.push.notification.NotificationDeleteBroadcastReceiver
com.ss.android.ugc.aweme/com.a.b.SmpReceiver3
com.ss.android.ugc.aweme/.closefriends.widget.CloseFriendsWidgetSmallProvider
com.ss.android.ugc.aweme/com.taobao.accs.EventReceiver
com.ss.android.ugc.aweme/com.umeng.message.NotificationProxyBroadcastReceiver
com.ss.android.ugc.aweme/com.bytedance.android.ug.expore.widget.provider.HotSpotFakeIconWidgetProvider
com.ss.android.ugc.aweme/com.bytedance.tracer.TracerReceiver
com.ss.android.ugc.aweme/com.taobao.agoo.AgooCommondReceiver
com.ss.android.ugc.aweme/com.bytedance.frameworks.plugin.receiver.MiraErrorLogReceiver
com.ss.android.ugc.aweme/com.bytedance.applog.collector.Collector
'

# ===== 段4: 超级星饭团 com.sup.android.superb 41组件 (IFW转pm) =====
list4='
com.sup.android.superb/com.bytedance.push.appstatus.AppStatusServiceForPushProcess
com.sup.android.superb/com.ss.android.message.log.LogService
com.sup.android.superb/com.ss.android.message.NotifyService
com.sup.android.superb/com.ss.android.socialbase.downloader.notification.DownloadNotificationService
com.sup.android.superb/com.bytedance.org.chromium.content.app.SandboxedProcessService6
com.sup.android.superb/com.bytedance.org.chromium.content.app.SandboxedProcessService7
com.sup.android.superb/com.bytedance.common.wschannel.client.WsClientService
com.sup.android.superb/com.bytedance.org.chromium.content.app.SandboxedProcessService4
com.sup.android.superb/com.bytedance.org.chromium.content.app.SandboxedProcessService5
com.sup.android.superb/com.alibaba.sdk.android.push.PushIntentService
com.sup.android.superb/com.bytedance.org.chromium.content.app.SandboxedProcessService8
com.sup.android.superb/com.bytedance.org.chromium.content.app.SandboxedProcessService9
com.sup.android.superb/com.bytedance.org.chromium.content.app.SandboxedProcessService2
com.sup.android.superb/com.bytedance.org.chromium.content.app.SandboxedProcessService3
com.sup.android.superb/com.amap.api.location.APSService
com.sup.android.superb/com.bytedance.org.chromium.content.app.SandboxedProcessService0
com.sup.android.superb/com.bytedance.org.chromium.content.app.SandboxedProcessService1
com.sup.android.superb/com.umeng.message.UmengIntentService
com.sup.android.superb/com.taobao.accs.ChannelService$KernelService
com.sup.android.superb/com.tt.miniapphost.placeholder.MiniappService3
com.sup.android.superb/com.tt.miniapphost.placeholder.MiniappService4
com.sup.android.superb/com.ss.android.socialbase.downloader.downloader.SqlDownloadCacheService
com.sup.android.superb/com.ss.android.push.DefaultService
com.sup.android.superb/com.bytedance.common.wschannel.server.WsChannelService
com.sup.android.superb/com.taobao.accs.data.MsgDistributeService
com.sup.android.superb/com.umeng.UmengMessageHandler
com.sup.android.superb/com.taobao.accs.ChannelService
com.sup.android.superb/com.tt.miniapphost.placeholder.MiniappService1
com.sup.android.superb/com.tt.miniapphost.placeholder.MiniappService2
com.sup.android.superb/com.ss.android.newmedia.redbadge.RedBadgePushProcessService
com.sup.android.superb/com.bytedance.frameworks.plugin.stub.p1.StubReceiver
com.sup.android.superb/com.ss.android.push.window.oppo.ScreenReceiver
com.sup.android.superb/com.taobao.accs.EventReceiver
com.sup.android.superb/com.ss.android.article.base.feature.plugin.PluginReportReceiver
com.sup.android.superb/com.umeng.message.NotificationProxyBroadcastReceiver
com.sup.android.superb/com.alibaba.sdk.android.push.SystemEventReceiver
com.sup.android.superb/com.taobao.agoo.AgooCommondReceiver
com.sup.android.superb/com.bytedance.frameworks.plugin.receiver.MiraErrorLogReceiver
com.sup.android.superb/com.bytedance.embedapplog.collector.Collector
com.sup.android.superb/com.taobao.accs.ServiceReceiver
com.sup.android.superb/com.bytedance.frameworks.plugin.stub.p0.StubReceiver
'

# ===== 段5: 系统广告服务 (伪装隐藏换pm disable, 不隐藏图标) =====
system_pkgs='
com.opos.ad
com.opos.ads
com.xiaomi.ab
com.miui.analytics
com.miui.systemAdSolution
com.android.append
bin.mt.plus.termex
'

disable_list="$list1$list2$list3$list4"

# restore 模式: 卸载时恢复所有被禁组件/系统包
if [ "$1" = "restore" ]; then
    for i in $disable_list; do
        pm enable "$i" >/dev/null 2>&1
    done
    for p in $system_pkgs; do
        pm enable "$p" >/dev/null 2>&1
    done
    echo "[$(date)] component_disable: restore 全部组件/系统包" >> "$LOG"
    exit 0
fi

# 等待 package service 可用
for i in $(seq 1 20); do
    pm list packages com.android.settings 2>/dev/null | grep -q settings && break
    sleep 2
done

disabled=0
failed=0

for i in $disable_list; do
    [ -z "$i" ] && continue
    if pm disable "$i" >/dev/null 2>&1; then
        disabled=$((disabled + 1))
    else
        failed=$((failed + 1))
    fi
done

# 系统广告服务包 (disable整个包, 不hide)
for p in $system_pkgs; do
    [ -z "$p" ] && continue
    if pm list packages "$p" 2>/dev/null | grep -qF "package:$p"; then
        if pm disable "$p" >/dev/null 2>&1; then
            disabled=$((disabled + 1))
        else
            failed=$((failed + 1))
        fi
    else
        failed=$((failed + 1))
    fi
done

echo "[$(date)] component_disable: total=289 disabled=$disabled failed=$failed" >> "$LOG"