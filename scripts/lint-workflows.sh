#!/usr/bin/env bash
set -euo pipefail

# Checks workflows/*.js against the contract in
# docs/superpowers/specs/2026-08-19-workflow-orchestration-design.md:
#
#   - meta is a literal with name, description, phases
#   - meta.name is profile-<x> and collides with no skill directory
#   - stage parity: every SKILL.md stage that names an agent has a meta.phases entry,
#     and no meta.phases entry invents a stage the profile does not have
#   - every agentType resolves to a file in agents/
#   - none of the sandbox-forbidden globals, and no worktree isolation (decision D5)

cd "$(dirname "$0")/.."

[ -d workflows ] || { echo "no workflows/ directory — nothing to lint"; exit 0; }

python3 - <<'PY'
import os, re, sys

violations = []

def strip_comments(src):
    src = re.sub(r'/\*.*?\*/', '', src, flags=re.S)
    return re.sub(r'(?m)^\s*//.*$', '', src)

def skill_stages(profile):
    """Stage bullets under '## 2. Stages' in the mirroring skill, and which name an agent."""
    path = f'skills/workflow-{profile}/SKILL.md'
    if not os.path.exists(path):
        return None, None
    text = open(path, encoding='utf-8').read()
    m = re.search(r'^## 2\. Stages\s*$(.*?)(?=^## )', text, flags=re.M | re.S)
    if not m:
        return None, None
    stages, with_agent = [], []
    for bullet in re.finditer(r'^- \*\*([^*]+)\*\*(.*?)(?=^- \*\*|\Z)', m.group(1), flags=re.M | re.S):
        name, body = bullet.group(1).strip(), bullet.group(2)
        stages.append(name)
        if 'swift-toolkit:swift-' in body:
            with_agent.append(name)
    return stages, with_agent

files = sorted(f for f in os.listdir('workflows') if f.endswith('.js'))
if not files:
    print('no workflow scripts — nothing to lint')
    sys.exit(0)

for fname in files:
    path = f'workflows/{fname}'
    raw = open(path, encoding='utf-8').read()
    src = strip_comments(raw)

    meta = re.search(r'export const meta\s*=\s*\{(.*?)^\}', raw, flags=re.M | re.S)
    if not meta:
        violations.append(f'{path}: no `export const meta = {{ … }}` literal')
        continue
    block = meta.group(1)

    name = re.search(r"\bname:\s*'([^']+)'", block)
    if not name:
        violations.append(f'{path}: meta has no name')
        continue
    name = name.group(1)

    for field in ('description', 'whenToUse'):
        if not re.search(rf"\b{field}:\s*'", block) and not re.search(rf"\b{field}:\s*$", block, flags=re.M):
            violations.append(f'{path}: meta has no {field}')

    if not name.startswith('profile-'):
        violations.append(f'{path}: meta.name "{name}" must start with "profile-"')
        continue
    profile = name[len('profile-'):]

    if os.path.isdir(f'skills/{name}'):
        violations.append(f'{path}: meta.name "{name}" collides with skills/{name}')

    if f'{profile}.js' != fname and f'profile-{profile}.js' != fname:
        violations.append(f'{path}: filename does not match meta.name "{name}"')

    titles = re.findall(r"title:\s*'([^']+)'", block)
    if not titles:
        violations.append(f'{path}: meta.phases is empty or unparsable')

    stages, with_agent = skill_stages(profile)
    if stages is None:
        violations.append(f'{path}: no mirroring skills/workflow-{profile}/SKILL.md with a "## 2. Stages" section')
    else:
        for missing in [s for s in with_agent if s not in titles]:
            violations.append(f'{path}: stage "{missing}" names an agent in the skill but has no meta.phases entry')
        for invented in [t for t in titles if t not in stages]:
            violations.append(f'{path}: meta.phases has "{invented}", which is not a stage of the {profile.upper()} profile')

    for agent_type in sorted(set(re.findall(r"agentType:\s*'([^']+)'", src))):
        bare = agent_type.split(':', 1)[1] if ':' in agent_type else agent_type
        if not os.path.exists(f'agents/{bare}.md'):
            violations.append(f'{path}: agentType "{agent_type}" has no agents/{bare}.md')
        if not agent_type.startswith('swift-toolkit:'):
            violations.append(f'{path}: agentType "{agent_type}" is missing the swift-toolkit: prefix')

    for token, why in (
        ('Date.now(', 'rejected by the workflow validator'),
        ('Math.random(', 'rejected by the workflow validator'),
        ('new Date(', 'rejected by the workflow validator'),
        ('import(', 'the script sandbox loads no modules'),
        ('isolation:', 'decision D5 — worktrees branch from the default branch, not the task branch'),
    ):
        if token in src:
            violations.append(f'{path}: contains `{token}` — {why}')

for v in violations:
    print(v)

if violations:
    print()
    print(f'workflow lint failed: {len(violations)} violation(s)')
    sys.exit(1)

print(f'workflow lint passed: {len(files)} script(s), stages in sync with their skills')
PY
