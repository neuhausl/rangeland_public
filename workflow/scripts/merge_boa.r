#!/usr/bin/env Rscript

# taken from https://github.com/nf-core/rangeland/blob/master/bin/merge_boa.r

args = commandArgs(trailingOnly=TRUE)


if (length(args) < 3) {
    stop("\nthis program needs at least 3 inputs\n1: output filename\n2-*: input files", call.=FALSE)
}

fout <- args[1]
finp <- args[2:length(args)]
nf <- length(finp)

require(raster)


img <- brick(finp[1])
nc <- ncell(img)
nb <- nbands(img)


sum <- matrix(0, nc, nb)
num <- matrix(0, nc, nb)

for (i in 1:nf){

    data <- brick(finp[i])[]

    num <- num + !is.na(data)

    data[is.na(data)] <- 0
    sum <- sum + data

}

mean <- sum/num
img[] <- mean


writeRaster(img, filename = fout, format = "GTiff", datatype = "INT2S",
            options = c("INTERLEAVE=BAND", "COMPRESS=LZW", "PREDICTOR=2",
            "NUM_THREADS=ALL_CPUS", "BIGTIFF=YES",
            sprintf("BLOCKXSIZE=%s", img@file@blockcols[1]),
            sprintf("BLOCKYSIZE=%s", img@file@blockrows[1])))
