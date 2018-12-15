IDIR := src
SRCDIR := src
ODIR := obj
LDIR :=

BLACKTDIR = ../blackt
LIBSMSDIR = ../libsms

AR=ar
CXX=g++
# Compile only
CDEFINES = -DBLACKT_ENABLE_LIBPNG
#CLIBS = -lpng
CFLAGS = -std=gnu++11 -O2 -Wall -L${LIBSMSDIR} -lsms -L${BLACKTDIR} -lblackt -lpng
CINCLUDES = -I${BLACKTDIR}/src -I${LIBSMSDIR}/src
CXXFLAGS=$(CFLAGS) $(CDEFINES) $(CINCLUDES) -I$(IDIR)

LIBDEPS := $(LIBSMSDIR)/libsms.a $(BLACKTDIR)/libblackt.a

TOOLSRCS := $(wildcard $(SRCDIR)/*.cpp)
TOOLSINDIR := $(patsubst %.cpp,%,$(TOOLSRCS))
TOOLS := $(notdir $(TOOLSINDIR))

.SECONDEXPANSION:

all: blackt libsms $(TOOLS)

blackt:
	cd ${BLACKTDIR} && $(MAKE) && cd $(CURDIR)

libsms:
	cd ${LIBSMSDIR} && $(MAKE) && cd $(CURDIR)

$(TOOLS): $(SRCDIR)/$$@.cpp $(LIBDEPS)
	make blackt
	make libsms
	$(CXX) $(SRCDIR)/$@.cpp $(OBJ) -o $(notdir $@) $(CXXFLAGS)

.PHONY: blackt libsms cleanme clean

cleanme:
	rm -f $(TOOLS)

clean: cleanme
#	rm -f $(LIB)
#	rm -rf $(ODIR)
	cd ${BLACKTDIR} && $(MAKE) clean && cd $(CURDIR)
	cd ${LIBSMSDIR} && $(MAKE) clean && cd $(CURDIR)