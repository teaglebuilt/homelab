#!/usr/bin/env python3

from __future__ import annotations
from pathlib import Path
from argparse import ArgumentParser
from typing import Any
import subprocess
import tempfile
import logging
import json
import yaml
import sys
import os

from .machine_config import MachineConfig, render_tfvars

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
TF_MODULE = Path("tf_modules/virtual_machine")
ADMIN_USER = os.getenv("HOMELAB_ADMIN_USER", "gnosisadmin")
ADMIN_PASSWORD = os.getenv("HOMELAB_ADMIN_PASSWORD", "password")

def write_tfvars(machine: MachineConfig, admin_password: str, path: Path) -> None:
    vars = {
        "name": machine.name,
        "node": machine.node,
        "cores": machine.cores,
        "memory": machine.memory,
        "disk_size": machine.disk_size,
        "storage": machine.storage,
        "bridge": machine.bridge,
        "iso_file_id": machine.iso_file_id,
        "os_type": machine.os_type,
        "endpoint": "https://proxmox.local:8006/api2/json",
        "username": "root@pam",
        "password": admin_password,
    }
    path.write_text(json.dumps(vars, indent=2))


def get_vm_ip(terraform_dir: str) -> str:
    result = subprocess.run(
        ["terraform", "output", "-json"],
        cwd=terraform_dir,
        capture_output=True,
        check=True,
    )
    outputs = json.loads(result.stdout)
    return outputs["ip"]["value"]


def terraform_apply(tf_dir: Path) -> dict[str, Any]:
    subprocess.run(["terraform", "init"], cwd=tf_dir, check=True)
    subprocess.run(["terraform", "apply", "-auto-approve"], cwd=tf_dir, check=True)
    result = subprocess.run(["terraform", "output", "-json"], cwd=TF_MODULE, check=True, capture_output=True)
    output = json.loads(result.stdout)
    return json.loads(output.stdout)


def run_ansible_playbook(
    machine: MachineConfig,
    playbook_path: Path = Path("playbooks/apply-postinstall.yml"),
) -> None:
    ip_address = get_vm_ip(TF_MODULE)
    extra_vars = {
        "admin_user": ADMIN_USER,
        "admin_password": ADMIN_PASSWORD,
        "postinstall_tasks": machine.postinstall_tasks,
        "postinstall_handlers": machine.postinstall_handlers,
    }

    with tempfile.NamedTemporaryFile("w+", suffix=".yml", delete=False) as temp_file:
        yaml.dump(extra_vars, temp_file)
        temp_file_path = Path(temp_file.name)

    cmd = [
        "ansible-playbook",
        str(playbook_path),
        "-i", f"{ip_address},",
        "--extra-vars", f"@{temp_file_path}",
    ]

    logging.info("Running Ansible playbook for machine: %s", machine.name)
    logging.debug("Ansible command: %s", " ".join(cmd))

    try:
        subprocess.run(cmd, check=True)
        logging.info("Postinstall tasks completed successfully.")
    except subprocess.CalledProcessError as e:
        logging.error("Ansible playbook failed with exit code %s", e.returncode)
        sys.exit(e.returncode)
    finally:
        if temp_file_path.exists():
            temp_file_path.unlink()


def provision(machine_file: Path, admin_password: str):
    machine = MachineConfig.load(machine_file)
    with tempfile.NamedTemporaryFile(suffix=".tfvars.json", delete=False) as tf:
        write_tfvars(machine, admin_password, Path(tf.name))
        ip = terraform_apply(Path(tf.name))
        run_ansible_playbook(machine, ip, admin_password)


def parse_args() -> tuple[Path, str, str]:
    parser = ArgumentParser(description="Run Ansible postinstall for a machine config.")
    parser.add_argument("machine_config", type=Path, help="Path to machine YAML config file")

    args = parser.parse_args()
    return args.machine_config, args.ip_address, args.admin_password


def main() -> None:
    try:
        config_path = parse_args()
        machine = MachineConfig.load(config_path)

        tfvars_path = Path("terraform/machines") / f"{machine.name}.tfvars.json"

        render_tfvars(machine, tfvars_path)
        outputs = terraform_apply(TF_MODULE)
        print("outputs", outputs)

        ip_address = get_vm_ip(TF_MODULE)
        if not ip_address:
            raise RuntimeError("Terraform output missing 'ip' value")
    except Exception as e:
        logging.exception(f"Failed to execute machine postinstall process: {e}")
        sys.exit(1)
