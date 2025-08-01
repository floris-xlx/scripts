Spent a lot of time figuring out fixes but all programs started showing some form of `STATUS_ACCESS_VIOLATION`, 

im running:
64gb ddr5 6000mhz
i9-14900k
rtx-5080 inno 3d x3 16gb
1000w psu
4tb nvme nq790 ssd
Z790 AORUS MASTER (rev. 1.0)

fixes ive tried:
- replaced ram slots,
- reinstalled windows onto new drives 2x
- take out all excess drives on the nvme lanes (this motherboard can support 5)
- reinstall all programs

How to Fix;

- Download Intel Extreme Tuning Utility (currently im using 7.14.2.45 - intel(R) Core(TM) i9400K)
- Go to `Advanced Tuning`
- Some modal will popup blablal overclocking dangers blalabala, just click yes
- Middle left of `Advanced Tuning` you'll see something along the lines of `Performance Per-Core Tuning`

- In the middle it will say selected core which will probably default to `Performance Core 0`
- Look for the field called `Ratio Multiplier`, Mine was set to `X60`, i've set that to `X57` and applied

IF you have a Gigabyte z790 motherboard, ( i dont have another one so it might be different )

GO into bios
- Turn on Advanced bios view on the top right
- Disable `Enhanced Multi-Core Performance`
- Enable `XMP Profile 1` (only if you can)
- `Intel Default Settings`: `EXTREME` -> `DISABLED`
- `Performance CPU Clock Ratio`: `AUTO` -> `57`
- `Turbo Power Limits`: `AUTO` -> `ENABLED`

After enabling `Turbo Power Limits` you'll get more settings:
- `Package Power Limit1 - TDP (watts)`: `AUTO` -> `253`
- `Package Power Limit1 Time`: `AUTO` -> `56`
- `Package Power Limit2 (watts)`: `AUTO` -> `253`
- `Core Current Limit (amps)`: `AUTO` -> `307`
