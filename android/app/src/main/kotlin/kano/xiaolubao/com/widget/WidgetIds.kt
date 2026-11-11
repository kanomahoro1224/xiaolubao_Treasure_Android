package kano.xiaolubao.com.widget

import android.content.Context
import androidx.annotation.DrawableRes
import kano.xiaolubao.com.R

/**
 * 按名字取 id。
 *
 * 月历的 42 个格子和 6 行 × 7 列的嵌套容器是脚本展开出来的
 * （`tool/gen_widget_layouts.py`），名字有规律（`sw_d0`..`sw_d41`），
 * 用名字查比在 Kotlin 里写 126 个常量清楚。结果缓存，`getIdentifier` 只在首次查表。
 */
object WidgetIds {
    private val cache = HashMap<String, Int>()

    fun id(context: Context, name: String): Int = cache.getOrPut(name) {
        context.resources.getIdentifier(name, "id", context.packageName)
    }

    // ---- 日程：2x4 列表 ----
    fun row(context: Context, index: Int) = id(context, "sw_row$index")
    fun dot(context: Context, index: Int) = id(context, "sw_dot$index")
    fun title(context: Context, index: Int) = id(context, "sw_title$index")
    fun meta(context: Context, index: Int) = id(context, "sw_meta$index")
    fun tag(context: Context, index: Int) = id(context, "sw_tag$index")
    fun divider(context: Context, index: Int) = id(context, "sw_div$index")

    // ---- 日程：4x4 月历 ----
    fun weekday(context: Context, index: Int) = id(context, "sw_wd$index")
    fun day(context: Context, index: Int) = id(context, "sw_d$index")
    fun dayCircle(context: Context, index: Int) = id(context, "sw_daybg$index")
    fun chip(context: Context, index: Int, slot: Int) =
        id(context, "sw_c$index${if (slot == 0) "a" else "b"}")
}

/**
 * 类型色 → 着色 drawable。
 *
 * 颜色只有 7 档（与 `KanoKind.colorValue` 一一对应），所以圆点 / 胶囊底的
 * shape 全部预生成成资源，运行期只 `setImageResource` / `setBackgroundResource`。
 * 不用 `setColorFilter`：RemoteViews 对它的支持在各家 ROM 上不一致。
 */
object WidgetColors {
    /** 与 KanoKind.colorValue 同值，Dart 侧快照里就是这些大写十六进制串 */
    private const val SONG = "#D6336C"
    private const val GAME = "#5F3DC4"
    private const val TALK = "#099268"
    private const val LIVE = "#C2410C"
    private const val VIDEO = "#1971C2"
    private const val SHORT = "#0C8599"

    @DrawableRes
    fun dot(color: String): Int = when (normalize(color)) {
        SONG -> R.drawable.widget_dot_song
        GAME -> R.drawable.widget_dot_game
        TALK -> R.drawable.widget_dot_talk
        LIVE -> R.drawable.widget_dot_live
        VIDEO -> R.drawable.widget_dot_video
        SHORT -> R.drawable.widget_dot_short
        else -> R.drawable.widget_dot_flat
    }

    @DrawableRes
    fun tag(color: String): Int = when (normalize(color)) {
        SONG -> R.drawable.widget_tag_song
        GAME -> R.drawable.widget_tag_game
        TALK -> R.drawable.widget_tag_talk
        LIVE -> R.drawable.widget_tag_live
        VIDEO -> R.drawable.widget_tag_video
        SHORT -> R.drawable.widget_tag_short
        else -> R.drawable.widget_tag_flat
    }

    @DrawableRes
    fun chip(color: String): Int = when (normalize(color)) {
        SONG -> R.drawable.widget_chip_song
        GAME -> R.drawable.widget_chip_game
        TALK -> R.drawable.widget_chip_talk
        LIVE -> R.drawable.widget_chip_live
        VIDEO -> R.drawable.widget_chip_video
        SHORT -> R.drawable.widget_chip_short
        else -> R.drawable.widget_chip_flat
    }

    private fun normalize(color: String): String = color.trim().uppercase()
}
