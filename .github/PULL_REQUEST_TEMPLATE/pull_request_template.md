name: "📦 Pull Request"
description: Submit your contributions for review and integration into the project.

body:
  - type: markdown
    attributes:
      value: |
        # 📦 **Pull Request Template**

        > [!NOTE]
        > 🛠️ We are meticulous about merging code into the main branch, so please understand that pull requests not meeting the project's standards may be rejected. It's never personal!  
        > 🎮 **Note for game-related scripts:** These have a lower likelihood of being merged.

  - type: input
    id: description
    attributes:
      label: ✍️ Description
      description: Provide a summary of the changes made and/or reference the issue being addressed.
      placeholder: "e.g., Added new features to enhance compatibility with Debian 12."
    validations:
      required: true

  - type: input
    id: issue_reference
    attributes:
      label: 🔗 Fixes #
      description: If this pull request resolves an existing issue, please reference the issue number (e.g., `Fixes #123`). Leave blank if not applicable.
      placeholder: "Fixes #"

  - type: checkboxes
    id: change_type
    attributes:
      label: 🛠️ Type of change
      description: Please check the relevant option(s) below:
      options:
        - label: Bug fix (non-breaking change that resolves an issue)
        - label: New feature (non-breaking change that adds functionality)
        - label: Breaking change (a fix or feature that would cause existing functionality to change unexpectedly)
        - label: New script (a fully functional and thoroughly tested script or set of scripts.)
    validations:
      required: true

  - type: checkboxes
    id: prerequisites
    attributes:
      label: ✅ Prerequisites
      description: The following steps must be completed for the pull request to be considered. Please check all that apply:
      options:
        - label: Self-review performed (I have reviewed my code to ensure it follows established patterns and conventions.)
        - label: Testing performed (I have thoroughly tested my changes and verified expected functionality.)
        - label: Documentation updated (I have updated any relevant documentation, including README files or comments.)
    validations:
      required: true

  - type: textarea
    id: additional_information
    attributes:
      label: 📋 Additional Information (optional)
      description: Provide any extra context or screenshots about the feature or fix here.
      placeholder: "e.g., Screenshots, logs, or further explanations."

  - type: textarea
    id: related_prs
    attributes:
      label: 🔗 Related Pull Requests / Discussions
      description: If there are other pull requests or discussions related to this change, please link them here.
      placeholder: "e.g., Related PR #123 or [Discussion thread](https://github.com/community-scripts/ProxmoxVE/discussions/456)."
