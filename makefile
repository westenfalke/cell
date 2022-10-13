.PRECIOUS: %.l

FILES_IN  := $(wildcard *.cell)
FILES_OUT := $(patsubst %.cell,%.o, $(FILES_IN))

all: FORCE
	$(MAKE) $(FILES_OUT)

%.l : %.cell
	./lexer.sh $< > $@ 

%.o : %.l
	./parser.sh $< > $@ 

clean: FORCE
	rm -rfv *.l *.o

FORCE: 