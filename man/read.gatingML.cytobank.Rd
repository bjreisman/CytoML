% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/read.gatingML.cytobank.R
\name{read.gatingML.cytobank}
\alias{read.gatingML.cytobank}
\title{Parser for gatingML exported by Cytobank}
\usage{
read.gatingML.cytobank(file, ...)
}
\arguments{
\item{file}{Gating-ML XML file}

\item{...}{additional arguments passed to the handlers of 'xmlTreeParse'}
}
\value{
a graphGML that represents the population tree.
The gate and population name are stored in nodeData of each node.
Compensation and transformations are stored in graphData.
}
\description{
The Default parser (flowUtils::read.gatingML) does not  parse the population tree as well as
the custom information from cytobank. (e.g. gate name, fcs filename).
}
\examples{
\dontrun{
xml <- system.file("extdata/cytotrol_tcell_cytobank.xml", package = "CytoML")
g <- read.gatingML.cytobank(xml) #parse the population tree
#plot(g) #visualize it
}
}
