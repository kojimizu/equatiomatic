create_eq <- function(lhs,...) {
  UseMethod("create_eq", lhs)
}

#' Create the full equation
#'
#' @keywords internal
#'
#' @param lhs A character string of the left-hand side variable extracted with
#'   \code{extract_lhs}
#' @param rhs A data frame of right-hand side variables extracted with
#'   \code{extract_rhs}.
#'
#' @inheritParams extract_eq

create_eq.default <- function(lhs, rhs, ital_vars, use_coefs, coef_digits, fix_signs, model) {
  rhs$final_terms <- create_term(rhs, ital_vars)

  if (use_coefs) {
    rhs$final_terms <- add_coefs(rhs, rhs$final_terms, coef_digits)
  } else {
    rhs$final_terms <- add_greek(rhs, rhs$final_terms)
  }

  # Add error row
  error_row <- rhs[nrow(rhs) + 1,]
  error_row$term <- "error"
  error_row$final_terms <- "\\epsilon"
  rhs <- rbind(rhs, error_row)

  list(lhs = list(lhs), rhs = list(rhs$final_terms))
}

create_eq.polr <- function(lhs, rhs, ital_vars, use_coefs, coef_digits,
                          fix_signs, model) {
  rhs$final_terms <- create_term(rhs, ital_vars)

  if (use_coefs) {
    rhs$final_terms <- add_coefs(rhs, rhs$final_terms, coef_digits)
  } else {
    rhs$final_terms <- add_greek(rhs, rhs$final_terms)
  }

  splt <- split(rhs, rhs$coefficient_type)
  rhs_final <- lapply(splt$zeta$final_terms, function(x) {
    c(x, splt$coefficient$final_terms, "\\epsilon")
  })
  attributes(lhs) <- NULL 
  list(lhs = lhs, rhs = rhs_final)
}


#' Create a full term w/subscripts
#'
#' @keywords internal
#'
#' @param rhs A data frame of right-hand side variables extracted with
#'   \code{extract_rhs}.
#'
#' @inheritParams extract_eq

create_term <- function(rhs, ital_vars) {
  prim_escaped <- lapply(rhs$primary, function(x) {
    vapply(x, escape_tex, FUN.VALUE = character(1))
  })
  prim <- lapply(prim_escaped, add_tex_ital_v, ital_vars)

  subs_escaped <- lapply(rhs$subscripts, function(x) {
    vapply(x, escape_tex, FUN.VALUE = character(1))
  })
  subs <- lapply(subs_escaped, add_tex_ital_v, ital_vars)
  subs <- lapply(subs, add_tex_subscripts_v)

  final <- Map(paste0, prim, subs)

  vapply(final, add_tex_mult, FUN.VALUE = character(1))
}


#' Escape TeX
#'
#' Escape special TeX characters.
#'
#' Ten characters have special meaning in TeX \code{& \% $ # _ { } ~ ^ \\}.
#' This function either escapes them with \\, or in the case of the last three,
#' replaces them with special TeX macros.
#'
#' @keywords internal
#'
#' @param term A character string to escape
#'
#' @return A character string

escape_tex <- function(term) {
  unescaped <- c("&", "%", "$", "#", "_", "{", "}", "~", "^", "\\")
  escaped <- c("\\&", "\\%", "\\$", "\\#", "\\_", "\\{", "\\}",
               "\\char`\\~", "\\char`\\^", "\\backslash ")

  if (length(term) == 0) {
    return("")
  }

  # Split term into a vector of single characters
  characters <- strsplit(term, "")[[1]]

  # Go through term and replace all unescaped characters with their escaped versions
  replaced <- vapply(characters,
                     function(x) ifelse(x %in% unescaped,
                                        escaped[which(x == unescaped)],
                                        x),
                     FUN.VALUE = character(1))

  # Return the reassembled term
  paste0(replaced, collapse = "")
}


#' Wrap text in \code{\\text{}}
#'
#' Add tex code to make string not italicized within an equation
#'
#' @keywords internal
#'
#' @param term A character to wrap in \code{\\text{}}
#' @param ital_vars Passed from \code{extract_eq}
#'
#' @return A character string

add_tex_ital <- function(term, ital_vars) {
  if (any(nchar(term) == 0, ital_vars)) {
    return(term)
  }
  paste0("\\text{", term, "}")
}


#' Wrap text in \code{\\text{}} (vectorized)
#'
#' Add tex code to make string not italicized within an equation for a vector
#' of strings
#'
#' @keywords internal
#'
#' @return A vector of characters

add_tex_ital_v <- function(term_v, ital_vars) {
  vapply(term_v, add_tex_ital, ital_vars, FUN.VALUE = character(1))
}


#' Wrap text in \code{_{}}
#'
#' Add tex code to make subscripts for a single string
#'
#' @keywords internal
#'
#' @param term A character string to TeXify
#'
#' @return A character string

add_tex_subscripts <- function(term) {
  if (any(nchar(term) == 0)) {
    return(term)
  }
  paste0("_{", term, "}")
}


#' Wrap text in \code{_{}}
#'
#' Add tex code to make subscripts for a vector of strings
#'
#' @keywords internal
#'
#' @return A vector of characters

add_tex_subscripts_v <- function(term_v) {
  vapply(term_v, add_tex_subscripts, FUN.VALUE = character(1))
}


#' Add multiplication symbol for interaction terms
#'
#' @keywords internal

add_tex_mult <- function(term) {
  paste(term, collapse = " \\times ")
}


#' Add coefficient values to the equation
#'
#' @keywords internal

add_coefs <- function(rhs, term, coef_digits) {
  ests <- round(rhs$estimate, coef_digits)
  ifelse(
    rhs$term == "(Intercept)",
    paste0(ests, term),
    paste0(ests, "(", term, ")")
  )
}


add_greek <- function(rhs, ...) {
  UseMethod("add_greek", rhs)
}

#' Adds greek symbols to the equation
#'
#' @keywords internal

add_greek.default <- function(rhs, terms) {
  if (any(grepl("(Intercept)", terms))) {
    anno_greek("beta", seq_len(nrow(rhs)), terms)
  } else {
    ifelse(rhs$term == "(Intercept)",
           "\\alpha",
           anno_greek("beta", seq_len(nrow(rhs)) - 1, terms)
           )
  }
}

add_greek.polr <- function(rhs, terms) {
  ifelse(rhs$coefficient_type == "zeta",
         anno_greek("alpha", 
                    rev(seq_along(grep("zeta", rhs$coefficient_type)))),
         anno_greek("beta", 
                    seq_along(grep("coefficient", rhs$coefficient_type)),
                    terms)
         )
}

#' Intermediary function to wrap text in `\\beta_{}`
#'
#' @keywords internal

anno_greek <- function(greek, nums, terms = NULL) {
  greek <- paste0("\\", greek, "_{", nums,"}")
  if(!is.null(terms)) {
    greek <- paste0(greek, "(", terms, ")")
  }
  greek
}


#' Deduplicate operators
#'
#' Convert "+ -" to "-"
#'
#' @keywords internal
#'
#' @param eq String containing a LaTeX equation
#'
#' @inheritParams extract_eq
#'
fix_coef_signs <- function(eq) {
  # Side-by-side + -
  eq_clean <- gsub("\\+ -", "- ", eq)

  # + - that spans lines
  eq_clean <- gsub("\\+ \\\\\\\\\\n&\\\\quad -",
                   "- \\\\\\\\\n&\\\\quad ",
                   eq_clean)

  eq_clean
}
