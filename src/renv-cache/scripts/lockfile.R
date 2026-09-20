renv_cache_exclude_packages <- function(lock_data, skip_list) {
  if (is.null(lock_data$Packages)) {
    return(list(lockfile = lock_data, skipped = skip_list, write_lockfile = FALSE))
  }

  changed <- TRUE
  while (changed) {
    changed <- FALSE
    for (pkg_name in names(lock_data$Packages)) {
      reqs <- lock_data$Packages[[pkg_name]]$Requirements
      if (!is.null(reqs) && any(reqs %in% skip_list) && !(pkg_name %in% skip_list)) {
        skip_list <- c(skip_list, pkg_name)
        changed <- TRUE
      }
    }
  }

  for (pkg in skip_list) {
    lock_data$Packages[[pkg]] <- NULL
  }

  list(lockfile = lock_data, skipped = skip_list, write_lockfile = TRUE)
}

renv_cache_force_cached_versions <- function(lock_data, cache_path) {
  if (is.null(lock_data$Packages)) {
    return(list(lockfile = lock_data, changed = FALSE))
  }

  cached_pkgs <- list.files(cache_path)
  changed <- FALSE

  for (pkg in names(lock_data$Packages)) {
    pkg_info <- lock_data$Packages[[pkg]]

    # Only apply to standard CRAN/Bioc packages (ignore GitHub/Git/Local).
    is_standard <- is.null(pkg_info$Source) || pkg_info$Source %in% c("Repository", "CRAN", "Bioconductor")
    if (!is_standard || !(pkg %in% cached_pkgs)) {
      next
    }

    pkg_dir <- file.path(cache_path, pkg)
    versions <- list.files(pkg_dir)
    req_ver <- pkg_info$Version

    # Only retarget when the requested version is missing from the cache.
    if (length(versions) == 0 || req_ver %in% versions) {
      next
    }

    valid_vers <- versions[grepl("^[0-9]+(?:\\.[0-9]+)*$", versions)]
    if (length(valid_vers) == 0) {
      next
    }

    parsed_vers <- tryCatch(utils::package_version(valid_vers), error = function(e) NULL)
    if (is.null(parsed_vers)) {
      next
    }

    latest_ver <- as.character(max(parsed_vers))
    hashes <- list.files(file.path(pkg_dir, latest_ver))
    if (length(hashes) == 0) {
      next
    }

    target_hash <- hashes[1]
    message("  - Exact v", req_ver, " missing. Retargeting ", pkg, " to cached v", latest_ver)
    lock_data$Packages[[pkg]]$Version <- latest_ver
    lock_data$Packages[[pkg]]$Hash <- target_hash
    changed <- TRUE
  }

  list(lockfile = lock_data, changed = changed)
}
