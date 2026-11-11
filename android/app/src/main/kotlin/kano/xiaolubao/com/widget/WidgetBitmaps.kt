package kano.xiaolubao.com.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Shader
import android.graphics.Typeface

/**
 * 小组件里无法用 XML 表达的三样东西，都在这里画成位图再塞进 ImageView：
 *
 * 1. **今天的圆圈**：颜色是用户主题色（运行期才知道），而且鸿蒙那一格是
 *    「26x26 主题色圆 + 白字 Bold」。RemoteViews 既不能按色染色，也不能改字重，
 *    所以把圆和数字一起画进位图，颜色 / 字重都跟鸿蒙一致。
 * 2. **圆形头像**：鸿蒙 `borderRadius(size/2).clip(true)`，RemoteViews 的 ImageView
 *    只能靠 `scaleType`，圆角得自己裁。
 * 3. **粉丝折线**：鸿蒙 `Polyline(fillOpacity 0, strokeWidth 2, 圆角端点)`，
 *    RemoteViews 里没有画布，只能画好比特图。
 */
object WidgetBitmaps {

    /** 今天那一格：26dp 圆 + 白字 Bold 14sp，对齐鸿蒙 MonthGrid 里的今日样式 */
    fun todayCircle(context: Context, day: Int, color: Int): Bitmap {
        val density = context.resources.displayMetrics.density
        val scaled = context.resources.displayMetrics.scaledDensity
        val size = (26 * density).toInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val half = size / 2f

        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            this.color = color
        }
        canvas.drawCircle(half, half, half, fill)

        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = Color.WHITE
            textSize = 14 * scaled
            textAlign = Paint.Align.CENTER
            typeface = Typeface.DEFAULT_BOLD
        }
        val metrics = text.fontMetrics
        // 与 TextView gravity=center 一致：按字形高度居中，不按行高
        val baseline = half - (metrics.ascent + metrics.descent) / 2f
        canvas.drawText(day.toString(), half, baseline, text)
        return bitmap
    }

    /** 头像裁成圆形：鸿蒙是 borderWidth 圆角 + clip，这里用 shader 直接画圆 */
    fun circular(source: Bitmap): Bitmap {
        val size = minOf(source.width, source.height)
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = BitmapShader(source, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        }
        // 居中裁正方形
        val matrix = Matrix().apply {
            val dx = (source.width - size) / 2f
            val dy = (source.height - size) / 2f
            setTranslate(-dx, -dy)
        }
        paint.shader.setLocalMatrix(matrix)
        val radius = size / 2f
        canvas.drawCircle(radius, radius, radius, paint)
        return output
    }

    /**
     * 粉丝走势折线：118x44dp，上下各留 3dp，描边 2dp、圆角端点、**不填充**
     * （鸿蒙 `Polyline().fillOpacity(0)`）。样本不足 2 个返回 null，卡片里直接隐藏。
     */
    fun sparkline(context: Context, values: List<Int>, color: Int): Bitmap? {
        if (values.size < 2) return null
        val density = context.resources.displayMetrics.density
        val width = (118 * density).toInt().coerceAtLeast(1)
        val height = (44 * density).toInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val padding = 3 * density
        val usableHeight = height - padding * 2
        val line = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 2 * density
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
            this.color = color
        }

        val min = values.min()
        val max = values.max()
        val range = (max - min).toFloat()
        val path = Path()
        for (i in values.indices) {
            val ratio = if (range > 0f) (values[i] - min) / range else 0.5f
            val x = i * width / (values.size - 1).toFloat()
            val y = padding + (1 - ratio) * usableHeight
            if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }
        canvas.drawPath(path, line)
        return bitmap
    }
}
