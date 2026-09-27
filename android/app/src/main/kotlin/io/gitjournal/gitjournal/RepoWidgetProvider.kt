/*
 * SPDX-FileCopyrightText: 2019-2021 Vishesh Handa <me@vhanda.in>
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package io.gitjournal.gitjournal

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class RepoWidgetProvider : HomeWidgetProvider() {

    companion object {
        private const val PREF_NAME = "HomeWidgetPreferences"

        // Pending keys – written by Dart before requesting a pin.
        // The next new widget claims these and stores them per-widget-ID.
        private const val KEY_PENDING_REPO_ID = "pending_repo_id"
        private const val KEY_PENDING_TITLE = "pending_title"
        private const val KEY_PENDING_SUBTITLE = "pending_subtitle"

        // Per-widget keys: widget_<id>_<field>
        private fun widgetKey(id: Int, field: String) = "widget_${id}_$field"

        // Per-repo keys (shared across all widgets bound to the same repo):
        // repo_<repoId>_<field>
        private fun repoKey(repoId: String, field: String) = "repo_${repoId}_$field"
    }

    // ─────────────────────────────────────────────────────────────
    //  Lifecycle
    // ─────────────────────────────────────────────────────────────

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val editor = widgetData.edit()
        for (appWidgetId in appWidgetIds) {
            ensureBinding(appWidgetId, widgetData, editor)
        }
        editor.apply()

        for (appWidgetId in appWidgetIds) {
            val views = buildRemoteViews(context, appWidgetId, widgetData)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle
    ) {
        val widgetData = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        val views = buildRemoteViews(
            context, appWidgetId, widgetData, options = newOptions
        )
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        // Clean up per-widget keys when a widget is removed
        val widgetData = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        val editor = widgetData.edit()
        for (id in appWidgetIds) {
            editor.remove(widgetKey(id, "repo_id"))
        }
        editor.apply()
    }

    // ─────────────────────────────────────────────────────────────
    //  Binding logic
    // ─────────────────────────────────────────────────────────────

    /**
     * If this widget ID doesn't have a repo binding yet, claim the
     * "pending" data written by the Dart side before pinning.
     */
    private fun ensureBinding(
        appWidgetId: Int,
        widgetData: SharedPreferences,
        editor: SharedPreferences.Editor
    ) {
        val boundRepoKey = widgetKey(appWidgetId, "repo_id")
        if (widgetData.getString(boundRepoKey, null) != null) {
            return // already bound
        }

        val pendingRepoId = widgetData.getString(KEY_PENDING_REPO_ID, null)
        if (pendingRepoId != null) {
            editor.putString(boundRepoKey, pendingRepoId)
            // Also save per-repo title/subtitle if they came with the pending data
            val pendingTitle = widgetData.getString(KEY_PENDING_TITLE, null)
            val pendingSubtitle = widgetData.getString(KEY_PENDING_SUBTITLE, null)
            if (pendingTitle != null) {
                editor.putString(repoKey(pendingRepoId, "title"), pendingTitle)
            }
            if (pendingSubtitle != null) {
                editor.putString(repoKey(pendingRepoId, "subtitle"), pendingSubtitle)
            }
            // Clear pending so the next new widget doesn't reuse it
            editor.remove(KEY_PENDING_REPO_ID)
            editor.remove(KEY_PENDING_TITLE)
            editor.remove(KEY_PENDING_SUBTITLE)
        }
    }

    // ─────────────────────────────────────────────────────────────
    //  View building
    // ─────────────────────────────────────────────────────────────

    private fun buildRemoteViews(
        context: Context,
        appWidgetId: Int,
        widgetData: SharedPreferences,
        options: android.os.Bundle? = null
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_repo)

        // Read this widget's bound repoId
        val repoId = widgetData.getString(widgetKey(appWidgetId, "repo_id"), null)

        // Title / subtitle come from per-repo keys (shared & updatable)
        val title = if (repoId != null) {
            widgetData.getString(repoKey(repoId, "title"), null)
                ?: context.getString(R.string.widget_repo_default_title)
        } else {
            context.getString(R.string.widget_repo_default_title)
        }

        val subtitle = if (repoId != null) {
            widgetData.getString(repoKey(repoId, "subtitle"), null)
                ?: context.getString(R.string.widget_repo_default_subtitle)
        } else {
            context.getString(R.string.widget_repo_default_subtitle)
        }

        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(R.id.widget_subtitle, subtitle)

        // Subtitle visible only when widget is resized beyond ~2x2
        val showSubtitle = if (options != null) {
            val minWidth = options.getInt(
                AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0
            )
            val minHeight = options.getInt(
                AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0
            )
            minWidth >= 100 || minHeight >= 140
        } else {
            false
        }

        views.setViewVisibility(
            R.id.widget_subtitle,
            if (showSubtitle) android.view.View.VISIBLE else android.view.View.GONE
        )

        // Click intent – uses THIS widget's repoId
        val uri = if (repoId != null) {
            Uri.parse("gitjournal://repo/$repoId")
        } else {
            null
        }

        val pendingIntent = HomeWidgetLaunchIntent.getActivity(
            context, MainActivity::class.java, uri
        )
        views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

        return views
    }
}
