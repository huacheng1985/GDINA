library(shiny)
shinyServer(function(input, output) {

  ######## INPUTS

  output$contents1 <- renderTable({
    inFile <- input$file1
    if (is.null(inFile))
      return(NULL)
    x <- read.csv(inFile$datapath, header = input$header,
             sep = input$sep, quote = input$quote)
    head(x)
  })

  output$contents2 <- renderTable({
    inFile <- input$file2
    if (is.null(inFile))
      return(NULL)
    y <- read.csv(inFile$datapath, header = input$header,
             sep = input$sep, quote = input$quote)
    head(y)
  })


  ##################
  #  Model Estimation
  ##################

  est.result <- reactive(
    withProgress(message = 'Model Estimating', value = 0.5, {
    inFile1 <- input$file1
    dat <- read.csv(inFile1$datapath, header = input$header,
             sep = input$sep, quote = input$quote)

    inFile2 <- input$file2
    Q <- read.csv(inFile2$datapath, header = input$header,
                    sep = input$sep, quote = input$quote)
    if(input$attdis==0){
      emp <- TRUE;ho <- FALSE
    }else if(input$attdis==1){
      emp <- FALSE;ho <- TRUE
    }else if(input$attdis==2){
      emp <- FALSE;ho <- FALSE
    }
    if(input$type=="autoSelected"){
      fit <- GDINA::autoGDINA(dat = dat, Q = Q, Qvalid = FALSE,
                              alpha.level = input$alphalevel, modelselectionrule = input$waldmethod,
                              GDINA1.option = list(verbose = 0,higher.order = ho,
                          higher.order.model = input$hom,empirical = emp,
                          sequential = input$seq,
                          mono.constraint = input$mono),
                          CDM.option = list(verbose = 0,higher.order = ho,
                                                                             higher.order.model = input$hom,empirical = emp,
                                                                             sequential = input$seq,
                                                                             mono.constraint = input$mono))
      est <- fit$CDM.obj
    }else{
      est <- GDINA::GDINA(dat = dat, Q = Q, model = input$type,
                          verbose = 0,higher.order = ho,
                          higher.order.model = input$hom,empirical = emp,
                          sequential = input$seq,
                          mono.constraint = input$mono)
    }

    est
  }))


  ##################
  # Summary
  ##################
  info <- reactive({
    summary(est.result())
  })
  iter.info <- reactive({
    est.info <- function(x) {
      cat("\nThe Generalized DINA Model Framework  \n")
      packageinfo <- utils::packageDescription("GDINA")
      cat( paste( "   Beta Version " , packageinfo$Version , " (" , packageinfo$Date , ")" , sep="") , "\n" )
      cat(  "   Wenchao Ma & Jimmy de la Torre \n" )

      cat("\nNumber of items       =", extract(x,"nitem"), "\n")
      cat("Number of individuals =", extract(x,"nobs"), "\n")
      cat("Number of attributes  =", extract(x,"natt"), "\n")
      M <- c("GDINA", "DINA", "DINO", "ACDM", "LLM", "RRUM")
      cat("Number of iterations  =", extract(x,"nitr"), "\n")
      cat("Fitted model(s)       =\n")
      print(extract(x,"models"))
      if(extract(x,"att.str")){
        strc <- "User specified"
      }else {
        if(extract(x,"higher.order")){
          strc <- "Higher-order"
        }else{
          strc <- "Saturated"
        }
      }

      cat("\nAttribute structure   =",strc,"\n")
      if (extract(x,"higher.order")) cat("Higher-order model    =",extract(x,"higher.order.model"),"\n")
      tmp <- ifelse(extract(x,"sequential"),max(extract(x,"Q")),max(extract(x,"Q")[,-c(1:2)]))
      cat("Attribute level       =",ifelse(tmp>1,"Polytomous","Dichotomous"),"\n")
      cat("Response level        =",ifelse(max(extract(x,"dat"),na.rm = TRUE)>1,"Polytomous","Dichotomous"),"\n")
      cat("\nNumber of parameters  =", extract(x,"npar"), "\n")
      cat("  No. of item parameters       =",extract(x,"npar.item"),"\n")
      cat("  No. of population parameters =",extract(x,"npar.att"),"\n")
      cat("\nFor the last iteration:\n")
      cat("  Max abs change in success prob. =", format(round(extract(x,"dif.p"), 5),scientific = FALSE), "\n")
      cat("  Abs change in deviance          =", format(round(extract(x,"dif.LL"), 2),scientific = FALSE), "\n")
      cat("\nTime used             =", format(round(extract(x,"time"), 4),scientific = FALSE), "\n")

    }
    est.info(est.result())
  })


  output$info <- renderPrint({
    if (input$goButton == 0)
      return()
    info()
  })

  output$iter.info <- renderPrint({
    if (input$goButton == 0)
      return()
    iter.info()
  })


  ip <- reactive({
    if (input$goButton == 0) return()
    itemparm(est.result(),what = input$ips,withSE=TRUE)
  })

  output$ip <- renderPrint({
    if (input$goButton == 0)
      return()
    itemparm(est.result(),what = input$ips,withSE=TRUE)
  })

  output$pparm <- renderPrint({
    head(personparm(object = est.result(),what = input$pp),10)
  })

  q <- reactive({
    if (input$qvalcheck == 0)  return()
    Qval(est.result(),eps = input$PVAFcutoff)
  })
  output$sugQ <- renderPrint({
    if (input$qvalcheck == 0)  return()
    extract(q(),what = "sug.Q")
  })

makeIRFplot <- function(){
  if (input$goButton == 0)
    return()
  inFile2 <- input$file2
  Q <- read.csv(inFile2$datapath, header = input$header,
                sep = input$sep, quote = input$quote)
  if (input$item.plot<1||input$item.plot>nrow(Q)) NULL
  plotIRF(est.result(),input$item.plot,errorbar=input$IRFplotse)
}

output$plot <- renderPlot({
  if (input$goButton == 0)
    return()
  makeIRFplot()
})

makeMesaplot <- function(){
  if (input$qvalcheck == 0)  return()
  GDINA::mesaplot(q(),item = input$item.mesaplot,type = input$mesatype, data.label = input$datalabel)
}

  output$mesaplot <- renderPlot({
    if (input$qvalcheck == 0)  return()
    makeMesaplot()
  })

  output$downloadMesaplot <- downloadHandler(
    filename = function() {
      paste('MesaPlot', Sys.Date(), '.pdf', sep='')
    },
    content = function(FILE=NULL) {
      pdf(file=FILE)
      print(makeMesaplot())
      dev.off()
    }
  )


  output$downloadpp <- downloadHandler(
    # This function returns a string which tells the client
    # browser what name to use when saving the file.
    filename = function() {
      paste(input$pp, input$ppfiletype, sep = ".")
    },

    # This function should write data to a file given to it by
    # the argument 'file'.
    content = function(file) {
      sep <- switch(input$ppfiletype, "csv" = ",", "tsv" = "\t")

      # Write to a file specified by the 'file' argument
      write.table(personparm(object = est.result(),what = input$pp), file, sep = sep,
                  row.names = FALSE)
    }
  )
  output$downloadIRFplot <- downloadHandler(
    filename = function() {
      paste('IRFPlot', Sys.Date(), '.pdf', sep='')
    },
    content = function(FILE=NULL) {
      pdf(file=FILE)
      print(makeIRFplot())
      dev.off()
    }
  )



  })

