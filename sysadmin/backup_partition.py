#!/usr/bin/env python3
"""
Back up a partition to another partition, which should have a
different UUID. Includes special support for root partitions which
includes updating the fstab and grub.cfg files and rebuilding initrd,
so that the other partition will be independently bootable (we hope).
"""

import argparse
import contextlib
from dataclasses import dataclass
from datetime import datetime
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import threading
import time
import io
from typing import Callable, NoReturn

try:
    from typing import Self
except ImportError:
    from typing_extensions import Self


MOUNT_ROOT = "/media"
MOUNT_PREFIX = f"{MOUNT_ROOT}/backup"


def run_cmd(
    cmd: list[str],
    *,
    dry_run: bool = False,
    capture_output: bool = False,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    """Run a command with optional dry-run mode."""
    if dry_run:
        print(f"\033[90m    WOULD run: {" ".join(cmd)}\033[0m", file=sys.stderr)
        return subprocess.CompletedProcess(args=cmd, returncode=0, stdout="", stderr="")

    if capture_output:
        return subprocess.run(cmd, capture_output=True, check=check, text=True)

    # Stream output with coloring, don't collect it
    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=False,  # to preserve '\r' where needed
    )

    def colorize_and_indent(stream: io.BufferedIOBase, color: str) -> None:
        indent = "    "
        reset = "\033[0m"
        buffer = b""
        keep_going = True
        while keep_going:
            chunk = stream.read(4096)
            if chunk:
                buffer += chunk
            else:
                keep_going = False
            lines = re.split(rb"(?<=[\n\r])", buffer)
            buffer = lines.pop()  # last line isn't complete
            for line in lines:
                text = line.decode("utf-8", errors="replace")
                print(
                    f"{indent}{color}{text}{reset}", end="", file=sys.stdout, flush=True
                )
        if buffer:
            text = buffer.decode("utf-8", errors="replace")
            print(f"{indent}{color}{text}{reset}", end="", file=sys.stdout)

    stdout_thread = threading.Thread(
        target=colorize_and_indent, args=(process.stdout, "\033[33m")
    )
    stderr_thread = threading.Thread(
        target=colorize_and_indent, args=(process.stderr, "\033[31m")
    )
    stdout_thread.start()
    stderr_thread.start()
    exit_code = process.wait()
    stdout_thread.join()
    stderr_thread.join()

    if check and exit_code != 0:
        raise subprocess.CalledProcessError(exit_code, cmd)
    return subprocess.CompletedProcess(
        args=cmd, returncode=exit_code, stdout="", stderr=""
    )


# ------------------------------------------------------------


class ElapsedTimer:
    """Timer for measuring elapsed time"""

    def __init__(self):
        self.start_time: float = time.time()

    def __str__(self) -> str:
        return self.elapsed()

    def elapsed(self) -> str:
        """Get the elapsed time since the timer was started"""
        end_time = time.time()
        delta = int(end_time - self.start_time)
        if delta >= 3600:
            return f"{delta // 3600:02d}:{(delta // 60) % 60:02d}:{delta % 60:02d}"
        else:
            return f"{delta // 60:02d}:{delta % 60:02d}"


# ------------------------------------------------------------


@dataclass(frozen=True)
class MountInfo:
    """Information about a mounted device"""

    device: str
    mountpoint: str


class FailedMountError(RuntimeError):
    """Raised when mounting a device fails"""


class FailedUnmountError(RuntimeError):
    """Raised when unmounting a device fails"""


class TemporaryMount:
    """An object corresponding to a temporarily mounted device"""

    def __init__(
        self,
        mount_info: MountInfo,
        *,
        msg_mounting: str | None = None,
        msg_unmounting: str | None = None,
        mount_options: list[str] | None = None,
        unmount_options: list[str] | None = None,
        verbose: bool = True,
        dry_run: bool = False,
    ):
        self._mount_info = mount_info
        self._msg_mounting = msg_mounting or "Mounting device"
        self._msg_unmounting = msg_unmounting or "Unmounting device"
        self.__mount_options = mount_options or []
        self.__unmount_options = unmount_options or []
        self.__verbose = verbose
        self.__dry_run = dry_run
        self.__dir_created: bool = False
        self.__mounted_here: bool = False

    @property
    def mount_info(self) -> MountInfo:
        """Get the underlying MountInfo object"""
        return self._mount_info

    @property
    def dir_created(self) -> bool:
        """Whether the mountpoint directory was created by this object"""
        return self.__dir_created

    @property
    def mounted_here(self) -> bool:
        """Whether the device is currently mounted"""
        return self.__mounted_here

    def __del__(self):
        """On destruction, unmount the device if still mounted as a fallback"""
        self.unmount()

    def __enter__(self) -> Self:
        """Enter context manager - mounts the device"""
        self.mount()
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc_val: BaseException | None,
        exc_tb: object | None,
    ) -> None:
        """Exit context manager - unmounts the device"""
        self.unmount()

    def __repr__(self) -> str:
        return f"{self.__class__.__name__}(" f"mount_info={self._mount_info!r}, ...)"

    def mount(self) -> None:
        """Mount a device"""
        if self.__mounted_here:
            return

        device = self._mount_info.device
        mountpoint = self._mount_info.mountpoint

        if self.__verbose:
            print(f"\033[34m({self._msg_mounting} {device!r} on {mountpoint!r})\033[0m")
        if not os.path.exists(mountpoint) and not self.__dry_run:
            os.makedirs(mountpoint)
            self.__dir_created = True
        try:
            run_cmd(
                ["mount", *self.__mount_options, device, mountpoint],
                dry_run=self.__dry_run,
            )
            self.__mounted_here = True
        except subprocess.CalledProcessError as exc:
            raise FailedMountError(
                f"Failed to mount {device!r} on {mountpoint!r}"
            ) from exc

    def unmount(self) -> None:
        """Unmount the device"""
        if not self.__mounted_here:
            return

        device = self._mount_info.device
        mountpoint = self._mount_info.mountpoint

        if self.__verbose:
            print(
                f"\033[34m({self._msg_unmounting} {device!r}"
                f" from {mountpoint!r})\033[0m"
            )
        try:
            run_cmd(
                ["umount", *self.__unmount_options, mountpoint],
                dry_run=self.__dry_run,
            )
            self.__mounted_here = False
        except subprocess.CalledProcessError as exc:
            raise FailedUnmountError(
                f"Failed to unmount {device!r} from {mountpoint!r}"
            ) from exc
        finally:
            if self.__dir_created:
                try:
                    os.rmdir(mountpoint)
                except OSError:
                    pass


class TemporaryBindMount(TemporaryMount):
    """An object corresponding to a temporary bind mount"""

    def __init__(
        self,
        source_path: str,
        mountpoint: str,
        *,
        mount_options: list[str] | None = None,
        unmount_options: list[str] | None = None,
        verbose: bool = True,
        dry_run: bool = False,
    ):
        mount_options = mount_options or []
        super().__init__(
            mount_info=MountInfo(device=source_path, mountpoint=mountpoint),
            msg_mounting="Bind-mounting directory",
            msg_unmounting="Unmounting bind-mounted directory",
            mount_options=["--bind", *mount_options],
            unmount_options=unmount_options,
            verbose=verbose,
            dry_run=dry_run,
        )


# ------------------------------------------------------------


class MissingMountError(ValueError):
    """Raised when the specified device is not mounted, or
    no device is mounted on a specified mountpoint"""


def get_mounted_devices(*, even_fake_devices: bool = False) -> list[MountInfo]:
    """Read the list of mounted devices in the system"""
    result = run_cmd(["mount"], capture_output=True, check=False)
    devices: list[MountInfo] = []

    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 3 and parts[1] == "on":
            dev = parts[0]
            mount = parts[2]
            if dev.startswith("/"):
                try:
                    real_dev = os.path.realpath(dev)
                    devices.append(MountInfo(device=real_dev, mountpoint=mount))
                except OSError:
                    continue  # do nothing if the device cannot be resolved
            elif even_fake_devices:
                devices.append(MountInfo(device=dev, mountpoint=mount))

    return devices


def get_matching_mounted_devices(
    *,
    device: str | None = None,
    mountpoint: str | None = None,
    ignore_missing: bool = False,
) -> list[MountInfo]:
    """Get a list of mounted devices, possibly filtered by device or mountpoint"""
    all_mounts = get_mounted_devices()

    if device is not None:
        try:
            real_dev = os.path.realpath(device)
        except OSError as exc:
            if ignore_missing:
                return []
            raise MissingMountError(f"Device {device!r} does not exist!") from exc

        all_mounts = [dev for dev in all_mounts if dev.device == real_dev]

    if mountpoint is not None:
        all_mounts = [dev for dev in all_mounts if dev.mountpoint == mountpoint]

    return all_mounts


def is_mounted(*, device: str | None = None, mountpoint: str | None = None) -> bool:
    """Check if a device is mounted on a mountpoint"""
    if device is None and mountpoint is None:
        raise ValueError("Must specify device or mountpoint or both")
    try:
        matched_dev_objects = get_matching_mounted_devices(
            device=device, mountpoint=mountpoint, ignore_missing=False
        )
        return len(matched_dev_objects) > 0
    except MissingMountError:
        return False


def get_mount_from_mountpoint(
    mountpoint: str,
    ignore_filter: Callable[[MountInfo], bool] | None = None,
) -> MountInfo:
    """Given a mountpoint, find the MountInfo of the mounted device"""

    matched_dev_objects = get_matching_mounted_devices(
        mountpoint=mountpoint, ignore_missing=False
    )
    if ignore_filter is None:
        infos = matched_dev_objects
        desc_mount = "mount"
    else:
        infos: list[MountInfo] = []
        for dev in matched_dev_objects:
            if ignore_filter(dev):
                print(
                    f"\033[33mNotice: Ignoring {dev.device!r} for {mountpoint!r}...\033[0m",
                    file=sys.stderr,
                )
            else:
                infos.append(dev)
        desc_mount = "relevant mount"
    if len(infos) >= 1:
        if len(infos) > 1:
            ignored_devices = ", ".join([repr(dev.device) for dev in infos[1:]])
            print(
                f"\033[93mWarning: Path {mountpoint!r} has more than one {desc_mount}?! "
                f"(will use {infos[0].device!r} and ignore {ignored_devices})\033[0m",
                file=sys.stderr,
            )
        return infos[0]
    if len(matched_dev_objects) >= 1:
        desc_device = "relevant device"  # some exist but are ignored
    else:
        desc_device = "device"  # none exist
    raise MissingMountError(
        f"No {desc_device} is mounted on mountpoint {mountpoint!r}."
    )


def get_mount_from_device(
    device: str,
    ignore_filter: Callable[[MountInfo], bool] | None = None,
) -> MountInfo:
    """Given a device, find its MountInfo"""

    matched_dev_objects = get_matching_mounted_devices(
        device=device, ignore_missing=False
    )
    if ignore_filter is None:
        infos = matched_dev_objects
        desc_mount = "mount"
    else:
        infos: list[MountInfo] = []
        for dev in matched_dev_objects:
            if ignore_filter(dev):
                print(
                    f"\033[33mNotice: Ignoring {dev.mountpoint!r} for {device!r}...\033[0m",
                    file=sys.stderr,
                )
            else:
                infos.append(dev)
        desc_mount = "relevant mount"
    if len(infos) >= 1:
        if len(infos) > 1:
            ignored_mountpoints = ", ".join([repr(dev.mountpoint) for dev in infos[1:]])
            print(
                f"\033[93mWarning: Device {device!r} has more than one {desc_mount}?! "
                f"(will use {infos[0].mountpoint!r} and ignore {ignored_mountpoints})\033[0m",
                file=sys.stderr,
            )
        return infos[0]
    if len(matched_dev_objects) >= 1:
        desc_mounts = "relevant mounts"  # some exist but are ignored
    else:
        desc_mounts = "mounts"  # none exist
    raise MissingMountError(f"Device {device!r} has no {desc_mounts}.")


# ------------------------------------------------------------


class InvalidMountError(ValueError):
    """Raised when the specified device doesn't exist or is already mounted, or the
    specified mountpoint is already in use, or the device information is inconsistent"""


class Device:
    """Represents a block device with its path, mountpoint, and UUID"""

    def __init__(
        self,
        spec: str | None = None,
        *,
        device: str | None = None,
        mountpoint: str | None = None,
        uuid: str | None = None,
        fallback_name: str | None = None,
        verbose: bool = True,
        dry_run: bool = False,
    ):
        if spec is not None:
            spec_device = self._get_device_from_spec(spec)
            if device is None:
                device = spec_device
            elif spec_device != device:
                raise InvalidMountError(
                    f"Provided spec {spec!r} does not match"
                    f" provided device {device!r}"
                )

        if mountpoint is not None:
            if device is None:
                device = self._get_mount_from_mountpoint(mountpoint).device
            else:
                if not self._is_mounted(device=device, mountpoint=mountpoint):
                    raise InvalidMountError(
                        f"Selected device {device!r} is not mounted on"
                        f" provided mountpoint {mountpoint!r}"
                    )

        if uuid is not None:
            if device is None:
                device = self._get_device_from_named_value("UUID", uuid)
            else:
                device_uuid = self._get_named_value_from_device("UUID", device)
                if device_uuid != uuid:
                    raise InvalidMountError(
                        f"Provided UUID {uuid!r} does not match UUID {device_uuid!r}"
                        f" of provided device {device!r}"
                    )

        if device is None:
            raise InvalidMountError(
                "Could not determine device from provided information."
            )
        try:
            real_device = os.path.realpath(device)
            assert real_device is not None
        except OSError as exc:
            raise InvalidMountError(f"Device {device!r} does not exist.") from exc

        self._device: str = real_device
        self._mountpoint: str | None = mountpoint
        self._uuid: str | None = uuid
        self._fallback_name: str | None = fallback_name
        self._verbose: bool = verbose
        self._dry_run: bool = dry_run
        self._mount: TemporaryMount | None = None

    def __enter__(self) -> Self:
        """Enter context manager - mount the device if not already mounted"""
        if self._prepare_temporary_mount():
            assert self._mount is not None
            self._mount.mount()
            if self._mountpoint is None:
                self._mountpoint = self._mount.mount_info.mountpoint
            assert (
                self._mountpoint == self._mount.mount_info.mountpoint
            ), f"Mountpoint mismatch: {self._mountpoint!r} != {self._mount.mount_info.mountpoint!r}"
        assert self._mountpoint is not None
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc_val: BaseException | None,
        exc_tb: object | None,
    ) -> None:
        """Exit context manager - unmount the device if it was mounted by us"""
        if self._mount is not None:
            self._mount.unmount()

    @property
    def device_path(self) -> str:
        """Get the device path"""
        return self._device

    @property
    def device_uuid(self) -> str:
        """Get the UUID of the device"""
        if self._uuid is None:
            self._uuid = self._get_named_value_from_device("UUID", self._device)
        return self._uuid

    @property
    def mountpoint_path(self) -> str | None:
        """Get the mountpoint if device is mounted"""
        if self._mountpoint is None:
            info = self._look_for_mount_from_device(self._device)
            self._mountpoint = info.mountpoint if info else None
        return self._mountpoint

    def _prepare_temporary_mount(self) -> bool:
        """Find where a filesystem is mounted, or mount it ourselves"""

        if self._mount is not None or self.mountpoint_path is not None:
            return False
        label = self._get_named_value_from_device("LABEL", self._device)
        name = (
            label or self._fallback_name or f"device_{os.path.basename(self._device)}"
        )
        name = re.sub(r"[^A-Za-z0-9]+", "_", name)
        if not name:
            raise RuntimeError(f"Bad mount name {name!r}")

        mount = f"{MOUNT_PREFIX}/{name}"
        while is_mounted(mountpoint=mount) or os.path.exists(mount):
            name = f"{name}.alt"
            mount = f"{MOUNT_PREFIX}/{name}"

        if is_mounted(device=self._device):
            raise InvalidMountError(f"Device {self._device!r} is already mounted")
        if is_mounted(mountpoint=mount):
            raise InvalidMountError(f"Mountpoint {mount!r} is already in use")

        self._mount = TemporaryMount(
            mount_info=MountInfo(device=self._device, mountpoint=mount),
            verbose=self._verbose,
            dry_run=self._dry_run,
        )
        return True

    @classmethod
    def _get_device_from_spec(cls, spec: str) -> str:
        """Get a device specified by device path, mountpoint, LABEL=*, or UUID=*"""
        assert spec

        if spec.startswith("/dev/"):
            if not os.path.exists(spec):
                raise ValueError(f"Device {spec!r} does not exist.")
            return spec
        if spec.startswith("LABEL=") or spec.startswith("UUID="):
            result = run_cmd(
                ["blkid", "-o", "device", "-t", spec],
                capture_output=True,
                check=False,
            )
            device = result.stdout.strip()
            if not device:
                raise ValueError(f"No device found for spec {spec!r}.")
            if not os.path.exists(device):
                raise ValueError(f"Device {device!r} for spec {spec!r} does not exist.")
            return device
        return cls._get_mount_from_mountpoint(spec).device

    @classmethod
    def _get_mount_from_mountpoint(cls, mountpoint: str) -> MountInfo:
        """Given a mountpoint, find the mounted device"""

        # MissingMountError will be passed through
        return get_mount_from_mountpoint(mountpoint)

    @classmethod
    def _look_for_mount_from_device(
        cls, device: str, mountpoint: str | None = None
    ) -> MountInfo | None:
        """Given a mounted device, find its MountInfo, if any"""

        if mountpoint is None:

            def ignore_snaps(dev: MountInfo) -> bool:
                return "/snap/" in dev.mountpoint

            ignore_filter = ignore_snaps
        else:

            def ignore_wrong_mountpoints(dev: MountInfo) -> bool:
                return dev.mountpoint != mountpoint

            ignore_filter = ignore_wrong_mountpoints

        try:
            return get_mount_from_device(device, ignore_filter=ignore_filter)
        except MissingMountError:
            pass
        return None

    @classmethod
    def _get_named_value_from_device(cls, name: str, device: str) -> str:
        """Get the named value (LABEL or UUID) for a device"""
        if not device:
            raise ValueError("Device path is required, empty path provided.")
        result = run_cmd(
            ["blkid", "-o", "value", "-s", name, device],
            capture_output=True,
            check=False,
        )
        value = result.stdout.strip()
        if not value:
            raise ValueError(f"No {name} was found for device {device!r}.")
        return value

    @classmethod
    def _get_device_from_named_value(cls, name: str, value: str) -> str:
        """Get the device for a named value (LABEL or UUID)"""
        if not value:
            raise ValueError(f"{name} is required, empty {name} provided.")
        result = run_cmd(
            ["blkid", "-o", "device", "-t", f"{name}={value}"],
            capture_output=True,
            check=False,
        )
        device = result.stdout.strip()
        if not device:
            raise ValueError(f"No device found for UUID {value!r}.")
        return device

    @classmethod
    def _is_mounted(cls, device: str, mountpoint: str) -> bool:
        """Check if a device is mounted on a mountpoint"""

        return is_mounted(device=device, mountpoint=mountpoint)

    def look_for_device_alias(
        self,
        pattern: str = "/dev/disk/by-id/*",
        if_multiple_use_first: bool = False,
    ) -> str | None:
        """Get the device alias path matching the specified real device"""

        matches: list[str] = []
        pattern_path = Path(pattern)
        if pattern_path.parent.exists():
            for id_dev in pattern_path.parent.glob(pattern_path.name):
                try:
                    id_path = os.path.realpath(str(id_dev))
                except OSError:
                    continue
                if id_path == self._device:
                    matches.append(str(id_dev))

        if len(matches) >= 1:
            if len(matches) == 1 or if_multiple_use_first:
                return matches[0]
        return None


# ------------------------------------------------------------


def copy_files(
    src_path: str,
    dst_path: str,
    *,
    exclude: list[str] | None = None,
    verbose: bool = False,
    dry_run: bool = False,
) -> bool:
    """Copy files using rsync"""
    if exclude is None:
        exclude = []

    print("  Copying data...")
    timer = ElapsedTimer()

    rsync_cmd = ["rsync", "--one-file-system"]
    rsync_cmd.extend(arg for pattern in exclude for arg in ("--exclude", pattern))
    rsync_cmd.extend(
        [
            "--checksum",
            "--archive",
            "--delete",
            "--hard-links",
            "--sparse",
            "--acls",
            "--xattrs",
        ]
    )

    if verbose:
        rsync_cmd.extend(
            ["--info=progress2,flist2,stats2,skip,symsafe", "--human-readable"]
        )

    rsync_cmd.extend([f"{src_path}/.", f"{dst_path}/."])

    try:
        run_cmd(rsync_cmd, capture_output=False, dry_run=dry_run)
    except subprocess.CalledProcessError:
        print("\033[91m...FAILED!\033[0m")
        return False
    print(f"  ...done in {timer.elapsed()}.")
    return True


def file_shell_game(
    filetype: str, file_old: str, file_cur: str, file_new: str, *, dry_run: bool = False
) -> bool:
    """Move current to old, then move new to current"""
    if dry_run:
        return True

    if not os.path.exists(file_new):
        print(
            f"\033[91m  ERROR: no new {filetype} file was found!\033[0m",
            file=sys.stderr,
        )
        return False

    if os.path.exists(file_cur):
        try:
            if os.path.exists(file_old):
                os.remove(file_old)
        except OSError:
            pass

        shutil.move(file_cur, file_old)
        if os.path.exists(file_cur):
            print(
                f"\033[91m  ERROR: failed to move the current {filetype} file"
                " out of the way!\033[0m",
                file=sys.stderr,
            )
            return False

    shutil.move(file_new, file_cur)
    if os.path.exists(file_new):
        print(
            f"\033[91m  ERROR: failed to move the new {filetype} file!\033[0m",
            file=sys.stderr,
        )
        return False
    if not os.path.exists(file_cur):
        print(
            f"\033[91m  ERROR: failed to replace the current {filetype} file!\033[0m",
            file=sys.stderr,
        )
        return False

    return True


def file_fallback(
    filetype: str, file_old: str, file_cur: str, file_new: str, *, dry_run: bool = False
) -> bool:
    """Fallback: if there's no new file, create one from cur/old"""
    if not os.path.exists(file_new):
        if os.path.exists(file_cur):
            if dry_run:
                print(
                    f"\033[90m    WOULD copy {file_cur} to {file_new}\033[0m",
                    file=sys.stderr,
                )
            else:
                shutil.copy2(file_cur, file_new)
        elif os.path.exists(file_old):
            if dry_run:
                print(
                    f"\033[90m    WOULD copy {file_old} to {file_new}\033[0m",
                    file=sys.stderr,
                )
            else:
                shutil.copy2(file_old, file_new)
        else:
            print(
                f"\033[93mWarning: No {filetype} file found in {file_cur} or {file_old}!\033[0m",
                file=sys.stderr,
            )
            return False
    return True


# Fstab manipulation functions


def restore_fstab(dst_path: str, *, dry_run: bool = False) -> bool:
    """Restore source fstab file"""
    dst_path = dst_path.rstrip("/")
    fstab_old = f"{dst_path}/etc/fstab.edited"
    fstab_cur = f"{dst_path}/etc/fstab"
    fstab_new = f"{dst_path}/etc/fstab.source"

    if not os.path.isdir(f"{dst_path}/etc"):
        return True

    if not file_fallback("fstab", fstab_old, fstab_cur, fstab_new, dry_run=dry_run):
        return False

    print("  Restoring source fstab file.")
    return file_shell_game("fstab", fstab_old, fstab_cur, fstab_new, dry_run=dry_run)


def propagate_fstab(dst_path: str, *, dry_run: bool = False) -> bool:
    """Propagate edited fstab file"""
    dst_path = dst_path.rstrip("/")
    fstab_old = f"{dst_path}/etc/fstab.source"
    fstab_cur = f"{dst_path}/etc/fstab"
    fstab_new = f"{dst_path}/etc/fstab.edited"

    print("  Propagating edited fstab file.")
    result = file_shell_game("fstab", fstab_old, fstab_cur, fstab_new, dry_run=dry_run)
    if not result:
        print("\033[91m...FAILED!\033[0m")
    return result


def edit_fstab(
    dst_path: str,
    dst_efi_dev: Device | None,
    dst_boot_dev: Device | None,
    dst_root_dev: Device,
    *,
    dry_run: bool = False,
) -> bool:
    """Edit fstab file to update UUIDs"""
    dst_path = dst_path.rstrip("/")
    source_fstab = f"{dst_path}/etc/fstab"
    edited_fstab = f"{dst_path}/etc/fstab.edited"

    if dry_run:
        print("\033[90m    WOULD edit fstab file.\033[0m")
        return True

    print("  Editing fstab file.")

    try:
        if os.path.exists(edited_fstab):
            os.remove(edited_fstab)
    except OSError:
        pass

    shutil.copy2(source_fstab, edited_fstab)

    with open(source_fstab, "r", encoding="utf-8") as fin, open(
        edited_fstab, "w", encoding="utf-8"
    ) as fout:
        edit_fstab_contents(fin, fout, dst_efi_dev, dst_boot_dev, dst_root_dev)

    return True


def edit_fstab_contents(
    fin: io.TextIOWrapper,
    fout: io.TextIOWrapper,
    dst_efi_dev: Device | None,
    dst_boot_dev: Device | None,
    dst_root_dev: Device,
) -> None:
    """Edit fstab contents"""
    lines = list(fin)

    # Check if LVM device is used
    dst_root_lvm_dev: str | None = None
    if any("/dev/disk/by-id/dm-uuid-LVM-" in line for line in lines):
        dst_root_lvm_dev = dst_root_dev.look_for_device_alias(
            "/dev/disk/by-id/dm-uuid-LVM-*"
        )

    for line in lines:
        if line.strip().startswith("#"):
            fout.write(line)
            continue

        parts = line.split()
        if len(parts) < 2:
            fout.write(line)
            continue

        device_spec = parts[0]
        mountpoint = parts[1]

        # Handle root partition
        if mountpoint == "/" and dst_root_dev:
            if device_spec.startswith("UUID="):
                orig = line.rstrip("\n")
                parts[0] = f"UUID={dst_root_dev.device_uuid}"
                fout.write(" ".join(parts) + "\n")
                fout.write(f"### {orig}\n")
                continue
            if device_spec.startswith("/dev/disk/by-uuid/"):
                orig = line.rstrip("\n")
                parts[0] = f"/dev/disk/by-uuid/{dst_root_dev.device_uuid}"
                fout.write(" ".join(parts) + "\n")
                fout.write(f"### {orig}\n")
                continue
            if (
                device_spec.startswith("/dev/disk/by-id/dm-uuid-LVM-")
                and dst_root_lvm_dev
            ):
                orig = line.rstrip("\n")
                parts[0] = dst_root_lvm_dev
                fout.write(" ".join(parts) + "\n")
                fout.write(f"### {orig}\n")
                continue

        # Handle /boot partition
        elif mountpoint == "/boot" and dst_boot_dev:
            if device_spec.startswith("UUID="):
                orig = line.rstrip("\n")
                parts[0] = f"UUID={dst_boot_dev.device_uuid}"
                fout.write(" ".join(parts) + "\n")
                fout.write(f"### {orig}\n")
                continue
            if device_spec.startswith("/dev/disk/by-uuid/"):
                orig = line.rstrip("\n")
                parts[0] = f"/dev/disk/by-uuid/{dst_boot_dev.device_uuid}"
                fout.write(" ".join(parts) + "\n")
                fout.write(f"### {orig}\n")
                continue

        # Handle /boot/efi partition
        elif mountpoint == "/boot/efi" and dst_efi_dev:
            if device_spec.startswith("UUID="):
                orig = line.rstrip("\n")
                parts[0] = f"UUID={dst_efi_dev.device_uuid}"
                fout.write(" ".join(parts) + "\n")
                fout.write(f"### {orig}\n")
                continue
            if device_spec.startswith("/dev/disk/by-uuid/"):
                orig = line.rstrip("\n")
                parts[0] = f"/dev/disk/by-uuid/{dst_efi_dev.device_uuid}"
                fout.write(" ".join(parts) + "\n")
                fout.write(f"### {orig}\n")
                continue

        fout.write(line)


def update_initrd(root_path: str, *, dry_run: bool = False) -> bool:
    """Update initrd files, optionally in a chroot environment with bind mounts."""
    root_path = root_path.rstrip("/")
    update_bin = "/usr/sbin/update-initramfs"
    update_cmd = [update_bin, "-u", "-k", "all"]

    pretty_root = root_path if root_path != "" else "/"
    command_prefix = ["chroot", root_path] if root_path != "" else []

    full_update_bin = f"{root_path}{update_bin}"
    if not os.path.exists(full_update_bin) and not dry_run:
        print(f"  Skipped updating initrd because {full_update_bin!r} was not found.")
        return True

    print(f"  Updating initrd files in {pretty_root}.")

    if root_path != "" and not dry_run:
        os.makedirs(f"{root_path}/var/tmp", exist_ok=True)

    try:
        timer = ElapsedTimer()
        run_cmd(
            command_prefix + update_cmd,
            capture_output=False,
            dry_run=dry_run,
        )
        print(f"  ...done in {timer.elapsed()}.")
    except subprocess.CalledProcessError:
        print("\033[91m  ...FAILED!\033[0m")
        return False

    return True


def update_grub(root_path: str, *, dry_run: bool = False) -> bool:
    """Update GRUB menus in current partition"""
    root_path = root_path.rstrip("/")
    update_bin = "/usr/sbin/update-grub"
    update_cmd = [update_bin]

    pretty_root = root_path if root_path != "" else "/"
    command_prefix = ["chroot", root_path] if root_path != "" else []

    full_update_bin = f"{root_path}{update_bin}"
    if not os.path.exists(full_update_bin) and not dry_run:
        print(f"  Skipped updating GRUB because {full_update_bin!r} was not found.")
        return True

    print(f"  Updating GRUB in {pretty_root}.")

    try:
        timer = ElapsedTimer()
        run_cmd(
            command_prefix + update_cmd,
            capture_output=False,
            dry_run=dry_run,
        )
        print(f"  ...done in {timer.elapsed()}.")
    except subprocess.CalledProcessError:
        print("\033[91m  ...FAILED!\033[0m")
        return False

    return True


# ------------------------------------------------------------


@dataclass
class SyncFlags:
    """Flags for syncing partitions"""

    exclude: list[str]
    verbosity: int
    dry_run: bool


def sync_partition(
    *,
    src_dev: Device,
    dst_dev: Device,
    flags: SyncFlags,
) -> bool:
    """Sync one partition to another"""
    if dst_dev.device_uuid == src_dev.device_uuid:
        raise ValueError(
            f"UUIDs are the same for {src_dev.device_path} and {dst_dev.device_path}."
        )

    assert src_dev.mountpoint_path is not None
    assert dst_dev.mountpoint_path is not None
    print(f"Copying {src_dev.mountpoint_path} to {dst_dev.mountpoint_path}...")
    timer = ElapsedTimer()

    if not copy_files(
        src_dev.mountpoint_path,
        dst_dev.mountpoint_path,
        exclude=flags.exclude,
        verbose=flags.verbosity > 0,
        dry_run=flags.dry_run,
    ):
        print("\033[91m...FAILED!\033[0m")
        return False

    print(f"...done in {timer.elapsed()}.")
    return True


def sync_efi_boot_root(
    *,
    src_efi_dev: Device | None,
    dst_efi_dev: Device | None,
    src_boot_dev: Device | None,
    dst_boot_dev: Device | None,
    src_root_dev: Device,
    dst_root_dev: Device,
    flags: SyncFlags,
) -> bool:
    """Sync EFI, boot, and root partitions"""
    if src_efi_dev and dst_efi_dev:
        if not sync_partition(
            src_dev=src_efi_dev,
            dst_dev=dst_efi_dev,
            flags=flags,
        ):
            return False

    if src_boot_dev and dst_boot_dev:
        if not sync_partition(
            src_dev=src_boot_dev,
            dst_dev=dst_boot_dev,
            flags=flags,
        ):
            return False

    if src_root_dev and dst_root_dev:
        assert dst_root_dev.mountpoint_path is not None

        if not restore_fstab(dst_root_dev.mountpoint_path, dry_run=flags.dry_run):
            return False

        if not sync_partition(
            src_dev=src_root_dev,
            dst_dev=dst_root_dev,
            flags=SyncFlags(
                exclude=[
                    "/tmp/",
                    "/var/tmp/",
                    "/media/",
                    "/mnt/",
                    *flags.exclude,
                ],
                verbosity=flags.verbosity,
                dry_run=flags.dry_run,
            ),
        ):
            return False

        print("Updating destination OS...")
        dst_os_update_timer = ElapsedTimer()

        if not (
            edit_fstab(
                dst_root_dev.mountpoint_path,
                dst_efi_dev,
                dst_boot_dev,
                dst_root_dev,
                dry_run=flags.dry_run,
            )
            and propagate_fstab(dst_root_dev.mountpoint_path, dry_run=flags.dry_run)
        ):
            return False

        chroot_prefix = dst_root_dev.mountpoint_path.rstrip("/")
        assert chroot_prefix != ""

        with contextlib.ExitStack() as stack:
            for p in ["/proc", "/dev", "/sys"]:
                stack.enter_context(
                    TemporaryBindMount(
                        source_path=p,
                        mountpoint=f"{chroot_prefix}{p}",
                        verbose=flags.verbosity > 0,
                        dry_run=flags.dry_run,
                    )
                )
            if src_boot_dev and dst_boot_dev:
                assert src_boot_dev.mountpoint_path is not None
                assert dst_boot_dev.mountpoint_path is not None
                stack.enter_context(
                    TemporaryBindMount(
                        source_path=dst_boot_dev.mountpoint_path,
                        mountpoint=f"{chroot_prefix}{src_boot_dev.mountpoint_path}",
                        verbose=flags.verbosity > 0,
                        dry_run=flags.dry_run,
                    )
                )
            if src_efi_dev and dst_efi_dev:
                assert src_efi_dev.mountpoint_path is not None
                assert dst_efi_dev.mountpoint_path is not None
                stack.enter_context(
                    TemporaryBindMount(
                        source_path=dst_efi_dev.mountpoint_path,
                        mountpoint=f"{chroot_prefix}{src_efi_dev.mountpoint_path}",
                        verbose=flags.verbosity > 0,
                        dry_run=flags.dry_run,
                    )
                )

            # Update initrd for the OS copy
            if not update_initrd(
                dst_root_dev.mountpoint_path,
                dry_run=flags.dry_run,
            ):
                return False

            # Update GRUB for the OS copy
            if not update_grub(
                dst_root_dev.mountpoint_path,
                dry_run=flags.dry_run,
            ):
                return False

            # HACK: Debian may have mounted efivars
            maybe_efivars = f"{chroot_prefix}/sys/firmware/efi/efivars"
            if os.path.ismount(maybe_efivars):
                run_cmd(
                    ["umount", maybe_efivars],
                    capture_output=False,
                    check=False,
                )

        print(f"...done in {dst_os_update_timer.elapsed()}.")

    print("Updating source OS...")
    src_os_update_timer = ElapsedTimer()

    # Update GRUB for the currently booted OS
    if not update_grub("/", dry_run=flags.dry_run):
        return False

    print(f"...done in {src_os_update_timer.elapsed()}.")
    return True


def process_partition(
    devs: list[str],
    *,
    src_default_mount_name: str = "backup-src",
    dst_default_mount_name: str = "backup-dst",
    flags: SyncFlags,
) -> bool:
    """Sync one partition to another"""
    assert len(devs) == 2, repr(devs)
    with Device(
        devs[0],
        fallback_name=src_default_mount_name,
        verbose=flags.verbosity > 0,
        dry_run=flags.dry_run,
    ) as src_dev, Device(
        devs[1],
        fallback_name=dst_default_mount_name,
        verbose=flags.verbosity > 0,
        dry_run=flags.dry_run,
    ) as dst_dev:
        return sync_partition(
            src_dev=src_dev,
            dst_dev=dst_dev,
            flags=flags,
        )


def process_efi_boot_root(
    efi_devs: list[str] | None,
    boot_devs: list[str] | None,
    root_devs: list[str],
    *,
    flags: SyncFlags,
) -> bool:
    """Sync a set of bootable partitions"""
    assert efi_devs is None or len(efi_devs) == 2, repr(efi_devs)
    assert boot_devs is None or len(boot_devs) == 2, repr(boot_devs)
    with contextlib.ExitStack() as stack:
        if efi_devs:
            src_efi_dev = stack.enter_context(
                Device(
                    efi_devs[0],
                    fallback_name="backup-efi-src",
                    verbose=flags.verbosity > 0,
                    dry_run=flags.dry_run,
                )
            )
            dst_efi_dev = stack.enter_context(
                Device(
                    efi_devs[1],
                    fallback_name="backup-efi-dst",
                    verbose=flags.verbosity > 0,
                    dry_run=flags.dry_run,
                )
            )
        else:
            src_efi_dev, dst_efi_dev = None, None
        if boot_devs:
            src_boot_dev = stack.enter_context(
                Device(
                    boot_devs[0],
                    fallback_name="backup-boot-src",
                    verbose=flags.verbosity > 0,
                    dry_run=flags.dry_run,
                )
            )
            dst_boot_dev = stack.enter_context(
                Device(
                    boot_devs[1],
                    fallback_name="backup-boot-dst",
                    verbose=flags.verbosity > 0,
                    dry_run=flags.dry_run,
                )
            )
        else:
            src_boot_dev, dst_boot_dev = None, None
        src_root_dev = stack.enter_context(
            Device(
                root_devs[0],
                fallback_name="backup-root-src",
                verbose=flags.verbosity > 0,
                dry_run=flags.dry_run,
            )
        )
        dst_root_dev = stack.enter_context(
            Device(
                root_devs[1],
                fallback_name="backup-root-dst",
                verbose=flags.verbosity > 0,
                dry_run=flags.dry_run,
            )
        )
        return sync_efi_boot_root(
            src_efi_dev=src_efi_dev,
            dst_efi_dev=dst_efi_dev,
            src_boot_dev=src_boot_dev,
            dst_boot_dev=dst_boot_dev,
            src_root_dev=src_root_dev,
            dst_root_dev=dst_root_dev,
            flags=flags,
        )


def validate_log_file(log_file: str) -> None:
    """Validate log file path. Not race condition safe!"""
    if os.path.islink(log_file):
        print(
            f"\033[91mError: {log_file!r} is a symbolic link!\033[0m", file=sys.stderr
        )
        sys.exit(3)
    if os.path.exists(log_file) and not os.path.isfile(log_file):
        print(
            f"\033[91mError: {log_file!r} is not a regular file!\033[0m",
            file=sys.stderr,
        )
        sys.exit(3)
    if os.path.exists(log_file) and os.stat(log_file).st_uid != os.getuid():
        print(
            f"\033[91mError: {log_file!r} is not owned by this user!\033[0m",
            file=sys.stderr,
        )
        sys.exit(3)


def write_to_log_file(log_file: str, text: str, erase: bool = False) -> None:
    """Write text to log file. Not race condition safe!"""
    validate_log_file(log_file)
    mode = "w" if erase else "a"
    with open(log_file, mode, encoding="utf-8") as f:
        print(text, file=f)


class ArgumentParserWithColor(argparse.ArgumentParser):
    """ArgumentParser that prints errors in red"""

    def error(self, message: str) -> NoReturn:
        """Print error message in red and exit"""
        super().error(f"\033[91m{message}\033[0m")


def parse_arguments() -> argparse.Namespace:
    """Parse command line arguments"""
    parser = ArgumentParserWithColor(
        description="Back up a partition to another partition with different UUID"
    )
    parser.add_argument(
        "-n",
        "--dry-run",
        action="store_true",
        help="Show what would be done without doing it",
    )
    parser.add_argument(
        "-D",
        "--data",
        nargs=2,
        metavar=("SRC", "DST"),
        action="append",
        default=[],
        help="Copy data partition (can be used multiple times)",
    )
    parser.add_argument(
        "-E", "--efi", nargs=2, metavar=("SRC", "DST"), help="Set EFI partition pair"
    )
    parser.add_argument(
        "-B", "--boot", nargs=2, metavar=("SRC", "DST"), help="Set boot partition pair"
    )
    parser.add_argument(
        "-R",
        "--root",
        nargs=2,
        metavar=("SRC", "DST"),
        help="Sync EFI, boot, and root partitions",
    )
    parser.add_argument(
        "-X",
        "--exclude",
        action="append",
        default=[],
        help="Exclude pattern (can be used multiple times)",
    )
    parser.add_argument("-v", "--verbose", action="count", help="Verbose rsync output")
    parser.add_argument(
        "--write-times",
        metavar="LOG_FILE",
        help="Write start and end times to log file",
    )

    args = parser.parse_args()

    # Check combinations of operations
    if (args.efi or args.boot) and not args.root:
        print(
            "\033[91mError: --efi and --boot cannot be used without --root.\033[0m",
            file=sys.stderr,
        )
        sys.exit(1)
    if not args.data and not args.root:
        print(
            "\033[91mError: Must specify at least one operation: either --data or"
            " (optional --efi and/or --boot with) --root.\033[0m",
            file=sys.stderr,
        )
        sys.exit(1)

    return args


def main() -> None:
    """Main entry point for the backup_partition script."""
    args = parse_arguments()

    sync_flags = SyncFlags(
        exclude=args.exclude or [],
        verbosity=args.verbose or 0,
        dry_run=args.dry_run,
    )

    if args.write_times and not args.dry_run:
        write_to_log_file(
            args.write_times,
            f"# Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            erase=True,
        )

    # Process operations
    success = True

    # Process data partitions if specified (can be multiple)
    for data_pair in args.data:
        result = process_partition(data_pair, flags=sync_flags)
        success = success and result
        if not success:
            print("\033[41m(stopping)\033[0m", file=sys.stderr)
            sys.exit(2)

    # Process system partitions if specified (only one)
    if args.root:
        result = process_efi_boot_root(
            args.efi,
            args.boot,
            args.root,
            flags=sync_flags,
        )
        success = success and result
        if not success:
            print("\033[41m(stopping)\033[0m", file=sys.stderr)
            sys.exit(2)

    # Write end time to log
    if args.write_times and not args.dry_run:
        write_to_log_file(
            args.write_times,
            f"# Ended:   {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        )

    if not success:
        sys.exit(3)


if __name__ == "__main__":
    main()
