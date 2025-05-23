configfile: "config/config.yaml"
# checks from dir where it is started from (always start from rangeland-main/) 

# generate a tile allow-list
rule generate_allowed_tiles_list:
    input:
        tmp      = "results/tmp",
        aoi      = config["aoi"],
        datacube = config["datacube"]
        # tmp as input, so this runs after the preparation rule
        # one output to link dependencies 

    # allowed tiles
    output:    
        allowed_tiles = config["preparation"] + "allowed_tiles.txt"

    params:
        prep = config["preparation"]

    container:
        config["force"]

    shell:
        """
        echo "START: generate allowed_tiles-list"

        mkdir -p {params.prep}

        # needs to be inside output dir, aoi is in mounted data dir
        cp {input.datacube} {params.prep}

        force-tile-extent {input.aoi} {params.prep} {output.allowed_tiles}
        """