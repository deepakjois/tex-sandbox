.PHONY: pdf tex

OPTIONS= --chapters -V documentclass=report -V fontsize=12pt -V papersize=a4 -V classoption=titlepage

pdf:
	pandoc -s $(OPTIONS) --latex-engine=xelatex chapter1.md -o chapter1.pdf
tex:
	pandoc -s $(OPTIONS) chapter1.md -o chapter1.tex
