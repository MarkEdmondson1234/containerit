% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/dockerfile.R
\name{dockerfile}
\alias{dockerfile}
\title{dockerfile-method}
\usage{
dockerfile(from = utils::sessionInfo(), save_image = FALSE,
  maintainer = Sys.info()[["user"]], r_version = getRVersionTag(from),
  image = imagefromRVersion(r_version), env = list(generator =
  paste("containeRit", utils::packageVersion("containeRit"))), soft = FALSE,
  copy = "script", container_workdir = "/payload", cmd = Cmd("R"),
  add_self = FALSE, vanilla = TRUE, silent = FALSE,
  versioned_libs = FALSE)
}
\arguments{
\item{from}{(sessionInfo, file or a string specifying the path to a workspace) The source of the information to construct the Dockerfile}

\item{save_image}{When TRUE, it calls \link[base]{save.image} and include the resulting .RData in the container's working directory. 
 Alternatively, you can pass a list of objects to be saved, which may also include arguments to be passed down to \code{save}. E.g. save_image = list("object1","object2", file = "path/in/wd/filename.RData").
\code{save} will be called with default arguments file = ".RData" and envir = .GlobalEnv}

\item{maintainer}{optionally specify the maintainer of the dockerfile. See documentation at \url{'https://docs.docker.com/engine/reference/builder/#maintainer'}}

\item{r_version}{(character) optionally specify the R version that should run inside the container. By default, the R version from the given sessioninfo is used (if applicable) or the version of the currently running R instance}

\item{image}{(From-object or character) optionally specify the image that shall be used for the docker container (FROM-statement)
By default, the image is determinded from the given r_version, while the version is matched with tags from the base image rocker/r-ver
see details about the rocker/r-ver at \url{'https://hub.docker.com/r/rocker/r-ver/'}}

\item{env}{optionally specify environment variables to be included in the image. See documentation: \url{'https://docs.docker.com/engine/reference/builder/#env}}

\item{soft}{(boolean) Whether to include soft dependencies when system dependencies are installed}

\item{copy}{whether and how a workspace should be copied - values: "script", "script_dir" or a list of relative file paths to be copied}

\item{container_workdir}{the working directory of the container}

\item{cmd}{The CMD statement that should be executed by default when running a parameter. Use cmd_Rscript(path) in order to reference an R script to be executed on startup}

\item{add_self}{Whether to add the package containeRit itself if loaded/attached to the session}

\item{vanilla}{Whether to use an empty vanilla session when packaging scripts and markdown files (equal to R --vanilla)}

\item{silent}{Whether or not to print information during execution}

\item{versioned_libs}{[EXPERIMENTAL] Whether it shall be attempted to match versions of linked external libraries}
}
\value{
An object of class Dockerfile
}
\description{
Create a Dockerfile based on either a sessionInfo, a workspace or a file
}
\examples{
dockerfile()


}
