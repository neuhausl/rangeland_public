rule preprocessing:
    output:
        "pre_processed.txt"
        
    shell:
        """
        echo 'write to file...'
        echo 'ThIs Is A fIlE tO tEsT aLl MoDuLeS!' > {output}
        """