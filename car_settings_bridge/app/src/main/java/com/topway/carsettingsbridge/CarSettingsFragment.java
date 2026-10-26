package com.topway.carsettingsbridge;

import android.content.ComponentName;
import android.content.Intent;
import android.os.Bundle;
import android.widget.Toast;
import androidx.preference.Preference;
import androidx.preference.PreferenceFragmentCompat;

public class CarSettingsFragment extends PreferenceFragmentCompat {

    private static final String TARGET_PKG = "com.ts.MainUI";

    @Override
    public void onCreatePreferences(Bundle savedInstanceState, String rootKey) {
        setPreferencesFromResource(R.xml.car_settings_preferences, rootKey);

        // 1. Reversing Camera
        setupPreference("pref_camera", TARGET_PKG, "com.ts.factoryset.FsBackCarSetActivity", null);

        // 2. Steering Wheel Controls
        setupPreference("pref_swc", TARGET_PKG, "com.ts.main.CStudy.CStudyMainActivity", null);

        // 3. CAN Bus Configuration
        setupPreference("pref_can", TARGET_PKG, "com.ts.factoryset.FsCanActivity", null);

        // 4. DSP & Equalizer
        setupPreference("pref_dsp", TARGET_PKG, "com.ts.set.dsp.SetDspMainActivity", null);

        // 5. Fan & Cooling
        setupPreference("pref_fan", TARGET_PKG, "com.ts.main.cpufan.ElectricFanActivity", null);

        // 6. RGB Button Color
        setupPreference("pref_colorkey", TARGET_PKG, "com.ts.set.SetColorKeyMainActivity", null);

        // 7. Factory Menu (Direct access with factory=true flag - bypasses 8878 PIN)
        Bundle factoryExtras = new Bundle();
        factoryExtras.putBoolean("factory", true);
        setupPreference("pref_factory", TARGET_PKG, "com.ts.factoryset.FsMainActivity", factoryExtras);

        // 8. Vehicle Apps: DVR Dashcam
        setupPreference("pref_dvr", "com.ankai.cardvr", "com.ankai.cardvr.MainActivity", null);

        // 9. TPMS Tire Pressure
        setupPreference("pref_tpms", TARGET_PKG, "com.ts.main.tpms.TPMSMainActivity", null);

        // 10. DVD USB Player
        setupPreference("pref_dvd", TARGET_PKG, "com.ts.dvdplayer.DvdMainActivity", null);
    }

    private void setupPreference(String prefKey, String pkg, String cls, Bundle extras) {
        Preference pref = findPreference(prefKey);
        if (pref != null) {
            pref.setOnPreferenceClickListener(preference -> {
                launchActivity(pkg, cls, extras);
                return true;
            });
        }
    }

    private void launchActivity(String pkg, String cls, Bundle extras) {
        try {
            Intent intent = new Intent();
            intent.setComponent(new ComponentName(pkg, cls));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            if (extras != null) {
                intent.putExtras(extras);
            }
            startActivity(intent);
        } catch (Exception e) {
            // If explicit component fails, try opening by package launcher
            try {
                Intent launchIntent = requireContext().getPackageManager().getLaunchIntentForPackage(pkg);
                if (launchIntent != null) {
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    startActivity(launchIntent);
                    return;
                }
            } catch (Exception ignored) {
            }
            Toast.makeText(getContext(),
                    getString(R.string.toast_launch_failed, cls),
                    Toast.LENGTH_LONG).show();
        }
    }
}
