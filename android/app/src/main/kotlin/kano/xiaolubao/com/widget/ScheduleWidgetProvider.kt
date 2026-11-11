package kano.xiaolubao.com.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import kano.xiaolubao.com.MainActivity
import kano.xiaolubao.com.R
import org.json.JSONArray
import org.json.JSONObject

/**
 * 日程桌面卡片，对应鸿蒙 `ScheduleFormAbility` + `widget/pages/ScheduleCard.ets`。
 *
 * 两套外观（鸿蒙按 `dimension` 2x4 / 4x4 分，这里按桌面给的尺寸判）：
 * - 矮卡（2x4）：即将开始列表，最多 3 条，行结构 / 字号 / 分割线与鸿蒙 `ListCard()` 一致；
 * - 高卡（4x4）：42 格月历，今天 26x26 主题色圆 + 白字，每天至多两枚类型胶囊。
 *
 * 文案、类型标签、配色、主题色全部由 Flutter 快照给出（`widget_snapshot.dart`），
 * 这里不做业务判断；`status` 三态（loading / error / ok）也照鸿蒙的写法：
 * 非 ok 时整卡只留一行居中文案。
 */
open class ScheduleWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        // 小米的「展现刷新」走自己的 action，不是原生 APPWIDGET_UPDATE。
        // 规范要求在这里手动捞 id 再走一遍 onUpdate。
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
        // 拉伸卡片立刻换布局，不等下一次定时刷新
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
        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
        val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val data = WidgetData.schedule(context)

        // 2x4 的高度塞不下 6 行格子，够大才走月历
        val grid = height >= 210 && width >= 240
        val views = if (grid) buildGrid(context, data) else buildList(context, data)
        // 根布局的 id 按小米规范固定为 @android:id/background
        views.setOnClickPendingIntent(android.R.id.background, openApp(context, id))
        return views
    }

    // ==================== 列表态（2x4） ====================

    private fun buildList(context: Context, data: JSONObject?): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_schedule_list)
        val status = data?.optString("status").orEmpty()
        val items: JSONArray = data?.optJSONArray("items") ?: JSONArray()
        // 鸿蒙：status !== 'ok' 或 无日程 → 居中一行文案（ok 且空时显示 emptyText）
        val showList = status == "ok" && items.length() > 0

        views.setViewVisibility(R.id.sw_list, if (showList) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.sw_status, if (showList) View.GONE else View.VISIBLE)
        if (!showList) {
            views.setTextViewText(R.id.sw_status_text, statusText(context, data, status))
            return views
        }

        views.setTextViewText(
            R.id.sw_header,
            data?.optString("header").orEmpty().ifEmpty {
                context.getString(R.string.widget_schedule_upcoming)
            },
        )

        val count = minOf(items.length(), LIST_MAX_ITEMS)
        for (i in 0 until LIST_MAX_ITEMS) {
            val rowId = WidgetIds.row(context, i)
            if (rowId == 0) continue
            if (i >= count) {
                views.setViewVisibility(rowId, View.GONE)
                hide(views, WidgetIds.divider(context, i))
                continue
            }
            val item = items.optJSONObject(i) ?: continue
            views.setViewVisibility(rowId, View.VISIBLE)
            views.setTextViewText(WidgetIds.title(context, i), item.optString("title"))
            views.setTextViewText(WidgetIds.meta(context, i), item.optString("meta"))
            views.setTextViewText(WidgetIds.tag(context, i), item.optString("tag"))

            val color = item.optString("color")
            // 8dp 圆点用预生成的着色 oval，胶囊底同理（RemoteViews 染不了色）
            views.setImageViewResource(WidgetIds.dot(context, i), WidgetColors.dot(color))
            views.setInt(WidgetIds.tag(context, i), "setBackgroundResource", WidgetColors.tag(color))

            // 鸿蒙 `index < items.length - 1` 才画分割线
            val dividerId = WidgetIds.divider(context, i)
            if (dividerId != 0) {
                views.setViewVisibility(
                    dividerId,
                    if (i < count - 1) View.VISIBLE else View.GONE,
                )
            }
        }
        return views
    }

    // ==================== 月历态（4x4） ====================

    private fun buildGrid(context: Context, data: JSONObject?): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_schedule_grid)
        val status = data?.optString("status").orEmpty()
        val ok = status == "ok"

        views.setViewVisibility(R.id.sw_grid, if (ok) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.sw_status, if (ok) View.GONE else View.VISIBLE)
        if (!ok || data == null) {
            views.setTextViewText(R.id.sw_status_text, statusText(context, data, status))
            return views
        }

        views.setTextViewText(R.id.sw_month_big, data.optString("monthLabel"))
        views.setTextViewText(R.id.sw_year, data.optString("year"))

        val weekdays = data.optJSONArray("weekdays") ?: JSONArray()
        for (i in 0 until 7) {
            views.setTextViewText(
                WidgetIds.weekday(context, i),
                if (i < weekdays.length()) weekdays.optString(i) else "",
            )
        }

        // 今天圆圈用 App 主题色（快照里的 todayColor），取不到退回默认粉
        val todayColor = parseColor(data.optString("todayColor"), DEFAULT_TODAY_COLOR)
        val normalColor = ContextCompat.getColor(context, R.color.schedule_card_text_primary)
        var todayBitmap: Bitmap? = null

        val cells = data.optJSONArray("cells") ?: JSONArray()
        for (i in 0 until GRID_CELLS) {
            val dayId = WidgetIds.day(context, i)
            if (dayId == 0) continue
            val circleId = WidgetIds.dayCircle(context, i)
            val chipA = WidgetIds.chip(context, i, 0)
            val chipB = WidgetIds.chip(context, i, 1)

            val cell = if (i < cells.length()) cells.optJSONObject(i) else null
            val day = cell?.optInt("day") ?: 0
            if (day <= 0) {
                // 月初对齐用的空格：数字留位不显示，胶囊与圆圈全部收起
                views.setViewVisibility(dayId, View.INVISIBLE)
                hide(views, circleId)
                hide(views, chipA)
                hide(views, chipB)
                continue
            }

            views.setViewVisibility(dayId, View.VISIBLE)
            val isToday = cell?.optBoolean("today") == true
            if (isToday) {
                // 鸿蒙：今天 = 主题色圆 + 白字 Bold。RemoteViews 改不了字重，
                // 所以圆和数字一起画成位图，文字层留空。
                val bitmap = todayBitmap
                    ?: WidgetBitmaps.todayCircle(context, day, todayColor).also { todayBitmap = it }
                views.setImageViewBitmap(circleId, bitmap)
                views.setViewVisibility(circleId, View.VISIBLE)
                views.setTextViewText(dayId, "")
            } else {
                hide(views, circleId)
                views.setTextViewText(dayId, day.toString())
                views.setTextColor(dayId, normalColor)
            }

            val chips = cell?.optJSONArray("chips") ?: JSONArray()
            setChip(views, chipA, chips.optJSONObject(0))
            setChip(views, chipB, chips.optJSONObject(1))
        }
        return views
    }

    private fun setChip(views: RemoteViews, viewId: Int, chip: JSONObject?) {
        if (viewId == 0) return
        if (chip == null) {
            views.setViewVisibility(viewId, View.GONE)
            return
        }
        views.setViewVisibility(viewId, View.VISIBLE)
        views.setTextViewText(viewId, chip.optString("t"))
        views.setInt(viewId, "setBackgroundResource", WidgetColors.chip(chip.optString("c")))
    }

    // ==================== 工具 ====================

    /** 鸿蒙 `statusText()`：error → errorText，ok → emptyText，其余 loadingText */
    private fun statusText(context: Context, data: JSONObject?, status: String): String =
        when (status) {
            "error" -> data?.optString("error").orEmpty()
                .ifEmpty { context.getString(R.string.widget_schedule_error) }

            "ok" -> data?.optString("empty").orEmpty()
                .ifEmpty { context.getString(R.string.widget_schedule_empty) }

            else -> data?.optString("loading").orEmpty()
                .ifEmpty { context.getString(R.string.widget_schedule_loading) }
        }

    private fun hide(views: RemoteViews, viewId: Int) {
        if (viewId != 0) views.setViewVisibility(viewId, View.GONE)
    }

    /** 点击整卡进 App。鸿蒙的 postCardAction 带 `source` + `formId`，这里同样带，
     便于后续按卡片实例做归因（App 侧目前只读 source）。 */
    private fun openApp(context: Context, widgetId: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("source", "scheduleWidget")
            putExtra("formId", widgetId.toString())
        }
        return PendingIntent.getActivity(
            context,
            1001,
            intent,
            // 小米规范 11.2：不要用 FLAG_IMMUTABLE，否则解析不了宿主（桌面/负一屏）
            // 往 Intent 里补的参数；Android S 以上用 FLAG_MUTABLE。
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
    }

    private fun parseColor(value: String, fallback: Int): Int = try {
        if (value.isEmpty()) fallback else android.graphics.Color.parseColor(value)
    } catch (error: IllegalArgumentException) {
        fallback
    }

    private companion object {
        /** 鸿蒙 SCHEDULE_LIST_MAX_ITEMS */
        const val LIST_MAX_ITEMS = 3

        /** 6 行 × 7 列 */
        const val GRID_CELLS = 42

        /** 鸿蒙 SCHEDULE_THEME_DEFAULT */
        const val DEFAULT_TODAY_COLOR = 0xFFFFC0CB.toInt()
    }
}
