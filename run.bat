rm -rf test.exe
bison -d --debug --report=all test.y
flex test.l
cc -o test test.tab.c lex.yy.c
