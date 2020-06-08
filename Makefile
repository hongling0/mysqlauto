.PHONY:clean install
.PHONY:default
INCLUDE_LUA?=
INCLUDE_SKYNET?=
SHARED:=-fPIC --shared
CFLAGS=-g -O3 -Wall $(INCLUDE_LUA) $(INCLUDE_SKYNET)
TARGET:=luaclib/time.so

default:
	@echo none
clean:
	@echo none
ifneq ( $(MAKECMDGOALS),install)  
include ../skyent_3rd.mk 
install: install_skynet
endif 
