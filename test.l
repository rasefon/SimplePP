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

extern char into_func;
extern int brace_count;

int func_end_line = 0;


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
  PUTS("STR");
  return TMM;
}
"[Transaction(TestTransactionMode.CommitAutomatically)]" {
  PUTS("TMCA");
  return TMCA;
}
"[Transaction(TestTransactionMode.RollbackAutomatically)]" { 
  PUTS("TMRA");
  return TMRA;
}

\[TestClass.*\] { 
  PUTS("TC");
  return TC;
}

\[TestMethod.*\] |
\[TestCleanup.*\] |
\[TestInitialize.*\] |
\[ClassCleanup.*\] |
\[ClassInitialize.*\] { 
  PUTS("TM");
  return TM;
}


class |
interface |
struct { 
  PUTS("CLASS");
  return CLASS;
}

"{" { 
  PUTS("%s ic:%d\n", yytext, into_func);
  PUTS("before bc:%d---", brace_count);
  if(into_func) {
    brace_count++;
  }
  PUTS("after bc:%d\n", brace_count);
  return yytext[0];
}

"}" { 
  PUTS("%s ic%d\n:", yytext, into_func);
  PUTS("before bc:%d---", brace_count);
  if(into_func && brace_count > 0) {
    func_end_line = yylineno;
  }
  brace_count--;
  PUTS("after bc:%d\n", brace_count);
  return yytext[0];
}

";" {
  PUTS("%s", yytext);
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

