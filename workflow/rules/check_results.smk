configfile: "config/config.yaml"
# checks from dir where it is started from (always start from rangeland-main/) 

DATA        =   config["data"]
TREND       =   config["trend"]
SCRIPT      =   config["scripts"]

rule check_results:
    input:
        mosaic = TREND + "mosaic/",
        test_script = SCRIPT + "check_results.r",
        woody = "reference/woody_cover_chg_ref.tif",
        woody_yoc = "reference/woody_cover_yoc_ref.tif",
        herbaceous = "reference/herbaceous_cover_chg_ref.tif",
        herbaceous_yoc = "reference/herbaceous_cover_yoc_ref.tif",
        peak = "reference/peak_chg_ref.tif",
        peak_yoc = "reference/peak_yoc_ref.tif",

    output:
        check_results = directory(TREND + "mosaic/sorted/"),

    container:
        "docker://rocker/geospatial:3.6.2" # old version, otherwise singularity cannot pull docker image

    params:
        r_run = 'docker run --rm -v $(pwd):/reference -v $(pwd):/results -w /results --user "$(id -u):$(id -g)" ' + 'rocker/geospatial:4.3.1'

    shell:
        """
        echo "Check results..."

        mkdir -p {output.check_results}
        
        ##### the following part only restructures files into directories, but is not needed #####

        vrt_files=`find -L {input.mosaic} -type f -name '*.vrt'`
        
        # move .vrt files into own dir and corresponding .tif files according to their tile_ID
        for path in $vrt_files; do
            tif_files=$(find -L {input.mosaic} -type f -name "$(basename "$path" .vrt).tif")

            for tif in $tif_files; do
                tile_name=$(basename $(dirname $tif))
                mkdir -p {input.mosaic}/sorted/$(basename $path .vrt)/$tile_name
                cp $tif {input.mosaic}/sorted/$(basename $path .vrt)/$tile_name
            done;

            mkdir -p {input.mosaic}/sorted/$(basename $path .vrt)/mosaic/
            # ".vrt" in the basename section removes the extension

            cp $path {input.mosaic}/sorted/$(basename $path .vrt)/mosaic/
        done;

        ##### the following part only restructures files into directories, but is not needed #####

        chmod +x {input.test_script}
        docker pull rocker/geospatial:latest
        {params.r_run} {input.test_script} {input.mosaic}/mosaic/ {input.woody} {input.woody_yoc} {input.herbaceous} {input.herbaceous_yoc} {input.peak} {input.peak_yoc}

        touch {output.check_results} 
        """
