package com.topway.carsettingsbridge;

import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Binder;
import android.os.IBinder;
import android.os.RemoteCallbackList;
import android.os.RemoteException;
import android.util.Log;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;

public class CarSettingsService extends Service {
    private static final String TAG = "CarSettingsService";
    private static final int API_VERSION = 1;

    private static final String THERMAL_TEMP_PATH = "/sys/class/thermal/thermal_zone0/temp";
    private static final String FAN_PWM_PATH = "/sys/class/leds/fan/brightness";

    private final RemoteCallbackList<ICarSettingsCallback> mCallbacks = new RemoteCallbackList<>();

    private int mMasterVolume = 15;
    private boolean mMuted = false;
    private int mAudioSource = 0;
    private boolean mHeadlightsOn = false;
    private boolean mReverseEngaged = false;
    private boolean mAccOn = true;

    private BroadcastReceiver mVehicleReceiver;

    @Override
    public void onCreate() {
        super.onCreate();
        Log.i(TAG, "Topway TS8667 CarSettingsService initialized (API v" + API_VERSION + ")");

        mVehicleReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                if (intent == null || intent.getAction() == null) return;
                String action = intent.getAction();

                if ("android.intent.action.BACKCAR_SERVICE".equals(action)) {
                    boolean status = intent.getBooleanExtra("status", false);
                    mReverseEngaged = status;
                    notifyReverseChanged(status);
                } else if ("com.topway.action.ILLUM_CHANGED".equals(action)) {
                    boolean illum = intent.getBooleanExtra("illum", false);
                    mHeadlightsOn = illum;
                    notifyIllumChanged(illum);
                }
            }
        };

        IntentFilter filter = new IntentFilter();
        filter.addAction("android.intent.action.BACKCAR_SERVICE");
        filter.addAction("com.topway.action.ILLUM_CHANGED");
        registerReceiver(mVehicleReceiver, filter);
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (mVehicleReceiver != null) {
            unregisterReceiver(mVehicleReceiver);
        }
        mCallbacks.kill();
        Log.i(TAG, "CarSettingsService destroyed");
    }

    private final ICarSettingsService.Stub mBinder = new ICarSettingsService.Stub() {
        @Override
        public int getApiVersion() {
            return API_VERSION;
        }

        @Override
        public int getMasterVolume() {
            return mMasterVolume;
        }

        @Override
        public boolean setMasterVolume(int volume) {
            if (volume < 0 || volume > 30) {
                Log.w(TAG, "Rejected invalid master volume: " + volume);
                return false;
            }
            mMasterVolume = volume;
            notifyVolumeChanged(mMasterVolume, mMuted);
            return true;
        }

        @Override
        public boolean isMuted() {
            return mMuted;
        }

        @Override
        public boolean setMuted(boolean muted) {
            mMuted = muted;
            notifyVolumeChanged(mMasterVolume, mMuted);
            return true;
        }

        @Override
        public boolean setAudioSource(int source) {
            if (source < 0 || source > 3) {
                Log.w(TAG, "Rejected invalid audio source: " + source);
                return false;
            }
            mAudioSource = source;
            return true;
        }

        @Override
        public boolean getIlluminationState() {
            return mHeadlightsOn;
        }

        @Override
        public boolean getReverseState() {
            return mReverseEngaged;
        }

        @Override
        public boolean getAccPowerState() {
            return mAccOn;
        }

        @Override
        public int getCpuTemperature() {
            File f = new File(THERMAL_TEMP_PATH);
            if (!f.exists() || !f.canRead()) {
                return -1;
            }
            try (BufferedReader reader = new BufferedReader(new FileReader(f))) {
                String line = reader.readLine();
                if (line != null) {
                    return Integer.parseInt(line.trim());
                }
            } catch (Exception e) {
                Log.e(TAG, "Error reading CPU thermal sensor: " + e.getMessage());
            }
            return -1;
        }

        @Override
        public int getFanSpeed() {
            File f = new File(FAN_PWM_PATH);
            if (!f.exists() || !f.canRead()) {
                return -1;
            }
            try (BufferedReader reader = new BufferedReader(new FileReader(f))) {
                String line = reader.readLine();
                if (line != null) {
                    return Integer.parseInt(line.trim());
                }
            } catch (Exception e) {
                Log.e(TAG, "Error reading fan PWM: " + e.getMessage());
            }
            return -1;
        }

        @Override
        public boolean setFanSpeed(int pwmValue) {
            if (pwmValue < 0 || pwmValue > 255) {
                Log.w(TAG, "Rejected invalid fan PWM: " + pwmValue);
                return false;
            }
            File f = new File(FAN_PWM_PATH);
            if (!f.exists() || !f.canWrite()) {
                Log.w(TAG, "Fan PWM interface " + FAN_PWM_PATH + " not writable");
                return false;
            }
            try (FileWriter writer = new FileWriter(f)) {
                writer.write(String.valueOf(pwmValue) + "\n");
                return true;
            } catch (IOException e) {
                Log.e(TAG, "Failed to write fan PWM: " + e.getMessage());
                return false;
            }
        }

        @Override
        public void registerCallback(ICarSettingsCallback callback) {
            if (callback != null) {
                mCallbacks.register(callback);
            }
        }

        @Override
        public void unregisterCallback(ICarSettingsCallback callback) {
            if (callback != null) {
                mCallbacks.unregister(callback);
            }
        }
    };

    private void notifyReverseChanged(boolean reverseEngaged) {
        int n = mCallbacks.beginBroadcast();
        for (int i = 0; i < n; i++) {
            try {
                mCallbacks.getBroadcastItem(i).onReverseGearChanged(reverseEngaged);
            } catch (RemoteException e) {
                Log.w(TAG, "RemoteException in notifyReverseChanged: " + e.getMessage());
            }
        }
        mCallbacks.finishBroadcast();
    }

    private void notifyIllumChanged(boolean headlightsOn) {
        int n = mCallbacks.beginBroadcast();
        for (int i = 0; i < n; i++) {
            try {
                mCallbacks.getBroadcastItem(i).onIlluminationChanged(headlightsOn);
            } catch (RemoteException e) {
                Log.w(TAG, "RemoteException in notifyIllumChanged: " + e.getMessage());
            }
        }
        mCallbacks.finishBroadcast();
    }

    private void notifyVolumeChanged(int vol, boolean muted) {
        int n = mCallbacks.beginBroadcast();
        for (int i = 0; i < n; i++) {
            try {
                mCallbacks.getBroadcastItem(i).onVolumeChanged(vol, muted);
            } catch (RemoteException e) {
                Log.w(TAG, "RemoteException in notifyVolumeChanged: " + e.getMessage());
            }
        }
        mCallbacks.finishBroadcast();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return mBinder;
    }
}
