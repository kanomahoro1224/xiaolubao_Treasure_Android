package kano.xiaolubao.com

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kano.xiaolubao.com.widget.WidgetRefresh

/**
 * 除了承载 Flutter，还多挂一条 `kano/widget` 通道：
 * Dart 侧写完小组件快照后喊一声，桌面上的卡片立刻重绘，不用等 30 分钟的定时刷新。
 *
 * `kano/notifications`：设置页打开「接收推送」时申请 POST_NOTIFICATIONS。
 */
class MainActivity : FlutterActivity() {
    private var notificationResult: MethodChannel.Result? = null

    /**
     * 这里**不能**用 `registerForActivityResult`：那是 `ComponentActivity` 的 API，
     * 而 `FlutterActivity` 继承的是老式 `android.app.Activity`，Kotlin 侧解析不到，
     * 会直接编译失败（Unresolved reference）。所以退回 `requestPermissions` +
     * `onRequestPermissionsResult` 这套传统回调。
     */
    private companion object {
        const val REQUEST_NOTIFICATIONS = 1001
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kano/widget")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "refresh" -> {
                        WidgetRefresh.updateAll(this)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kano/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensure" -> ensureNotifications(result)
                    "enabled" -> result.success(
                        NotificationManagerCompat.from(this).areNotificationsEnabled(),
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private fun ensureNotifications(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33) {
            result.success(true)
            return
        }
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            result.success(true)
            return
        }
        if (notificationResult != null) {
            result.success(false)
            return
        }
        notificationResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_NOTIFICATIONS,
        )
    }

    /** 「接收推送」的系统弹窗结果，回给等着的 Dart 侧。 */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_NOTIFICATIONS) return
        val pending = notificationResult ?: return
        notificationResult = null
        pending.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
    }
}
