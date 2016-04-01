.PHONY: scratch scratch-hi


OPTIONS = --latex-engine=xelatex --bibliography=scratch.bib  --filter pandoc-citeproc --chapters -s
scratch:
	pandoc $(OPTIONS) --template=report.xelatex scratch.md -o scratch.pdf
scratch-hi:
	pandoc $(OPTIONS) --template=report-hi.xelatex scratch-hi.md -o scratch-hi.pdf

