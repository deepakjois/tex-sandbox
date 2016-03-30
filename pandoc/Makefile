.PHONY: pdf tex

OPTIONS= --template=report.xelatex --chapters

pdf:
	pandoc -s $(OPTIONS) --latex-engine=xelatex chapter1.md -o chapter1.pdf
tex:
	pandoc -s $(OPTIONS) chapter1.md -o chapter1.tex
