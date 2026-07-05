# Contributing to AI Dev Workflow

Thank you for your interest in contributing! This is the community edition of the AI Dev Workflow project.

## How to Contribute

### Reporting Issues

- Check existing issues before creating a new one
- Use a clear, descriptive title
- Include steps to reproduce (if applicable)
- Describe expected vs actual behavior
- Include your environment (OS, shell, AI assistant used)

### Suggesting Enhancements

- Explain the problem your enhancement solves
- Provide examples of how it would work
- Consider backward compatibility
- Tag with "enhancement" label

### Code Contributions

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/your-feature`)
3. **Make your changes**
   - Follow existing code style
   - Keep shell scripts POSIX-compatible where possible
   - Test on multiple shells/OS if changing scripts
4. **Test your changes**
   - Run scaffold.sh bootstrap on a test project
   - Verify placeholders are substituted correctly
   - Check that templates remain valid markdown
5. **Commit with clear messages**
   - Use present tense ("Add feature" not "Added feature")
   - Reference issues when applicable
6. **Push to your fork**
7. **Open a Pull Request**
   - Describe what changed and why
   - Link related issues
   - Include any breaking changes

### Template Contributions

**For CLAUDE.md, ARCHITECT.md, or WORKFLOW.md improvements:**
- Keep language/stack-agnostic (use placeholders)
- Maintain the Principle → Binding pattern
- Add examples where helpful
- Update BOOTSTRAP.md if adding new principles

**For scaffold.sh improvements:**
- Test on both bootstrap and adopt modes
- Verify placeholder substitution works
- Check that derived values (SIDE, OTHER_SIDE) work correctly
- Document any new command-line options

### Documentation Contributions

- Fix typos, clarify instructions, improve examples
- Keep examples concrete but generic (not project-specific)
- Maintain consistent voice and formatting

## Principle → Binding Contributions

If you want to add support for a new language/framework to the Principle → Binding table:

1. Ensure all 7 core principles map cleanly to your stack
2. Add a row to each principle table in BOOTSTRAP.md
3. Provide concrete examples (not just keywords)
4. Test by bootstrapping a real project in that stack

## Code Style

**Shell scripts:**
- Use `set -euo pipefail`
- Quote variables: `"$VAR"` not `$VAR`
- Use `[[ ]]` for conditionals (bash), `[ ]` for POSIX
- Prefer readable over clever

**Markdown:**
- Use ATX headers (`#` not underline style)
- Fenced code blocks with language tags
- Tables for structured comparisons
- Consistent list formatting

## Review Process

1. Maintainer reviews PR within 1 week
2. Feedback addressed by contributor
3. Approval → merge to main
4. Changes included in next release

## Questions?

Open an issue with the "question" label or start a discussion.

---

**Note:** This is the public community edition. Advanced features (product workspace, legal templates, upstream harvesting) are maintained separately.
