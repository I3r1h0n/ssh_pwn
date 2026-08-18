#!/usr/bin/env python3
"""A tool to enum linux hosts over ssh"""

import argparse
import getpass
import json
import os
import shlex
import sys

import paramiko
import yaml

BANNER = r"""
              .__
  ______ _____|  |__           ________  _  ______
 /  ___//  ___/  |  \   ______ \____ \ \/ \/ /    \
 \___ \ \___ \|   Y  \ /_____/ |  |_> >     /   |  \
/____  >____  >___|  /         |   __/ \/\_/|___|  /
     \/     \/     \/          |__|              \/   v 0.1.0
                                    prod by I3r1h0n
"""

# Arguments

def parse_args():
    p = argparse.ArgumentParser(
        description="A tool to enum linux hosts over ssh",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "target formats (for -t and lines in -tL file):\n"
            "  host              192.168.1.1\n"
            "  host:port         192.168.1.1:2222\n"
            "  user@host         admin@192.168.1.1\n"
            "  user:pass@host    admin:secret@192.168.1.1:2222\n"
        ),
    )
    p.add_argument("-u", metavar="USER", help="SSH username (default: current OS user)")
    p.add_argument("-p", metavar="PASS", help="SSH password")
    p.add_argument("-i", metavar="KEY", help="Path to SSH private key")

    tgt = p.add_mutually_exclusive_group(required=True)
    tgt.add_argument("-t", metavar="TARGET", help="Single target (host or host:port)")
    tgt.add_argument("-tL", metavar="FILE", help="File with targets, one per line")

    p.add_argument("-o", metavar="FILE", help="Write JSON results to this file")
    p.add_argument("--extra-checks", metavar="PATHS",
                   help="Comma-separated YAML files and/or directories with extra checks")
    p.add_argument("--verbose", action="store_true", help="Print connection details and command output")

    return p.parse_args()

# Target parsing

def parse_host_port(host_str):
    if ":" in host_str:
        host, port_str = host_str.rsplit(":", 1)
        try:
            return host, int(port_str)
        except ValueError:
            pass
    return host_str, 22


def parse_target_line(line, default_user, default_password):
    line = line.strip()
    user = default_user
    password = default_password

    if "@" in line:
        creds, host_part = line.rsplit("@", 1)
        if ":" in creds:
            user, password = creds.split(":", 1)
        else:
            user = creds
    else:
        host_part = line

    host, port = parse_host_port(host_part)
    return host, port, user, password


def build_targets(args):
    default_user = args.u or getpass.getuser()
    default_pass = args.p

    if args.t:
        host, port = parse_host_port(args.t)
        return [(host, port, default_user, default_pass)]

    path = args.tL
    if not os.path.isfile(path):
        print(f"[-] Target file not found: {path}")
        sys.exit(1)

    targets = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            targets.append(parse_target_line(line, default_user, default_pass))
    return targets


# Key

def find_default_key():
    ssh_dir = os.path.expanduser("~/.ssh")
    for name in ("id_ed25519", "id_rsa", "id_ecdsa"):
        path = os.path.join(ssh_dir, name)
        if os.path.isfile(path):
            return path
    return None


def check_key_passphrase(key_path):
    key_classes = (paramiko.Ed25519Key, paramiko.RSAKey, paramiko.ECDSAKey)
    needs_passphrase = False

    for cls in key_classes:
        try:
            cls.from_private_key_file(key_path)
            return None
        except paramiko.ssh_exception.PasswordRequiredException:
            needs_passphrase = True
            break
        except (paramiko.SSHException, OSError):
            continue

    if not needs_passphrase:
        return None

    passphrase = getpass.getpass(f"Passphrase for {key_path}: ")
    for cls in key_classes:
        try:
            cls.from_private_key_file(key_path, password=passphrase)
            return passphrase
        except (paramiko.SSHException, OSError):
            continue

    print(f"[-] Could not load key {key_path} with the provided passphrase")
    sys.exit(1)


# SSH

def ssh_connect(host, port, username, password, key_path, passphrase, verbose):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    kw = {"hostname": host, "port": port, "username": username, "timeout": 10}

    if password:
        kw["password"] = password
        kw["look_for_keys"] = False
        kw["allow_agent"] = False
    elif key_path:
        kw["key_filename"] = key_path
        if passphrase:
            kw["passphrase"] = passphrase
        kw["look_for_keys"] = False
        kw["allow_agent"] = False
    else:
        kw["look_for_keys"] = True
        kw["allow_agent"] = True

    if verbose:
        auth = "password" if password else f"key ({key_path})" if key_path else "default keys/agent"
        print(f"  [*] Connecting {username}@{host}:{port}  auth={auth}")

    client.connect(**kw)

    if verbose:
        print("  [+] Connected")

    return client


# Command execution

def run_cmd(client, cmd, verbose=False):
    _, stdout, stderr = client.exec_command(cmd, timeout=15)
    out = stdout.read().decode(errors="replace").strip()
    err = stderr.read().decode(errors="replace").strip()
    code = stdout.channel.recv_exit_status()

    if verbose:
        print(f"  [cmd] {cmd}  (exit {code})")
        for ln in out.splitlines():
            print(f"    | {ln}")
        for ln in err.splitlines():
            print(f"    ! {ln}")

    return out, err, code


def run_sudo_stdin(client, cmd, password, verbose=False):
    full = f"sudo -S {cmd}"
    stdin, stdout, stderr = client.exec_command(full, timeout=15)
    stdin.write(password + "\n")
    stdin.flush()
    stdin.channel.shutdown_write()

    out = stdout.read().decode(errors="replace").strip()
    err = stderr.read().decode(errors="replace").strip()
    code = stdout.channel.recv_exit_status()

    if verbose:
        print(f"  [cmd] {full}  (exit {code})")
        for ln in out.splitlines():
            print(f"    | {ln}")
        # skip stderr lines that are just the sudo password prompt (doesn't work now, fix later)
        for ln in err.splitlines():
            if not ln.startswith("[sudo"):
                print(f"    ! {ln}")

    return out, err, code


# Enum

def check_root(client, password, verbose):
    out, _, _ = run_cmd(client, "id -u", verbose)
    try:
        uid = int(out)
    except ValueError:
        return False, False, None

    if uid == 0:
        return True, True, "direct"

    # passwordless sudo
    out, _, code = run_cmd(client, "sudo -n id -u 2>/dev/null", verbose)
    if code == 0 and out.strip() == "0":
        return False, True, "sudo_nopasswd"

    # sudo with password
    if password:
        out, _, code = run_sudo_stdin(client, "id -u", password, verbose)
        if code == 0 and out.strip() == "0":
            return False, True, "sudo_password"

    return False, False, None


def parse_os_pretty_name(raw):
    for line in raw.splitlines():
        if line.startswith("PRETTY_NAME="):
            return line.split("=", 1)[1].strip('"')
    return raw.splitlines()[0] if raw else "Unknown"


def _validate_checks(checks, source, base_dir=None):
    """
    Validate and normalize extra check entries (TLDR - look in /extra_checks dir for samples)

    I'm surprised that you are still now in /extra_checks, but:
        Each entry must have "name" and either "cmd" or "script" (not both)
            Optional flags:
                "only_sudo" (skip if can't sudo/root),
                "sudo" (run as root if possible, fall back to regular user otherwise)
            Script paths are resolved relative to the YAML file's directory
    """
    if not isinstance(checks, list):
        print(f"[-] {source}: must contain a YAML list")
        sys.exit(1)
    for i, entry in enumerate(checks):
        if not isinstance(entry, dict) or "name" not in entry:
            print(f'[-] {source} entry {i}: must have a "name" field')
            sys.exit(1)
        has_cmd = "cmd" in entry
        has_script = "script" in entry
        if has_cmd == has_script:
            print(f'[-] {source} entry {i}: must have either "cmd" or "script" (not both)')
            sys.exit(1)
        entry.setdefault("only_sudo", False)
        entry.setdefault("sudo", False)
        if entry["only_sudo"] and entry["sudo"]:
            print(f'[-] {source} entry {i}: "only_sudo" and "sudo" are mutually exclusive')
            sys.exit(1)
        # read script content at load time so we fail on missing files
        if has_script:
            script_path = entry["script"]
            if base_dir and not os.path.isabs(script_path):
                script_path = os.path.join(base_dir, script_path)
            if not os.path.isfile(script_path):
                print(f"[-] {source} entry {i}: script not found: {script_path}")
                sys.exit(1)
            with open(script_path) as sf:
                entry["_script_body"] = sf.read()
    return checks


def _load_from_path(path):
    if os.path.isdir(path):
        all_checks = []
        files = sorted(
            f for f in os.listdir(path)
            if f.endswith((".yaml", ".yml"))
        )
        if not files:
            print(f"[-] No .yaml/.yml files found in {path}")
            sys.exit(1)
        for name in files:
            fpath = os.path.join(path, name)
            with open(fpath) as f:
                checks = yaml.safe_load(f)
            all_checks.extend(_validate_checks(checks, fpath, base_dir=path))
        return all_checks

    if not os.path.isfile(path):
        print(f"[-] Extra checks path not found: {path}")
        sys.exit(1)
    with open(path) as f:
        checks = yaml.safe_load(f)
    return _validate_checks(checks, path, base_dir=os.path.dirname(os.path.abspath(path)))


def load_extra_checks(paths_str):
    all_checks = []
    for path in paths_str.split(","):
        path = path.strip()
        if not path:
            continue
        all_checks.extend(_load_from_path(path))
    return all_checks


def enumerate_host(client, password, verbose, extra_checks=None):
    info = {}

    out, _, _ = run_cmd(client, "whoami", verbose)
    info["user"] = out

    is_root, can_sudo, root_method = check_root(client, password, verbose)
    info["is_root"] = is_root
    info["can_sudo"] = can_sudo
    info["root_method"] = root_method

    out, _, _ = run_cmd(client, "cat /etc/hostname", verbose)
    info["hostname"] = out

    out, _, _ = run_cmd(client, "cat /etc/os-release", verbose)
    info["os_release_raw"] = out
    info["os_release"] = parse_os_pretty_name(out)

    out, _, _ = run_cmd(client, "uname -a", verbose)
    info["kernel"] = out

    out, _, code = run_cmd(
        client,
        "python3 --version 2>/dev/null || python --version 2>/dev/null",
        verbose,
    )
    info["python_version"] = out if code == 0 and out else None

    # extra checks from file
    if extra_checks:
        info["extra_checks"] = []
        for chk in extra_checks:
            label = chk.get("cmd") or chk.get("script", "")

            if chk["only_sudo"] and not (is_root or can_sudo):
                info["extra_checks"].append({
                    "name": chk["name"],
                    "label": label,
                    "skipped": True,
                    "reason": "requires root",
                })
                continue

            # decide whether this check should sudo
            use_sudo = (chk["only_sudo"] or chk["sudo"]) and can_sudo and not is_root

            is_script = "_script_body" in chk

            if use_sudo:
                if is_script:
                    # can't use heredoc with sudo -S (both fight for stdin) so wrap script body in bash -c with proper quoting
                    quoted = shlex.quote(chk["_script_body"])
                    base_cmd = f"bash -c {quoted}"
                else:
                    base_cmd = chk["cmd"]

                if root_method == "sudo_nopasswd":
                    out, err, code = run_cmd(client, f"sudo -n {base_cmd}", verbose)
                else:
                    out, err, code = run_sudo_stdin(client, base_cmd, password, verbose)
            else:
                if is_script:
                    heredoc = f"<<'__SSH_PWN_EOF__'\n{chk['_script_body']}\n__SSH_PWN_EOF__"
                    cmd = f"bash {heredoc}"
                else:
                    cmd = chk["cmd"]
                out, err, code = run_cmd(client, cmd, verbose)

            info["extra_checks"].append({
                "name": chk["name"],
                "label": label,
                "skipped": False,
                "stdout": out,
                "stderr": err,
                "exit_code": code,
            })

    return info


# Output

ROOT_METHOD_LABEL = {
    "direct": "direct root login",
    "sudo_nopasswd": "sudo without password",
    "sudo_password": "sudo with password",
}

def print_result(result):
    tag = f"{result['host']}:{result['port']}"

    if not result["success"]:
        print(f"\n{'=' * 55}")
        print(f"[-] {tag}  FAILED: {result['error']}")
        print(f"{'=' * 55}")
        return

    info = result["info"]

    if info["can_sudo"]:
        can_sudo_str = f"Yes ({ROOT_METHOD_LABEL.get(info['root_method'], info['root_method'])})"
    else:
        can_sudo_str = "No"

    print(f"\n{'=' * 55}")
    print(f"[+] {tag}")
    print(f"{'=' * 55}")
    print(f"  User:      {info['user']}")
    print(f"  Root:      {'Yes' if info['is_root'] else 'No'}")
    print(f"  Can Sudo:  {can_sudo_str}")
    print(f"  Hostname:  {info['hostname']}")
    print(f"  OS:        {info['os_release']}")
    print(f"  Kernel:    {info['kernel']}")
    print(f"  Python:    {info['python_version'] or 'not found'}")

    if info.get("extra_checks"):
        print(f"  {'─' * 40}")
        print("  Extra checks:")
        for chk in info["extra_checks"]:
            if chk.get("skipped"):
                print(f"    [SKIP] {chk['name']} ({chk['reason']})")
                continue
            status = "ok" if chk["exit_code"] == 0 else "FAIL"
            print(f"    [{status}] {chk['name']}:")
            for ln in chk["stdout"].splitlines():
                print(f"      | {ln}")
            if chk["stderr"]:
                for ln in chk["stderr"].splitlines():
                    print(f"      ! {ln}")

    print(f"{'=' * 55}")


def write_json(results, path):
    # combine info into each result for cleaner json
    out = []
    for r in results:
        entry = {"host": r["host"], "port": r["port"], "username": r["username"],
                 "success": r["success"], "error": r.get("error")}
        if r["success"]:
            entry.update(r["info"])
        out.append(entry)

    with open(path, "w") as f:
        json.dump(out, f, indent=2, default=str)

# Main

def main():
    print(BANNER)
    args = parse_args()

    # resolve ssh key
    key_path = args.i
    passphrase = None
    if not args.p:
        if not key_path:
            key_path = find_default_key()
        if key_path:
            if args.i and not os.path.isfile(key_path):
                print(f"[-] Key file not found: {key_path}")
                sys.exit(1)
            passphrase = check_key_passphrase(key_path)

    # load extra checks
    extra_checks = None
    if args.extra_checks:
        extra_checks = load_extra_checks(args.extra_checks)
        print(f"[*] Loaded {len(extra_checks)} extra check(s)")

    targets = build_targets(args)
    if not targets:
        print("[-] No targets to process")
        sys.exit(1)

    print(f"[*] Loaded {len(targets)} target(s)")

    results = []

    for host, port, username, password in targets:
        result = {"host": host, "port": port, "username": username}

        try:
            client = ssh_connect(
                host, 
                port, 
                username, 
                password,
                key_path if not password else None,
                passphrase if not password else None,
                args.verbose
            )
        except Exception as e:
            result["success"] = False
            result["error"] = str(e)
            print_result(result)
            results.append(result)
            continue

        try:
            info = enumerate_host(client, password, args.verbose, extra_checks)
            result["success"] = True
            result["error"] = None
            result["info"] = info
        except Exception as e:
            result["success"] = False
            result["error"] = f"Enumeration failed: {e}"
        finally:
            client.close()

        print_result(result)
        results.append(result)

    # summary
    ok = sum(1 for r in results if r["success"])
    fail = len(results) - ok
    print(f"\n[*] Done: {ok} succeeded, {fail} failed out of {len(results)}")

    # output json dump
    if args.o:
        write_json(results, args.o)
        print(f"[*] JSON results written to {args.o}")

if __name__ == "__main__":
    main()
