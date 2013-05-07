%option noyywrap yylineno

%x COMMENT

%{
#include "test.tab.h"
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

/*#define RDEBUG*/
#ifdef RDEBUG
#define PUTS printf
#else
#define PUTS 
#endif

extern int into_func;
extern int brace_count;

int func_end_line = 0;

void mylog(char *msg);

%}

ID          [_a-zA-Z][_a-zA-Z0-9]*
OPERATOR    [~`!#$%^&*_+\-=:',./\(\)]+ 
STR         L?\"(\\.|[^\\"])*\" 
CSSTR       @\"[^"]*\" 

%%
 /* comments */
"/*"           { BEGIN(COMMENT) ; }
<COMMENT>"*/"  { BEGIN(INITIAL); }
<COMMENT>([^*]|\n|\r\n)+|. 

 /* C++ comment, a common extension */
"//".*\n 

 /*ignore string*/
{STR} |
{CSSTR} {
  /*mylog("STR");*/
}

 /*c# region...*/
#.*

"[Transaction(TestTransactionMode.Manual)]" {
  mylog("STR");
  return TMM;
}
"[Transaction(TestTransactionMode.CommitAutomatically)]" {
  mylog("TMCA");
  return TMCA;
}
"[Transaction(TestTransactionMode.RollbackAutomatically)]" { 
  mylog("TMRA");
  return TMRA;
}

\[TestClass.*\] { 
  mylog("TC");
  return TC;
}

\[TestMethod.*\] |
\[TestCleanup.*\] |
\[TestInitialize.*\] |
\[ClassCleanup.*\] |
\[ClassInitialize.*\] { 
  mylog("TM");
  return TM;
}


class |
interface |
struct { 
  mylog("CLASS");
  return CLASS;
}

"{" { 
  mylog(yytext);
  if(into_func) {
    brace_count++;
  }
  return yytext[0];
}

"}" { 
  mylog(yytext);
  PUTS("bc:%d\n", brace_count);
  if(into_func && brace_count > 0) {
    func_end_line = yylineno;
  }
  brace_count--;
  return yytext[0];
}

";" {
  mylog(yytext);
  return yytext[0];
}

using | 
namespace |
public | 
protected |
private |
partial |
\<{ID}\> |
\[([a-zA-Z0-9,.:+!#$%^_`';=/\(\)\-\\\r\n\t ]|{STR}|{CSSTR})*\] | 
abstract |
bool |
byte |
case |
catch |
const |
double |
event |
explicit
extern
float |
finally | 
implicit
in |
int |
internal |
is |
long |
new |
object |
out |
override |
params |
try |
readonly |
ref |
sealed |
\[TestData.*\] | 
short |
siezof |
stackalloc |
static | 
string |
this |
throw |
uint |
ulong |
unchecked |
unsafe |
ushort |
virtual |
volatile |
void /* ignore all these token! */

{OPERATOR} {
  /*PUTS("OP:%s ", yytext);*/
}

{ID} { 
  PUTS("ID:%s ", yytext);
  /*PUTS("ID ");*/
  yylval.strval = strdup(yytext);
  return ID;
}

[ \t]
[\r\n]+ {
  PUTS("\n%d: ", yylineno);
}

. 

%%

void mylog(char* msg)
{
  PUTS("%s ", msg);
}
