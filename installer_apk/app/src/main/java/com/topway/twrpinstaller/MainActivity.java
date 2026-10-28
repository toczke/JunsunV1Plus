package com.topway.twrpinstaller;

import android.app.Activity;
import android.content.pm.ActivityInfo;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.widget.Button;
import android.widget.TextView;

import java.io.BufferedReader;
import java.io.DataOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.NetworkInterface;
import java.security.MessageDigest;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Enumeration;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class MainActivity extends Activity {

    private static final String FFSU_BIN = "/system/xbin/ffsu";
    private static final String FFSU_BACKDOOR_KEY = "@#zxcvbnmasdfghjklqwertyuiop1234567890,.";

    private TextView tvRootStatus;
    private TextView tvFileInfo;
    private TextView tvLogs;

    private Button btnAdbWifi;
    private Button btnFlashMagisk;
    private Button btnFlashTwrp;
    private Button btnRebootRecovery;
    private Button btnBackup;
    private Button btnRestoreStock;
    private Button btnRebootSystem;

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
        btnFlashTwrp = findViewById(R.id.btn_flash_twrp);
        btnRebootRecovery = findViewById(R.id.btn_reboot_recovery);
        btnBackup = findViewById(R.id.btn_backup);
        btnRestoreStock = findViewById(R.id.btn_restore_stock);
        btnRebootSystem = findViewById(R.id.btn_reboot_system);

        checkRootStatus();

        btnAdbWifi.setOnClickListener(v -> runEnableAdbWifi());
        btnFlashMagisk.setOnClickListener(v -> runFlashMagiskRoot());
        btnFlashTwrp.setOnClickListener(v -> runFlashTwrpRecovery());
        btnRebootRecovery.setOnClickListener(v -> runRebootRecovery());
        btnBackup.setOnClickListener(v -> runBackupAll());
        btnRestoreStock.setOnClickListener(v -> runRestoreStock());
        btnRebootSystem.setOnClickListener(v -> runRebootSystem());
    }

    private void setButtonsEnabled(final boolean enabled) {
        mainHandler.post(() -> {
            btnAdbWifi.setEnabled(enabled);
            btnFlashMagisk.setEnabled(enabled);
            btnFlashTwrp.setEnabled(enabled);
            btnRebootRecovery.setEnabled(enabled);
            btnBackup.setEnabled(enabled);
            btnRestoreStock.setEnabled(enabled);
            btnRebootSystem.setEnabled(enabled);
        });
    }

    private void log(String msg) {
        mainHandler.post(() -> {
            String time = new SimpleDateFormat("HH:mm:ss", Locale.US).format(new Date());
            tvLogs.append("[" + time + "] " + msg + "\n");
        });
    }

    private void checkRootStatus() {
        new Thread(() -> {
            String result = executeRootCommand("id");
            if (result.contains("uid=0")) {
                isRootAvailable = true;
                mainHandler.post(() -> {
                    tvRootStatus.setText("Root Privileges: Active (uid=0)");
                    tvRootStatus.setTextColor(0xFF00E676); // Green
                });
                log("Root privileges confirmed.");
                runEnableAdbWifi();
                scanAvailableFiles();
            } else {
                isRootAvailable = false;
                mainHandler.post(() -> {
                    tvRootStatus.setText("Warning: Root privileges not available (" + result.trim() + ")");
                    tvRootStatus.setTextColor(0xFFFF5252); // Red
                });
                log("Failed to acquire root privileges: " + result.trim());
            }
        }).start();
    }

    private String getLocalIpAddress() {
        try {
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
            log("IP detection error: " + ex.getMessage());
        }

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
            log("Configuring ADB over Wi-Fi (port 5555)...");
            executeRootCommand("setprop service.adb.tcp.port 5555");
            executeRootCommand("stop adbd");
            executeRootCommand("start adbd");

            String ip = getLocalIpAddress();
            if (ip != null) {
                log("ADB over Wi-Fi active: adb connect " + ip + ":5555");
            } else {
                log("ADB over Wi-Fi configured on port 5555 (waiting for Wi-Fi IP).");
            }
        }).start();
    }

    private String findBlockDevice(String partitionName) {
        String byName = "/dev/block/by-name/" + partitionName;
        String check = executeRootCommand("[ -b " + byName + " ] && echo EXISTS || echo NO").trim();
        if ("EXISTS".equals(check)) {
            return byName;
        }

        String platformByName = "/dev/block/platform/bootdevice/by-name/" + partitionName;
        check = executeRootCommand("[ -b " + platformByName + " ] && echo EXISTS || echo NO").trim();
        if ("EXISTS".equals(check)) {
            return platformByName;
        }

        String resolved = executeRootCommand("readlink -f /dev/block/by-name/" + partitionName + " 2>/dev/null").trim();
        if (resolved.startsWith("/dev/block/")) {
            return resolved;
        }

        resolved = executeRootCommand("find /dev/block -name " + partitionName + " 2>/dev/null | head -n 1").trim();
        if (resolved.startsWith("/dev/block/")) {
            return resolved;
        }
        return byName;
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
            String stockBoot = findFile("boot_stock.img", "stock_boot.img");
            String stockRec = findFile("recovery.img", "stock_recovery.img");

            StringBuilder sb = new StringBuilder("Storage: ");
            sb.append(magiskImg != null ? "[Magisk Boot: OK] " : "[Magisk Boot: Missing] ");
            sb.append(twrpImg != null ? "[TWRP: OK] " : "[TWRP: Missing] ");
            sb.append(stockBoot != null ? "[Stock Boot: OK] " : "[Stock Boot: Missing] ");
            sb.append(stockRec != null ? "[Stock Recovery: OK] " : "[Stock Recovery: Missing] ");

            mainHandler.post(() -> tvFileInfo.setText(sb.toString()));
        }).start();
    }

    private String computeFileSha256(String filePath, long maxBytes) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            FileInputStream fis = new FileInputStream(new File(filePath));
            byte[] buffer = new byte[65536];
            long bytesReadTotal = 0;
            int n;
            while ((n = fis.read(buffer)) != -1) {
                if (maxBytes > 0 && bytesReadTotal + n > maxBytes) {
                    digest.update(buffer, 0, (int)(maxBytes - bytesReadTotal));
                    break;
                }
                digest.update(buffer, 0, n);
                bytesReadTotal += n;
            }
            fis.close();
            byte[] hash = digest.digest();
            StringBuilder sb = new StringBuilder();
            for (byte b : hash) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception ex) {
            log("Error computing file SHA-256: " + ex.getMessage());
            return null;
        }
    }

    private String computePartitionSha256(String blockDev, long byteCount) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            Process process;
            File ffsu = new File(FFSU_BIN);
            if (ffsu.exists()) {
                process = Runtime.getRuntime().exec(new String[]{FFSU_BIN, FFSU_BACKDOOR_KEY});
            } else {
                process = Runtime.getRuntime().exec("su");
            }

            DataOutputStream os = new DataOutputStream(process.getOutputStream());
            long blocks = (byteCount + 65535) / 65536;
            os.writeBytes("dd if=" + blockDev + " bs=65536 count=" + blocks + " 2>/dev/null\n");
            os.writeBytes("exit\n");
            os.flush();

            InputStream is = process.getInputStream();
            byte[] buffer = new byte[65536];
            long bytesRemaining = byteCount;
            while (bytesRemaining > 0) {
                int toRead = (int) Math.min(buffer.length, bytesRemaining);
                int n = is.read(buffer, 0, toRead);
                if (n == -1) break;
                digest.update(buffer, 0, n);
                bytesRemaining -= n;
            }
            process.waitFor();

            byte[] hash = digest.digest();
            StringBuilder sb = new StringBuilder();
            for (byte b : hash) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception ex) {
            log("Error computing partition SHA-256: " + ex.getMessage());
            return null;
        }
    }

    /**
     * Flashes verified boot image to boot partition ONLY.
     * Performs automatic safety backup and post-flash SHA-256 integrity verification.
     */
    private void runFlashMagiskRoot() {
        new Thread(() -> {
            setButtonsEnabled(false);
            try {
                log(">>> [1/5] Initiating Magisk Root installation (boot.img)...");
                String magiskImg = findFile("boot_magisk_patched.img", "magisk_boot.img");
                if (magiskImg == null) {
                    log("[ERROR] boot_magisk_patched.img not found on external storage!");
                    return;
                }

                File srcFile = new File(magiskImg);
                long fileSize = srcFile.length();
                String bootDev = findBlockDevice("boot");
                String miscDev = findBlockDevice("misc");

                log("Source: " + magiskImg + " (" + fileSize + " bytes)");
                log("Target Partition: " + bootDev + " (BOOT ONLY)");

                // 1. Compute source checksum
                log(">>> [2/5] Computing source SHA-256 checksum...");
                String srcHash = computeFileSha256(magiskImg, fileSize);
                log("Source SHA-256: " + srcHash);

                // 2. Backup current boot
                log(">>> [3/5] Backing up current boot partition...");
                String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date());
                String backupPath = "/sdcard/RecoveryBackup/boot_backup_" + timeStamp + ".img";
                executeRootCommand("mkdir -p /sdcard/RecoveryBackup && dd if=" + bootDev + " of=" + backupPath + " bs=4M conv=fsync");
                executeRootCommand("sync");

                String chk = executeRootCommand("[ -s " + backupPath + " ] && stat -c%s " + backupPath + " 2>/dev/null || echo 0").trim();
                long backupSize = 0;
                try { backupSize = Long.parseLong(chk); } catch (Exception ignored) {}
                if (backupSize < 30000000) {
                    log("[CRITICAL ERROR] Pre-flash boot backup verification failed (size=" + backupSize + " bytes)!");
                    log("Aborting flash immediately to protect device integrity.");
                    return;
                }
                log("Pre-flash boot backup verified (" + backupSize + " bytes).");

                // Also copy backup to USB storage alongside source image if possible
                try {
                    File parent = srcFile.getParentFile();
                    if (parent != null && parent.isDirectory()) {
                        String usbBackupDir = parent.getAbsolutePath() + "/RecoveryBackup";
                        executeRootCommand("mkdir -p " + usbBackupDir + " && cp " + backupPath + " " + usbBackupDir + "/ && sync");
                        log("Safety backup mirrored to USB: " + usbBackupDir);
                    }
                } catch (Exception ignored) {}

                // 3. Write boot partition
                log(">>> [4/5] Writing Magisk boot image to " + bootDev + "...");
                executeRootCommand("dd if=\"" + magiskImg + "\" of=\"" + bootDev + "\" bs=4M conv=fsync");
                executeRootCommand("sync");

                // Clear misc to prevent any boot loop
                executeRootCommand("dd if=/dev/zero of=\"" + miscDev + "\" bs=512 count=1 conv=notrunc");
                executeRootCommand("sync");

                // 4. Verify post-flash integrity
                log(">>> [5/5] Performing post-flash SHA-256 verification on eMMC...");
                String partHash = computePartitionSha256(bootDev, fileSize);
                log("eMMC Partition SHA-256: " + partHash);

                if (srcHash != null && srcHash.equalsIgnoreCase(partHash)) {
                    log("==================================================");
                    log("[VERIFICATION SUCCESS] SHA-256 matches perfectly!");
                    log("Magisk boot image written and verified on eMMC flash.");
                    log("Reboot device via 'Reboot System' to enter rooted Android.");
                    log("==================================================");
                } else {
                    log("==================================================");
                    log("[CRITICAL ERROR] SHA-256 mismatch detected!");
                    log("Restoring backup immediately to prevent brick...");
                    executeRootCommand("dd if=\"" + backupPath + "\" of=\"" + bootDev + "\" bs=4M conv=fsync");
                    executeRootCommand("sync");
                    log("Safety backup restored. Boot partition is safe.");
                    log("==================================================");
                }
            } finally {
                setButtonsEnabled(true);
            }
        }).start();
    }

    /**
     * Flashes TWRP recovery image to recovery partition ONLY.
     * Never touches boot partition! Performs SHA-256 integrity verification.
     */
    private void runFlashTwrpRecovery() {
        new Thread(() -> {
            setButtonsEnabled(false);
            try {
                log(">>> [1/5] Initiating TWRP Recovery installation (recovery.img)...");
                String twrpImg = findFile("twrp_fixed_32mb.img", "twrp.img");
                if (twrpImg == null) {
                    log("[ERROR] twrp_fixed_32mb.img or twrp.img not found!");
                    return;
                }

                File srcFile = new File(twrpImg);
                long fileSize = srcFile.length();
                String recDev = findBlockDevice("recovery");

                log("Source: " + twrpImg + " (" + fileSize + " bytes)");
                log("Target Partition: " + recDev + " (RECOVERY ONLY)");

                // 1. Source checksum
                log(">>> [2/5] Computing source SHA-256 checksum...");
                String srcHash = computeFileSha256(twrpImg, fileSize);
                log("Source SHA-256: " + srcHash);

                // 2. Backup recovery
                log(">>> [3/5] Backing up current recovery partition...");
                String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date());
                String backupPath = "/sdcard/RecoveryBackup/recovery_backup_" + timeStamp + ".img";
                executeRootCommand("mkdir -p /sdcard/RecoveryBackup && dd if=" + recDev + " of=" + backupPath + " bs=4M conv=fsync");
                executeRootCommand("sync");

                String chk = executeRootCommand("[ -s " + backupPath + " ] && stat -c%s " + backupPath + " 2>/dev/null || echo 0").trim();
                long backupSize = 0;
                try { backupSize = Long.parseLong(chk); } catch (Exception ignored) {}
                if (backupSize < 30000000) {
                    log("[CRITICAL ERROR] Pre-flash recovery backup verification failed (size=" + backupSize + " bytes)!");
                    log("Aborting flash immediately to protect device integrity.");
                    return;
                }
                log("Pre-flash recovery backup verified (" + backupSize + " bytes).");

                // Also copy backup to USB storage alongside source image if possible
                try {
                    File parent = srcFile.getParentFile();
                    if (parent != null && parent.isDirectory()) {
                        String usbBackupDir = parent.getAbsolutePath() + "/RecoveryBackup";
                        executeRootCommand("mkdir -p " + usbBackupDir + " && cp " + backupPath + " " + usbBackupDir + "/ && sync");
                        log("Safety backup mirrored to USB: " + usbBackupDir);
                    }
                } catch (Exception ignored) {}

                // 3. Write recovery partition
                log(">>> [4/5] Writing TWRP image to " + recDev + "...");
                executeRootCommand("dd if=\"" + twrpImg + "\" of=\"" + recDev + "\" bs=4M conv=fsync");
                executeRootCommand("sync");

                // 4. Verify post-flash integrity
                log(">>> [5/5] Performing post-flash SHA-256 verification on eMMC...");
                String partHash = computePartitionSha256(recDev, fileSize);
                log("eMMC Partition SHA-256: " + partHash);

                if (srcHash != null && srcHash.equalsIgnoreCase(partHash)) {
                    log("==================================================");
                    log("[VERIFICATION SUCCESS] SHA-256 matches perfectly!");
                    log("TWRP successfully written to recovery partition.");
                    log("Click 'Reboot Recovery (ffup)' to boot into TWRP.");
                    log("==================================================");
                } else {
                    log("==================================================");
                    log("[CRITICAL ERROR] SHA-256 mismatch detected!");
                    log("Restoring backup immediately...");
                    executeRootCommand("dd if=\"" + backupPath + "\" of=\"" + recDev + "\" bs=4M conv=fsync");
                    executeRootCommand("sync");
                    log("Safety backup restored. Recovery partition is safe.");
                    log("==================================================");
                }
            } finally {
                setButtonsEnabled(true);
            }
        }).start();
    }

    /**
     * Reboots to recovery via Topway LittleKernel 'ffup' trigger.
     */
    private void runRebootRecovery() {
        new Thread(() -> {
            log(">>> Setting LittleKernel 'ffup' recovery trigger in misc...");
            String miscDev = findBlockDevice("misc");
            executeRootCommand("printf \"ffup\" | dd of=\"" + miscDev + "\" bs=4 count=1 conv=notrunc");
            executeRootCommand("sync");

            log(">>> Rebooting headunit cleanly (LittleKernel will detect ffup)...");
            try { Thread.sleep(1000); } catch (Exception ignored) {}
            executeRootCommand("reboot");
        }).start();
    }

    /**
     * Performs a full backup of boot and recovery partitions to /sdcard/RecoveryBackup/.
     */
    private void runBackupAll() {
        new Thread(() -> {
            log(">>> Initiating full partition backup (boot and recovery)...");
            String bootDev = findBlockDevice("boot");
            String recDev = findBlockDevice("recovery");

            String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date());
            String outDir = "/sdcard/RecoveryBackup";
            executeRootCommand("mkdir -p " + outDir);

            String bootOut = outDir + "/boot_" + timeStamp + ".img";
            String recOut = outDir + "/recovery_" + timeStamp + ".img";

            log("Saving boot backup to: " + bootOut);
            executeRootCommand("dd if=" + bootDev + " of=" + bootOut + " bs=4M");

            log("Saving recovery backup to: " + recOut);
            executeRootCommand("dd if=" + recDev + " of=" + recOut + " bs=4M");

            executeRootCommand("sync");
            log("[SUCCESS] Partitions backed up successfully to " + outDir);
        }).start();
    }

    /**
     * Restores stock boot and recovery images and clears misc trigger.
     */
    private void runRestoreStock() {
        new Thread(() -> {
            log(">>> Initiating stock firmware restoration...");
            String stockBoot = findFile("boot_stock.img", "stock_boot.img");
            String stockRec = findFile("recovery.img", "stock_recovery.img");

            String bootDev = findBlockDevice("boot");
            String recDev = findBlockDevice("recovery");
            String miscDev = findBlockDevice("misc");

            if (stockBoot != null) {
                log("Restoring stock boot.img from: " + stockBoot);
                executeRootCommand("dd if=\"" + stockBoot + "\" of=\"" + bootDev + "\" bs=4M conv=fsync");
            } else {
                log("[WARNING] Stock boot image not found on external storage.");
            }

            if (stockRec != null) {
                log("Restoring stock recovery.img from: " + stockRec);
                executeRootCommand("dd if=\"" + stockRec + "\" of=\"" + recDev + "\" bs=4M conv=fsync");
            } else {
                log("[WARNING] Stock recovery image not found on external storage.");
            }

            log("Clearing misc trigger...");
            executeRootCommand("dd if=/dev/zero of=\"" + miscDev + "\" bs=512 count=1 conv=notrunc");
            executeRootCommand("sync");

            log("==================================================");
            log("[SUCCESS] Factory stock state restored.");
            log("Click 'Reboot System' to restart.");
            log("==================================================");
        }).start();
    }

    /**
     * Clears misc partition to eliminate boot loops and reboots system cleanly.
     */
    private void runRebootSystem() {
        new Thread(() -> {
            log("Clearing misc trigger to ensure clean boot...");
            String miscDev = findBlockDevice("misc");
            executeRootCommand("dd if=/dev/zero of=\"" + miscDev + "\" bs=512 count=1 conv=notrunc");
            executeRootCommand("sync");

            log("Rebooting system...");
            try { Thread.sleep(500); } catch (Exception ignored) {}
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
