# put target rules here
rule all:
    input:
        "deleted.txt"


rule create_dir: 
    output:
        directory(expand("test_{no}/", no=[1,2,3,4]))

    shell:
        """
        echo "create directories"
        mkdir -p {output}
        """


rule change_dir:
    input:
        "test_{numbr}/"

    output:
        directory("changed_test_{numbr}/")

    shell:
        """
        echo "rename directories"
        mv {input} {output}
        """


rule delete_all:
    input:
        changed_dirs = expand("changed_test_{numbr}/", numbr=[1,2,3]),
        dirs = "test_4/"
    
    output: 
        "deleted.txt"

    shell:
        """
        echo "{input.changed_dirs}" >> {output}
        echo "{input.dirs}" >> {output}
        rm -rf {input}
        """
    
