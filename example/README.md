# Example Usage

To use `skills_sync`, you need a `skills.yaml` file in your project root.

## 1. Initialize

```bash
skills_sync init
```

## 2. Configuration Example (`skills.yaml`)

```yaml
sources:
  mono0926/skills_sync:
    - skills_sync
  anthropics/skills:
    - '*'
    - '!recipe-*'
```

## 3. Sync

```bash
skills_sync sync
```
