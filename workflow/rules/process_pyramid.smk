configfile: "config/config.yaml"
# checks from dir where it is started from (always start from rangeland-main/) 

HIGHERLVL   =   config["higher_level"]
PYRAMID     =   config["pyramid"]

# input function to resolve wildcards for higher_level_processing
def get_tiles(wildcards):
    # get checkpoint ouptput of higher_lvl_parameters
    ard_dir = checkpoints.higher_lvl_parameters.get().output.merged_ard  # .output[2] 3rd output should be ard dir

    tiles = [name for name in os.listdir(ard_dir) if os.path.isdir(os.path.join(ard_dir, name))]
    return tiles

# pyramids
rule pyramids:
    input:
        higher_lvl_dummy = expand(HIGHERLVL + "trend/{tiles}", tiles=get_tiles),
        higher_lvl       = HIGHERLVL + "trend/{tile}",
        # higher_lvl as input so this rule runs after higher level processing

    output:
        pyramid = directory(PYRAMID + "{tile}"),

    container:
        config["force"]

    shell:
        """
        # create output dir
        mkdir -p {output.pyramid}

        # copy files
        results=$(find {input.higher_lvl} -name '*.tif')

        for path in $results; do
            cp "$path" "{output.pyramid}" 
        done;

        echo "START: pyramids"

        # check if there are .tif files present, "grep -q ." returns if files were found
        if find {output.pyramid} -name "*.tif" | grep -q .; then
            # start pyramids
            force-pyramid {output.pyramid}/*
        else 
            echo "no files present in: {output.pyramid} to create pyramids!"
        fi

        # remove '*.tif' files
        find "{output.pyramid}" -type f -name "*.tif" -delete;
        """