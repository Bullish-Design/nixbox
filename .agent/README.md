# Agent Development Resources

This directory contains resources for AI agents working on the nixbox/cairn project.

## Directory Structure

```
.agent/
├── README.md         # This file
└── skills/           # Skill guides for specific subsystems
    ├── SKILL-AGENTFS.md
    ├── SKILL-MONTY.md
    ├── SKILL-JJ.md
    ├── SKILL-NEOVIM.md
    ├── SKILL-TMUX.md
    └── SKILL-DEVENV.md
```

## Skills

Skills are focused guides on specific subsystems or technologies used in this project. Each skill provides:

- **Quick Reference**: Essential patterns and code snippets
- **Working Examples**: Copy-pasteable code that works
- **Common Patterns**: Solutions to typical problems
- **See Also**: Links to related skills and documentation

### Available Skills

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| [SKILL-AGENTFS](skills/SKILL-AGENTFS.md) | Working with AgentFS SDK | File operations, overlays, KV store |
| [SKILL-MONTY](skills/SKILL-MONTY.md) | Monty sandbox integration | Agent code execution, external functions |
| [SKILL-JJ](skills/SKILL-JJ.md) | Jujutsu VCS integration | Change management, squashing, abandoning |
| [SKILL-NEOVIM](skills/SKILL-NEOVIM.md) | Neovim plugin development | UI components, commands, watchers |
| [SKILL-TMUX](skills/SKILL-TMUX.md) | TMUX workspace patterns | Layout, preview management |
| [SKILL-DEVENV](skills/SKILL-DEVENV.md) | Nix/devenv modules | Module structure, composition |

## Skill Authoring Best Practices

When creating or updating skills:

### 1. Naming Convention

- **Format**: `SKILL-<NAME>.md` (uppercase SKILL prefix, descriptive name)
- **Examples**: `SKILL-AGENTFS.md`, `SKILL-MONTY.md`
- **Don't**: Use generic names like `SKILL-UTILS.md` or `SKILL-MISC.md`

### 2. Structure

Each skill should follow this structure:

```markdown
# SKILL: [Technology/Subsystem Name]

[Brief description of what this skill covers]

## [Section 1: Core Concept]

[Explanation]

```code
[Working example]
```

## [Section 2: Common Pattern]

[When to use]

```code
[Example]
```

## [Section 3: Advanced Usage]

[Optional: more complex examples]

## See Also
- [Related SKILL or doc]
```

### 3. Content Guidelines

- **Keep it practical**: More code examples, less theory
- **Make it actionable**: Every section should have copy-pasteable code
- **Stay focused**: One skill = one subsystem/technology
- **Link liberally**: Reference other skills and main docs
- **Update regularly**: Keep examples current with codebase

### 4. Code Examples

- **Must work**: All code should be tested and functional
- **Be complete**: Include necessary imports and context
- **Show real usage**: Prefer real-world examples over toy examples
- **Annotate tricky parts**: Add comments for non-obvious code

### 5. Scope

A skill should be:
- **Self-contained**: Readable without needing other skills
- **Focused**: Covers one subsystem thoroughly
- **Practical**: Answers "how do I..." questions
- **Discoverable**: Easy to find via filename and title

## Using Skills in Development

### For AI Agents

When working on code related to a specific subsystem:
1. Check if a skill exists for that subsystem
2. Read the skill to understand patterns and conventions
3. Use the skill's examples as templates
4. Update the skill if you discover new patterns

### For Human Developers

Skills are also useful for onboarding and reference:
- Quick start for new contributors
- Reference for forgotten patterns
- Documentation for subsystem APIs
- Examples of best practices

## Maintenance

Skills should be:
- **Updated with code changes**: When subsystem APIs change
- **Expanded with new patterns**: When new use cases emerge
- **Reviewed periodically**: To remove stale content
- **Kept concise**: Split if a skill becomes too large (>50KB)

## Creating New Skills

To create a new skill:

1. **Check if needed**: Does this subsystem warrant a separate skill?
2. **Choose a name**: Follow the `SKILL-<NAME>.md` convention
3. **Create the file**: Place in `.agent/skills/`
4. **Follow the template**: Use structure from existing skills
5. **Add to table**: Update the Available Skills table above
6. **Test examples**: Ensure all code examples work
7. **Get feedback**: Have another developer review

## Related Documentation

- [AGENT.md](../AGENT.md) - Complete guide for AI agents
- [SPEC.md](../SPEC.md) - Technical specification
- [CONCEPT.md](../CONCEPT.md) - Design philosophy
- [.roadmap/](../.roadmap/) - Development roadmap

---

**Remember**: Skills are living documents. Keep them updated, practical, and focused!
