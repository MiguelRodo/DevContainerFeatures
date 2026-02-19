
# Mermaid (mermaid)

Installs Mermaid CLI to generate diagrams. Sets up a non-root user and Puppeteer configuration.

## Example Usage

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/mermaid:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| userName | Specify the username under which Mermaid CLI will run. | string | mermaiduser |
| puppeteerConfigDir | Directory to store Puppeteer configuration files. | string | /usr/local/share/mermaid-config |
| nodeVersion | Node.js version to install if not present (e.g., 'lts', '20', '18'). | string | lts |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/MiguelRodo/DevContainerFeatures/blob/main/src/mermaid/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
