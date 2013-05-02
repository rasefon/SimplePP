bison -d -g --debug --report=all test.y
flex test.l
cc -o test test.tab.c lex.yy.c -lfl
