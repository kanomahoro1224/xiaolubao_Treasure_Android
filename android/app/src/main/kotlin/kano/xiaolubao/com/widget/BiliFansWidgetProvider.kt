package kano.xiaolubao.com.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import kano.xiaolubao.com.MainActivity
import kano.xiaolubao.com.R
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * B站粉丝桌面卡片，对应鸿蒙 `BilibiliFansFormAbility` + `widget/pages/BilibiliFansCard.ets`。
 *
 * - 2x2 小卡：头像 + 涨跌 + 粉丝数（VIP 粉色）+ caption + 获赞；
 * - 2x4 中卡：头像 + 昵称 / 签名 + 涨跌 + 粉丝数 + 118x44 折线 + 获赞 / 更新时间。
 *
 * 文案与涨跌口径由 Dart 侧按鸿蒙同一套规则算好（`widget_snapshot.dart`），
 * 原生不判断业务；折线与圆形头像用 Canvas 画成位图（RemoteViews 不能画自定义 View）。
 */
open class BiliFansWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_MIUI_UPDATE) {
            val ids = intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS)
            if (ids != null && ids.isNotEmpty()) {
                onUpdate(context, AppWidgetManager.getInstance(context), ids)
            }
            return
        }
        super.onReceive(context, intent)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { id ->
            appWidgetManager.updateAppWidget(id, build(context, appWidgetManager, id))
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        appWidgetManager.updateAppWidget(
            appWidgetId,
            build(context, appWidgetManager, appWidgetId),
        )
    }

    private fun build(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
    ): RemoteViews {
        val options = manager.getAppWidgetOptions(id)
        val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val data = WidgetData.fans(context)

        val wide = width >= 200
        val views = if (wide) buildWide(context, data, id) else buildSmall(context, data, id)
        views.setOnClickPendingIntent(android.R.id.background, openApp(context, id))
        return views
    }

    // ==================== 小卡（2x2） ====================

    private fun buildSmall(context: Context, data: JSONObject?, id: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_fans_small)
        val status = statusOf(data)

        // 鸿蒙：loading 显示 loadingText + caption；error 只显示 errorText；ok 显示数字 + caption
        views.setViewVisibility(
            R.id.fw_loading,
            if (status == STATUS_OK || status == STATUS_ERROR) View.GONE else View.VISIBLE,
        )
        views.setViewVisibility(
            R.id.fw_error,
            if (status == STATUS_ERROR) View.VISIBLE else View.GONE,
        )
        views.setViewVisibility(
            R.id.fw_count,
            if (status == STATUS_OK) View.VISIBLE else View.GONE,
        )
        views.setViewVisibility(
            R.id.fw_caption,
            if (status == STATUS_ERROR) View.GONE else View.VISIBLE,
        )

        if (status == STATUS_ERROR) {
            views.setTextViewText(
                R.id.fw_error,
                data?.optString("error").orEmpty().ifEmpty {
                    context.getString(R.string.widget_fans_error)
                },
            )
        } else if (status != STATUS_OK) {
            views.setTextViewText(
                R.id.fw_loading,
                data?.optString("loading").orEmpty().ifEmpty {
                    context.getString(R.string.widget_fans_loading)
                },
            )
        }

        views.setTextViewText(R.id.fw_caption, caption(context, data))
        views.setTextViewText(R.id.fw_count, data?.optString("followersShortText").orEmpty().ifEmpty { "--" })
        views.setTextColor(
            R.id.fw_count,
            if (data?.optBoolean("isVip") == true) pink(context) else primary(context),
        )
        views.setTextViewText(R.id.fw_likes, data?.optString("likesShortText").orEmpty())

        applyDiff(context, views, R.id.fw_diff, data)
        applyAvatar(context, views, data, id)
        return views
    }

    // ==================== 中卡（2x4） ====================

    private fun buildWide(context: Context, data: JSONObject?, id: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_fans_wide)
        val status = statusOf(data)

        views.setTextViewText(R.id.fw_name, data?.optString("uname").orEmpty())
        views.setTextColor(
            R.id.fw_name,
            if (data?.optBoolean("isVip") == true) pink(context) else primary(context),
        )
        views.setTextViewText(R.id.fw_sign, data?.optString("sign").orEmpty())
        views.setTextViewText(R.id.fw_caption, caption(context, data))
        views.setTextViewText(R.id.fw_count, data?.optString("followersText").orEmpty().ifEmpty { "--" })

        // 鸿蒙 MediumCard：loading 只留 11sp 文案，error 只留 11sp 错误，ok 才出数字 + caption
        val ok = status == STATUS_OK
        views.setViewVisibility(R.id.fw_count, if (ok) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.fw_caption, if (ok) View.VISIBLE else View.GONE)
        views.setViewVisibility(
            R.id.fw_loading,
            if (!ok && status != STATUS_ERROR) View.VISIBLE else View.GONE,
        )
        views.setViewVisibility(
            R.id.fw_error,
            if (status == STATUS_ERROR) View.VISIBLE else View.GONE,
        )
        if (!ok) {
            val fallback = if (status == STATUS_ERROR) {
                data?.optString("error").orEmpty().ifEmpty { context.getString(R.string.widget_fans_error) }
            } else {
                data?.optString("loading").orEmpty().ifEmpty { context.getString(R.string.widget_fans_loading) }
            }
            val target = if (status == STATUS_ERROR) R.id.fw_error else R.id.fw_loading
            views.setTextViewText(target, fallback)
        }
        views.setTextColor(
            R.id.fw_count,
            if (data?.optBoolean("isVip") == true) pink(context) else primary(context),
        )
        views.setTextViewText(R.id.fw_likes, data?.optString("likesText").orEmpty())

        val updated = data?.optString("updateTimeText").orEmpty()
        views.setTextViewText(R.id.fw_updated, updated)
        views.setViewVisibility(R.id.fw_updated, if (updated.isEmpty()) View.GONE else View.VISIBLE)

        applyDiff(context, views, R.id.fw_diff, data)
        applyChart(context, views, data)
        applyAvatar(context, views, data, id)
        return views
    }

    // ==================== 公共片段 ====================

    private fun applyDiff(context: Context, views: RemoteViews, viewId: Int, data: JSONObject?) {
        val text = data?.optString("diffText").orEmpty()
        views.setTextViewText(viewId, text)
        views.setTextColor(viewId, diffColor(context, data))
        views.setViewVisibility(viewId, if (text.isEmpty()) View.GONE else View.VISIBLE)
    }

    /** 鸿蒙同款三色：涨 #E8413C、跌 #31A84B、持平 #8A8F99（国内红涨绿跌） */
    private fun diffColor(context: Context, data: JSONObject?): Int = when {
        data?.optString("diffText").orEmpty().isEmpty() ->
            ContextCompat.getColor(context, R.color.widget_diff_flat)

        data?.optBoolean("diffUp") == true -> ContextCompat.getColor(context, R.color.widget_diff_up)
        else -> ContextCompat.getColor(context, R.color.widget_diff_down)
    }

    private fun applyChart(context: Context, views: RemoteViews, data: JSONObject?) {
        val values = mutableListOf<Int>()
        val array: JSONArray = data?.optJSONArray("history") ?: JSONArray()
        for (i in 0 until array.length()) values.add(array.optInt(i))
        // 鸿蒙 ChartView()：样本 > 1 才画，否则整块不出现
        val bitmap = WidgetBitmaps.sparkline(context, values, chartColor(context, data))
        if (bitmap == null) {
            views.setViewVisibility(R.id.fw_chart, View.GONE)
            return
        }
        views.setViewVisibility(R.id.fw_chart, View.VISIBLE)
        views.setImageViewBitmap(R.id.fw_chart, bitmap)
    }

    /** 折线颜色与涨跌同色（鸿蒙 chartColor()） */
    private fun chartColor(context: Context, data: JSONObject?): Int = diffColor(context, data)

    /**
     * 头像：有缓存就画（裁成圆形），没有就先显示粉色占位圆并异步拉一次。
     * 拉回来会重绘这张卡，占位换成真头像。
     */
    private fun applyAvatar(
        context: Context,
        views: RemoteViews,
        data: JSONObject?,
        widgetId: Int,
    ) {
        val face = data?.optString("face").orEmpty()
        val cached = if (face.isEmpty()) null else avatarCache[face]
        if (cached != null) {
            views.setViewVisibility(R.id.fw_avatar, View.VISIBLE)
            views.setViewVisibility(R.id.fw_avatar_ph, View.GONE)
            views.setImageViewBitmap(R.id.fw_avatar, cached)
            return
        }
        views.setViewVisibility(R.id.fw_avatar, View.GONE)
        views.setViewVisibility(R.id.fw_avatar_ph, View.VISIBLE)
        if (face.isNotEmpty()) fetchAvatar(context, widgetId, face)
    }

    private fun caption(context: Context, data: JSONObject?): String =
        data?.optString("caption").orEmpty().ifEmpty {
            context.getString(R.string.widget_fans_caption)
        }

    private fun pink(context: Context): Int = ContextCompat.getColor(context, R.color.widget_bili_pink)

    private fun primary(context: Context): Int =
        ContextCompat.getColor(context, R.color.fans_card_text_primary)

    private fun statusOf(data: JSONObject?): String {
        val raw = data?.optString("status").orEmpty()
        return raw.ifEmpty { if (data == null) STATUS_LOADING else STATUS_OK }
    }

    // ==================== 头像下载 ====================

    private fun fetchAvatar(context: Context, widgetId: Int, url: String) {
        if (avatarPending.contains(url)) return
        avatarPending.add(url)
        val appContext = context.applicationContext
        executor.execute {
            val bitmap = try {
                val connection = URL(url).openConnection() as HttpURLConnection
                connection.connectTimeout = 8000
                connection.readTimeout = 8000
                // B 站图床（i0/i1/i2.hdslb.com）有防盗链：不带 Referer 会回 403，
                // 解出来是 null，卡片就只剩粉色占位圆。UA 也一起带上。
                connection.setRequestProperty("Referer", "https://www.bilibili.com/")
                connection.setRequestProperty(
                    "User-Agent",
                    "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 " +
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
                )
                connection.inputStream.use { BitmapFactory.decodeStream(it) }
            } catch (error: Exception) {
                null
            }
            avatarPending.remove(url)
            if (bitmap == null) return@execute
            avatarCache[url] = WidgetBitmaps.circular(bitmap)
            handler.post {
                val manager = AppWidgetManager.getInstance(appContext)
                manager.updateAppWidget(widgetId, build(appContext, manager, widgetId))
            }
        }
    }

    // ==================== 工具 ====================

    /** 点击整卡进 App，参数与鸿蒙 postCardAction 对齐（source + formId） */
    private fun openApp(context: Context, widgetId: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("source", "bilibiliFansWidget")
            putExtra("formId", widgetId.toString())
        }
        return PendingIntent.getActivity(
            context,
            1002,
            intent,
            // 小米规范 11.2：不用 FLAG_IMMUTABLE，宿主需要往 Intent 里补参数
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
    }

    private companion object {
        const val STATUS_OK = "ok"
        const val STATUS_ERROR = "error"
        const val STATUS_LOADING = "loading"

        val avatarCache = HashMap<String, Bitmap>()
        val avatarPending = HashSet<String>()
        val executor = Executors.newSingleThreadExecutor()
        val handler = Handler(Looper.getMainLooper())
    }
}
