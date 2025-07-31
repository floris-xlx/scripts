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

What i think might be the golden post here is:

- Download Intel Extreme Tuning Utility (currently im using 7.14.2.45 - intel(R) Core(TM) i9400K)
- Go to `Advanced Tuning`
- Some modal will popup blablal overclocking dangers blalabala, just click yes
- Middle left of `Advanced Tuning` you'll see something along the lines of `Performance Per-Core Tuning`

- In the middle it will say selected core which will probably default to `Performance Core 0`
- Look for the field called `Ratio Multiplier`, Mine was set to `X60`, i've set that to `X57` and applied

  - SO far so good
