#' Recommendation rules
#'
#' Returns the rules table used by [suggest_analyses()]. Each row is an
#' analysis, with the condition under which it is suggested, the rationale,
#' the caveats and the recommended R packages. Use this function to inspect
#' the rules or as a starting point for your own.
#'
#' @param file Optional. Path to a CSV file with custom rules, separated by
#'   commas or semicolons, encoded in UTF-8 or latin1 (as saved by Excel).
#'   If omitted, the table shipped with the package is used
#'   (`system.file("rules", "rules.csv", package = "rsguia")`).
#'
#' @details
#' Required columns:
#' * `id`: short, unique identifier (e.g. `"ndvi"`). The analysis' code
#'   template is looked up in `inst/templates/<id>.R`; custom rules can point
#'   to another file in the optional column `template`.
#' * `analysis`, `category`: name of the analysis and the group it belongs
#'   to.
#' * `condition`: expression using tags produced by [diagnose()], combined
#'   with `&` (and), `|` (or) and `!` (not). Example:
#'   `"band:green & band:nir | band:green & band:swir1"`.
#' * `rationale`: why the analysis is possible with these data.
#' * `caveats`: assumptions and precautions, separated by `|`.
#' * `packages`: suggested R packages, separated by `;`.
#'
#' Available tags: `raster`, `vector`, `table`, `multispectral`, `dem`,
#' `time_series`, `long_series`, `overlap`, `crs_mismatch`,
#' `band:<group>` (`coastal`, `blue`, `green`, `red`, `rededge`, `nir`,
#' `swir1`, `swir2`, `thermal`, `quality`), `scale:<type>`
#' (`reflectance_0_1`, `int_10000`, `landsat_c2`, `int_8bit`, `index`,
#' `categorical`, `elevation`, `unknown`) and `vector:<type>` (`points`,
#' `lines`, `polygons`, `labeled`).
#'
#' @return A `data.frame` with the rules.
#'
#' @examples
#' rules <- rsguia_rules()
#' rules[, c("id", "analysis", "condition")]
#'
#' # Adding a custom rule
#' gndvi <- data.frame(
#'   id = "gndvi", analysis = "GNDVI", category = "Vegetation indices",
#'   condition = "band:green & band:nir",
#'   rationale = "Uses green instead of red; sensitive to chlorophyll.",
#'   caveats = "Use surface reflectance | Mask clouds", packages = "terra"
#' )
#' my_rules <- rbind(rules, gndvi)
#'
#' @export
rsguia_rules <- function(file = NULL) {
  rules <- if (is.null(file)) {
    read_internal_table("rules.csv")
  } else {
    read_csv_any(file, na = c("", "NA"))
  }
  validate_rules(rules)
}

RULE_COLUMNS <- c("id", "analysis", "category", "condition", "rationale", "caveats",
                  "packages")

validate_rules <- function(rules) {
  if (is.character(rules)) rules <- rsguia_rules(rules)
  if (!is.data.frame(rules)) {
    cli::cli_abort("Rules must be a data.frame or the path to a CSV file.")
  }
  missing <- setdiff(RULE_COLUMNS, names(rules))
  if (length(missing)) {
    cli::cli_abort("Columns missing from the rules table: {.val {missing}}.")
  }
  if (anyDuplicated(rules$id)) {
    cli::cli_abort("Duplicated ids in the rules: {.val {unique(rules$id[duplicated(rules$id)])}}.")
  }
  if (anyNA(rules$condition) || any(!nzchar(trimws(rules$condition)))) {
    cli::cli_abort("Every rule needs a condition.")
  }
  used <- unique(unlist(lapply(rules$condition, function(cond) {
    unlist(lapply(parse_condition(cond), unlist))
  })))
  unknown <- used[!vapply(used, known_tag, logical(1))]
  if (length(unknown)) {
    cli::cli_warn(c(
      "Unknown tags in the conditions: {.val {unknown}}.",
      "i" = "These rules will never be suggested. See the valid tags in {.code ?rsguia_rules}."
    ))
  }
  rules
}

known_tag <- function(x) {
  fixed <- c("raster", "vector", "table", "multispectral", "dem", "time_series",
             "long_series", "overlap", "crs_mismatch")
  x %in% c(fixed,
           paste0("band:", names(GROUP_LABELS)),
           paste0("scale:", names(SCALES)),
           paste0("vector:", c("points", "lines", "polygons", "labeled")))
}

# "a & b | !c" -> list(list(yes = c("a", "b"), no = character()),
#                      list(yes = character(), no = "c"))
parse_condition <- function(condition) {
  alternatives <- strsplit(condition, "|", fixed = TRUE)[[1]]
  lapply(alternatives, function(alt) {
    terms <- trimws(strsplit(alt, "&", fixed = TRUE)[[1]])
    terms <- terms[nzchar(terms)]
    negated <- startsWith(terms, "!")
    tags <- trimws(sub("^!", "", terms))
    list(yes = tags[!negated], no = tags[negated])
  })
}

eval_condition <- function(condition, tags) {
  any(vapply(parse_condition(condition), function(alt) {
    all(alt$yes %in% tags) && !any(alt$no %in% tags)
  }, logical(1)))
}

#' Suggest analyses from a diagnosis
#'
#' Matches the characteristics found by [diagnose()] against the rules table
#' ([rsguia_rules()]) and lists the possible analyses, each with a rationale,
#' caveats, suggested packages and an example code snippet already filled in
#' with your file and band names. The analyses are not run.
#'
#' You usually don't need to call this function: [diagnose()] already does it
#' (argument `suggest = TRUE`). Use it to redo the suggestions with other
#' rules.
#'
#' @param diagnosis An object of class `rsguia_diagnosis`.
#' @param rules Optional. A `data.frame` of rules or the path to a CSV file;
#'   see [rsguia_rules()].
#'
#' @return The same diagnosis, with the element `suggestions` (a
#'   `data.frame` with one row per analysis and dataset it applies to).
#'
#' @examples
#' r <- terra::rast(nrows = 20, ncols = 20, nlyrs = 4, crs = "EPSG:32718",
#'                  extent = terra::ext(500000, 500200, 9150000, 9150200))
#' terra::values(r) <- round(runif(terra::ncell(r) * 4, 100, 4000))
#' names(r) <- c("B2", "B3", "B4", "B8")
#' d <- diagnose(r, suggest = FALSE)
#' d <- suggest_analyses(d)
#' d$suggestions[, c("analysis", "applies_to")]
#'
#' @export
suggest_analyses <- function(diagnosis, rules = NULL) {
  check_diagnosis(diagnosis)
  rules <- if (is.null(rules)) rsguia_rules() else validate_rules(rules)
  ctx <- diagnosis$contexts

  rows <- list()
  for (k in seq_len(nrow(rules))) {
    rule <- rules[k, , drop = FALSE]
    ok <- vapply(ctx, function(cx) eval_condition(rule$condition, cx$tags), logical(1))
    targets <- ctx[ok]
    # If the rule holds for a smaller set of data (e.g. the image alone), it
    # is not repeated for larger combinations (image + points, series...)
    targets <- Filter(function(cx) {
      !any(vapply(targets, function(other) {
        length(other$items) < length(cx$items) && all(other$items %in% cx$items)
      }, logical(1)))
    }, targets)
    for (cx in targets) {
      rows[[length(rows) + 1]] <- data.frame(
        id = rule$id, analysis = rule$analysis, category = rule$category,
        context = cx$id, applies_to = cx$label,
        rationale = rule$rationale, caveats = rule$caveats,
        packages = rule$packages,
        code = build_code(rule, cx, diagnosis),
        stringsAsFactors = FALSE
      )
    }
  }
  diagnosis$suggestions <- if (length(rows)) {
    do.call(rbind, rows)
  } else {
    data.frame(id = character(), analysis = character(), category = character(),
               context = character(), applies_to = character(), rationale = character(),
               caveats = character(), packages = character(), code = character(),
               stringsAsFactors = FALSE)
  }
  diagnosis
}

#' Show the example code of a suggested analysis
#'
#' Prints the example code of one or more suggested analyses, already filled
#' in with your file and band names, ready to copy.
#'
#' @param diagnosis An object of class `rsguia_diagnosis`.
#' @param analysis Id of the analysis (e.g. `"ndvi"`, column `id` of
#'   `diagnosis$suggestions`). If omitted, shows all of them.
#'
#' @return The code, invisibly, as a character vector.
#'
#' @examples
#' r <- terra::rast(nrows = 20, ncols = 20, nlyrs = 4, crs = "EPSG:32718",
#'                  extent = terra::ext(500000, 500200, 9150000, 9150200))
#' terra::values(r) <- round(runif(terra::ncell(r) * 4, 100, 4000))
#' names(r) <- c("B2", "B3", "B4", "B8")
#' d <- diagnose(r)
#' show_code(d, "ndvi")
#'
#' @export
show_code <- function(diagnosis, analysis = NULL) {
  check_diagnosis(diagnosis)
  s <- diagnosis$suggestions
  if (is.null(s) || !nrow(s)) {
    cli::cli_abort("No suggested analyses. Run {.fun suggest_analyses} first.")
  }
  if (!is.null(analysis)) {
    unknown <- setdiff(analysis, s$id)
    if (length(unknown)) {
      cli::cli_abort(c(
        "Analysis not suggested for these data: {.val {unknown}}.",
        "i" = "Suggested: {.val {unique(s$id)}}."
      ))
    }
    s <- s[s$id %in% analysis, , drop = FALSE]
  }
  for (k in seq_len(nrow(s))) {
    cat(cli::rule(left = sprintf("%s - %s", s$analysis[k], s$applies_to[k])), "\n", sep = "")
    cat(if (is.na(s$code[k])) "# (no example code for this analysis)" else s$code[k], "\n\n", sep = "")
  }
  invisible(s$code)
}

check_diagnosis <- function(x) {
  if (!inherits(x, "rsguia_diagnosis")) {
    cli::cli_abort("{.arg diagnosis} must be the result of {.fun diagnose}.", call = parent.frame())
  }
}
