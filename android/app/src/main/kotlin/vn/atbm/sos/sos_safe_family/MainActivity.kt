package vn.atbm.sos.sos_safe_family

import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Activity chính của ứng dụng SOS An Toàn Gia Đình.
 *
 * Kế thừa [FlutterFragmentActivity] (thay vì `FlutterActivity`) vì plugin
 * `local_auth` cần FragmentActivity để hiển thị `BiometricPrompt` của Android.
 *
 * Cài đặt MethodChannel `vn.atbm.sos/security` cung cấp hai chức năng bảo mật
 * ở tầng native:
 *  - `setFlagSecure(enabled)`: bật/tắt cờ `FLAG_SECURE` để chống chụp và quay
 *    màn hình (ảnh chụp sẽ thành màn hình đen thay vì nội dung nhạy cảm).
 *  - `checkDeviceIntegrity()`: phát hiện thiết bị đã root ở mức cơ bản.
 */
class MainActivity : FlutterFragmentActivity() {

    private val securityChannelName = "vn.atbm.sos/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, securityChannelName)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "setFlagSecure" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        applyFlagSecure(enabled)
                        result.success(enabled)
                    }

                    "checkDeviceIntegrity" -> {
                        result.success(checkDeviceIntegrity())
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Bật hoặc xoá cờ FLAG_SECURE của cửa sổ Activity hiện tại.
     *
     * @param enabled true để chống chụp/quay màn hình, false để cho phép.
     */
    private fun applyFlagSecure(enabled: Boolean) {
        runOnUiThread {
            if (enabled) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        }
    }

    /**
     * Kiểm tra toàn vẹn thiết bị ở mức cơ bản.
     *
     * Phát hiện root bằng cách kiểm tra sự tồn tại của các binary `su` ở các
     * đường dẫn thông dụng, hoặc bằng build tag `test-keys` / `dev-keys` /
     * `debug-keys` (dấu hiệu của ROM build tùy chỉnh / firmware debug).
     *
     * @return true nếu phát hiện dấu hiệu thiết bị đã root.
     */
    private fun checkDeviceIntegrity(): Boolean {
        // 1. Binary `su` tồn tại ở các vị trí thông dụng.
        val suPaths = arrayOf(
            "/system/bin/su",
            "/system/xbin/su",
            "/sbin/su",
            "/system/sbin/su",
            "/system/app/Superuser.apk",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/su/bin/su"
        )
        for (path in suPaths) {
            if (java.io.File(path).exists()) {
                return true
            }
        }

        // 2. Build tag không phải bản phát hành chính thức.
        val buildTags = Build.TAGS ?: return false
        if (buildTags.contains("test-keys") ||
            buildTags.contains("dev-keys") ||
            buildTags.contains("debug-keys")
        ) {
            return true
        }

        return false
    }
}
