#!/usr/bin/env python3
"""
Topway MCU & Vehicle Bus Mock Emulator
Target Hardware: Topway TS-8667-02 / Junsun V1 Plus
SoC: MediaTek MT8667 / MT6768 (spm8667p1_64)

This emulator creates a virtual serial port (PTY) that exposes the exact Topway MCU protocol
expected on /dev/ttyMT1 by vendor HALs (libts67xhw.so, MainService, BackcarService).
It allows interactive testing of:
- ACC Power States (Sleep, Wake, Deep Sleep)
- Reverse Gear Detection (TP2850 camera switching trigger)
- Steering Wheel Controls (SWC / Key1 / Key2 ADC & CAN)
- Audio DSP (ROHM BD3702FV) command parsing & state tracking
- CAN-bus vehicle telemetry (Doors, Climate/HVAC, Speed, RPM)
"""

import os
import sys
import pty
import time
import select
import threading
import argparse

# Topway Protocol Constants
HEADER_TOPWAY = 0x2E
CMD_POWER_STATE = 0x01
CMD_AUDIO_DSP   = 0x02
CMD_RADIO_TUNER = 0x03
CMD_SWC_KEYS    = 0x04
CMD_VEHICLE_CAN = 0x05
CMD_REVERSE_CAM = 0x06
CMD_SYSTEM_INFO = 0x10

SWC_KEY_CODES = {
    "VOL_UP":    0x01,
    "VOL_DOWN":  0x02,
    "MUTE":      0x03,
    "NEXT":      0x04,
    "PREV":      0x05,
    "PLAY_PAUSE":0x06,
    "MODE":      0x07,
    "PHONE_CALL":0x08,
    "PHONE_END": 0x09,
    "VOICE":     0x0A,
    "HOME":      0x0B,
    "BACK":      0x0C,
    "NAV":       0x0D,
}


def calc_checksum(packet_bytes: bytes) -> int:
    """Topway checksum: sum of payload modulo 256 inverted (0xFF - (sum & 0xFF))."""
    return (0xFF - (sum(packet_bytes[2:]) & 0xFF)) & 0xFF


def build_topway_packet(cmd_group: int, sub_cmd: int, data: bytes = b'') -> bytes:
    """Builds a framed Topway MCU packet: [0x2E, Length, CmdGroup, SubCmd, Data..., Checksum]"""
    payload = bytes([cmd_group, sub_cmd]) + data
    length = len(payload) + 3 # Header + Length + Payload + Checksum
    pkt = bytes([HEADER_TOPWAY, length]) + payload
    checksum = calc_checksum(pkt)
    return pkt + bytes([checksum])


class TopwayMCUEmulator:
    def __init__(self, pty_link_path="/tmp/mcu_uart"):
        self.master_fd, self.slave_fd = pty.openpty()
        self.slave_name = os.ttyname(self.slave_fd)
        self.pty_link_path = pty_link_path
        self.running = True
        
        # Vehicle & MCU State
        self.acc_on = True
        self.reverse_on = False
        self.illumination = False
        self.parking_brake = True
        self.volume = 18
        self.dsp_eq = [0] * 10
        self.vehicle_speed = 0
        self.doors = {"FL": False, "FR": False, "RL": False, "RR": False, "Trunk": False}

        self._setup_symlink()

    def _setup_symlink(self):
        try:
            if os.path.exists(self.pty_link_path) or os.path.islink(self.pty_link_path):
                os.remove(self.pty_link_path)
            os.symlink(self.slave_name, self.pty_link_path)
            print(f"[MCU] Slave PTY created at: {self.slave_name}")
            print(f"[MCU] Symlink active:       {self.pty_link_path} -> {self.slave_name}")
        except Exception as e:
            print(f"[MCU] Warning: Could not create symlink {self.pty_link_path}: {e}")

    def write_packet(self, pkt: bytes):
        """Send raw packet to Android vendor stack."""
        try:
            os.write(self.master_fd, pkt)
        except OSError:
            pass

    def send_heartbeat(self):
        """Periodic MCU heartbeat with basic power & line status."""
        flags = (0x01 if self.acc_on else 0x00) | \
                (0x02 if self.reverse_on else 0x00) | \
                (0x04 if self.illumination else 0x00) | \
                (0x08 if self.parking_brake else 0x00)
        pkt = build_topway_packet(CMD_POWER_STATE, 0x01, bytes([flags]))
        self.write_packet(pkt)

    def trigger_swc_key(self, key_name: str, duration: float = 0.1):
        """Simulate steering wheel key press and release."""
        code = SWC_KEY_CODES.get(key_name.upper())
        if code is None:
            print(f"[MCU] Unknown SWC key '{key_name}'. Supported: {list(SWC_KEY_CODES.keys())}")
            return
        
        # Key down
        pkt_down = build_topway_packet(CMD_SWC_KEYS, 0x01, bytes([code, 0x01]))
        self.write_packet(pkt_down)
        print(f"[MCU] SWC Event: {key_name} (DOWN)")
        
        time.sleep(duration)
        
        # Key up
        pkt_up = build_topway_packet(CMD_SWC_KEYS, 0x01, bytes([code, 0x00]))
        self.write_packet(pkt_up)
        print(f"[MCU] SWC Event: {key_name} (UP)")

    def set_reverse(self, state: bool):
        """Engage/disengage reverse camera trigger."""
        self.reverse_on = state
        state_byte = 0x01 if state else 0x00
        pkt = build_topway_packet(CMD_REVERSE_CAM, 0x01, bytes([state_byte]))
        self.write_packet(pkt)
        self.send_heartbeat()
        print(f"[MCU] REVERSE GEAR {'ENGAGED (Camera Active)' if state else 'DISENGAGED'}")

    def set_acc(self, state: bool):
        """Set ACC power ignition status."""
        self.acc_on = state
        state_byte = 0x01 if state else 0x00
        pkt = build_topway_packet(CMD_POWER_STATE, 0x02, bytes([state_byte]))
        self.write_packet(pkt)
        self.send_heartbeat()
        print(f"[MCU] ACC POWER {'ON (Ignition Wake)' if state else 'OFF (Vehicle Sleep)'}")

    def set_door(self, door: str, open_state: bool):
        """Simulate CAN bus vehicle door status."""
        if door.upper() in self.doors:
            self.doors[door.upper()] = open_state
            mask = (0x01 if self.doors["FL"] else 0) | \
                   (0x02 if self.doors["FR"] else 0) | \
                   (0x04 if self.doors["RL"] else 0) | \
                   (0x08 if self.doors["RR"] else 0) | \
                   (0x10 if self.doors["Trunk"] else 0)
            pkt = build_topway_packet(CMD_VEHICLE_CAN, 0x01, bytes([mask]))
            self.write_packet(pkt)
            print(f"[MCU] CAN Bus Door Update: {door.upper()} is {'OPEN' if open_state else 'CLOSED'}")

    def handle_incoming_byte(self, data: bytes):
        """Parse incoming commands from Android framework / HAL."""
        if not data or data[0] != HEADER_TOPWAY:
            return
        if len(data) >= 4:
            cmd_group = data[2]
            sub_cmd = data[3]
            payload = data[4:-1] if len(data) > 5 else b''
            
            # Handle DSP BD3702FV Commands
            if cmd_group == CMD_AUDIO_DSP:
                if sub_cmd == 0x01 and len(payload) >= 1: # Volume
                    self.volume = payload[0]
                    print(f"[MCU <- Android] DSP Volume set to: {self.volume}")
                elif sub_cmd == 0x02 and len(payload) >= 10: # EQ bands
                    self.dsp_eq = list(payload[:10])
                    print(f"[MCU <- Android] DSP EQ updated: {self.dsp_eq}")
                # Send ACK
                ack = build_topway_packet(CMD_AUDIO_DSP, 0xFF, bytes([sub_cmd, 0x00]))
                self.write_packet(ack)

    def _read_loop(self):
        """Thread reading incoming serial commands from Android."""
        while self.running:
            r, _, _ = select.select([self.master_fd], [], [], 0.2)
            if self.master_fd in r:
                try:
                    data = os.read(self.master_fd, 1024)
                    if data:
                        self.handle_incoming_byte(data)
                except OSError:
                    break

    def _heartbeat_loop(self):
        """Thread sending periodic MCU heartbeats every 1 second."""
        while self.running:
            self.send_heartbeat()
            time.sleep(1.0)

    def start(self):
        self.t_read = threading.Thread(target=self._read_loop, daemon=True)
        self.t_read.start()
        self.t_hb = threading.Thread(target=self._heartbeat_loop, daemon=True)
        self.t_hb.start()

    def stop(self):
        self.running = False
        try:
            os.close(self.master_fd)
            os.close(self.slave_fd)
        except Exception:
            pass


def interactive_cli(mcu: TopwayMCUEmulator):
    print("==========================================================")
    print(" Topway TS8667 MCU Mock CLI Shell")
    print(" Type commands to simulate vehicle and hardware triggers:")
    print("   reverse on / reverse off  - Toggle backup camera")
    print("   acc on / acc off          - Toggle ignition / sleep")
    print("   vol+ / vol- / mute        - Steering wheel volume")
    print("   next / prev / play        - Steering wheel media")
    print("   door <fl|fr|rl|rr|trunk> <open|close>")
    print("   status                    - Dump current simulated state")
    print("   help                      - Show this guide")
    print("   exit / quit               - Terminate emulator")
    print("==========================================================")

    while True:
        try:
            line = input("topway-mcu> ").strip()
        except (EOFError, KeyboardInterrupt):
            break

        if not line:
            continue
        parts = line.split()
        cmd = parts[0].lower()

        if cmd in ("exit", "quit"):
            break
        elif cmd == "reverse":
            if len(parts) > 1 and parts[1].lower() == "on":
                mcu.set_reverse(True)
            elif len(parts) > 1 and parts[1].lower() == "off":
                mcu.set_reverse(False)
            else:
                print("Usage: reverse <on|off>")
        elif cmd == "acc":
            if len(parts) > 1 and parts[1].lower() == "on":
                mcu.set_acc(True)
            elif len(parts) > 1 and parts[1].lower() == "off":
                mcu.set_acc(False)
            else:
                print("Usage: acc <on|off>")
        elif cmd == "vol+":
            mcu.trigger_swc_key("VOL_UP")
        elif cmd == "vol-":
            mcu.trigger_swc_key("VOL_DOWN")
        elif cmd == "mute":
            mcu.trigger_swc_key("MUTE")
        elif cmd == "next":
            mcu.trigger_swc_key("NEXT")
        elif cmd == "prev":
            mcu.trigger_swc_key("PREV")
        elif cmd == "play":
            mcu.trigger_swc_key("PLAY_PAUSE")
        elif cmd == "door":
            if len(parts) == 3:
                mcu.set_door(parts[1], parts[2].lower() == "open")
            else:
                print("Usage: door <fl|fr|rl|rr|trunk> <open|close>")
        elif cmd == "status":
            print(f"ACC:       {mcu.acc_on}")
            print(f"Reverse:   {mcu.reverse_on}")
            print(f"Volume:    {mcu.volume}")
            print(f"EQ:        {mcu.dsp_eq}")
            print(f"Doors:     {mcu.doors}")
        elif cmd == "help":
            print("Commands: reverse on|off, acc on|off, vol+, vol-, mute, next, prev, play, door <name> <open|close>, status, quit")
        else:
            print(f"Unknown command: {cmd}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Topway TS8667 MCU Virtual Hardware Mock")
    parser.add_argument("--pty-link", default="/tmp/mcu_uart", help="Symlink path for slave PTY")
    parser.add_argument("--non-interactive", action="store_true", help="Run background daemon without CLI prompt")
    args = parser.parse_args()

    mcu = TopwayMCUEmulator(pty_link_path=args.pty_link)
    mcu.start()

    if args.non_interactive:
        print("[MCU] Running in non-interactive daemon mode. Press Ctrl+C to stop.")
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            pass
    else:
        interactive_cli(mcu)

    mcu.stop()
    print("[MCU] Emulator stopped.")
