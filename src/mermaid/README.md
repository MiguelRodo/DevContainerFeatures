
# Mermaid (mermaid)

This DevContainer feature installs and configures the Mermaid CLI to generate diagrams from `.mmd` files. It sets up a non-root user and a Puppeteer configuration that allows rendering Mermaid diagrams in headless mode.

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



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/MiguelRodo/DevContainerFeatures/blob/main/src/mermaid/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
