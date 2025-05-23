configfile: "config/config.yaml"
# checks from dir where it is started from (always start from rangeland-main/) 

HIGHERLVL   =   config["higher_level"]
PYRAMID     =   config["pyramid"]
        

# pyramids
rule pyramids:
    input:
        higher_lvl = HIGHERLVL + "trend/{tiled_images}",
        higher_lvl_dummy = HIGHERLVL + "trend/",
        # dummy input, so this runs after the higher level process,
        # dependency not recognized with wildcards if not used before

    output:
        pyramid = PYRAMID + "{tiled_images}",

    container:
        config["force"]

    shell:
        """
        # copy files
        cp {input.higher_lvl} {output.pyramid}

        echo "START: pyramids"

        force-pyramid {output.pyramid} 

        """