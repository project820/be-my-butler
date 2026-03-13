# Contributing to BMB

Thanks for your interest in contributing to BMB! This guide covers how to
get involved.

## Ways to Contribute

- **Bug reports** — File an issue using the bug report template
- **Feature requests** — File an issue using the feature request template
- **Pull requests** — Fix bugs, add features, improve docs
- **Translations** — Add or improve i18n support (see below)
- **Discussions** — Share ideas, ask questions, help others

## Code Style

- **Shell scripts**: Must pass `shellcheck` with zero warnings
- **Markdown**: Must pass `markdownlint` with zero warnings
- **Keep it simple**: Prefer clarity over cleverness

## PR Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/my-change`)
3. Make your changes
4. Run `shellcheck` on any modified `.sh` files
5. Test with `install.sh` and `doctor.sh`
6. Commit with a clear message
7. Open a PR against `main`
8. Wait for review — maintainers aim to respond within 48 hours

## Issue Labels

| Label     | Description                        |
|-----------|------------------------------------|
| `bug`     | Something is broken                |
| `feature` | New functionality request          |
| `docs`    | Documentation improvements         |
| `i18n`    | Internationalization / translation |

## Translations

BMB supports multiple languages. Translation files live in
`docs/README.{lang}.md` (e.g., `README.ko.md`, `README.ja.md`).

To contribute a translation:

1. Copy `docs/README.en.md` (or the main `README.md`) as your base
2. Translate into your target language
3. Name the file `docs/README.{lang}.md` using the ISO 639-1 code
4. Open a PR with the `i18n` label

## Development Setup

```bash
git clone https://github.com/be-my-butler/bmb.git
cd bmb
./install.sh    # install BMB into ~/.claude/
./doctor.sh     # verify installation
```

## Code of Conduct

Be respectful, constructive, and inclusive. We follow common open-source
etiquette — treat others the way you want to be treated.
