# Copyright 2017 Opening Reproducible Research (http://o2r.info)


# Shorthand method for creating a local Docker Image based on either an existing Dockerfile (given by folder) or a Dockerfile object
# When a Dockerfile object is written, a temporary file is written in the context directory and deleted after build 
# Currently used for testing only. 
create_localDockerImage <- function(x, host = harbor::localhost,
                                   image_name = strsplit(tempfile(pattern = "containerit_test", tmpdir = ""), "/")[[1]][2],
                                   no_cache = FALSE, use_workdir = FALSE) {
  if (is.character(x))
    docker_build(
      harbor::localhost,
      dockerfolder = x,
      new_image = image_name,
      wait = TRUE
    )
  if (inherits(x, "Dockerfile")) {
    

    tempdir <- tempfile(pattern = "dir")
    
    if(use_workdir){
      context = getwd()
      message <- paste0("Building Docker image from temporary Dockerfile in context directory:\n\t",
              context)
      futile.logger::flog.info(message)
      dockerfile_path = tempfile(pattern = "Dockerfile",tmpdir = context)
    } else{
      message <- "Building docker image from temporary docker file and directory..."
      futile.logger::flog.info(message)
      context = tempdir
      dir.create(tempdir)
      #write dockerfile into temp dir
      dockerfile_path = file.path(tempdir, "Dockerfile");
    }

  
    write(x, file = dockerfile_path)
    dockerfile_path = normalizePath(dockerfile_path)
    
    docker_build(
      host,
      dockerfolder = context,
      new_image = image_name,
      wait = TRUE,
      no_cache = no_cache,
      dockerfile = dockerfile_path
      
    )

    if(use_workdir){
      message <- "Deleting temporary Dockerfile..."
      futile.logger::flog.info(message)
      unlink(dockerfile_path, recursive = TRUE)
    }else{
      message <- "Deleting temporary Dockerfile and directory..."
      futile.logger::flog.info(message)
      unlink(tempdir, recursive = TRUE)
    }

  }
  return(image_name)
}


## R expression for writing sessioninfo as an object named 'info' to a given (temporary) rdata-file
.writeSessionInfoExp <- function(tempfile) {
  e1 <- quote(info <- sessionInfo())
  e2 <- quote(save(list = "info", file = tempfile))
  e2[[3]] <- tempfile
  #for debugging:
  #e3 <- quote(file.exists(tempfile))
  #e3[[2]] <- tempfile
  return(c(e1, e2))
}

#converts an vector or list of R expression into command line parmaeters for R (batch mode)
.exprToParam <- function(expr, e_append = append, to_string = FALSE) {
  #convert from expressions to enquoted strings
  if(to_string) #for command line execution, the commands have to be deparsed once more to strings
    expr <- sapply(expr, function(x){deparse(x, width.cutoff = 500)})
  expr <- sapply(expr, function(x){deparse(x, width.cutoff = 500)}, simplify = TRUE, USE.NAMES = FALSE)
  
  if(!is.null(e_append))
    expr <- sapply(expr, function(x) {
      e_append("-e", x)
    })
  return(unlist(as.character(expr)))
}


# Obtains a session info from a local R session executed by external system commands with the given expression expr or file
# In any case, a sessioninfo is written to a temporary file and then loaded into the current session
# If a file (R script) is given, the script is copied to a temporary file and the commands to write the sessionInfo are appended
#
# This method is used for packaging R scripts (see dockerFileFromFile) 
# and for comparing session information (see test/testtheat/test_sessioninfo_repoduce.R)
obtain_localSessionInfo <-
  function(expr = c(), 
           file = NULL, #an R script to be executed
           rmd_file = NULL, #a markdown file
           rnw_file = NULL, # a sweave file or anything that can be compiled with knitr::knit(...)
           vanilla = TRUE,
           silent = TRUE,
           slave = FALSE,
           echo = FALSE, #whether R scripts should be 'echoed'
           local_tempfile = tempfile(pattern = "rdata-sessioninfo"), local_temp_script = tempfile(pattern = "r-script")) {
    
    #append commands to create a local sessionInfo
    
    if(!is.null(file) && file.exists(file)){
      
      expr <- append(expr, call("source", file = file, echo = echo))

      #if a script file is given, create modified temporary script with commands appended for writing the sessioninfo
      #success <- file.copy(file, local_temp_script)
      #if(!success){
      #  stop("Failed to create temporary file!")
      #}
      
      #expr <- sapply(expr, deparse)
      #expr <- append("\r\n", expr) #insert line break
      #write(expr, file = local_temp_script, append = TRUE)
      #args <- local_temp_script
    }#else{

    #convert to cmd parameters
    #args <- .exprToParam(expr)
    #}
    
    
    if(!is.null(rmd_file) && file.exists(rmd_file)){
      #TODO: configure output format?
      render_call <- quote(rmarkdown::render("file"))
      render_call[[2]] <- rmd_file #replace the argument "file
      expr <- append(expr, render_call)
    }
    
    if(!is.null(rnw_file) && file.exists(rnw_file)){
      render_call <- quote(knitr::knit2pdf("file", clean = TRUE))
      render_call[[2]] <- rnw_file  #replace the argument "file
      expr <- append(expr, render_call)
    }
    
    expr <- append(expr, .writeSessionInfoExp(local_tempfile))
    args <- .exprToParam(expr, to_string = TRUE)
    if (vanilla)
      args <- append("--vanilla", args)
    
    if (slave)
      args <- append("--slave", args)
    
    if (silent)
      args <- append("--silent", args)
    
    flog.info(
      paste("Creating an R session with the following arguments:\n\t R ", paste(args, collapse = " "))
    )

    system2("R", args)
    
    if(!file.exists(local_tempfile))
      stop("Failed to execute the script locally! A sessionInfo could not be determined.")

    load(local_tempfile)
    #clean up:
    unlink(local_tempfile)
    unlink(local_temp_script)
    return(get("info"))
  }

## optains a session info from an R session executed in docker given expression expr and a docker image with R installed
# TODO: 
#  This method currently supports only expressions as an input (they sould not be to long and complex). 
#  If the method should also execute complete scripts and optain the sessionInfo, it would have to be re-written according to optain_localSessionInfo. 
#  A temporary R script must be mounted. And then exectuted inside the container.
#  As this function was only created for test purposes in order to compare sessionInfos
#  (see test/testtheat/test_sessioninfo_repoduce.R) this feature is out of scope at the moment.
obtain_dockerSessionInfo <-
  function(docker_image,
           expr = c(),
           vanilla = FALSE,
           docker_tempdir = "/tmp/containerit_temp",
           local_tempdir = tempfile(pattern = "dir"),
           deleteTempfiles = TRUE) {
    #create local temporary directory
    dir.create(local_tempdir)
    if (!dir.exists(local_tempdir))
      stop("Unable to locate temporary directory: ", local_tempdir)

    #mount option
    volume_opt = c("-v", paste0(local_tempdir, ":", docker_tempdir))

    #rdata file to which session info shall be written
    docker_tempfile =  paste0(docker_tempdir, "/", "rdata")
    local_docker_tempfile = file.path(local_tempdir, "rdata")
    #cat(writeExp(docker_tempfile))
    expr <- append(expr, .writeSessionInfoExp(docker_tempfile))
    #convert to cmd parameters
    expr <- .exprToParam(expr)

    cmd <- c("R")
    if (vanilla) {
      cmd <- append(cmd, "--vanilla")
    }
    cmd <- append(cmd, expr)
    message <- paste0("Creating R session in Docker with the following arguments:\n\t",
            "docker run ", paste(volume_opt, collapse = " ")," ",docker_image," ",paste(cmd, collapse = " "))
    futile.logger::flog.info(message)
    
    container <- harbor::docker_run(
      harbor::localhost,
      image = docker_image,
      cmd = cmd ,
      docker_opts = volume_opt
    )

    if (harbor::container_running(container))
      stop("Unexpected behavior: The container is still running!")

    harbor::container_rm(container)

    if (!file.exists(local_docker_tempfile))
      stop("Sessioninfo was not written to file (it does not exist): ",
           local_docker_tempfile)

    message <- paste("Wrote sessioninfo from Docker to this tempfile:",
            local_docker_tempfile)
    futile.logger::flog.info(message)
    load(local_docker_tempfile)
    #clean up
    if (deleteTempfiles)
      unlink(local_tempdir, recursive = TRUE)
    return(get("info"))
  }





