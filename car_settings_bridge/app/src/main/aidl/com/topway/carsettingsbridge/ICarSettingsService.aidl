package com.topway.carsettingsbridge;

import com.topway.carsettingsbridge.ICarSettingsCallback;

/**
 * Topway TS8667 Automotive Settings API Bridge Service.
 * Version: 1.0 (AIDL IPC Interface)
 *
 * Provides a stable, decoupled IPC bridge between Android System UI,
 * Settings applications, Car Launchers, and underlying hardware daemons.
 */
interface ICarSettingsService {
    /** Returns current API version (1) for capability discovery. */
    int getApiVersion();

    /** Read master hardware audio volume level (0 - 30). */
    int getMasterVolume();

    /** Set master hardware audio volume level (0 - 30). Returns true on success. */
    boolean setMasterVolume(int volume);

    /** Query hardware mute status. */
    boolean isMuted();

    /** Set hardware mute status. */
    boolean setMuted(boolean muted);

    /**
     * Set hardware audio source routing.
     * 0: Main SoC DAC (A_DIFF), 1: AUX In, 2: Bluetooth Handsfree, 3: Radio Tuner.
     */
    boolean setAudioSource(int source);

    /** Query vehicle headlight / illumination state (true = headlights ON). */
    boolean getIlluminationState();

    /** Query vehicle reverse gear state (true = reverse engaged). */
    boolean getReverseState();

    /** Query ignition / ACC power state (true = ACC ON). */
    boolean getAccPowerState();

    /** Read SoC MT6768 core temperature in millidegrees Celsius. */
    int getCpuTemperature();

    /** Read cooling fan speed (0 - 255 PWM duty cycle). */
    int getFanSpeed();

    /**
     * Set fan speed PWM mode.
     * @param pwmValue 0-255 manual duty cycle, or -1 for automatic temperature hysteresis.
     */
    boolean setFanSpeed(int pwmValue);

    /** Register asynchronous event listener for hardware state updates. */
    void registerCallback(ICarSettingsCallback callback);

    /** Unregister event listener. */
    void unregisterCallback(ICarSettingsCallback callback);
}
