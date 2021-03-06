#' Data Cleaning
#'
#' A function for scrubbing a datasetset for usage with most standard algorithms. This involves one-hot-encoding columns that are probably categorical.
#' @param dataset a list with at least the following key-worded elements:
#' \itemize{
#' \item{\code{X}}{\code{[n, d]} matrix containing \code{n} samples in \code{d} dimensions.}
#' \item{\code{Y}}{\code{[n, r]} matrix containing  or \code{[n]} vector containing regressors or class labels forsamples in \code{X}.}
#' }
#' @param clean.invalid whether to remove samples with invalid entries. Defaults to \code{TRUE}.
#' \itemize{
#' \item \code{TRUE} Remove samples that have features with \code{NaN} entries or non-finite.
#' \item \code{FALSE} Do not remove samples that have features with \code{NaN} entries or are non-finite..
#' }
#' @param clean.ohe options for whether to one-hot-encode columns. Defaults to \code{FALSE}.
#' \itemize{
#' \item{\code{clean.ohe < 1}}{Converts columns with < thr*n unique identifiers to one-hot encoded.}
#' \item{\code{is.integer(clean.ohe)}}{Converts columns with < thr unique identifiers to one-hot encoded.}
#' \item{\code{FALSE}}{Do not one-hot-encode any columns.}
#' }
#' @return A list containing at least the following key-worded elements:
#' \itemize{
#' \item{X}{\code{[m, d+r]} the array with \code{m} samples in \code{d+r} dimensions, where \code{r} is the number of additional columns appended for encodings. \code{m < n} when  there are non-finite or \code{NaN} entries. \code{colnames(dataset)} returns the column names of the cleaned columns.}
#' \item{Y}{\code{[m, r]} matrix or \code{[n]} vector containg regressors or class labels for samples in \code{X}. \code{m < n} when there are non-finite or \code{NaN} entries.}
#' \item{samples}{\code{m} the sample ids that are included in the final array, where \code{samp[i]} is the original row id corresponding to \code{Xc[i,]}. If \code{m < n}, there were non-finite or \code{NaN} entries that were purged.}
#' }
#' @author Eric Bridgeford
#' @export
clean.dataset <- function(dataset, clean.invalid=TRUE, clean.ohe=FALSE) {
  sumX <- apply(dataset$X, c(1), sum)
  Y <- dataset$Y
  y.2d <- check_ydims(Y)
  if (y.2d) {
    sumY <- apply(Y, c(1), sum)
  } else {
    sumY <- Y
  }
  n <- length(sumX)
  samp <- 1:n
  if (clean.invalid) {
    # check if any samples have invalid entries
    samp <- which(!is.nan(sumX) & is.finite(sumX) & !is.nan(sumY) & is.finite(sumY))
    exc <- which(is.nan(sumX) || !is.finite(sumX) || is.nan(sumY) || !is.finite(sumY))
  }
  # grab the appropriate samples that don't have invalid entries
  X <- dataset$X[samp,]
  if (y.2d) {
    Y <- dataset$Y[samp,]
  } else {
    Y <- dataset$Y[samp]
  }

  dimx <- dim(X)
  n <- dimx[1]; d <- dimx[2]
  if (clean.ohe < 1) {
    # if it's a threshold, it's clean.ohe*n
    Kmax <- clean.ohe*n
  } else if (round(clean.ohe) == clean.ohe) {
    # if it's an integer, it's clean.ohe
    Kmax <- clean.ohe
  } else if (!isTRUE(clean.ohe)) {
    # otherwise, if FALSE, just make it impossible to ever have a column with that
    # many entries
    Kmax <- d + 1
  }
  if (is.null(colnames(X))) {
    colnames(X) <- as.character(1:d)
  }
  # handle the X first, then handle Y
  Xce <- lapply(1:d, function(i) {
    unx <- unique(X[,i])  # unique elements in X
    cname <- colnames(X)[i]  # column names for this particular column
    x <- X[, i]  # get desired column
    K <- length(unx)
    # if 2 < K < kmax, one-hot-encode
    if (K <= Kmax & K > 2) {
      # one-hot-encode
      x <- array(0, dim=c(n, K))
      for (j in 1:length(unx)) {
        x[which(X[,i] == unx[j]), j] <- 1
      }
    }
    enc <- array(cname, dim=c(ifelse(K > Kmax || K <= 2, 1, K)))
    return(list(enc=enc, x=x))
  })
  # grab all the potentially one-hot-encoded columns
  enc <- do.call(c, lapply(Xce, function(x) x$enc))
  # grab the columns themselves
  Xc <- do.call(cbind, lapply(Xce, function(x) x$x))
  colnames(Xc) <- enc
  # return  the whole dataset, making sure to put back unused columns from the dataset
  # list at the beginning
  return(c(list(X=Xc, Y=Y, samp.incl=samp, samp.excluded=exc), dataset[!names(dataset) %in% c("X", "Y")]))
}
