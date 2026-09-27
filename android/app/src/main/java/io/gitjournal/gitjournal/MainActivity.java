// SPDX-FileCopyrightText: 2019-2021 Vishesh Handa <me@vhanda.in>
//
// SPDX-License-Identifier: AGPL-3.0-or-later

package io.gitjournal.gitjournal;

import androidx.annotation.NonNull;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.ProxyInfo;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;
import android.view.WindowManager;

import java.io.File;
import java.io.IOException;
import java.nio.charset.Charset;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugins.GeneratedPluginRegistrant;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL_NAME = "gitjournal.io/git";
    static MethodChannel channel;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine);
        channel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_NAME);
        channel.setMethodCallHandler(
                    (call, result) -> {
                        if (call.method.equals("getProxy")) {
                            try {
                                if (Build.VERSION.SDK_INT < 23) {
                                    result.success(null);
                                    return;
                                }
                                ConnectivityManager cm = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
                                ProxyInfo proxyInfo = cm.getDefaultProxy();
                                if (proxyInfo == null || proxyInfo.getHost() == null) {
                                    result.success(null);
                                } else {
                                    String host = proxyInfo.getHost();
                                    int port = proxyInfo.getPort();
                                    result.success(host + ":" + port);
                                }
                            } catch (Exception e) {
                                result.success(null);
                            }
                            return;
                        }
                        result.notImplemented();
                }
        );
    }

    @Override
    protected void onResume() {
        super.onResume();
    }
}
