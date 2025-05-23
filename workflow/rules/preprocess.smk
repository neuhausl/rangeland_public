configfile: "config/config.yaml"
# checks from dir where it is started from (alway start from rangeland-main/) 

container:
    config["force"]

DATA        =   config["data"]
CUBE        =   config["datacube"]
DEM         =   config["dem"]
WVDB        =   config["wvdb"]
PREP        =   config["preparation"]
MASK        =   config["mask"]
PREPROCESS  =   config["preprocess"]
PARAMS      =   config["params"]
L2PS_SCRIPT =   config["l2ps_script"]

# Level 2 parameter file
rule prepare_lvl2:
    input: 
        allowed_tiles       = PREP + "allowed_tiles.txt",
        mask                = MASK,
        datacube            = CUBE,
        l2ps_params_script  = L2PS_SCRIPT
        # masks and allowed_tiles list outputs, so this rule runs after 

    output:
        lvl2_paramfile = PARAMS + "l2ps.prm"

    # changed due to changes in FORCE
    shell:
        """
        echo "START: Generate Parameterfile(s) for Level 2 Processing"

        # create parameter file
        force-parameter -c {output.lvl2_paramfile} LEVEL2

        # execute permission to shell script
        chmod +x {input.l2ps_params_script}

        # update parameterfile 
        {input.l2ps_params_script} {output.lvl2_paramfile} {input.datacube}

        """


# preprocessing to Level 2 ARD
rule preprocess:
    input:
        dem             = DEM + "dem.vrt",
        wvdb            = WVDB,
        allowed_tiles   = PREP + "allowed_tiles.txt",
        paramfile       = PARAMS + "l2ps.prm",
        image_dir       = DATA + "{image_dirs}/"
        # use {wildcards.image_dirs} to access the exact foldername of the images
        # use {wildcards.wildcard_name} to access exact wildcard values

    output:
        directory(PREPROCESS + "{image_dirs}"),
        # wildcards need to be resolved in next rule, it is a Snakemake design choice

    shell:
        """
        echo "START: Preprocessing (Level 2 Processing)"

        # create output dirs and copy param file
        mkdir -p {output}/param/
        mkdir -p {output}/ard/
        mkdir -p {output}/prov/
        mkdir -p {output}/tmp/
        mkdir -p {output}/log/

        cp {input.paramfile} {output}/param/l2ps.prm

        # set output directories in parameter file
        sed -i "/^DIR_LEVEL2 /c\\DIR_LEVEL2 = {output}/ard/" {output}/param/l2ps.prm
        sed -i "/^DIR_PROVENANCE /c\\DIR_PROVENANCE = {output}/prov/" {output}/param/l2ps.prm
        sed -i "/^DIR_LOG /c\\DIR_LOG = {output}/log/" {output}/param/l2ps.prm
        sed -i "/^DIR_TEMP /c\\DIR_TEMP = {output}/tmp/" {output}/param/l2ps.prm

        # temporary fix for shell script
        sed -i "/^FILE_DEM /cFILE_DEM = {input.dem}" {output}/param/l2ps.prm
        sed -i "/^DIR_WVPLUT /cDIR_WVPLUT = {input.wvdb}" {output}/param/l2ps.prm
        sed -i "/^FILE_TILE /cFILE_TILE = {input.allowed_tiles}" {output}/param/l2ps.prm
        
        echo "DONE, starting FORCE"

        # preprocessing single images
        force-l2ps {input.image_dir} {output}/param/l2ps.prm
        """

        # can't be rewritten to use {directory}/*/* instead of wildcards,
        # because it then can't scale anymore with multiple computing nodes  
