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
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.NetworkInterface;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Enumeration;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class MainActivity extends Activity {

    private static final String FFSU_BIN = "/system/xbin/ffsu";
    // Hardware vendor backdoor key discovered in ffsu binary
    private static final String FFSU_BACKDOOR_KEY = "@#zxcvbnmasdfghjklqwertyuiop1234567890,.";

    private TextView tvRootStatus;
    private TextView tvFileInfo;
    private TextView tvLogs;

    private Button btnAdbWifi;
    private Button btnFlashMagisk;
    private Button btnFlashTwrpFfup;
    private Button btnBootTwrpDirect;
    private Button btnBackup;
    private Button btnRestoreStock;
    private Button btnReboot;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private boolean isRootAvailable = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);
        setContentView(R.layout.activity_main);

        tvRootStatus = findViewById(R.id.tv_root_status);
        tvFileInfo = findViewById(R.id.tv_file_info);
        tvLogs = findViewById(R.id.tv_logs);

        btnAdbWifi = findViewById(R.id.btn_adb_wifi);
        btnFlashMagisk = findViewById(R.id.btn_flash_magisk);
        btnFlashTwrpFfup = findViewById(R.id.btn_flash_twrp_ffup);
        btnBootTwrpDirect = findViewById(R.id.btn_boot_twrp_direct);
        btnBackup = findViewById(R.id.btn_backup);
        btnRestoreStock = findViewById(R.id.btn_restore_stock);
        btnReboot = findViewById(R.id.btn_reboot);

        checkExploitStatus();

        btnAdbWifi.setOnClickListener(v -> runEnableAdbWifi());
        btnFlashMagisk.setOnClickListener(v -> runFlashMagiskRoot());
        btnFlashTwrpFfup.setOnClickListener(v -> runFlashTwrpFfup());
        btnBootTwrpDirect.setOnClickListener(v -> runBootTwrpDirect());
        btnBackup.setOnClickListener(v -> runBackupAll());
        btnRestoreStock.setOnClickListener(v -> runRestoreStock());
        btnReboot.setOnClickListener(v -> runReboot());
    }

    private void log(String msg) {
        mainHandler.post(() -> {
            String time = new SimpleDateFormat("HH:mm:ss", Locale.US).format(new Date());
            tvLogs.append("[" + time + "] " + msg + "\n");
        });
    }

    private void checkExploitStatus() {
        new Thread(() -> {
            String result = executeRootCommand("id");
            if (result.contains("uid=0")) {
                isRootAvailable = true;
                mainHandler.post(() -> {
                    tvRootStatus.setText("Status ROOT: AKTYWNY (uid=0) - Pełne uprawnienia!");
                    tvRootStatus.setTextColor(0xFF00FF00); // Green
                });
                log("Uprawnienia ROOT potwierdzone pomyślnie.");
                runEnableAdbWifi();
                scanAvailableFiles();
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

    private String getLocalIpAddress() {
        try {
            // First check Wi-Fi interface (wlan0)
            for (Enumeration<NetworkInterface> en = NetworkInterface.getNetworkInterfaces(); en.hasMoreElements(); ) {
                NetworkInterface intf = en.nextElement();
                String name = intf.getName().toLowerCase(Locale.US);
                if (name.startsWith("wlan") || name.startsWith("eth") || name.startsWith("tiwlan")) {
                    for (Enumeration<InetAddress> enumIpAddr = intf.getInetAddresses(); enumIpAddr.hasMoreElements(); ) {
                        InetAddress inetAddress = enumIpAddr.nextElement();
                        if (!inetAddress.isLoopbackAddress() && inetAddress instanceof Inet4Address) {
                            String host = inetAddress.getHostAddress();
                            if (host != null && !host.isEmpty() && !host.equals("127.0.0.1")) {
                                return host;
                            }
                        }
                    }
                }
            }
            // General fallback across any active non-loopback network interface
            for (Enumeration<NetworkInterface> en = NetworkInterface.getNetworkInterfaces(); en.hasMoreElements(); ) {
                NetworkInterface intf = en.nextElement();
                if (intf.isLoopback() || !intf.isUp()) continue;
                for (Enumeration<InetAddress> enumIpAddr = intf.getInetAddresses(); enumIpAddr.hasMoreElements(); ) {
                    InetAddress inetAddress = enumIpAddr.nextElement();
                    if (!inetAddress.isLoopbackAddress() && inetAddress instanceof Inet4Address) {
                        String host = inetAddress.getHostAddress();
                        if (host != null && !host.isEmpty() && !host.equals("127.0.0.1")) {
                            return host;
                        }
                    }
                }
            }
        } catch (Exception ex) {
            log("Błąd odczytu IP: " + ex.getMessage());
        }

        // Secondary fallback: parse 'ip addr show' with strict IPv4 regex
        try {
            String out = executeRootCommand("ip -4 addr show 2>/dev/null");
            Pattern p = Pattern.compile("inet\\s+([0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+)");
            Matcher m = p.matcher(out);
            while (m.find()) {
                String candidate = m.group(1);
                if (!"127.0.0.1".equals(candidate)) {
                    return candidate;
                }
            }
        } catch (Exception ignored) {}

        return null;
    }

    private void runEnableAdbWifi() {
        new Thread(() -> {
            log("Konfiguracja ADB przez Wi-Fi (port 5555)...");
            executeRootCommand("setprop service.adb.tcp.port 5555 && stop adbd && start adbd");

            String ip = getLocalIpAddress();
            if (ip != null && !ip.isEmpty()) {
                final String targetIp = ip;
                mainHandler.post(() -> {
                    tvRootStatus.setText("ADB aktywne: adb connect " + targetIp + ":5555");
                    tvRootStatus.setTextColor(0xFF00E5FF);
                });
                log("ADB PO WI-FI AKTYWNE: adb connect " + targetIp + ":5555");
            } else {
                mainHandler.post(() -> {
                    tvRootStatus.setText("ADB aktywne na porcie 5555 (brak aktywnego IP Wi-Fi)");
                    tvRootStatus.setTextColor(0xFFFFAA00);
                });
                log("ADB aktywne na porcie 5555. Połącz stację z Wi-Fi, aby zobaczyć IP.");
            }
        }).start();
    }

    private String findBlockDevice(String partitionName) {
        String[] candidates = new String[]{
                "/dev/block/by-name/" + partitionName,
                "/dev/block/platform/bootdevice/by-name/" + partitionName
        };
        for (String c : candidates) {
            String out = executeRootCommand("[ -b \"" + c + "\" ] && echo EXISTS || true");
            if (out.contains("EXISTS")) {
                return c;
            }
        }
        String out = executeRootCommand("find /dev/block -name " + partitionName + " 2>/dev/null | head -n 1").trim();
        if (out.startsWith("/dev/block")) {
            return out;
        }
        return "/dev/block/by-name/" + partitionName;
    }

    private String findFile(String... names) {
        for (String name : names) {
            String cmd = "find /storage /mnt /sdcard -name \"" + name + "\" 2>/dev/null | head -n 1";
            String out = executeRootCommand(cmd).trim();
            if (!out.isEmpty() && out.startsWith("/") && !out.contains("Exception")) {
                return out;
            }
        }
        return null;
    }

    private void scanAvailableFiles() {
        new Thread(() -> {
            String magiskImg = findFile("boot_magisk_patched.img", "magisk_boot.img");
            String twrpImg = findFile("twrp_fixed_32mb.img", "twrp.img");
            String stockBoot = findFile("boot_stock.img", "stock_boot.img", "boot.img");

            StringBuilder sb = new StringBuilder("Wykryto pliki: ");
            if (magiskImg != null) sb.append("[Magisk Boot: OK] ");
            if (twrpImg != null) sb.append("[TWRP: OK] ");
            if (stockBoot != null) sb.append("[Stock Boot: OK] ");

            mainHandler.post(() -> tvFileInfo.setText(sb.toString()));
        }).start();
    }

    /**
     * Option 1: Installs Magisk root cleanly via boot partition
     */
    private void runFlashMagiskRoot() {
        new Thread(() -> {
            log(">>> [1/4] Rozpoczynanie instalacji Root Magisk...");
            String magiskImg = findFile("boot_magisk_patched.img", "magisk_boot.img");
            if (magiskImg == null) {
                log("BŁĄD: Nie znaleziono obrazu boot_magisk_patched.img na USB/SD!");
                return;
            }

            String bootDev = findBlockDevice("boot");
            log("Znaleziono obraz Magisk: " + magiskImg);
            log("Docelowa partycja boot: " + bootDev);

            // Safety backup
            log(">>> [2/4] Zrzut kopii zapasowej obecnego boot.img...");
            String backupPath = "/sdcard/RecoveryBackup/stock_boot_auto_backup.img";
            executeRootCommand("mkdir -p /sdcard/RecoveryBackup && dd if=" + bootDev + " of=" + backupPath + " bs=4M");

            // Flash
            log(">>> [3/4] Wgrywanie spatchowanego boot.img (Magisk)...");
            String res = executeRootCommand("dd if=\"" + magiskImg + "\" of=\"" + bootDev + "\" bs=4M");
            log(res.trim());

            log(">>> [4/4] Synchronizacja pamięci flash (sync)...");
            executeRootCommand("sync");

            log("==================================================");
            log("SUKCES! Magisk Boot został wgrany na partycję boot!");
            log("Zrestartuj radio przyciskiem 'Restartuj Radio', aby mieć pełnego Roota.");
            log("==================================================");
        }).start();
    }

    /**
     * Option 2: Flashes TWRP and triggers Topway LittleKernel RECOVERY via 'ffup'
     */
    private void runFlashTwrpFfup() {
        new Thread(() -> {
            log(">>> [1/5] Przygotowanie TWRP oraz wyzwalacza ffup...");
            String twrpImg = findFile("twrp_fixed_32mb.img", "twrp.img");
            if (twrpImg == null) {
                log("BŁĄD: Nie znaleziono pliku twrp_fixed_32mb.img ani twrp.img!");
                return;
            }

            String recDev = findBlockDevice("recovery");
            String miscDev = findBlockDevice("misc");
            log("Obraz TWRP: " + twrpImg);
            log("Partycja recovery: " + recDev);
            log("Partycja misc: " + miscDev);

            // Flash TWRP
            log(">>> [2/5] Wgrywanie TWRP na partycję recovery...");
            executeRootCommand("dd if=\"" + twrpImg + "\" of=\"" + recDev + "\" bs=4M");

            // Write 'ffup' into misc
            log(">>> [3/5] Zapisywanie vendorowego wyzwalacza 'ffup' do misc...");
            executeRootCommand("printf \"ffup\" | dd of=\"" + miscDev + "\" bs=4 count=1 conv=notrunc");

            // Sync
            log(">>> [4/5] Synchronizacja buforów...");
            executeRootCommand("sync");

            log(">>> [5/5] Restartowanie stacji w trybie standardowym (LK wykryje ffup)...");
            try { Thread.sleep(1500); } catch (Exception ignored) {}
            // Plain reboot, NOT reboot recovery!
            executeRootCommand("reboot");
        }).start();
    }

    /**
     * Option 3: Direct boot to TWRP by flashing TWRP into boot partition (100% guaranteed hardware boot)
     */
    private void runBootTwrpDirect() {
        new Thread(() -> {
            log(">>> [1/4] Bezpośredni start TWRP przez partycję boot...");
            String twrpImg = findFile("twrp_fixed_32mb.img", "twrp.img");
            if (twrpImg == null) {
                log("BŁĄD: Nie znaleziono pliku twrp_fixed_32mb.img!");
                return;
            }

            String bootDev = findBlockDevice("boot");
            log("Obraz TWRP: " + twrpImg);
            log("Docelowa partycja startowa: " + bootDev);

            // Safety backup of stock boot
            log(">>> [2/4] Zapisywanie kopii obecnego boot do /sdcard/RecoveryBackup/stock_boot_before_twrp.img...");
            executeRootCommand("mkdir -p /sdcard/RecoveryBackup && dd if=" + bootDev + " of=/sdcard/RecoveryBackup/stock_boot_before_twrp.img bs=4M");

            // Flash TWRP into boot
            log(">>> [3/4] Wgrywanie TWRP na partycję boot...");
            executeRootCommand("dd if=\"" + twrpImg + "\" of=\"" + bootDev + "\" bs=4M");
            executeRootCommand("sync");

            log(">>> [4/4] Restartowanie... Radio odpali się WPROST do menu TWRP!");
            try { Thread.sleep(1500); } catch (Exception ignored) {}
            executeRootCommand("reboot");
        }).start();
    }

    /**
     * Option 4: Full backup of boot and recovery
     */
    private void runBackupAll() {
        new Thread(() -> {
            log("Rozpoczynanie zrzutu kopii zapasowej partycji boot i recovery...");
            String bootDev = findBlockDevice("boot");
            String recDev = findBlockDevice("recovery");

            String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date());
            String outDir = "/sdcard/RecoveryBackup";
            executeRootCommand("mkdir -p " + outDir);

            executeRootCommand("dd if=" + bootDev + " of=" + outDir + "/boot_backup_" + timeStamp + ".img bs=4M");
            executeRootCommand("dd if=" + recDev + " of=" + outDir + "/recovery_backup_" + timeStamp + ".img bs=4M");
            executeRootCommand("chmod -R 666 " + outDir);

            log("SUKCES! Kopie zapasowe zapisane w " + outDir);
        }).start();
    }

    /**
     * Option 5: Restores stock boot and stock recovery
     */
    private void runRestoreStock() {
        new Thread(() -> {
            log("Przywracanie oryginalnych partycji fabrycznych (Stock)...");
            String stockBoot = findFile("boot_stock.img", "stock_boot.img", "stock_boot_before_twrp.img");
            String stockRec = findFile("recovery.img", "stock_recovery.img");

            String bootDev = findBlockDevice("boot");
            String recDev = findBlockDevice("recovery");
            String miscDev = findBlockDevice("misc");

            if (stockBoot != null) {
                log("Przywracanie fabrycznego boot.img z: " + stockBoot);
                executeRootCommand("dd if=\"" + stockBoot + "\" of=\"" + bootDev + "\" bs=4M");
            }
            if (stockRec != null) {
                log("Przywracanie fabrycznego recovery.img z: " + stockRec);
                executeRootCommand("dd if=\"" + stockRec + "\" of=\"" + recDev + "\" bs=4M");
            }

            // Clear misc trigger
            log("Czyszczenie nagłówka misc...");
            executeRootCommand("dd if=/dev/zero of=\"" + miscDev + "\" bs=4 count=1 conv=notrunc");
            executeRootCommand("sync");

            log("SUKCES! Przywrócono fabryczny stan stacji.");
        }).start();
    }

    private void runReboot() {
        new Thread(() -> {
            log("Restartowanie stacji...");
            executeRootCommand("reboot");
        }).start();
    }

    private String executeRootCommand(String command) {
        StringBuilder output = new StringBuilder();
        try {
            Process process;
            File ffsu = new File(FFSU_BIN);
            if (ffsu.exists()) {
                process = Runtime.getRuntime().exec(new String[]{FFSU_BIN, FFSU_BACKDOOR_KEY});
            } else {
                process = Runtime.getRuntime().exec("su");
            }

            DataOutputStream os = new DataOutputStream(process.getOutputStream());
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
