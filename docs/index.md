---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
   name: 'Moodle CLI: mdl'
   text: CLI tool to manage Moodle instances
   tagline: Moodle containerization made easy
   actions:
      - text: Getting Started
        link: getting-started
      - theme: alt
        text: Script Reference
        link: scripts
      - theme: alt
        text: Box Integration
        link: box

features:
   - title: Container infrastructure
     details: Configured to run in a Docker or podman environment using Bitnami's Moodle image.
   - title: Suite of management scripts
     details: Command-line scripts for managing Moodle environments including backups, restores, upgrades, and more.
   - title: Box.com integration
     details: Store backup sets in the cloud using an account on Box.com.
---
