rule processing:
    input:
        "pre_processed.txt"
    
    output:
        "processed.txt"
    
    shell:
        """
        echo 'convert to lowercase...'
        tr '[:upper:]' '[:lower:]' < {input} > {output}
        rm {input}
        """