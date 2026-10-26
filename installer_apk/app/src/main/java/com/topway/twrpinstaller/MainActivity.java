package com.topway.twrpinstaller;

import android.app.Activity;
import android.content.pm.ActivityInfo;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;

import java.io.BufferedReader;
import java.io.DataOutputStream;
import java.io.File;
import java.io.InputStreamReader;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

public class MainActivity extends Activity {

    // Target block devices verified from /fstab.mt6768
    private static final String RECOVERY_DEV = "/dev/block/platform/bootdevice/by-name/recovery";
    private static final String FFSU_BIN = "/system/xbin/ffsu";

    private TextView tvRootStatus;
    private TextView tvFileInfo;
    private TextView tvLogs;
    private Button btnBackup;
    private Button btnFlash;
    private Button btnReboot;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private boolean isRootAvailable = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // Force Landscape for non-rotatable car screen
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);
        setContentView(R.layout.activity_main);

        tvRootStatus = findViewById(R.id.tv_root_status);
        tvFileInfo = findViewById(R.id.tv_file_info);
        tvLogs = findViewById(R.id.tv_logs);
        btnBackup = findViewById(R.id.btn_backup);
        btnFlash = findViewById(R.id.btn_flash);
        btnReboot = findViewById(R.id.btn_reboot_recovery);

        checkExploitStatus();

        btnBackup.setOnClickListener(v -> runBackupRecovery());
        btnFlash.setOnClickListener(v -> runFlashTwrp());
        btnReboot.setOnClickListener(v -> runRebootRecovery());
    }

    private void log(String msg) {
        mainHandler.post(() -> {
            String time = new SimpleDateFormat("HH:mm:ss", Locale.US).format(new Date());
            tvLogs.append("[" + time + "] " + msg + "\n");
        });
    }

    private void checkExploitStatus() {
        new Thread(() -> {
            File ffsu = new File(FFSU_BIN);
            if (ffsu.exists()) {
                log("Znaleziono wbudowany binarny backdoor: " + FFSU_BIN);
            }

            // Test executing root command via ffsu
            String result = executeRootCommand("id");
            if (result.contains("uid=0")) {
                isRootAvailable = true;
                mainHandler.post(() -> {
                    tvRootStatus.setText("Luka aktywna! Posiadasz pełne uprawnienia ROOT (uid=0)");
                    tvRootStatus.setTextColor(0xFF00FF00); // Green
                });
                log("Test uprawnień: " + result.trim());
            } else {
                isRootAvailable = false;
                mainHandler.post(() -> {
                    tvRootStatus.setText("Ostrzeżenie: ffsu nie zwrócił roota. Sprawdź adb.");
                    tvRootStatus.setTextColor(0xFFFF4444); // Red
                });
                log("Błąd roota: " + result.trim());
            }
        }).start();
    }

    private void runBackupRecovery() {
        new Thread(() -> {
            log("Rozpoczynanie kopii zapasowej fabrycznego recovery...");
            File outDir = new File(Environment.getExternalStorageDirectory(), "RecoveryBackup");
            if (!outDir.exists()) outDir.mkdirs();

            String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date());
            File outFile = new File(outDir, "stock_recovery_" + timeStamp + ".img");

            String cmd = String.format("dd if=%s of=%s bs=1048576 && chmod 666 %s",
                    RECOVERY_DEV, outFile.getAbsolutePath(), outFile.getAbsolutePath());

            log("Wykonywanie: " + cmd);
            String res = executeRootCommand(cmd);
            log(res);

            if (outFile.exists() && outFile.length() > 10 * 1024 * 1024) {
                log("SUKCES! Zapisano fabryczny recovery (" + (outFile.length() / 1024 / 1024) + " MB) do:");
                log(outFile.getAbsolutePath());
            } else {
                log("BŁĄD: Kopia nie powiodła się!");
            }
        }).start();
    }

    private void runFlashTwrp() {
        new Thread(() -> {
            log("Szukanie pliku TWRP...");
            // Search standard paths on internal storage and USB drives
            File[] candidatePaths = new File[]{
                    new File(Environment.getExternalStorageDirectory(), "twrp.img"),
                    new File(Environment.getExternalStorageDirectory(), "recovery.img"),
                    new File(Environment.getExternalStorageDirectory(), "Download/twrp.img"),
                    new File("/storage/usbotg/twrp.img"),
                    new File("/mnt/media_rw/twrp.img")
            };

            File targetTwrp = null;
            for (File f : candidatePaths) {
                if (f.exists() && f.length() > 5 * 1024 * 1024) {
                    targetTwrp = f;
                    break;
                }
            }

            if (targetTwrp == null) {
                log("BŁĄD: Nie znaleziono pliku twrp.img!");
                log("Wrzuć plik 'twrp.img' bezpośrednio do pamięci urządzenia (/sdcard/twrp.img) lub na pendrive!");
                return;
            }

            log("Znaleziono obraz TWRP: " + targetTwrp.getAbsolutePath() + " (" + (targetTwrp.length() / 1024 / 1024) + " MB)");
            log("Fleszowanie do partycji: " + RECOVERY_DEV);

            String cmd = String.format("dd if=%s of=%s bs=1048576", targetTwrp.getAbsolutePath(), RECOVERY_DEV);
            String res = executeRootCommand(cmd);
            log(res);

            log("Wymuszanie zapisu na nośnik (sync)...");
            executeRootCommand("sync");

            log("GRATULACJE! TWRP zostało pomyślnie wgrane do partycji recovery!");
            log("Możesz teraz kliknąć przycisk 3, aby uruchomić TWRP.");
        }).start();
    }

    private void runRebootRecovery() {
        new Thread(() -> {
            log("Uruchamianie urządzenia w trybie Recovery (TWRP)...");
            executeRootCommand("reboot recovery");
        }).start();
    }

    /**
     * Executes a command with root privileges by utilizing /system/xbin/ffsu or su
     */
    private String executeRootCommand(String command) {
        StringBuilder output = new StringBuilder();
        try {
            // First preference: vendor's built-in ffsu backdoor, fallback: su, sh
            Process process;
            if (new File(FFSU_BIN).exists()) {
                process = Runtime.getRuntime().exec(new String[]{FFSU_BIN, "-c", command});
            } else {
                process = Runtime.getRuntime().exec("su");
                DataOutputStream os = new DataOutputStream(process.getOutputStream());
                os.writeBytes(command + "\nexit\n");
                os.flush();
            }

            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            BufferedReader errorReader = new BufferedReader(new InputStreamReader(process.getErrorStream()));
            String line;
            while ((line = reader.readLine()) != null) {
                output.append(line).append("\n");
            }
            while ((line = errorReader.readLine()) != null) {
                output.append(line).append("\n");
            }
            process.waitFor();
        } catch (Exception e) {
            output.append("Wyjątek: ").append(e.getMessage());
        }
        return output.toString();
    }
}
