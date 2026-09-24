---
name: ansible-role
description: Scaffolds and reviews Ansible roles for this repo — directory layout, variable naming, argument_specs, handlers and check-mode safety. Use when creating a role, restructuring one, or reviewing whether an existing role is laid out correctly.
---

# Ansible role structure

Roles here configure the Proxmox host and the homelab VMs. They are **not**
built for Galaxy distribution: no collection scaffolding, no `galaxy.yml`, no
CoP inclusion review. Optimise for a single operator reading this in a year.

## Layout

```
roles/<role_name>/
  defaults/main.yml         every knob a caller may override, all documented
  vars/main.yml             internal constants a caller must NOT override
  tasks/main.yml            dispatcher only, once it passes ~50 lines
  tasks/install.yml
  tasks/configure.yml
  tasks/service.yml
  handlers/main.yml
  templates/<file>.j2
  files/
  meta/main.yml             dependencies and supported platforms
  meta/argument_specs.yml   the validated public interface
```

No README.md is required per role: `argument_specs.yml` is the documentation.
Add one only where a role's shape genuinely needs more explaining than that.

Create only the directories the role actually uses. An empty `files/` is noise.

## The four rules that matter most

**1. Prefix every variable with the role name.** Ansible variables live in one
flat global namespace: `port` from one role silently overwrites `port` from
another. `edge_nginx_listen_port` cannot collide. No exceptions, including
loop vars (`edge_nginx_vhosts`) and internal ones in `vars/`.

**2. `defaults/` and `vars/` are not interchangeable.** `defaults/` is the
lowest precedence in Ansible: anything overrides it, which is what you want for
a knob. `vars/` sits near the top and is painful to override, which is what you
want for a constant the caller has no business changing. Putting a tunable in
`vars/` is the single most common structural mistake — it works until someone
tries to change it from the inventory and cannot.

**3. Declare the interface in `meta/argument_specs.yml`.** It validates types
and required-ness before the first task runs, and it fails with a readable
message instead of a templating error forty tasks in. It also doubles as the
role's real documentation.

```yaml
argument_specs:
  main:
    short_description: Configure NGINX on the edge VM
    options:
      edge_nginx_listen_address:
        type: str
        required: true
        description: Zone IP to bind to. Never 0.0.0.0.
      edge_nginx_vhosts:
        type: list
        elements: dict
        default: []
```

**4. The role must run clean under `--check`.** This repo never runs
`ansible-playbook` without `--check` (see `CLAUDE.md`), so a role that cannot
be check-run is a role that cannot be reviewed. Every `command`/`shell` needs
`check_mode: false` plus `changed_when:` when it only reads, and any later task
that consumes its output needs a guard for the check run. If a role can only be
validated by actually applying it, restructure it.

## Conventions

- `tasks/main.yml` stays a dispatcher: `ansible.builtin.include_tasks` or
  `ansible.builtin.import_tasks` per stage, with `tags`. Logic lives in the
  included files.
- Fully qualified module names everywhere (`ansible.builtin.template`, not
  `template`).
- Handlers named for the effect, not the mechanism: `restart nginx`, not
  `handler_1`. Use `listen` when several tasks trigger the same one.
- `become:` at play level, in the playbook — that is what this repo's
  playbooks do. Override it at task level (`become_user`, or `become: false`)
  only for the tasks that genuinely need something different.
- Never `ignore_errors: true`. Use `failed_when:` with the real condition.
- Templates carry `{{ ansible_managed }}` in a header comment, so anyone who
  finds the file on the box knows not to edit it.
- Bind addresses and IPs come from the inventory, never hardcoded in the role.
  The zones and VMs are in `environments/prod/terraform.tfvars`, explained in
  `docs/zones.md`.
- Secrets never appear in `defaults/`. The role takes a variable; the value
  comes from a SOPS-encrypted file.

## Procedure

1. Confirm the role's single responsibility and name it after that, in
   `snake_case`. Two responsibilities means two roles.
2. Create the layout above, only the parts used.
3. Write `meta/argument_specs.yml` **before** the tasks: decide the interface
   first, then implement it.
4. Fill `defaults/main.yml` with a comment per variable, matching the specs.
5. Write the tasks, split by stage once `main.yml` grows past a dispatcher.
6. Run `ansible-lint` and fix everything it reports.
7. Verify with `ansible-playbook --check --diff` and read the diff.
8. Stop. The real run is launched by the human.

## Check before calling it done

- Every variable prefixed with the role name.
- Every tunable in `defaults/`, every constant in `vars/`.
- `argument_specs.yml` covers every variable the caller sets.
- No `shell`/`command` without `creates:` or `changed_when:`.
- Clean `--check` run, and the diff shows only what you intended.
- `ansible-lint` silent.
