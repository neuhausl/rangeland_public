#!/bin/bash

# from https://github.com/CRC-FONDA/FORCE2NXF-Rangeland/blob/main/originalWF/force-l2ps-params.sh

# set parameters - this is usually done by hand
PARAM=$1
CUBE=$2

# read grid definition
CRS=$(sed '1q;d' $CUBE)
ORIGINX=$(sed '2q;d' $CUBE)
ORIGINY=$(sed '3q;d' $CUBE)
TILESIZE=$(sed '6q;d' $CUBE)
BLOCKSIZE=$(sed '7q;d' $CUBE)

# set parameters
sed -i "/^FILE_QUEUE /cFILE_QUEUE = NULL" $PARAM
sed -i "/^DIR_LEVEL2 /cDIR_LEVEL2 = results/preprocess/ard/" $PARAM
sed -i "/^DIR_LOG /cDIR_LOG = results/log/" $PARAM
sed -i "/^DIR_TEMP /cDIR_TEMP = results/tmp/" $PARAM
sed -i "/^FILE_DEM /cFILE_DEM = data/dem/dem.vrt" $PARAM
sed -i "/^DIR_WVPLUT /cDIR_WVPLUT = data/wvdb/" $PARAM
sed -i "/^FILE_TILE /cFILE_TILE = results/preparation/allowed_tiles.txt" $PARAM
sed -i "/^DIR_PROVENANCE /cDIR_PROVENANCE = results/preprocess/prov/" $PARAM
sed -i "/^TILE_SIZE /cTILE_SIZE = $TILESIZE" $PARAM
sed -i "/^BLOCK_SIZE /cBLOCK_SIZE = $BLOCKSIZE" $PARAM
sed -i "/^ORIGIN_LON /cORIGIN_LON = $ORIGINX" $PARAM
sed -i "/^ORIGIN_LAT /cORIGIN_LAT = $ORIGINY" $PARAM
sed -i "/^PROJECTION /cPROJECTION = $CRS" $PARAM
sed -i "/^PARALLEL_READS /cPARALLEL_READS = TRUE" $PARAM
sed -i "/^NPROC /cNPROC = 56" $PARAM
sed -i "/^NTHREAD /cNTHREAD = 2" $PARAM
sed -i "/^DELAY /cDELAY = 2" $PARAM

exit 0