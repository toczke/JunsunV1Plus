package com.topway.carsettingsbridge;

/**
 * Asynchronous callback interface for vehicle state changes.
 */
oneway interface ICarSettingsCallback {
    /** Dispatched when vehicle illumination / headlights state changes. */
    void onIlluminationChanged(boolean headlightsOn);

    /** Dispatched when vehicle reverse gear is engaged or disengaged. */
    void onReverseGearChanged(boolean reverseEngaged);

    /** Dispatched when ignition / ACC power state changes. */
    void onAccPowerChanged(boolean accOn);

    /** Dispatched when steering wheel key event is processed. */
    void onSteeringWheelKeyEvent(int linuxKeyCode, int action);

    /** Dispatched when volume or mute state changes. */
    void onVolumeChanged(int newVolume, boolean isMuted);
}
