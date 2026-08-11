#!/usr/bin/env python3.14
import struct
import os
import sys
import glob
import subprocess
from pathlib import Path

fp = None

def patch(offset, data):
    file_offset = offset
    
    if isinstance(data, int):
        data = struct.pack('<I', data)
    if isinstance(data, str):
        data = data.encode()

    fp.seek(file_offset)
    fp.write(data)
    fp.flush()

def remote_cmd(my_command):
     os.system(f"./sshpass -p 'alpine' ssh -ostricthostkeychecking=false -ouserknownhostsfile=/dev/null -o StrictHostKeyChecking=no -q -p22222 root@localhost {my_command}")

def check_remote_file_exists(remote_path):
    status = os.system(f"./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q -p 22222 root@localhost 'test -f {remote_path}'")
    return status == 0

def get_bootManifestHash():
    cmd = "./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -q -p 22222 root@localhost '/bin/ls /mnt6'"
    output = subprocess.getoutput(cmd).split()
    
    return next((f for f in output if len(f) == 96), None)

# Patch iBSS
if not os.path.exists("iBSS.boot.bak"):
    os.system("cp iBSS.boot iBSS.boot.bak")

os.system("cp iBSS.boot.bak iBSS.boot")

fp = open("iBSS.boot", "r+b")

# rename "RELEASE" build to "PATCHED"
patch(0x240, "PATCHED")

# patch boot-args with "serial=3 -v %s"
patch(0x2C0D0, 0xB0000045);  # adrp x5, #0x35000
patch(0x2C0D4, 0x910860A5);  # add  x5, x5, #0x
patch(0x35218, "serial=3 -v %s");

# make possible load edited rootfs (needed to command snaputil -n later)
patch(0x63304, 0x1400002B)
patch(0x62F0C, 0xD503201F)
patch(0x6338C, 0x17FFFF31)
patch(0x67640, 0xD503201F)
patch(0x67844, 0x14000009)
'''
| vphone_llb | iBSS.boot.bak | iBSS Original Instruction | Changed with |
|---:|---:|---|---|
| `0x2BFE8` | `0x63304` | `cbz w0, 0x633B0` | `b 0x633B0` |
| `0x2BCA0` | `0x62F0C` | `b.hs 0x63080` | `nop` |
| `0x2C03C` | `0x6338C` | `cbz w0, 0x63050` | `b 0x63050` |
| `0x2FCEC` | `0x67640` | `cbz x8, 0x67740` | `nop` |
| `0x2FEE8` | `0x67844` | `cbz w0, 0x67868` | `b 0x67868` |
'''
fp.close()


# mount preboot to patch kernel
remote_cmd("/sbin/mount_apfs -o rw /dev/disk1s6 /mnt6")
bootManifestHash = get_bootManifestHash()

# ========= grab apticket.der =========
apticket_der_path = f"/mnt6/{bootManifestHash}/System/Library/Caches/apticket.der"
os.system(f"./sshpass -p 'alpine' scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P 22222 root@127.0.0.1:{apticket_der_path} .")

# ========= Backup kernelcache =======
kc_path = f"/mnt6/{bootManifestHash}/System/Library/Caches/com.apple.kernelcaches/kernelcache"
kc_path_bak = f"/mnt6/{bootManifestHash}/System/Library/Caches/com.apple.kernelcaches/kernelcache.bak"
if not check_remote_file_exists(kc_path_bak): 
     print(f"Created backup {kc_path_bak}")
     remote_cmd(f"/bin/cp {kc_path} {kc_path_bak}")

# ========= Grab kernelcache =========
os.system(f"./sshpass -p 'alpine' scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P 22222 root@127.0.0.1:{kc_path_bak} .")

# ========= Convert/Patch kernelcache"
os.system(f"pyimg4 img4 extract -i kernelcache.bak -p kernelcache.im4p")
os.system(f"./img4tool -e -o kernelcache.raw kernelcache.im4p")
fp = open("kernelcache.raw", "r+b")

# rename "RELEASE" build to "PATCHED"
patch(0x389BF, "PATCHED")
patch(0x38A25, "PATCHED")

# prevent panic 
# panic(cpu 0 caller 0xfffffff01a65bdac): "Failed to find the root snapshot: No error. (0). Rooting from the live fs of a sealed volume is not allowed on a RELEASE build\n" @apfs_vfsops.c:2269
patch(0x229fD50, 0xD503201F)

# AMFI: '/usr/libexec/mobileactivationd' has no CMS blob?
# AMFI: '/usr/libexec/mobileactivationd': Unrecoverable CT signature issue, bailing out.
# AMFI: code signature validation failed.
# patch(0xb301f0, 0xD2802020)     # mov x0, #0x101
# patch(0xb301f4, 0xD65F03C0)     # ret
# patch(0x1470414, 0x320003E0)  # mov w0, #1
# patch(0x1470418, 0xD65F03C0)  # ret

fp.close()

# os.system(f"./img4tool -c kernelcache.im4p -t krnl -d 'KernelCacheBuilder_release-2238.120.2' kernelcache.raw")
os.system("pyimg4 im4p create -i kernelcache.raw -o kernelcache.im4p -f krnl -d KernelCacheBuilder_release-2238.120.2 --lzss")
os.system("pyimg4 img4 create -p kernelcache.im4p -o kernelcache.img4 -m apticket.der")

# ========= apply patched kernelcache =========
# send to apply
# fix owner, permissions
os.system(f"./sshpass -p 'alpine' scp -q -r -ostricthostkeychecking=false -ouserknownhostsfile=/dev/null -o StrictHostKeyChecking=no -P 22222 kernelcache.img4 'root@127.0.0.1:{kc_path}'")
remote_cmd(f"/bin/chmod 0644 {kc_path}")
remote_cmd(f"/usr/sbin/chown 0:0 {kc_path}")


# mount rootfs to patch mobileactivationd
remote_cmd("/sbin/mount_apfs -o rw /dev/disk1s1 /mnt1")
# backup mobileactivationd before patch
file_path = "/mnt1/usr/libexec/mobileactivationd.bak"
if not check_remote_file_exists(file_path): 
     print(f"Created backup {file_path}")
     remote_cmd("/bin/cp /mnt1/usr/libexec/mobileactivationd /mnt1/usr/libexec/mobileactivationd.bak")
# grab mobileactivationd
os.system("./sshpass -p 'alpine' scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P 22222 root@127.0.0.1:/mnt1/usr/libexec/mobileactivationd.bak .")
# hackivation patch; always return true from bool __cdecl -[DeviceType should_hactivate]
fp = open("mobileactivationd.bak", "r+b")
patch(0x14810, 0xD2800020) #mov x0, #1
fp.close()
os.system("mv mobileactivationd.bak mobileactivationd")
# sign
os.system("./ldid_macosx_arm64 -S -M -Cadhoc mobileactivationd")
# os.system("./fastPathSign mobileactivationd")
# send to apply
os.system("./sshpass -p 'alpine' scp -q -r -ostricthostkeychecking=false -ouserknownhostsfile=/dev/null -o StrictHostKeyChecking=no -P 22222 mobileactivationd 'root@127.0.0.1:/mnt1/usr/libexec/mobileactivationd'")
remote_cmd("/bin/chmod 0755 /mnt1/usr/libexec/mobileactivationd")

# ========= Backup trustcache =======
tc_path = f"/mnt6/{bootManifestHash}/usr/standalone/firmware/FUD/StaticTrustCache.img4"
tc_path_bak = f"/mnt6/{bootManifestHash}/usr/standalone/firmware/FUD/StaticTrustCache.img4.bak"
if not check_remote_file_exists(tc_path_bak): 
     print(f"Created backup {tc_path_bak}")
     remote_cmd(f"/bin/cp {tc_path} {tc_path_bak}")

# ========= Grab trustcache =========
os.system(f"./sshpass -p 'alpine' scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P 22222 root@127.0.0.1:{tc_path_bak} .")
os.system(f"pyimg4 img4 extract -i ./StaticTrustCache.img4.bak -p ./StaticTrustCache.im4p")
os.system(f"./img4tool -e -o StaticTrustCache.raw StaticTrustCache.im4p")

# ========= Append trustcache for patched launchd, mobileactivationd ========== 
os.system(f"./trustcache_macos_arm64 append ./StaticTrustCache.raw ./mobileactivationd")

# ========= Convert ===========
os.system("pyimg4 im4p create -i StaticTrustCache.raw -o StaticTrustCache.im4p -f trst")
os.system("pyimg4 img4 create -p StaticTrustCache.im4p -o StaticTrustCache.img4 -m apticket.der")

# ========= Send to apply ==========
os.system(f"./sshpass -p 'alpine' scp -q -r -ostricthostkeychecking=false -ouserknownhostsfile=/dev/null -o StrictHostKeyChecking=no -P 22222 StaticTrustCache.img4 'root@127.0.0.1:{tc_path}'")
remote_cmd(f"/bin/chmod 0644 {tc_path}")
remote_cmd(f"/usr/sbin/chown 0:0 {tc_path}")

# localhost:/mnt1/Applications/AppStore.app root# chown root:admin PersistenceHelper_Embedded 
# localhost:/mnt1/Applications/AppStore.app root# chmod 0755 ./PersistenceHelper_Embedded 
# mv PersistenceHelper_Embedded  AppStore

# clean
# os.system(f"rm kernelcache.bak kernelcache apticket.der mobileactivationd kernelcache.raw kernelcache.img4 kernelcache.im4p")
