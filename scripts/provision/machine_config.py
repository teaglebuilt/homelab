from __future__ import annotations
from pathlib import Path
from dataclasses import dataclass, field
import json
import yaml


@dataclass
class PostinstallBlock:
    tasks: list[dict]
    handlers: list[dict] = field(default_factory=list)

    @staticmethod
    def from_dict(data: dict | None) -> PostinstallBlock:
        if not data:
            return PostinstallBlock(tasks=[])
        return PostinstallBlock(
            tasks=data.get("tasks", []),
            handlers=data.get("handlers", []),
        )


@dataclass
class MachineConfig:
    name: str
    operating_system: str
    postinstall: PostinstallBlock = field(default_factory=PostinstallBlock)

    @staticmethod
    def load(path: Path) -> MachineConfig:
        if not path.exists():
            raise FileNotFoundError(f"Machine config not found: {path}")

        raw = yaml.safe_load(path.read_text())

        try:
            return MachineConfig(
                name=raw["name"],
                operating_system=raw["operating_system"],
                admin=raw["admin"],
                connection_type=raw.get("connection_type", "ssh"),
                postinstall=PostinstallBlock.from_dict(raw.get("postinstall")),
            )
        except KeyError as e:
            raise ValueError(f"Missing required field in machine config: {e}") from e


def render_tfvars(machine: MachineConfig, output_path: Path) -> None:
    tfvars = {
        "name": machine.name,
        "vmid": 9000,  # or dynamically generate
        "node": "pve",
        "cores": 8,
        "memory": 16384,
        "disk_size": "64G",
        "iso": "local:iso/windows.iso" if "win" in machine.operating_system else "local:iso/linux.iso",
        "os_type": "win11" if "win" in machine.operating_system else "cloud-init",
        "connection_type": machine.connection_type,
        "admin_user": machine.admin,
        "admin_password": "from-ssm-or-env",
        "bridge": "vmbr0",
        "storage": "local-lvm",
        "endpoint": "https://pve.local:8006/api2/json",
        "user": "root@pam",
        "password": "your-password",
    }

    with open(output_path, "w") as f:
        json.dump(tfvars, f, indent=2)
