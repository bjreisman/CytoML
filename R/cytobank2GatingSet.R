#' A wrapper that parse the gatingML and FCS files (or cytobankExperiment object) into GatingSet
#' @param x the cytobankExperiment object or the full path of gatingML file
#' @param FCS FCS files to be loaded
#' @return a GatingSet
#' @export
#' @rdname cytobank2GatingSet
#' @examples
#' \dontrun{
#' acsfile <- system.file("extdata/cytobank_experiment.acs", package = "CytoML")
#' ce <- cytobankExperiment(acsfile)
#' xmlfile <- ce$gatingML
#' fcsFiles <- list.files(ce$fcsdir, full.names = TRUE)
#' gs <<- cytobank2GatingSet(xmlfile, fcsFiles)
#' library(ggcyto)
#' autoplot(gs[[1]])
#' }
#' @importFrom flowWorkspace GatingSet transform
#' @importFrom ncdfFlow read.ncdfFlowSet
cytobank2GatingSet.default <- function(x, FCS, ...){
  g <- read.gatingML.cytobank(x)
  fs <- read.ncdfFlowSet(FCS)
  gs <- GatingSet(fs)

  ## Compensate the data with the compensation information stored in `graphGML` object
  gs <- compensate(gs, g)

  ## Extract transformation functions from `graphGML` and transform the data
  trans <- getTransformations(g)
  if(!is.null(trans))
    gs <- transform(gs, trans)


  ##Apply gates stored in `graphGML`
  gating(g, gs)
  gs
}

#' compare the counts to cytobank's exported csv so that the parsing result can be verified.
#' @param gs parsed GatingSet
#' @param file the stats file (contains the populatio counts) exported from cytobank.
#' @param id.vars either "population" or "FCS filename" that tells whether the stats file format is one population per row or FCS file per row.
#' @param ... arguments passed to data.table::fread function
#' @return a data.table (in long format) that contains the counts from openCyto and Cytobank side by side.
#' @export compare.counts
#' @examples
#'
#' acsfile <- system.file("extdata/cytobank_experiment.acs", package = "CytoML")
#' ce <- cytobankExperiment(acsfile)
#' gs <- cytobank2GatingSet(ce)
#' ## verify the stats are correct
#' statsfile <- ce$attachments[1]
#' dt_merged <- compare.counts(gs, statsfile, id.vars = "population", skip = "FCS Filename")
#' all.equal(dt_merged[, count.x], dt_merged[, count.y], tol = 5e-4)
#'
#' @importFrom flowWorkspace getPopStats
compare.counts <- function(gs, file, id.vars = c("FCS Filename", "population"), ...){
  #load stats from cytobank
  id.vars <- match.arg(id.vars)
  variable.name <- ifelse(id.vars == "population", "FCS Filename", "population")
  cytobank_counts <- fread(file, stringsAsFactors = FALSE, blank.lines.skip = TRUE, ...)

  if(id.vars == "population"){
    #modify column name because cytobank always put FCS filename
    #as the first header regardless of the orienation of stats table
    setnames(cytobank_counts, "FCS Filename", "population")
  }
  # Melt the data
  cytobank_counts_long <- melt(cytobank_counts, variable.name = variable.name, value.name = "count", id.vars = id.vars)
  # Change column names
  setnames(cytobank_counts_long, c("FCS Filename"), c("fcs_filename"))
  # Properly format the column names
  cytobank_counts_long <- cytobank_counts_long[,population := gsub("(_EventCounts)|(Event Counts of )", "", population)]


  # extract the counts from our gating sets
  #load openCyto stats
  opencyto_counts <- getPopStats(gs, statType = "count", path = "auto")

  setnames(opencyto_counts, names(opencyto_counts), c("fcs_filename", "population", "parent", "count", "parent_count"))
  #add root entry
  root_count <- opencyto_counts[parent == "root", ]
  root_count[, population := "root"]
  root_count[, count := parent_count]
  opencyto_counts <- rbindlist(list(root_count, opencyto_counts))
  #drop the parent column for simplicity
  opencyto_counts <- opencyto_counts[,.(fcs_filename, population, count)]
  #Remove spaces in population names as cytobank removes them here
  opencyto_counts <- opencyto_counts[, population := gsub(" ", "", population)]



  # merge the two data.tables

  # set key (fcs_filename, population)
  setkey(opencyto_counts, fcs_filename, population)
  setkey(cytobank_counts_long, fcs_filename, population)
  merge(opencyto_counts, cytobank_counts_long)
}