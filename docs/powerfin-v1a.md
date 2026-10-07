# PowerFin V1A Baseline

This document records **observed** V1A board behavior separately from planned work.

## Observed board

- Board marking: `POWERFIN V1A`
- USB RNDIS interface enumerates successfully on the development host.
- Host address observed: `192.168.123.2/24`
- Board address observed: `192.168.123.100`
- ICMP ping to the board: successful, sub-millisecond on the USB link.
- PFC/Recovery HTTP service on TCP `8080`: reachable.
- TCP `22`: not listening in the observed Recovery environment.
- PFC reports:
  - `RK3506G PowerFin RAM boot`
  - platform `powerfin-rk3506`
  - Linux kernel `6.1.99`
  - DT compatible `rockchip,rk3506g-powerfin`
- With no SD card present, the observed UI is Recovery-oriented and exposes kernel/SD recovery operations.

## Preserve before modification

Before changing NOR, SD, boot images, kernel, or root filesystem, capture:

- cold UART0 boot log
- U-Boot environment
- partition layout
- NOR image and SHA256
- SD image and SHA256 when an SD baseline is available
- DTB/kernel/image versions

## Open checks

- Confirm the complete cold boot chain from SPL through Recovery using UART0.
- Confirm UART electrical level before connection; use `1500000` baud as the first value to test based on the current PowerFin engineering notes.
- Verify whether observed USB MAC addresses are stable across cold boots.
- Record exact factory image provenance before the first write operation.
