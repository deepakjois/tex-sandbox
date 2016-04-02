.PHONY: scratch scratch-hi


OPTIONS = --parse-raw --latex-engine=xelatex --bibliography=scratch.bib  --filter pandoc-citeproc --chapters -s
scratch-pdf:
	pandoc $(OPTIONS) --template=report.xelatex scratch.md -o scratch.pdf
scratch-pdf-hi:
	pandoc $(OPTIONS) --template=report-hi.xelatex scratch-hi.md -o scratch-hi.pdf
scratch-tex:
	pandoc $(OPTIONS) --template=report.xelatex scratch.md -o scratch.tex
scratch-tex-hi:
	pandoc $(OPTIONS) --template=report-hi.xelatex scratch-hi.md -o scratch-hi.tex
