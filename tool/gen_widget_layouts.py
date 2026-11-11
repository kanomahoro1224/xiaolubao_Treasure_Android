# -*- coding: utf-8 -*-
"""生成桌面小组件的 4 个布局 + 类型色 drawable，逐行对齐鸿蒙卡片。

对照源（鸿蒙，只读）：
  entry/src/main/ets/widget/pages/ScheduleCard.ets     → widget_schedule_list.xml / widget_schedule_grid.xml
  entry/src/main/ets/widget/pages/BilibiliFansCard.ets → widget_fans_small.xml / widget_fans_wide.xml

为什么用脚本：RemoteViews 不能运行时建视图，42 个月历格子 + 42 个今日圆圈底必须静态
声明，手写必然错 id。类型色只有固定 7 档（KanoKind.colorValue），所以圆点 / 标签底的
着色 drawable 也在这里一起生成，运行期只 setBackgroundResource / setImageResource，
不依赖 setColorFilter（RemoteViews 对它的支持不稳）。
"""
import os

RES = r"F:/WeChat/xiaolubao/android/app/src/main/res"
LAYOUT = os.path.join(RES, "layout")
DRAWABLE = os.path.join(RES, "drawable")

# 与 lib/features/kano/domain/kano_models.dart 的 KanoKind.colorValue 一一对应
KIND_COLORS = [
    ("song", "D6336C"),
    ("game", "5F3DC4"),
    ("talk", "099268"),
    ("live", "C2410C"),
    ("video", "1971C2"),
    ("short", "0C8599"),
    ("flat", "495057"),
]

HEADER = '<?xml version="1.0" encoding="utf-8"?>\n'


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


# ==================== 类型色 drawable ====================

def gen_drawables():
    for key, hexv in KIND_COLORS:
        # 日程行左侧 8dp 类型色点（鸿蒙 Row().width(8).height(8).borderRadius(4)）
        write(os.path.join(DRAWABLE, f"widget_dot_{key}.xml"), HEADER + f'''<!-- 日程行左侧 8dp 类型色圆点，颜色对应 KanoKind.{key} -->
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="oval">
    <solid android:color="#FF{hexv}" />
    <size android:width="8dp" android:height="8dp" />
</shape>
''')
        # 行尾类型胶囊：鸿蒙 11sp 白字 + radius6 + padding 7/3
        write(os.path.join(DRAWABLE, f"widget_tag_{key}.xml"), HEADER + f'''<!-- 即将开始行尾的类型胶囊底（KanoKind.{key}），文字 11sp 白字 -->
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="#FF{hexv}" />
    <corners android:radius="6dp" />
</shape>
''')
        # 月历格子内的类型标签：鸿蒙 9sp 白字 + radius4 + height13
        write(os.path.join(DRAWABLE, f"widget_chip_{key}.xml"), HEADER + f'''<!-- 月历格子里的每日类型标签底（KanoKind.{key}），文字 9sp 白字 -->
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="#FF{hexv}" />
    <corners android:radius="4dp" />
</shape>
''')

    # 头像缺失时的占位：鸿蒙 Circle().fill('#24FB7299')
    write(os.path.join(DRAWABLE, "widget_avatar_placeholder.xml"), HEADER + '''<!-- 头像未取到时的占位圆：与鸿蒙 Circle().fill('#24FB7299') 同色 -->
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="oval">
    <solid android:color="@color/widget_avatar_wash" />
</shape>
''')


# ==================== 日程 · 2x4 列表 ====================

def gen_schedule_list():
    rows = []
    for i in range(3):
        divider = ""
        if i < 2:
            divider = f'''
        <FrameLayout
            android:id="@+id/sw_div{i}"
            android:layout_width="match_parent"
            android:layout_height="1dp"
            android:background="@color/schedule_card_divider" />
'''
        rows.append(f'''        <LinearLayout
            android:id="@+id/sw_row{i}"
            android:layout_width="match_parent"
            android:layout_height="0dp"
            android:layout_weight="1"
            android:orientation="horizontal"
            android:gravity="center_vertical"
            android:visibility="gone">

            <!-- Row().width(8).height(8).borderRadius(4)：8dp 实心圆点 -->
            <ImageView
                android:id="@+id/sw_dot{i}"
                android:layout_width="8dp"
                android:layout_height="8dp"
                android:scaleType="fitXY"
                android:src="@drawable/widget_dot_flat"
                android:contentDescription="@null" />

            <!-- Column({{space:3}}) + layoutWeight(1) -->
            <LinearLayout
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:layout_marginStart="10dp"
                android:orientation="vertical">

                <TextView
                    android:id="@+id/sw_title{i}"
                    android:layout_width="match_parent"
                    android:layout_height="wrap_content"
                    android:maxLines="1"
                    android:ellipsize="end"
                    android:textSize="15sp"
                    android:textColor="@color/schedule_card_text_primary" />

                <TextView
                    android:id="@+id/sw_meta{i}"
                    android:layout_width="match_parent"
                    android:layout_height="wrap_content"
                    android:layout_marginTop="3dp"
                    android:maxLines="1"
                    android:ellipsize="end"
                    android:textSize="12sp"
                    android:textColor="@color/schedule_card_text_secondary" />
            </LinearLayout>

            <!-- 11sp Medium 白字 + 类型色底 radius6 + padding 7/3 -->
            <TextView
                android:id="@+id/sw_tag{i}"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:layout_marginStart="10dp"
                android:background="@drawable/widget_tag_flat"
                android:paddingStart="7dp"
                android:paddingEnd="7dp"
                android:paddingTop="3dp"
                android:paddingBottom="3dp"
                android:maxLines="1"
                android:ellipsize="end"
                android:textSize="11sp"
                android:fontFamily="sans-serif-medium"
                android:textColor="@color/widget_tag_text" />
        </LinearLayout>
{divider}''')

    body = """<?xml version="1.0" encoding="utf-8"?>
<!-- 日程卡（2x4 列表态）：逐行对齐鸿蒙 ScheduleCard.ListCard()。
     padding 14/14/12/12、header 14sp secondary、行 = 8dp 色点 + 标题 15sp / 元信息 12sp +
     11sp 白字类型胶囊，行间 1dp 分割线，最多 3 条（鸿蒙 SCHEDULE_LIST_MAX_ITEMS = 3）。 -->
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@android:id/background"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:background="@drawable/widget_panel"
    android:paddingStart="14dp"
    android:paddingEnd="14dp"
    android:paddingTop="12dp"
    android:paddingBottom="12dp">

    <!-- status != ok 时整卡只显示这一行居中文案（鸿蒙 build() 的第一分支） -->
    <LinearLayout
        android:id="@+id/sw_status"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1"
        android:orientation="vertical"
        android:gravity="center"
        android:visibility="gone">

        <TextView
            android:id="@+id/sw_status_text"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:maxLines="1"
            android:ellipsize="end"
            android:textSize="11sp"
            android:textColor="@color/schedule_card_text_secondary" />
    </LinearLayout>

    <!-- 有日程：3 行等分剩余高度，header 与行同属这一层 -->
    <LinearLayout
        android:id="@+id/sw_list"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1"
        android:orientation="vertical">

        <TextView
            android:id="@+id/sw_header"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:maxLines="1"
            android:textSize="14sp"
            android:textColor="@color/schedule_card_text_secondary" />

__ROWS__
    </LinearLayout>
</LinearLayout>
"""
    write(os.path.join(LAYOUT, "widget_schedule_list.xml"),
          body.replace("__ROWS__", "\n".join(rows)))


# ==================== 日程 · 4x4 月历 ====================

def gen_schedule_grid():
    weekdays = []
    for i in range(7):
        # 鸿蒙：周末（index>=5）用 Medium，其余 Normal
        medium = '\n            android:fontFamily="sans-serif-medium"' if i >= 5 else ""
        weekdays.append(f'''        <TextView
            android:id="@+id/sw_wd{i}"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:gravity="center"
            android:maxLines="1"
            android:textSize="12sp"{medium}
            android:textColor="@color/schedule_card_text_secondary" />''')

    rows = []
    for r in range(6):
        cells = []
        for c in range(7):
            i = r * 7 + c
            cells.append(f'''            <!-- 格子 {i}：宽 1/7，顶对齐，clip -->
            <LinearLayout
                android:layout_width="0dp"
                android:layout_height="match_parent"
                android:layout_weight="1"
                android:orientation="vertical"
                android:gravity="center_horizontal"
                android:clipChildren="true">

                <!-- 今天：26x26 主题色圆（位图由 Kotlin 按主题色画）+ 白字 14sp Bold -->
                <FrameLayout
                    android:layout_width="26dp"
                    android:layout_height="26dp"
                    android:layout_gravity="center_horizontal">

                    <ImageView
                        android:id="@+id/sw_daybg{i}"
                        android:layout_width="26dp"
                        android:layout_height="26dp"
                        android:scaleType="fitXY"
                        android:contentDescription="@null"
                        android:visibility="gone" />

                    <TextView
                        android:id="@+id/sw_d{i}"
                        android:layout_width="26dp"
                        android:layout_height="26dp"
                        android:gravity="center"
                        android:maxLines="1"
                        android:includeFontPadding="false"
                        android:textSize="14sp"
                        android:textColor="@color/schedule_card_text_primary" />
                </FrameLayout>

                <!-- 每日类型标签：9sp 白字、高 13dp、radius4、左右 padding 2 -->
                <TextView
                    android:id="@+id/sw_c{i}a"
                    android:layout_width="wrap_content"
                    android:layout_height="13dp"
                    android:layout_marginTop="1dp"
                    android:includeFontPadding="false"
                    android:maxWidth="36dp"
                    android:gravity="center"
                    android:maxLines="1"
                    android:ellipsize="end"
                    android:paddingStart="2dp"
                    android:paddingEnd="2dp"
                    android:background="@drawable/widget_chip_flat"
                    android:textSize="9sp"
                    android:fontFamily="sans-serif-medium"
                    android:textColor="@color/widget_tag_text"
                    android:visibility="gone" />

                <TextView
                    android:id="@+id/sw_c{i}b"
                    android:layout_width="wrap_content"
                    android:layout_height="13dp"
                    android:includeFontPadding="false"
                    android:maxWidth="36dp"
                    android:gravity="center"
                    android:maxLines="1"
                    android:ellipsize="end"
                    android:paddingStart="2dp"
                    android:paddingEnd="2dp"
                    android:background="@drawable/widget_chip_flat"
                    android:textSize="9sp"
                    android:fontFamily="sans-serif-medium"
                    android:textColor="@color/widget_tag_text"
                    android:visibility="gone" />
            </LinearLayout>''')
        rows.append(f'''        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="0dp"
            android:layout_weight="1"
            android:orientation="horizontal">

__CELLS__
        </LinearLayout>'''.replace("__CELLS__", "\n".join(cells)))

    body = """<?xml version="1.0" encoding="utf-8"?>
<!-- 日程卡（4x4 月历态）：逐行对齐鸿蒙 ScheduleCard.MonthGrid()。
     padding 10/10/12/10；月份 26sp Bold、年份 12sp 偏移 8/6；星期 12sp（周末 Medium）
     marginTop6/bottom4；42 格等宽，日期 14sp，今天 26x26 主题色圆 + 白字 Bold。 -->
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@android:id/background"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:background="@drawable/widget_panel"
    android:paddingStart="10dp"
    android:paddingEnd="10dp"
    android:paddingTop="12dp"
    android:paddingBottom="10dp">

    <!-- status != ok 时整卡只显示这一行居中文案（鸿蒙 build() 的第一分支） -->
    <LinearLayout
        android:id="@+id/sw_status"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1"
        android:orientation="vertical"
        android:gravity="center"
        android:visibility="gone">

        <TextView
            android:id="@+id/sw_status_text"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:maxLines="1"
            android:ellipsize="end"
            android:textSize="11sp"
            android:textColor="@color/schedule_card_text_secondary" />
    </LinearLayout>

    <LinearLayout
        android:id="@+id/sw_grid"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1"
        android:orientation="vertical">

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:orientation="horizontal"
            android:gravity="center_vertical">

            <TextView
                android:id="@+id/sw_month_big"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:maxLines="1"
                android:textSize="26sp"
                android:textStyle="bold"
                android:textColor="@color/schedule_card_text_primary" />

            <TextView
                android:id="@+id/sw_year"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:layout_marginStart="8dp"
                android:layout_marginTop="6dp"
                android:maxLines="1"
                android:textSize="12sp"
                android:textColor="@color/schedule_card_text_secondary" />
        </LinearLayout>

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="6dp"
            android:layout_marginBottom="4dp"
            android:orientation="horizontal">

__WEEKDAYS__
        </LinearLayout>

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="0dp"
            android:layout_weight="1"
            android:orientation="vertical">

__ROWS__
        </LinearLayout>
    </LinearLayout>
</LinearLayout>
"""
    write(os.path.join(LAYOUT, "widget_schedule_grid.xml"),
          body.replace("__WEEKDAYS__", "\n".join(weekdays)).replace("__ROWS__", "\n".join(rows)))


# ==================== 粉丝 · 2x2 小卡 ====================

def gen_fans_small():
    body = """<?xml version="1.0" encoding="utf-8"?>
<!-- B站粉丝卡（2x2）：逐行对齐鸿蒙 BilibiliFansCard.SmallCard()。
     padding 12；顶部 28 头像 + 右上涨跌 15sp Bold（上移 4dp）；中部粉丝数 28sp Bold
     （VIP 粉色）+ 10sp caption；底部获赞 10sp Medium。 -->
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@android:id/background"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:background="@drawable/widget_panel"
    android:padding="12dp">

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:gravity="center_vertical">

        <FrameLayout
            android:layout_width="28dp"
            android:layout_height="28dp">

            <ImageView
                android:id="@+id/fw_avatar"
                android:layout_width="28dp"
                android:layout_height="28dp"
                android:scaleType="fitXY"
                android:contentDescription="@null"
                android:visibility="gone" />

            <ImageView
                android:id="@+id/fw_avatar_ph"
                android:layout_width="28dp"
                android:layout_height="28dp"
                android:scaleType="fitXY"
                android:src="@drawable/widget_avatar_placeholder"
                android:contentDescription="@null" />
        </FrameLayout>

        <FrameLayout
            android:layout_width="0dp"
            android:layout_height="1dp"
            android:layout_weight="1" />

        <!-- Blank() 之后右上角，鸿蒙用 offset({y:-4}) 上移 -->
        <TextView
            android:id="@+id/fw_diff"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:maxLines="1"
            android:translationY="-4dp"
            android:textSize="15sp"
            android:textStyle="bold"
            android:visibility="gone" />
    </LinearLayout>

    <FrameLayout
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1" />

    <!-- Column({{space:3}}).alignItems(Start)：三种状态各占一行，切换可见性 -->
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="vertical">

        <TextView
            android:id="@+id/fw_loading"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:maxLines="1"
            android:textSize="12sp"
            android:textColor="@color/fans_card_text_secondary"
            android:visibility="gone" />

        <TextView
            android:id="@+id/fw_error"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:maxLines="2"
            android:textSize="11sp"
            android:textColor="@color/fans_card_text_secondary"
            android:visibility="gone" />

        <TextView
            android:id="@+id/fw_count"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:maxLines="1"
            android:textSize="32sp"
            android:textStyle="bold"
            android:textColor="@color/fans_card_text_primary" />

        <TextView
            android:id="@+id/fw_caption"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="3dp"
            android:maxLines="1"
            android:textSize="11sp"
            android:textColor="@color/fans_card_text_secondary" />
    </LinearLayout>

    <FrameLayout
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1" />

    <TextView
        android:id="@+id/fw_likes"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:maxLines="1"
        android:textSize="10sp"
        android:fontFamily="sans-serif-medium"
        android:textColor="@color/fans_card_text_tertiary" />
</LinearLayout>
"""
    write(os.path.join(LAYOUT, "widget_fans_small.xml"), body)


# ==================== 粉丝 · 2x4 中卡 ====================

def gen_fans_wide():
    body = """<?xml version="1.0" encoding="utf-8"?>
<!-- B站粉丝卡（2x4）：逐行对齐鸿蒙 BilibiliFansCard.MediumCard()。
     padding 14；顶部 36 头像 + 昵称 15sp Medium（VIP 粉色）+ 签名 10sp + 右上涨跌；
     中部粉丝数 26sp Bold + 118x44 折线；底部获赞 11sp 与更新时间 9sp。 -->
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@android:id/background"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:background="@drawable/widget_panel"
    android:padding="14dp">

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:gravity="center_vertical">

        <FrameLayout
            android:layout_width="36dp"
            android:layout_height="36dp">

            <ImageView
                android:id="@+id/fw_avatar"
                android:layout_width="36dp"
                android:layout_height="36dp"
                android:scaleType="fitXY"
                android:contentDescription="@null"
                android:visibility="gone" />

            <ImageView
                android:id="@+id/fw_avatar_ph"
                android:layout_width="36dp"
                android:layout_height="36dp"
                android:scaleType="fitXY"
                android:src="@drawable/widget_avatar_placeholder"
                android:contentDescription="@null" />
        </FrameLayout>

        <!-- Column({space:2}) + layoutWeight(1) -->
        <LinearLayout
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:layout_marginStart="10dp"
            android:orientation="vertical">

            <TextView
                android:id="@+id/fw_name"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:maxLines="1"
                android:ellipsize="end"
                android:textSize="15sp"
                android:fontFamily="sans-serif-medium"
                android:textColor="@color/fans_card_text_primary" />

            <TextView
                android:id="@+id/fw_sign"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:layout_marginTop="2dp"
                android:maxLines="1"
                android:ellipsize="end"
                android:textSize="10sp"
                android:textColor="@color/fans_card_text_secondary" />
        </LinearLayout>

        <TextView
            android:id="@+id/fw_diff"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginStart="10dp"
            android:maxLines="1"
            android:translationY="-4dp"
            android:textSize="15sp"
            android:textStyle="bold"
            android:visibility="gone" />
    </LinearLayout>

    <FrameLayout
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1" />

    <!-- alignItems(VerticalAlign.Bottom)：折线底边与粉丝数块底边对齐 -->
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:gravity="bottom">

        <!-- 鸿蒙 MediumCard 的这一列：loading 只显示 11sp 文案，error 显示 11sp 错误，
             ok 才显示 26sp Bold 粉丝数 + 10sp caption -->
        <LinearLayout
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:orientation="vertical">

            <TextView
                android:id="@+id/fw_loading"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:maxLines="1"
                android:textSize="11sp"
                android:textColor="@color/fans_card_text_secondary"
                android:visibility="gone" />

            <TextView
                android:id="@+id/fw_error"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:maxWidth="150dp"
                android:maxLines="2"
                android:textSize="11sp"
                android:textColor="@color/fans_card_text_secondary"
                android:visibility="gone" />

            <TextView
                android:id="@+id/fw_count"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:maxLines="1"
                android:textSize="30sp"
                android:textStyle="bold"
                android:textColor="@color/fans_card_text_primary" />

            <TextView
                android:id="@+id/fw_caption"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:layout_marginTop="3dp"
                android:maxLines="1"
                android:textSize="11sp"
                android:textColor="@color/fans_card_text_secondary" />
        </LinearLayout>

        <FrameLayout
            android:layout_width="0dp"
            android:layout_height="1dp"
            android:layout_weight="1" />

        <ImageView
            android:id="@+id/fw_chart"
            android:layout_width="118dp"
            android:layout_height="44dp"
            android:scaleType="fitXY"
            android:contentDescription="@null"
            android:visibility="gone" />
    </LinearLayout>

    <FrameLayout
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1" />

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:gravity="center_vertical">

        <TextView
            android:id="@+id/fw_likes"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:maxLines="1"
            android:textSize="11sp"
            android:textColor="@color/fans_card_text_secondary" />

        <FrameLayout
            android:layout_width="0dp"
            android:layout_height="1dp"
            android:layout_weight="1" />

        <TextView
            android:id="@+id/fw_updated"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:maxLines="1"
            android:textSize="9sp"
            android:textColor="@color/fans_card_text_tertiary"
            android:visibility="gone" />
    </LinearLayout>
</LinearLayout>
"""
    write(os.path.join(LAYOUT, "widget_fans_wide.xml"), body)


def main():
    for d in (LAYOUT, DRAWABLE):
        if not os.path.isdir(d):
            raise SystemExit(f"目录不存在: {d}")
    gen_drawables()
    gen_schedule_list()
    gen_schedule_grid()
    gen_fans_small()
    gen_fans_wide()
    print("layouts: widget_schedule_list / widget_schedule_grid / widget_fans_small / widget_fans_wide")
    print("drawables: widget_dot_* / widget_tag_* / widget_chip_* / widget_avatar_placeholder")


if __name__ == "__main__":
    main()
