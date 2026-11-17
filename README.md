# valetudo-helper-felroot — macOS (Apple Silicon) build

> **Disclaimer.** This macOS build is entirely vibecoded and has not been tested broadly.
> It has so far been used successfully on exactly one robot: a MOVA V50 Ultra, rooted with
> the fastboot method. Nothing else has been tested - other robot models, other robots,
> other code paths, other macOS versions. Rooting writes to your robot's flash and can
> brick it or void your warranty. Use it at your own risk.

Fork of [Hypfer/valetudo-helper-felroot](https://github.com/Hypfer/valetudo-helper-felroot)
with a **vibecoded macOS (Apple Silicon) build** added. The upstream release binaries are
static Linux executables and cannot run on macOS at all - that is not an amd64/arm64
detail, there is no macOS build to download.

Everything else is upstream's code. `src/main.c` differs by two pieces of platform
plumbing: selecting the USB device configuration explicitly, and a smaller bulk transfer
size. No binaries are published here - you build it in four commands below.

The actual rooting procedure, and which recon package your robot needs, is in the Valetudo
guide: https://valetudo.cloud/pages/installation/dreame/

## Build

```sh
git clone https://github.com/eisenbergrobin/valetudo-helper-felroot-macos.git
cd valetudo-helper-felroot
brew install libusb pkg-config
./build.sh
```

That leaves a working binary at `build/valetudo-helper-felroot-macos`. No `sudo`, no zig.

## Use

Unpack the recon package for your robot - the guide links the correct one per model, for
the MOVA V50 Ultra it is the URL below - and run the guide's commands with this binary.
These lines continue from the build above:

```sh
cd ..
curl -L -o dust-fel-recon-r2582.tar.gz https://fab.valetudo.cloud/robot/mova/r2582/fel/recon
mkdir -p dust-fel-recon-r2582
tar xzf dust-fel-recon-r2582.tar.gz -C dust-fel-recon-r2582
cp valetudo-helper-felroot/build/valetudo-helper-felroot-macos dust-fel-recon-r2582/
cd dust-fel-recon-r2582

# the package also carries valetudo-helper-felroot-amd64: that is the Linux build, ignore it
# put the robot in FEL mode first, as described in the guide
./valetudo-helper-felroot-macos boot fsbl.bin payload.bin
./valetudo-helper-felroot-macos getvar config
./valetudo-helper-felroot-macos oem stage0
./valetudo-helper-felroot-macos get_samples ./dustx100.bin
```

Then the sample/upload stage, then `oem dust <checkvalue>`, `oem prep`,
`flash <partition> <image>` and `reboot` - in the order the guide gives, with the partition
names and image files from the tarball the builder returns.

## Credits and license

All of it is upstream's work: https://github.com/Hypfer/valetudo-helper-felroot, which is
https://github.com/xboot/xfel cut down to what is needed, plus a C port of Android's
resparse logic, plus vendored libusb. Licensing of those three is in THIRD_PARTY_NOTICES.
The macOS build added here is community code and is not part of upstream.

## Notes

- Not part of upstream's release pipeline. The Linux binary is the reference implementation.
- The binary links libusb from Homebrew dynamically, so it runs on the Mac it was built
  on, not on a Mac without libusb installed.
- Up to `oem prep` / `flash` nothing is written to the robot's flash; FEL lives in the SoC
  boot ROM, so a failed attempt before that point is recoverable.
