configfile: "config/config.yaml"
# checks from dir where it is started from (always start from rangeland-main/) 

# generate processing masks
rule generate_masks:
    input:
        tmp         = "results/tmp/",
        aoi         = config["aoi"],
        datacube    = config["datacube"]
        # tmp as input, so this runs after the preparation rule
        # one output to link dependencies

    # mask for whole region
    output:
        mask = directory(config["mask"]),
    
    params:
        resolution = config["resolution"],

    container:
        config["force"]

    shell:
        """
        echo "START: generate masks"

        mkdir -p {output.mask}

        # needs to be inside output dir, aoi is in mounted data dir
        cp {input.datacube} {output.mask}

        force-cube -o {output.mask} -s {params.resolution} {input.aoi}
        """
        # force-cube command changed due to different data format
        # datacube-definition.prj needs to be in -o output directory
