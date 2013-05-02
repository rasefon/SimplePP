bison -d --debug --report=all test.y
flex test.l
cl /FeTest test.tab.c lex.yy.c
