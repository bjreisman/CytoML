
test_that("autogating--tcell", {
  dataDir <- system.file("extdata",package="flowWorkspaceData")
  #load raw FCS
  fs <- read.flowSet(file.path(dataDir,"CytoTrol_CytoTrol_1.fcs"))
  gs <- GatingSet(fs)

  #compensate
  comp <- spillover(fs[[1]])[["SPILL"]]
  chnls <- colnames(comp)
  comp <- compensation(comp)
  gs <- compensate(gs, comp)

  #transform
  trans <- flowJo_biexp_trans()
  trans <- transformerList(chnls, trans)
  gs <- transform(gs, trans)

  #run auto gating
  gtFile.orig <- system.file("extdata/gating_template/tcell.csv", package = "openCyto")
  gtFile <- tempfile()
  tbl <- data.table::fread(gtFile.orig)
  tbl[5, gating_args:= "gate_range = c(1e3, 3e3)"]
  tbl[c(8,11), gating_args:= "gate_range = c(2e3, 3e3)"]
  write.csv(tbl, file = gtFile)
  gt <- gatingTemplate(gtFile)
  expect_warning(gating(gt, gs))

  toggle.helperGates(gt, gs) #hide the helper gates
  stats.orig <- getPopStats(gs[[1]])[, list(openCyto.count, node)]
  #output to flowJo
  outFile <- tempfile(fileext = ".wsp")
  GatingSet2flowJo(gs, outFile)

  #parse it back in
  ws <- openWorkspace(outFile)
  gs1 <- parseWorkspace(ws, name = 1, path = dataDir)
  stats.new <- getPopStats(gs1[[1]])[, list(openCyto.count, node)]
  expect_equal(stats.orig, stats.new, tol = 6e-4)

  ####################
  #use logicle
  ####################
  gs <- GatingSet(fs)
  gs <- compensate(gs, comp)
  trans <- estimateLogicle(gs[[1]], chnls)
  gs <- transform(gs, trans)
  gt <- gatingTemplate(gtFile.orig)
  expect_warning(gating(gt, gs))
  toggle.helperGates(gt, gs) #hide the helper gates
  stats.orig <- getPopStats(gs[[1]])[, list(openCyto.count, node)]
  #output to flowJo

  GatingSet2flowJo(gs, outFile)
  #parse it back in
  ws <- openWorkspace(outFile)
  gs1 <- parseWorkspace(ws, name = 1, path = dataDir)
  stats.new <- getPopStats(gs1[[1]])[, list(openCyto.count, node)]
  expect_equal(stats.orig, stats.new, tol = 6e-4)

})
test_that("GatingSet2flowJo: manual gates with calibration table parsed and stored as biexp ",{
  dataDir <- system.file("extdata",package="flowWorkspaceData")
  gs <- load_gs(list.files(dataDir, pattern = "gs_manual",full = TRUE))
  stats.orig <- getPopStats(gs[[1]])
  #output to flowJo
  outFile <- tempfile(fileext = ".wsp")
  GatingSet2flowJo(gs, outFile)

  #parse it back in
  ws <- openWorkspace(outFile)
  gs1 <- parseWorkspace(ws, name = 1, path = dataDir)
  stats.new <- getPopStats(gs1[[1]])
  expect_equal(stats.orig, stats.new, tol = 5e-3)
})

test_that("GatingSet2flowJo: export clustering results as derived parameters ",{
  dataDir <- system.file("extdata",package="flowWorkspaceData")
  gs <- load_gs(list.files(dataDir, pattern = "gs_manual",full = TRUE))
  gh <- gs[[1]]
  params <- parameters(getGate(gh, "CD4"))
  Rm("CD4", gs)
  Rm("CD8", gs)
  Rm("DNT", gs)
  Rm("DPT", gs)
  #run flowClust

  fr <- getData(gh, "CD3+")
  library(flowClust)
  res <- flowClust(fr, varNames = params, K = 2, nu = 1, trans = 0)
  # plot(res, data = fr)
  #add results as factor
  Map <- selectMethod("Map", sig = "flowClust")
  res <- Map(res)
  res <- as.factor(res)
  add(gh, res, parent = "CD3+", name = "flowclust")

  rect <- rectangleGate(`<B710-A>` = c(500, 1500), `<R780-A>` = c(3500, 4000))
  add(gh, rect, parent = "flowclust_1", name = "rect")
  recompute(gh)
  stats.orig <- getPopStats(gs[[1]])
  #output to flowJo
  outFile <- tempfile(fileext = ".wsp")
  # outFile <- "~/test.wsp"
  expect_message(GatingSet2flowJo(gs, outFile), "DerivedParameter")

  #parse it back in
  ws <- openWorkspace(outFile)
  gs1 <- parseWorkspace(ws, name = 1, path = dataDir)
  stats.new <- getPopStats(gs1[[1]])
  expect_equal(stats.orig[-(5:7)], stats.new, tol = 5e-3)
})

test_that("GatingSet2flowJo: handle special encoding in keywords ",{
  data(GvHD)
  fs<-GvHD[1:3]
  gs <- GatingSet(fs)
  biexpTrans <- flowJo_biexp_trans(channelRange=4096, maxValue=262144, pos=4.5,neg=0, widthBasis=-10)
  transList <- transformerList(colnames(fs[[1]])[3:6], biexpTrans)
  gs<-transform(gs,transList)
  fs_trans<- getData(gs)
  
  ###Adding the cluster
  clean.inds <- lapply(1:length(fs_trans), function(i1) return(list(ind=which(exprs(fs_trans[[i1]])[,"Time"]>793))))
  clean.clust <- lapply(1:length(fs_trans), function(x){
    vec<-rep(0,nrow(fs_trans[[x]]))
    if (length(clean.inds[[x]]$ind)>0)
    {
      
      vec[clean.inds[[x]]$ind]<-1
    }
    # }else{
    #   vec[[1]]<-1
    # }
    vec <- as.factor(vec)
    levels(vec) <- c("0", "1")
    return(vec)
  })
  names(clean.clust)<-sampleNames(fs_trans)
  
  add(gs,clean.clust, parent="root",name = "Clean")
  recompute(gs)
  
  #add one gate
  rg <- rectangleGate("FSC-H"=c(200,400), "SSC-H"=c(250, 400),
                      filterId="rectangle")
  
  
  
  nodeID<-add(gs, rg,parent="Clean_0")#it is added to root node by default if parent is not specified
  recompute(gs)
  autoplot(gs, "rectangle")
  
  #add a quadGate
  qg <- quadGate("FL1-H"=1e3, "FL2-H"=1.5e3)
  nodeIDs<-add(gs,qg,parent="rectangle")
  recompute(gs)

  outFile <- tempfile(fileext = ".wsp")
  outDir <- dirname(outFile)
  GatingSet2flowJo(gs, outFile)
  write.flowSet(fs, outDir)
  ws <- openWorkspace(outFile)
  gs2 <- parseWorkspace(ws, name = 1)
  # stats1 <- getPopStats(gs)
  expect_is(gs2, "GatingSet")
})
