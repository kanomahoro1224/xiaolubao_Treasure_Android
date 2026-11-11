package kano.xiaolubao.com.widget

/**
 * 小米小部件（澎湃 OS）版日程卡。
 *
 * 渲染逻辑与原生版 [ScheduleWidgetProvider] 完全相同，这里只换一个 ComponentName：
 * 清单里给它挂 `miuiWidget=true` / 曝光刷新 / `:widgetProvider` 独立进程，
 * 系统才会把它归类为「小米小部件」并送进审核队列。
 * 未上架时这张卡在手机上不可见是系统行为，不影响原生版那张卡。
 */
class ScheduleMiWidgetProvider : ScheduleWidgetProvider()
