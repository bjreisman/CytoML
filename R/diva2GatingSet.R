#' divaWorkspace class
#' Inherited from \link{flowJoWorkspace}
#' @importClassesFrom flowWorkspace flowJoWorkspace
#' @exportClass divaWorkspace
setClass("divaWorkspace", contains = "flowJoWorkspace")
# copied from "openWorkspace" method (flowWorkspace/diva branch)
#' open Diva xml workspace
#'
#' @param file xml file
#' @param options argument passed to \link{xmlTreeParse}
#' @param ... arguments passed to \link{xmlTreeParse}
#' @return a \code{divaWorkspace} object
#' @examples
#' \dontrun{
#' library(flowWorkspace)
#' library(CytoML)
#' ws <- openDiva(system.file('extdata/diva/PE_2.xml', package = "CytoML"))
#' ws
#' getSampleGroups(ws)
#' getSamples(ws)
#' gs <- parseWorkspace(ws, name = 2, subset = 1)
#' sampleNames(gs)
#' getNodes(gs)
#' plotGate(gs[[1]])
#' }
#' @export
#' @importFrom XML xmlTreeParse xpathApply xmlGetAttr
openDiva <- function(file,options = 0,...){
  #message("We do not fully support all features found in a flowJo workspace, nor do we fully support all flowJo workspaces at this time.")
  tmp<-tempfile(fileext=".xml")
  if(!file.exists(file))
    stop(file, " not found!")
  if(!file.copy(file,tmp))
    stop("Can't copy ", file, " to ", tmp)

  if(inherits(file,"character")){
    x<-xmlTreeParse(tmp,useInternalNodes=TRUE,options = options, ...);
  }else{
    stop("Require a filename of a workspace, but received ",class(x)[1]);
  }
  #    browser()
  rootNode <- names(xmlChildren(x))

  ver <- xpathApply(x, paste0("/", rootNode),function(x)xmlGetAttr(x,"version"))[[1]]
  if(rootNode == "Workspace"){
    x<-new("flowJoWorkspace",version=ver,.cache=new.env(parent=emptyenv()),file=basename(file),path=dirname(file),doc=x, options = as.integer(options))
    x@.cache$flag <- TRUE
  }else if(rootNode == "bdfacs"){
    x <- new("divaWorkspace",version=ver,.cache=new.env(parent=emptyenv()),file=basename(file),path=dirname(file),doc=x, options = as.integer(options))
    x@.cache$flag <- TRUE
  }else
    stop("Unrecognized xml root node: ", rootNode)

  return(x);
}

#' @importFrom flowWorkspace getSamples
#' @export
setMethod("getSamples","divaWorkspace",function(x){
      selectMethod("getSampleGroups","divaWorkspace")(x)
    })

#' @importFrom flowWorkspace getSampleGroups
#' @export
setMethod("getSampleGroups","divaWorkspace",function(x){
      .getSampleGroupsDiva(x)
    })
#' @importFrom plyr ldply
.getSampleGroupsDiva<-function(x){
    ldply(
        xpathApply(x@doc, "/bdfacs/experiment/specimen",function(specimen){
              samples <- xpathApply(specimen, "tube",function(tube){
                                            c(tube = xmlGetAttr(tube,"name")
                                                , sampleName = xmlValue(xmlElementsByTagName(tube,"data_filename")[[1]])
                                            )
                                  })

              samples <- ldply(samples)
              samples[["specimen"]] <- xmlGetAttr(specimen, "name")
              samples
            })
      )

}

#' @importFrom flowWorkspace show
#' @export
setMethod("show",c("divaWorkspace"),function(object){
      cat("Diva Workspace Version ",object@version,"\n");
      cat("File location: ",object@path,"\n");
      cat("File name: ",object@file,"\n");
      if(object@.cache$flag){
        cat("Workspace is open.","\n");
        cat("\nGroups in Workspace\n");

        sg <- getSampleGroups(object)

        tbl <- data.frame(table(sg$specimen))
        colnames(tbl) <- c("specimen", "samples")
        print(tbl)
      }else{
        cat("Workspace is closed.","\n")
      }
    })

#' @importFrom flowWorkspace parseWorkspace
#' @export
setMethod("parseWorkspace",signature("divaWorkspace"),function(obj, ...){
      .preprocessorDiva(obj, ...)
    })

.preprocessorDiva<- function(obj, name = NULL
                                    , subset = NULL
                                    , path = obj@path
                                    , ...)
{

  #sample info
  sg <- getSamples(obj)

  # filter by group name
  sg[["specimen"]] <- factor(sg[["specimen"]])
  groups <- levels(sg[["specimen"]])

  if(is.null(name)){
    message("Choose which group of samples to import:\n");
    groupInd <- menu(groups,graphics=FALSE);
  }else if(is.numeric(name)){
    if(length(groups)<name)
      stop("Invalid sample group index.")
    groupInd <- name
  }else if(is.character(name)){
    if(is.na(match(name,groups)))
      stop("Invalid sample group name.")
    groupInd <- match(name,groups)
  }
  group.name <- groups[groupInd]

  sg <- subset(sg, specimen == group.name)
#    browser()
  #filter by subset (sample name or numeric index)
  if(is.factor(subset)){
    subset<-as.character(subset)
  }
  if(is.character(subset)){
    sg <- subset(sg, name %in% subset)
  }else if(is.numeric(subset))
    sg <- sg[subset, ]

  #check if there are samples to parse
  sn <- sg[["sampleName"]]
  nSample <- length(sn)
  if(nSample == 0)
    stop("No samples in this workspace to parse!")


  #check duplicated sample names

  isDup <- duplicated(sn)
  if(any(isDup))
    stop("Duplicated sample names detected within group: ", paste(sampleSelected[isDup], collapse = " "), "\n Please check if the appropriate group is selected.")


  message("Parsing ", nSample," samples");
  .parseDivaWorkspace(xmlFileName=file.path(obj@path,obj@file)
                      ,samples = sn
                      , groupName = group.name
                      ,path=path
                      ,xmlParserOption = obj@options
                      ,ws = obj
                      ,...)

}

#' @importFrom XML xpathSApply
#' @importFrom flowCore read.FCS transformList spillover logicleTransform
.parseDivaWorkspace <- function(xmlFileName,samples,path,xmlParserOption, ws, groupName,...){

  if(!file.exists(xmlFileName))
    stop(xmlFileName," not found!")
#  gs <- new("GatingSet", guid = .uuid_gen(), flag = FALSE)


  dataPaths <- vector("character")
  excludefiles<-vector("logical")
  for(file in samples){

    #########################################################
    #get full path for each fcs
    #########################################################
    ##escape "illegal" characters
    file<-gsub("\\?","\\\\?",gsub("\\]","\\\\]",gsub("\\[","\\\\[",gsub("\\-","\\\\-",gsub("\\+","\\\\+",gsub("\\)","\\\\)",gsub("\\(","\\\\(",file)))))))
    absPath <- list.files(pattern=paste("^",file,"",sep=""),path=path,recursive=TRUE,full.names=TRUE)
    nFound <- length(absPath)
    if(nFound == 0){
      warning("Can't find ",file," in directory: ",path,"\n");
      excludefiles<-c(excludefiles,TRUE);

    }else if(nFound > 1){
      stop('Multiple files found for:', file)
    }else{

      dataPaths<-c(dataPaths,dirname(absPath))
      excludefiles<-c(excludefiles,FALSE);
    }
  }
  #Remove samples where files don't exist.
  if(length(which(excludefiles))>0){
    message("Removing ",length(which(excludefiles))," samples from the analysis since we can't find their FCS files.");
    samples<-samples[!excludefiles];
  }


  files<-file.path(dataPaths,samples)

  if(length(files)==0)
    stop("not sample to be added to GatingSet!")

  #load the raw data from FCS
  fs <- read.ncdfFlowSet(files,isWriteSlice=FALSE,...)

  rootDoc <- ws@doc

  xpathGroup <- paste0("/bdfacs/experiment/specimen[@name='", groupName, "']")
  biexp_list <- new.env(parent = emptyenv())
  for(file in files)
  {


        sampleName <- basename(file)

        #get tube node
        xpathSample <- paste0(xpathGroup, "/tube[data_filename='", sampleName, "']")
        sampleNode <- xpathApply(rootDoc, xpathSample)[[1]]

        # get comp & param for biexp
        biexp_para <- new.env(parent = emptyenv())
        comp <- xpathApply(sampleNode, "instrument_settings/parameter", function(paramNode, biexp_para){

          paramName <- xmlGetAttr(paramNode, "name")

          isComp <- as.logical(xmlValue(xmlElementsByTagName(paramNode, "is_log")[[1]]))
          if(isComp){

            #get biexp para

            biexp_para[[paramName]] <- c(min = as.numeric(xmlValue(xmlElementsByTagName(paramNode, "min")[[1]]))
                                          , max = as.numeric(xmlValue(xmlElementsByTagName(paramNode, "max")[[1]]))
                                          , biexp_scale = as.numeric(xmlValue(xmlElementsByTagName(paramNode, "comp_biexp_scale")[[1]]))
                                          )
            #get comp
            coef <- as.numeric(xpathSApply(paramNode, "compensation/compensation_coefficient", xmlValue))
            # browser()
            res <- list(coef)
            names(res) <- paramName

          }else
            res <- NULL
            return(res)
        }, biexp_para = biexp_para)
        #comp stored in xml seems to be incorrect

        # comp <- unlist(comp, recur = F)
        # comp <- data.frame(comp, check.names = F)
        # comp <- t(comp)
        # colnames(comp) <- rownames(comp)
        # comp <- compensation(comp)


        ##################################
        #Compensating the data
        ##################################

        cnd <- colnames(fs)

        message("loading data: ",file);
        data <- read.FCS(file)[, cnd]

        message("Compensating");
        #we use the spillover from FCS keyword
        comp <- spillover(data)
        comp <- compact(comp)
        if(length(comp) > 1)
          stop("More than one spillover found in FCS!")
        else if(length(comp) == 0)
          stop("No spillover found in FCS!")
        else
          comp <- comp[[1]]
        data <- compensate(data,comp)



        message(paste("transforming ..."))

        params <- names(biexp_para)
        # browser()
        #transform data in default flowCore logicle scale
        trans <- sapply(params, function(pn){
          this_para <- biexp_para[[pn]]
          maxValue <- 262144
          pos <- 4.5
          r <- abs(this_para[["biexp_scale"]])
          w = (pos - log10(maxValue/r))/2
          lgclObj  <- logicleTransform(w=w, t = maxValue, m = pos) #
                    }
          , simplify = FALSE)
        translist <- transformList(params, trans)
        data <- transform(data, translist)

        # browser()
        fs[[sampleName]] <- data

        biexp_list[[sampleName]] <- trans

    }


  gs <- GatingSet(fs)
  message("parsing gates ...")
  for(sn in sampleNames(gs)){
    gh <- gs[[sn]]
    this_biexp <- biexp_list[[sn]]
    xpathSample <- paste0(xpathGroup, "/tube[data_filename='", sampleName, "']")
    sampleNode <- xpathApply(rootDoc, xpathSample)[[1]]
    #assume the gates listed in xml follows the topological order
    rootNode.xml <- NULL
    gateNodes <- xpathApply(sampleNode, "gates/gate")
    for(gateNode in gateNodes)
    {
      nodeName <- xmlGetAttr(gateNode, "fullname")
      nodeName <- gsub("\\\\", "/", nodeName)
      nodeName <- basename(nodeName)
      count <- as.integer(xmlValue(xmlElementsByTagName(gateNode, "num_events")[[1]]))
      parent <- xmlElementsByTagName(gateNode, "parent")
      if(length(parent) > 0){
        parent <- xmlValue(parent[[1]])
        parent <- gsub("\\\\", "/", parent)
        parent <- gsub(rootNode.xml, "root", parent)


        regionNode <- xmlElementsByTagName(gateNode, "region")[[1]]
        xParam <- xmlGetAttr(regionNode, "xparm")
        yParam <- xmlGetAttr(regionNode, "yparm")
        gType <- xmlGetAttr(regionNode, "type")

        #parse the coodinates
        mat <- xpathSApply(regionNode, "points/point", function(pointNode)as.numeric(xmlAttrs(pointNode)))
        #rescale the gate if it is stored as unscaled value
        is.x.scaled <- as.logical(xmlValue(xmlElementsByTagName(gateNode, "is_x_parameter_scaled")[[1]]))
        is.y.scaled <- as.logical(xmlValue(xmlElementsByTagName(gateNode, "is_y_parameter_scaled")[[1]]))


        x_biexp <- this_biexp[[xParam]]
        y_biexp <- if(is.null(yParam)) NULL else this_biexp[[yParam]]
        #the gate may be either stored as simple log or 4096 scale
        #we need to rescale them to the data scale (i.e. 4.5 )
        if(!is.null(x_biexp)){#when channel is logicle scale
          if(is.x.scaled)#if the gate is scaled to 4096
            mat[1, ] <- mat[1, ]/4096 * 4.5
          else #it was in log scale
          {
            #restore to raw scale
            mat[1, ] <- 10 ^ mat[1, ]
            #logicle transform it to data scale
            mat[1, ] <- x_biexp@.Data(mat[1, ])
          }

        }
        if(!is.null(y_biexp)){#when channel is logicle scale
          if(is.y.scaled)#if the gate is scaled to 4096
            mat[2, ] <- mat[2, ]/4096 * 4.5
          else #it was in log scale
          {
            #restore to raw scale
            mat[2, ] <- 10 ^ mat[2, ]
            #logicle transform it to data scale
            mat[2, ] <- y_biexp@.Data(mat[2, ])
          }

        }

        if(gType == "RECTANGLE_REGION"){
          x <- unique(mat[1,])
          y <- unique(mat[2,])
          if(length(x)!=2||length(y)!=2)
            stop("invalid RECTANGLE_REGION from ", nodeName)
          coord <- list(x,y)
          names(coord) <- c(xParam, yParam)
          gate <- rectangleGate(.gate = coord)
        }else if(gType == "POLYGON_REGION"){
          rownames(mat) <- c(xParam, yParam)
          gate <- polygonGate(.gate = t(mat))
        }else if(gType == "INTERVAL_REGION"){
          # browser()
          coord <- list(mat[1,])
          names(coord) <- xParam
          gate <- rectangleGate(coord)
        }else
          stop("unsupported gate type: ", gType)



        add(gh, gate, parent = parent, name = nodeName)
        if(parent == "root")
          parent <- ""
        unique.path <- file.path(parent, nodeName)
        recompute(gh, unique.path)
        #save the xml counts
        set.count.xml(gh, unique.path, count)
      }else{
        rootNode.xml <- nodeName
        if(rootNode.xml!="All Events")
          stop("unrecognized root node: ", rootNode.xml)
        set.count.xml(gh, "root", count)
        next
      }


    }


  }





  message("done!")



  #we don't want to return the splitted gs since they share the same cdf and externalptr
  #thus should be handled differently(more efficiently) from the regular gslist

#    # try to post process the GatingSet to split the GatingSets(based on different the gating trees) if needed
  gslist <- suppressMessages(flowWorkspace:::.groupByTree(gs))
  if(length(gslist) > 1)
    warning("GatingSet contains different gating tree structures and must be cleaned before using it! ")
#    if(length(gslist) == 1){
#      return (gslist[[1]])
#    }else
  {
#      warning("Due to the different gating tree structures, a list of GatingSets is returned instead!")
#      return (gslist)
  }
  gs

}
