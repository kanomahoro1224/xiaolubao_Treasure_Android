package kano.xiaolubao.com

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kano.xiaolubao.com.widget.WidgetRefresh

/**
 * 除了承载 Flutter，还多挂一条 `kano/widget` 通道：
 * Dart 侧写完小组件快照后喊一声，桌面上的卡片立刻重绘，不用等 30 分钟的定时刷新。
 */
class MainActivity : FlutterActivity() {
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
    }
}
