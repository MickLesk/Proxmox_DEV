---
name: "🐛 Bug Report"
about: Report a reproducible bug or regression.
description: Generate a report on an issue specifically related to a script. For other inquiries, please use the Discussions section.
title: 'Bug: '
labels: 'Status: Unconfirmed'

body:
  - type: markdown
    attributes:
      value: |
        **IMPORTANT:** Failure to comply with the following guidelines may result in immediate closure.
        - Prior to submitting, kindly search closed issues to see if the problem you are reporting has already been addressed. If you find a relevant closed issue, please comment on it instead of creating a new one.
        - If the default Linux distribution is not adhered to, script support will be discontinued.
        - For the error `[ERROR] in line 23: exit code *: while executing command "$@" > /dev/null 2>&1`, ensure to run the script in verbose mode to pinpoint the issue.
        - For suggestions, questions, or feature requests, please share them in the [Discussions section.](https://github.com/community-scripts/ProxmoxVE/discussions)

  - type: input
    id: guidelines
    attributes:
      label: Please confirm you have read and understood the guidelines.
      placeholder: 'yes'
    validations:
      required: true

  - type: textarea
    id: bug
    attributes:
      label: A clear and concise description of the issue.
    validations:
      required: true

  - type: dropdown
    id: settings
    attributes:
      label: What settings are you currently utilizing?
      options:
        - Default Settings
        - Advanced Settings
    validations:
      required: true

  - type: markdown
    attributes:
      value: |
        _(If you are using Advanced Settings, please try Default Settings before creating an issue)_

  - type: dropdown
    id: distribution
    attributes:
      label: Which Linux distribution are you using?
      options:
        - Alpine
        - Debian 11
        - Debian 12
        - Ubuntu 20.04
        - Ubuntu 22.04
        - Ubuntu 24.04
    validations:
      required: true

  - type: textarea
    id: screenshot
    attributes:
      label: If relevant, add screenshots or code blocks to clarify the issue.
      placeholder: Code blocks should be wrapped in triple backticks (```) above and below the code.
    validations:
      required: false

  - type: textarea
    id: reproduce
    attributes:
      label: Please provide detailed steps to reproduce the issue.
      placeholder: First do this, then this ...
    validations:
      required: false
