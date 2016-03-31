.PHONY: pdf tex scratch

OPTIONS= --bibliography=bibliography.bib --csl=chicago-author-date.csl --filter pandoc-citeproc --template=report.xelatex --chapters

pdf:
	pandoc -s $(OPTIONS) --latex-engine=xelatex chapter1.md biblio.md -o chapter1.pdf
tex:
	pandoc -s $(OPTIONS) chapter1.md -o chapter1.tex
scratch:
	pandoc --latex-engine=xelatex --bibliography=bibliography.bib --csl=chicago-author-date.csl --template=report.xelatex --filter pandoc-citeproc  --chapters -s scratch.md -o scratch.pdf
scratch-hi:
	pandoc --latex-engine=xelatex --bibliography=bibliography.bib --csl=chicago-author-date.csl --template=report-hi.xelatex --filter pandoc-citeproc  --chapters -s scratch-hi.md -o scratch-hi.pdf

