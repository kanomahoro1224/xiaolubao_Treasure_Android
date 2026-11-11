package kano.xiaolubao.com.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import org.json.JSONObject
import java.io.File

/** 小米（澎湃 OS）的「展现刷新」action：系统不发原生 APPWIDGET_UPDATE，改发这个。 */
const val ACTION_MIUI_UPDATE = "miui.appwidget.action.APPWIDGET_UPDATE"

/**
 * 小组件的数据来源：Flutter 侧 [WidgetSnapshot] 写出的 JSON 快照。
 *
 * 为什么不在原生重新拉接口：日程的「即将开始」筛选口径、类型配色、B站粉丝的历史曲线
 * 都在 Dart 侧算好了，Kotlin 再写一遍必然分叉。原生只负责把成品文字画出来。
 *
 * **为什么是文件而不是 SharedPreferences**：
 * 按小米规范，小部件跑在 `:widgetProvider` 独立进程里。SharedPreferences 每个进程
 * 各有一份内存缓存，Flutter 在主进程 commit 之后，widget 进程再读拿到的还是旧值。
 * 快照写成 `filesDir/kano_widget.json` 每次读盘，跨进程才不会读到过期数据。
 * 读不到文件时退回 `FlutterSharedPreferences`，兼容之前已经写过的老数据。
 */
object WidgetData {
    private const val PREFS = "FlutterSharedPreferences"
    private const val PREFIX = "flutter."
    private const val SNAPSHOT_FILE = "kano_widget.json"

    const val SCHEDULE_KEY = "kanoWidget:schedule"
    const val FANS_KEY = "kanoWidget:fans"

    /** 文件里的字段名，与 Dart 侧 `WidgetSnapshot` 的 key 对应 */
    private const val SCHEDULE_FIELD = "schedule"
    private const val FANS_FIELD = "fans"

    fun schedule(context: Context): JSONObject? = read(context, SCHEDULE_KEY, SCHEDULE_FIELD)

    fun fans(context: Context): JSONObject? = read(context, FANS_KEY, FANS_FIELD)

    private fun read(context: Context, prefsKey: String, field: String): JSONObject? = try {
        val fromFile = readFile(context, field)
        fromFile ?: readPrefs(context, prefsKey)
    } catch (error: Exception) {
        null
    }

    private fun readFile(context: Context, field: String): JSONObject? {
        val file = File(context.filesDir, SNAPSHOT_FILE)
        if (!file.exists()) return null
        val root = JSONObject(file.readText())
        return root.optJSONObject(field)
    }

    private fun readPrefs(context: Context, key: String): JSONObject? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(PREFIX + key, null)
        return if (raw.isNullOrEmpty()) null else JSONObject(raw)
    }
}

/** 让桌面上的小组件立刻重绘（App 拉到新数据后由 MethodChannel 触发）。 */
object WidgetRefresh {
    fun updateAll(context: Context) {
        // 两套 provider 都要通知：原生版（安卓小部件列表）和小米版（小部件中心）.
        notify(context, ScheduleWidgetProvider::class.java)
        notify(context, BiliFansWidgetProvider::class.java)
        notify(context, ScheduleMiWidgetProvider::class.java)
        notify(context, BiliFansMiWidgetProvider::class.java)
    }

    private fun notify(context: Context, provider: Class<*>) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, provider))
        if (ids.isEmpty()) return
        val intent = Intent(context, provider).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        // 目标 receiver 在 :widgetProvider 独立进程，显式 component 广播可跨进程投递
        context.sendBroadcast(intent)
    }
}
