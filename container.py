import argparse
import ctypes
import os
import socket
import subprocess
import sys

libc = ctypes.CDLL(None, use_errno=True)
libc.mount.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_ulong, ctypes.c_char_p]

def cgroup_create(memory_mb: int | None, cpu_pct: int | None) -> str:
    """STAGE 3: Resource limits via cgroups v2"""
    path = f"/sys/fs/cgroup/mycontainer-{os.getpid()}"
    os.mkdir(path)
    if memory_mb is not None:
        with open(f"{path}/memory.max", "w") as f:
            f.write(str(memory_mb * 1024 * 1024))
        # Disable swap for this cgroup so it OOMs immediately instead of swapping to 6GB
        try:
            with open(f"{path}/memory.swap.max", "w") as f: f.write("0")
        except FileNotFoundError: pass

    if cpu_pct is not None:
        with open(f"{path}/cpu.max", "w") as f:
            f.write(f"{cpu_pct * 1000} 100000")
    return path

def isolate(rootfs: str):
    """STAGE 1: Process & Filesystem isolation"""
    socket.sethostname("mycontainer")
    libc.mount(b"none", b"/", None, 16384 | 262144, None)  # MS_REC | MS_PRIVATE
    os.chroot(rootfs)
    os.chdir("/")
    if libc.mount(b"proc", b"/proc", b"proc", 0, b"") != 0:
        print(f"Warning: Failed to mount /proc: {ctypes.get_errno()}")

def run_container(rootfs: str, command: list[str], memory_mb: int | None, cpu_pct: int | None):
    cgroup_dir = cgroup_create(memory_mb, cpu_pct)
    pid = os.fork()
    if pid == 0:
        # Join cgroup *before* unshare to prevent escaping limits
        with open(f"{cgroup_dir}/cgroup.procs", "w") as f:
            f.write(str(os.getpid()))
        
        # STAGE 2: Namespaces (PID, Mount, UTS, Net)
        os.unshare(os.CLONE_NEWPID | os.CLONE_NEWNS | os.CLONE_NEWUTS | os.CLONE_NEWNET)
        if os.fork() == 0:
            subprocess.run(["ip", "link", "set", "lo", "up"], check=False)
            isolate(rootfs)
            os.execvpe(command[0], command, {"PATH": "/bin:/usr/bin:/sbin:/usr/sbin", "HOME": "/root"})
            
        _, status = os.wait()
        sys.exit(os.waitstatus_to_exitcode(status))
        
    try:
        _, status = os.waitpid(pid, 0)
        return os.waitstatus_to_exitcode(status)
    finally:
        try: os.rmdir(cgroup_dir)
        except OSError: pass

if __name__ == "__main__":
    if os.geteuid() != 0:
        print("Error: Container requires root privileges. Run with sudo.", file=sys.stderr)
        sys.exit(1)

    parser = argparse.ArgumentParser(description="Docker in 100 lines")
    parser.add_argument("action", choices=["run"])
    parser.add_argument("--rootfs", default="/tmp/rootfs")
    parser.add_argument("--memory", type=int)
    parser.add_argument("--cpu", type=int)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()

    cmd = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not os.path.exists(args.rootfs):
        sys.exit(f"Error: rootfs path {args.rootfs} not found.")
        
    sys.exit(run_container(args.rootfs, cmd or ["/bin/sh"], args.memory, args.cpu))
