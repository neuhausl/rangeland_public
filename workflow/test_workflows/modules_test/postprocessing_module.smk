rule postprocessing:
    input:
        "processed.txt"
    
    output:
        "post_processed.txt"

    shell:
        """
        echo 'convert to UPPERCASE...'
        tr '[:lower:]' '[:upper:]' < {input} > {output}
        rm {input}
        """