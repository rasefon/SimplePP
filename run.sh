#!/bin/bash
bison -d --debug test.y
flex test.l
cc -o test test.tab.c lex.yy.c
