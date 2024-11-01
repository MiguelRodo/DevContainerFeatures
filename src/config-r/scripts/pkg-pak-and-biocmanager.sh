#!/usr/local/bin/Rscript

# Exit immediately if an error occurs
options(error = function() quit(status = 1))

# Disable pak auto-matching in renv
Sys.setenv("RENV_CONFIG_PAK_ENABLED" = "false")

# Function to check if a package is installed
is_installed <- function(pkg) {
  requireNamespace(pkg, quietly = TRUE)
}

# Ensure renv is installed
if (!is_installed("renv")) {
  message("🔍 renv not found. Installing renv...")
  install.packages("renv", repos = "https://cloud.r-project.org")
} else {
  message("✅ renv is already installed.")
}

# Load renv
suppressMessages(library(renv))

# Create a temporary directory for the renv project
temp_dir <- tempfile("renv_temp_project_")
dir.create(temp_dir)
message("📁 Created temporary directory: ", temp_dir)

# Initialize a bare renv project without changing the working directory
message("🔧 Initializing renv in the temporary project...")
renv::init(project = temp_dir, bare = TRUE, restart = FALSE, bioconductor = TRUE)
message("✅ renv initialized.")

# Get debugging information
cache_path <- renv::paths$cache()
message("🗂️ renv global cache path: ", cache_path)

# Define the packages to install
packages_to_install <- c("pak", "BiocManager")
message("📦 Installing packages: ", paste(packages_to_install, collapse = ", "))

# Install the specified packages using renv within the temp_dir project
renv::install(packages_to_install, project = temp_dir)
message("✅ Packages installed and cached.")

message("🎉 renv cache setup completed successfully.")
