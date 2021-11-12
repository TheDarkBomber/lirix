![Lirix, get fully MaXXinated.](https://repository-images.githubusercontent.com/381812569/d49f0cb2-55b7-4a40-b595-e2bd29da2777)
# Table of Contents

1.  [Installation](#org6c3af4f)
    1.  [Acquiration](#orga12d4df)
    2.  [EZInstall](#orgb65afd1)

Lirix is an XFree86/Linux distribution based upon [Arch Linux](<https://archlinux.org>) that ships with the [MaXX Interactive Desktop](<https://maxxinteractive.com>).


<a id="org6c3af4f"></a>

# Installation


<a id="orga12d4df"></a>

## Acquiration

An ISO for Lirix can be found at [Lirix ISO](<https://caesar-rylan.60.nu/lirix/iso>). The current release era of Lirix is Mellifera.


<a id="orgb65afd1"></a>

## EZInstall

This installation guide assumes you know how to boot off an ISO.
After booting the ISO, you should find one of two screens:

-   A plain black and white screen that asks you which option you want. This is the screen used by [systemd-boot](<https://wiki.archlinux.org/title/Systemd-boot>), an inferior bootloader which requires manual configuration which the Arch ISO uses by default, which I have not yet found a way to change for EFI systems.
    Essentially, this means you are using EFI mode. If you were expecting LegacyBIOS mode, contact your motherboard manufacturer/prebuilt system seller if you have specifically requested LegacyBIOS and not EFI as you may be unsatisifed.
-   A nice screen with a branded « Lirix - get fully maxxinated » logo and apiochromic background. This is the screen used by [syslinux](<https://wiki.archlinux.org/title/Syslinux>), an archaic and old bootloader that is leagues better than systemd-boot.
    Essentially, this means you are using LegacyBIOS mode, check something in your firmware I guess if you were expecting EFI mode. Or do that contacting manufacturer thing, whichever works.

Select the first option if you wish to install Lirix. There are other options that may work and some that definitely won't.

This will present you with a language selection screen. This will also set your locale for the installation. Also, some languages may appear broken æsthetically. This is expected, there is no way to have a font that supports any character set with more than 512 characters in TTY.

For a quick installation, pressing ENTER after this point for every option presented to you will put you into a working installation. By the end of it you'll be using the bootloader, GRUB, a modern bootloader, well not even modern but it's keeping up with the changing technologies in a mutatis mutandis way which counts as modern, that has automatic configuration and is very pleasant, especially for me, the creator of the distribution.

And from there, EZInstall should guide you. Fun fact: EZInstall is named after EZsetup, the Out-of-Box Experience equivalent (though not exactly like an OOBE) for IRIX. Note that Lirix does not have an OOBE.

