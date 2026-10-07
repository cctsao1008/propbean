# PropBean Architecture

## Ownership

```text
PropBean
├─ external/ardupilot
│  └─ cctsao1008/ardupilot @ exact commit
├─ firmware
│  └─ PropBean-owned target software
├─ hardware
│  └─ PropBean-owned hardware definitions/designs
├─ examples
│  └─ minimal runnable references
├─ tools
│  └─ host-side tooling
├─ docs
│  └─ verified architecture/platform knowledge
└─ third_party/powerfin-sdk
   └─ Android repo-managed PowerFin SDK workspace
      ├─ Linux kernel
      ├─ Buildroot
      └─ U-Boot
```

## ArduPilot branch policy

```text
cctsao1008/ardupilot

master
  upstream tracking only

propbean
  long-lived PropBean / PowerFin integration branch

propbean/*
  optional bounded feature branches
```

The PropBean superproject pins `external/ardupilot` to an exact commit SHA.

## Platform boundary

ArduPilot should use normal Linux-facing interfaces wherever possible. RK3506 register-level work, interrupt handling, DMA, FlexBUS implementation, and other SoC-specific mechanisms belong in the Linux/BSP layer unless measurement proves a different split is necessary.

Fork individual PowerFin SDK components only when a real modification is required. Do not fork or mirror components merely for completeness.
