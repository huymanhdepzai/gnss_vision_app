package com.example.demo_app

import android.Manifest
import android.content.pm.PackageManager
import android.location.GnssStatus
import android.location.LocationManager
import android.os.Build
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "gnss_status_channel"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val locationManager = getSystemService(LOCATION_SERVICE) as LocationManager

        // Tạo một EventChannel để bơm dữ liệu liên tục lên Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                private var gnssCallback: GnssStatus.Callback? = null

                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        if (ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {

                            // Lắng nghe tín hiệu trực tiếp từ chip Vệ Tinh
                            gnssCallback = object : GnssStatus.Callback() {
                                override fun onSatelliteStatusChanged(status: GnssStatus) {
                                    val satellites = ArrayList<Map<String, Any>>()
                                    for (i in 0 until status.satelliteCount) {
                                        val sat = HashMap<String, Any>()
                                        sat["svid"] = status.getSvid(i)
                                        sat["constellationType"] = status.getConstellationType(i)
                                        sat["cn0DbHz"] = status.getCn0DbHz(i)
                                        sat["elevationDegrees"] = status.getElevationDegrees(i)
                                        sat["azimuthDegrees"] = status.getAzimuthDegrees(i)
                                        sat["usedInFix"] = status.usedInFix(i)
                                        satellites.add(sat)
                                    }
                                    // Bắn mảng dữ liệu này sang Dart
                                    events?.success(satellites)
                                }
                            }
                            locationManager.registerGnssStatusCallback(gnssCallback!!, null)
                        } else {
                            events?.error("PERMISSION_DENIED", "Cần cấp quyền vị trí", null)
                        }
                    } else {
                        events?.error("UNSUPPORTED", "Chỉ hỗ trợ Android 7.0 trở lên", null)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    // Dọn dẹp bộ nhớ khi user thoát màn hình
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && gnssCallback != null) {
                        locationManager.unregisterGnssStatusCallback(gnssCallback!!)
                        gnssCallback = null
                    }
                }
            }
        )
    }
}