"""Generate environments/prod/firewall.tf from the transit matrix in docs/zones.md.

docs/zones.md is normative; firewall.tf is derived from it and never edited by
hand. Run through scripts/generate-firewall, which pins the dependencies.
"""

import pathlib
import re
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
MATRIX = ROOT / "docs" / "zones.md"
OUTPUT = ROOT / "environments" / "prod" / "firewall.tf"


def blocks(text):
    merged = {}
    for block in re.findall(r"```yaml\n(.*?)```", text, re.S):
        merged.update(yaml.safe_load(block))
    return merged


def ports(values):
    # Proxmox writes port ranges as a:b.
    return ",".join(str(p).replace("-", ":") for p in values)


def ascii_note(entry):
    note = entry.get("note", "")
    note = note.replace("—", "-").encode("ascii", "ignore").decode()
    return f"{entry['id']}: {note}".strip().rstrip(":")


def main():
    matrix = blocks(MATRIX.read_text())
    zones = matrix["zones"]
    rules = {z["vnet"]: [] for z in zones.values()}
    node = matrix["node"]
    control = node["ingress_allowed_from"]
    control_zones = {name for name, z in zones.items() if z["group"] == control}
    admin_ports = {str(p) for p in node["ingress_ports"]}
    node_rules = []
    egress_rules = []

    for entry in matrix["transit"]:
        source = entry["from"]
        for dest in entry["to"]:
            if dest == "node":
                if source != "internet" and source not in zones:
                    raise SystemExit(f"{entry['id']}: unknown source {source!r} for a node rule")
                allowed = entry["ports"]
                if source in control_zones:
                    # Control reaches the node only on its admin ports, whatever
                    # else the entry opens towards the zones.
                    allowed = [p for p in allowed if str(p) in admin_ports]
                if allowed:
                    node_rules.append(
                        {
                            "source": zones[source]["cidr"] if source in zones else "",
                            "dport": ports(allowed),
                            "comment": ascii_note(entry),
                        }
                    )
                continue
            if dest == "internet":
                # Egress, covered by the zone's outbound policy, not an inbound rule.
                egress_rules.append(entry["id"])
                continue
            if source not in zones:
                raise SystemExit(f"{entry['id']}: unknown source {source!r} for a zone rule")
            rules[zones[dest]["vnet"]].append(
                {
                    "source": zones[source]["cidr"],
                    "dport": ports(entry["ports"]),
                    "comment": ascii_note(entry),
                }
            )

    no_egress = sorted(
        zones[e["from"]]["vnet"] for e in matrix["transit"] if not e["to"] and e["from"] in zones
    )

    out = [
        "# GENERATED from docs/zones.md by scripts/generate-firewall - do not edit by hand.",
        "# To change a rule: edit the transit block of docs/zones.md and regenerate.",
        f"# Internet-bound entries ({', '.join(sorted(set(egress_rules)))}) are egress, allowed by the",
        "# outbound policy of every zone but those in zone_firewall_no_egress.",
        "",
        "locals {",
        "  # Inbound rules per zone, keyed by VNet. All TCP.",
        "  zone_firewall_rules = {",
    ]
    for vnet in sorted(rules):
        if not rules[vnet]:
            out.append(f"    {vnet} = []")
            continue
        out.append(f"    {vnet} = [")
        for r in rules[vnet]:
            out.append(
                f'      {{ source = "{r["source"]}", dport = "{r["dport"]}", comment = "{r["comment"]}" }},'
            )
        out.append("    ]")
    out += [
        "  }",
        "",
        "  # Zones that initiate nothing: their VMs get an outbound DROP policy.",
        f"  zone_firewall_no_egress = [{', '.join(f'{v!r}'.replace(chr(39), chr(34)) for v in no_egress)}]",
        "",
        "  # Inbound rules of the node itself. All TCP; an empty source is any.",
        "  node_firewall_rules = [",
    ]
    for r in node_rules:
        out.append(
            f'    {{ source = "{r["source"]}", dport = "{r["dport"]}", comment = "{r["comment"]}" }},'
        )
    out += [
        "  ]",
        "}",
        "",
    ]
    OUTPUT.write_text("\n".join(out))
    print(f"wrote {OUTPUT.relative_to(ROOT)}", file=sys.stderr)


if __name__ == "__main__":
    main()
