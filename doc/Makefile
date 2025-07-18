report.pdf: report.ms bib
	./crrf report.ms | groff -ms -e -t -R -T pdf >$@

clean:
	rm -f report.pdf
