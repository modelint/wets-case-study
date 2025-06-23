#
#*++
# PROJECT:
#	WETS
# MODULE:
#	Makefile for the WETS application domain
#*--
#

DOMAIN_NAME = wets
COVERAGEDIR = ./coverage
PROGNAME = $(DOMAIN_NAME)_test_harness

REQUIRED_DIRS = \
	$(DOCDIR)\
	$(COVERAGEDIR)\
	$(NULL)

_MKDIRS := $(shell for d in $(REQUIRED_DIRS) ;	\
	     do					\
	       [ -d $$d ] || mkdir -p $$d ;	\
	     done)

_REQHDR := $(shell [ -f micca_rt.h ] || micca -posix)

MICCAFILES =\
	$(DOMAIN_NAME).micca\
	$(DOMAIN_NAME)_pop.micca\
	$(NULL)

MICCAOPTS =\
	-stubexternalops\
	$(NULL)

CPPFLAGS=\
	-D_ISOC11_SOURCE\
	-DMRT_INSTRUMENT\
	-DBOSAL\
	-I.\
	$(NULL)

CFLAGS	=\
	-std=c11\
	-g3\
	-Wall\
	-Og\
	$(NULL)

LDFLAGS	= -g --coverage

TESTOPTS =\
	-verbose bet\
	-level info\
	-showstates\
	$(NULL)

CLEANFILES =\
	$(DOMAIN_NAME).c\
	$(DOMAIN_NAME).h\
	$(PROGNAME).c\
	$(PROGNAME)\
	bosal.h\
	*.o\
	*.ral\
	*.sqlite*\
	*.gcov\
	*.gcno\
	*.gcda\
	$(NULL)

.PHONY : all generate coverage runtests harness clean FORCE

all : $(PROGNAME) coverage

harness : $(PROGNAME)

coverage : runtests
	gcovr --print-summary --html-details --html-title "WETS Coverage"\
		--output $(COVERAGEDIR)/$(DOMAIN_NAME).html

runtests : harness $(DOMAIN_NAME)_test.test
	tclsh $(DOMAIN_NAME)_test.test $(TESTOPTS)

$(DOMAIN_NAME).o : CFLAGS += --coverage

$(DOMAIN_NAME).o : $(DOMAIN_NAME).c $(DOMAIN_NAME).h

$(DOMAIN_NAME).c $(DOMAIN_NAME).h $(DOMAIN_NAME).ral : $(MICCAFILES)
	micca -save $(DOMAIN_NAME).ral $(MICCAOPTS) $^

$(PROGNAME).c : $(DOMAIN_NAME).ral
	bosal -main -output $@ $^

$(PROGNAME) : $(PROGNAME).o $(DOMAIN_NAME).o micca_rt.o
	$(LINK.c) -o $@ $^

$(DOMAIN_NAME)_test_harness.o : $(DOMAIN_NAME)_test_harness.c\
	$(DOMAIN_NAME).h micca_rt.h micca_rt_internal.h bosal.h

bosal.h :
	bosal -header

micca_rt.h micca_rt_internal.h micca_rt.c :
	micca -posix

clean :
	$(RM) $(CLEANFILES)
	$(RM) -r coverage
