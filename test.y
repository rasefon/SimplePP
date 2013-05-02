%{
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include "context.h"

extern int yylineno;
extern int func_end_line;
extern FILE *yyin;
FILE *output_rule = NULL;
FILE *faillog = NULL;
FILE *succlog = NULL;

char *curr_id_value = NULL;
int class_tm_line = 0;
int func_tm_line = 0;
int func_start_line = 0;
int tmp_tm_line = 0;

enum transction_mode curr_class_tm = NONE;
enum transction_mode curr_func_tm = NONE;
enum transction_mode tmp_tm = NONE;

enum attribute_type tmp_at = NA;
enum attribute_type curr_class_at = NA;
enum attribute_type curr_func_at = NA;

/*flags*/
char into_class = 0;
char into_func = 0;
char should_record_line = 0;
char class_tm_recorded = 0;

void yyerror(char *s, ...);

void set_id_value(char *id_str);
void reset_id_value();

void enter_class();
void leave_class();

void enter_func();
void leave_func();

void record_line();

void set_class_tm(enum transction_mode tm);
void set_func_tm(enum transction_mode tm);
/*void record_tm(enum transction_mode tm);*/

void set_class_at(enum attribute_type at);
/*void set_func_at(enum attribute_type at);*/

void set_tm_line(int tm_line);

void log_rm_class_tm();
void log_rm_func_tm();
void log_add_start_tm();
void log_add_end_tm();
char should_add_tm();

#define YYDEBUG 1

/*#define RDEBUG1*/
#ifdef RDEBUG1
#define P1 printf
#else
#define P1 
#endif

/*#define RDEBUG2*/
#ifdef RDEBUG2
#define P2 printf
#else
#define P2 
#endif


%}

%union {
	char *strval;
}

%token TMM
%token TMCA
%token TMRA
%token TC
%token TM
%token CLASS
%token <strval> ID

%start stmt_list

%%

/*stmt: TMM | TMCA | TMRA | TC | TM | CLASS | ID |*/
    /*'{' | '}' | '(' | ')' | ';'*/

stmt_list: stmt
  | stmt_list stmt
  ;

stmt: id_stmt | block | class_stmt | func_stmt
   ;

id_stmt: ID { set_id_value($1); }
  | ';'
  | id_stmt ID
  | id_stmt ';'
  ;

block: id_stmt '{' stmt_list '}' {
     }
  | id_stmt '{' stmt_list '}' ';' {
     }
  | '{' stmt_list '}' {
     }
  | '{' stmt_list '}' ';' {
     }
  | id_stmt '{' '}' {
     }
  | id_stmt '{' '}' ';' {
     }
  | '{' '}'
  | '{' '}' ';'
  ;

prop_list: prop_stmt
  | prop_list prop_stmt
  ;

prop_stmt: TMM { 
        tmp_tm = MAN; 
        tmp_tm_line = yylineno;
        P2("tm_line:%d MAN\n:", yylineno);
      }
  | TMCA { 
        tmp_tm = AUTO_C; 
        tmp_tm_line = yylineno;
        P2("tm_line:%d TMCA\n", yylineno);
      }
  | TMRA { 
        tmp_tm = AUTO_RB; 
        tmp_tm_line = yylineno;
        P2("tm_line:%d TMRA\n", yylineno);
      }
  | TC { tmp_at = T_C; 
        /*P1("at_line:%d T_C\n", yylineno);*/
      }
  | TM { tmp_at = T_M; 
        /*P1("at_line:%d T_M\n", yylineno);*/
      }
  ;

class_stmt: prop_list CLASS {enter_class(); 
        /*set_class_at(tmp_at); */
        set_class_tm(tmp_tm); 
        set_tm_line(tmp_tm_line);
        } block { 
        log_rm_class_tm();
        leave_class();
      }
  | CLASS block 
  ;

func_stmt: prop_list {enter_func(); 
        /*set_func_at(tmp_at); */
        set_func_tm(tmp_tm);
        set_tm_line(tmp_tm_line);
        record_line();
      } 
  block { 
    P2("@class tm line:%d func tm line:%d@\n", class_tm_line, func_tm_line);
    P2("func start line:%d CTM:%d FTM:%d fn:%s\n", func_start_line, curr_class_tm, curr_func_tm, curr_id_value);
    P2("func end line:%d\n\n", func_end_line);
    log_rm_func_tm();
    log_add_start_tm();
    log_add_end_tm();
    leave_func();
      }
  ;

%%

void main(int ac, char **av)
{
  extern int yydebug;
  /*yydebug = 1;*/


  if(ac != 4) {
    /*fprintf(stderr, "Need filename and output rule.\n");*/
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, "arg1: cs file name.\n");
    fprintf(stderr, "arg2: output rule file name.\n");
    fprintf(stderr, "arg3: fail log file name.\n");
    int i;
    for(i = 1; i < ac; i++) {
      fprintf(stderr, "av[%d]:%s\n", i, av[i]);
    }
    return;
  }

  yyin = fopen(av[1], "r");

  //check file
  if ( !yyin) {
    perror(av[1]);
    return;
  }

  output_rule = fopen(av[2], "w+");
  if (!output_rule) {
    perror(av[2]);
    return;
  }

  /*faillog = fopen("./fail.log", "a+");*/
  faillog = fopen(av[3], "a+");
  if (!faillog) {
    perror("fail.log");
    return;
  }

  /*succlog = fopen("./succ.log", "a+");*/
  /*if (!succlog) {*/
    /*perror("succ.log");*/
    /*return;*/
  /*}*/

  /*if(!yyparse()) {*/
  /*[>fprintf(succlog, "Succeed to parse file: %s\n", av[1]);<]*/
  /*}*/
  /*else {*/
  if(yyparse()) {
    fprintf(faillog, "Failed to parse file: %s\n", av[1]);
  }

  fcloseall();
}

void yyerror(char *s, ...)
{
  extern yylineno;

  va_list ap;
  va_start(ap, s);

  fprintf(stdout, "%d: error: ", yylineno);
  vfprintf(stdout, s, ap);
  fprintf(stdout, "\n");
}

void set_id_value(char *id_val)
{
  P1("name:%s ic:%d if:%d\n", id_val, into_class, into_func);
  if(NULL == curr_id_value && 1 == into_class && 1 == into_func)
    curr_id_value = id_val;
}

void reset_id_value()
{ 
  curr_id_value = NULL;
}

void enter_class()
{
  P1("enter class\n");
  into_class = 1;
  reset_id_value();
}

void leave_class()
{ 
  P1("leave class\n");
  into_class = 0;
  reset_id_value();
  set_class_tm(NONE);
  set_class_at(NA);
  class_tm_recorded = 0;
  tmp_tm = NONE;
}

void enter_func()
{
  P1("enter func\n");
  into_func = 1;
  should_record_line = 1;
  reset_id_value();
}

void leave_func()
{ 
  P1("leave func\n");
  into_func = 0;
  should_record_line = 0;
  reset_id_value();
  set_func_tm(NONE);
  tmp_tm = NONE;
  /*set_func_at(NA);*/
}

void record_line()
{
  P1("record line\n");
  if(should_record_line)
    func_start_line = yylineno + 2; /* TODO may cause error!!!*/

  should_record_line = 0;
}

void set_class_tm(enum transction_mode tm)
{
  curr_class_tm = tm;
}

void set_func_tm(enum transction_mode tm)
{ 
  P2("curr_ftm:%d tm:%d\n", curr_func_tm, tm);
  curr_func_tm = tm;
}

/*void record_tm(enum transction_mode tm)*/
/*{ */
  /*if(class_tm_recorded)*/
    /*set_func_tm(tm);*/
  /*else*/
    /*set_class_tm(tm);*/
/*}*/

void set_class_at(enum attribute_type at)
{
  curr_class_at = at; 
}

/*void set_func_at(enum attribute_type at)*/
/*{*/
  /*curr_func_at = at;*/
/*}*/

void set_tm_line(int tm_line)
{
  P2("*tm_line:%d if:%d, ic:%d*\n", tm_line, into_func, into_class);
  if(into_class && !into_func) {
    class_tm_line = tm_line;
  }

  if(into_func) {
    func_tm_line = tm_line;
  }
}

void log_rm_class_tm()
{
  if(NONE != curr_class_tm) { 
    fprintf(output_rule, "-|%d\n", class_tm_line);
  }
}

void log_rm_func_tm()
{
  if (NONE != curr_func_tm) {
    fprintf(output_rule, "-|%d\n", func_tm_line);
  }
}

void log_add_start_tm()
{
  if (should_add_tm()) {
    fprintf(output_rule, "+^|%d|%s\n", func_start_line, curr_id_value);
  }
}

void log_add_end_tm()
{
  if(should_add_tm()) {
    fprintf(output_rule, "+$|%d\n", func_end_line);
  }
}

char should_add_tm()
{ 
  char should_log = 0;
  if(NONE == curr_func_tm) {
    if(AUTO_RB == curr_class_tm || AUTO_C == curr_class_tm || NONE == curr_class_tm) {
      should_log = 1;
    }
  }
  else if(AUTO_RB == curr_func_tm || AUTO_C == curr_func_tm) {
    should_log = 1; 
  }
  return should_log;
}
