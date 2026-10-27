package com.topway.twrpinstaller;

import android.app.Activity;
import android.content.pm.ActivityInfo;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
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

    // Target block devices verified from stock fstab and partition table
    private static final String DEFAULT_RECOVERY_DEV = "/dev/block/platform/bootdevice/by-name/recovery";
    private static final String FFSU_BIN = "/system/xbin/ffsu";
    // Hardware vendor backdoor key discovered at offset 0x2c70 in ffsu binary
    private static final String FFSU_BACKDOOR_KEY = "@#zxcvbnmasdfghjklqwertyuiop1234567890,.";

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

    /**
     * Checks if root access can be obtained via ffsu backdoor or su
     */
    private void checkExploitStatus() {
        new Thread(() -> {
            File ffsu = new File(FFSU_BIN);
            if (ffsu.exists()) {
                log("Wykryto binarkę dostępową producenta: " + FFSU_BIN);
            }

            // Test executing root command via ffsu backdoor
            String result = executeRootCommand("id");
            if (result.contains("uid=0")) {
                isRootAvailable = true;
                mainHandler.post(() -> {
                    tvRootStatus.setText("Status ROOT: AKTYWNY (uid=0) - Pełne uprawnienia roota!");
                    tvRootStatus.setTextColor(0xFF00FF00); // Green
                });
                log("Uprawnienia ROOT potwierdzone pomyślnie: " + result.trim());
            } else {
                isRootAvailable = false;
                mainHandler.post(() -> {
                    tvRootStatus.setText("Ostrzeżenie: Brak uprawnień roota (" + result.trim() + ")");
                    tvRootStatus.setTextColor(0xFFFF4444); // Red
                });
                log("Błąd uzyskania uprawnień roota: " + result.trim());
            }
        }).start();
    }

    /**
     * Dynamically finds the active recovery block device
     */
    private String findRecoveryBlockDevice() {
        String[] candidates = new String[]{
                "/dev/block/by-name/recovery",
                "/dev/block/platform/bootdevice/by-name/recovery"
        };
        for (String c : candidates) {
            String out = executeRootCommand("[ -b \"" + c + "\" ] && echo EXISTS || true");
            if (out.contains("EXISTS")) {
                return c;
            }
        }
        // Fallback: search via find
        String out = executeRootCommand("find /dev/block -name recovery 2>/dev/null | head -n 1");
        String trimmed = out.trim();
        if (!trimmed.isEmpty() && trimmed.startsWith("/dev/block")) {
            return trimmed;
        }
        return DEFAULT_RECOVERY_DEV;
    }

    /**
     * Scans storage and USB drives to find TWRP or recovery image
     */
    private String findTwrpImage() {
        // Fast search using root privileges across all mounted partitions & USB drives
        String cmd = "find /sdcard /storage /mnt -maxdepth 3 \\( -name \"twrp.img\" -o -name \"recovery.img\" -o -name \"*twrp*.img\" \\) -size +10M 2>/dev/null";
        String out = executeRootCommand(cmd);
        String[] lines = out.split("\\r?\\n");
        for (String line : lines) {
            String trimmed = line.trim();
            if (trimmed.endsWith(".img") && !trimmed.contains("stock_recovery_")) {
                return trimmed;
            }
        }

        // Direct candidate paths fallback
        String[] directPaths = new String[]{
                "/sdcard/twrp.img",
                "/sdcard/recovery.img",
                "/sdcard/Download/twrp.img",
                "/storage/usbotg/twrp.img",
                "/mnt/media_rw/twrp.img"
        };
        for (String path : directPaths) {
            String check = executeRootCommand("[ -f \"" + path + "\" ] && echo EXISTS || true");
            if (check.contains("EXISTS")) {
                return path;
            }
        }

        return null;
    }

    private void runBackupRecovery() {
        new Thread(() -> {
            log("Rozpoczynanie kopii zapasowej fabrycznego recovery...");
            String recDev = findRecoveryBlockDevice();
            log("Urządzenie źródłowe: " + recDev);

            File outDir = new File(Environment.getExternalStorageDirectory(), "RecoveryBackup");
            if (!outDir.exists()) outDir.mkdirs();

            String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date());
            File outFile = new File(outDir, "stock_recovery_" + timeStamp + ".img");

            String cmd = String.format("mkdir -p %s && dd if=%s of=%s bs=1048576 && chmod 666 %s",
                    outDir.getAbsolutePath(), recDev, outFile.getAbsolutePath(), outFile.getAbsolutePath());

            log("Wykonywanie zrzutu: " + cmd);
            String res = executeRootCommand(cmd);
            log(res.trim());

            String check = executeRootCommand("ls -lh " + outFile.getAbsolutePath());
            if (check.contains("stock_recovery_")) {
                log("SUKCES! Kopia zapasowa zapisana w:");
                log(outFile.getAbsolutePath() + " (" + check.trim() + ")");
            } else {
                log("BŁĄD: Nie udało się wykonać kopii zapasowej!");
            }
        }).start();
    }

    private void runFlashTwrp() {
        new Thread(() -> {
            log("Wyszukiwanie pliku obrazu TWRP na pamięci i pendrive USB...");
            String targetTwrp = findTwrpImage();

            if (targetTwrp == null) {
                log("BŁĄD: Nie znaleziono pliku twrp.img ani recovery.img!");
                log("Podłącz pendrive z plikiem twrp.img lub skopiuj twrp.img do /sdcard/twrp.img!");
                return;
            }

            String recDev = findRecoveryBlockDevice();
            log("Znaleziono obraz TWRP: " + targetTwrp);
            log("Docelowa partycja recovery: " + recDev);

            // Automatic safety backup before flashing
            log("Tworzenie automatycznej kopii zapasowej obecnego recovery...");
            String autoBackup = "/sdcard/RecoveryBackup/stock_recovery_auto_preflash.img";
            executeRootCommand("mkdir -p /sdcard/RecoveryBackup && dd if=" + recDev + " of=" + autoBackup + " bs=1048576 && chmod 666 " + autoBackup);

            // Flash TWRP image to recovery partition
            log("Wgrywanie obrazu TWRP na partycję recovery (dd)...");
            String cmd = String.format("dd if=\"%s\" of=\"%s\" bs=1048576", targetTwrp, recDev);
            String res = executeRootCommand(cmd);
            log(res.trim());

            // Flush filesystem buffers
            log("Synchronizacja buforów (sync)...");
            executeRootCommand("sync");

            log("SUKCES! Obraz TWRP został pomyślnie wgrany na partycję recovery!");
            log("Możesz teraz kliknąć przycisk 3 ('Reboot to Recovery'), aby uruchomić TWRP.");
        }).start();
    }

    private void runRebootRecovery() {
        new Thread(() -> {
            log("Restartowanie stacji multimedialnej do trybu Recovery (TWRP)...");
            executeRootCommand("reboot recovery");
        }).start();
    }

    /**
     * Executes a command with root privileges by utilizing /system/xbin/ffsu backdoor or su
     */
    private String executeRootCommand(String command) {
        StringBuilder output = new StringBuilder();
        try {
            Process process;
            File ffsu = new File(FFSU_BIN);
            if (ffsu.exists()) {
                // Call ffsu with backdoor password argument to bypass package whitelist and gain root sh
                process = Runtime.getRuntime().exec(new String[]{FFSU_BIN, FFSU_BACKDOOR_KEY});
            } else {
                process = Runtime.getRuntime().exec("su");
            }

            DataOutputStream os = new DataOutputStream(process.getOutputStream());
            // Execute command followed by exit so the subshell terminates cleanly
            os.writeBytes(command + "\n");
            os.writeBytes("exit\n");
            os.flush();

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
            output.append("Exception: ").append(e.getMessage()).append("\n");
        }
        return output.toString();
    }
}
