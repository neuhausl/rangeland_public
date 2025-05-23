configfile: "config/config.yaml"
# checks from dir where it is started from (always start from rangeland-main/) 

HIGHERLVL   =   config["higher_level"]
CUBE        =   config["datacube"]
MOSAIC      =   config["mosaic"]

# input function to resolve wildcards for higher_level_processing
def get_tiles(wildcards):
    # get checkpoint ouptput of higher_lvl_parameters
    ard_dir = checkpoints.higher_lvl_parameters.get().output.merged_ard  # .output[2] 3rd output should be ard dir

    tiles = [name for name in os.listdir(ard_dir) if os.path.isdir(os.path.join(ard_dir, name))]
    return tiles

# mosaicking
rule mosaicking:
    input:
        higher_lvl  = expand(HIGHERLVL + "trend/{tile}", tile=get_tiles),
        datacube    = CUBE,

    output:
        mosaic = directory(MOSAIC),

    container:
        config["force"]

    shell:
        """
        # reverse renaming: transform from <Tile>_<Filename> to <Tile>/<Filename>
        results=$(find {input.higher_lvl} -name '*.tif')

        for path in $results; do
            # get name of the file
            base_name=$(basename $path)
            
            # cut tilename, after the second "_", bc <Tile>_<ID>_...
            tile_name=$(echo $base_name | cut -d'_' -f1,2)
            
            # get filename, after "_" and onwards
            file_name=$(echo $base_name | cut -d'_' -f3-)
            
            # new directory path with tilename
            new_dir="{output.mosaic}/$tile_name"
            mkdir -p "$new_dir"
            
            # new file path
            new_path="$new_dir/$file_name"
            
            # move file
            cp "$path" "$new_path"
        done

        echo "START: mosaicking"

        # datacube-dir
        force-mosaic {output.mosaic}

        """