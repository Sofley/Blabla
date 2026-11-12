package uz.nexustrade.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget: number of active contracts, the stage of the chosen
 * contract (progress bar), its amount and the profit. All texts are prepared
 * and translated by the app (lib/state/widget_sync.dart); amounts are shown
 * only to the owner and can be hidden in Settings.
 */
class NexusWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.nexus_widget).apply {
                fun text(view: Int, key: String, fallback: String = "") =
                    setTextViewText(view, widgetData.getString(key, fallback) ?: fallback)

                text(R.id.w_count_label, "w_count_label", "Active contracts")
                text(R.id.w_count, "w_count", "0")
                text(R.id.w_deal, "w_deal", "NexusTrade")
                text(R.id.w_client, "w_client")
                text(R.id.w_stage, "w_stage")
                text(R.id.w_sum_label, "w_sum_label", "Contract amount")
                text(R.id.w_sum, "w_sum", "—")
                text(R.id.w_profit_label, "w_profit_label", "Profit")
                text(R.id.w_profit, "w_profit", "—")

                val max = widgetData.getInt("w_progress_max", 4)
                val progress = widgetData.getInt("w_progress", 0)
                setProgressBar(R.id.w_progress, max, progress, false)

                val negative = widgetData.getBoolean("w_profit_negative", false)
                setTextColor(
                    R.id.w_profit,
                    if (negative) Color.parseColor("#FF7A7A") else Color.parseColor("#7BE0A8"),
                )

                // Tap opens the app (it asks for the PIN / password first).
                setOnClickPendingIntent(
                    R.id.w_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
