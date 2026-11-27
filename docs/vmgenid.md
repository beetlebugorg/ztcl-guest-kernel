# The generation ID device, for the host side

A guest of this kernel reseeds its RNG and steps its wall clock when the host gives it a new generation ID. The host gives a new ID after each restore of a snapshot and to each clone. This document is the host side, by effect and wire format only.

## The command line

    vmgenid.device=SIZE@BASE:IRQ

- `SIZE`: the size of the region, at least 16 bytes. Use `4K`.
- `BASE`: the guest physical address of the region, for example `0xd0010000`. The region is outside the guest RAM, as the virtio-mmio regions are.
- `IRQ`: the interrupt line of the device, a pin of the I/O APIC (KVM, WHP) that no other device uses.

The format is the format of `virtio_mmio.device=`.

## The region

| Offset | Size | Access | Value |
|---|---|---|---|
| 0 | 16 | read | The generation ID: 16 bytes. |

The guest reads the 16 bytes at boot and after each interrupt, with ordinary loads of 1 to 8 bytes. A read of any other offset can return 0. The guest never writes the region.

## A restore or a clone

1. Before the first vCPU of the restored guest runs, write a new random 16-byte ID into the region. Each clone gets its own ID.
2. Raise the interrupt: an edge on `IRQ` (`KVM_IRQ_LINE` with level 1, then level 0).

The guest then:

- reseeds its RNG with the new ID (`add_vmfork_randomness`), so the clones of one snapshot do not share random state;
- on x86 KVM, steps `CLOCK_REALTIME` to the time of the host with the hypercall `KVM_HC_CLOCK_PAIRING`. KVM answers it in the kernel when the clocksource of the host is the TSC. A host without it (WHP) gets no clock step, and the agent sets the clock (the RESUME request).

The guest does nothing when the ID did not change. `CLOCK_MONOTONIC` and `CLOCK_BOOTTIME` do not jump.
