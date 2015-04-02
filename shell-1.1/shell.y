%{
#include "node.h"
extern FILE* yyin;
extern FILE* yyout;
extern int yylineno;
extern char** environ;

/*Alias Linked List*/
typedef struct node {
    char* alias;
    char* val;
    struct node* next;
} node_t;
node_t* alias_head;

void push(node_t** head, char* alias, char* val) {
    node_t* current = *head;
    node_t* newNode = malloc(sizeof(node_t));
    newNode->alias = alias;
    newNode->val = val;
    newNode->next = NULL;
    if (current != NULL)
    {
        while (current->next != NULL && strcmp(current->alias, alias) != 0)
        {
            current = current->next;
        }
        if (strcmp(current->alias, alias) == 0)
        {
            current->val = val;
            free(newNode);
            return;
        }
        current->next = newNode;
    }
    else
    {
        *head = newNode;
    }
    
}

void print_alias_list(node_t* head)
{
    node_t* current = head;
    while (current != NULL)
    {
        printf("alias %s='%s'\n", current->alias, current->val);
        current = current->next;
    }
}

int remove_by_alias(node_t** head, char * alias) {
    node_t* current = *head;
    node_t* prev = NULL;
    while (1) {
        if (current == NULL) return -1;
        if (strcmp(current->alias, alias) == 0) break;
        prev = current;
        current = current->next;
    }
    if (current == *head) *head = current->next;
    if (prev != NULL) prev->next = current->next;
    free(current);
    return 0;
}

char* retrieve_val(node_t* head, char* alias)
{
    node_t* current = head;
    while (current != NULL)
    {
        if (strcmp(current->alias, alias) == 0)
        {
            return current->val;
        }
        current = current->next;
    }
    return NULL;
}

/*String Functions*/
char* str_replace_first(char* string, char* substr, char* replacement);

char* alias_replace(char* alias)
{
    char* val = retrieve_val(alias_head, alias);
    if (val != NULL) return val;
    return alias;
}

char* concat(char* s1, char* s2)
{
    char* result = malloc(strlen(s1)+strlen(s2)+1);
    strcpy(result, s1);
    strcat(result, s2);
    return result;
}

char* environment_replace(char* string)
{
    char* s = string;
    int control = 0;
    while(1)
    {
        int valid = 0;
        int counter = 0;
        int first = -2;
        int last = -2;
        int i;
        for (i=0; i<strlen(s); i++)
        {
            if (s[i] == '$' && first == -2) first = i;
            if (s[i] == '$' && first != -2 && valid == 0) first = i;
            if (s[i] == '{')
            {
                if (i == first + 1) valid = 1;
                if (valid && i - 1 >= 0 && s[i-1] == '$') counter++;
            }
            if (s[i] == '}')
            {
                if (valid)
                {
                    counter--;
                    if (counter == 0)
                    {
                        last = i;
                        valid = 0;
                        break;
                    }
                }
            }
        }
        if (first != -2 && last != -2)
        {
            char* temp = NULL;
            char subbuff[1000];
            char subbuff2[1000];
            memcpy(subbuff, &s[first], last - first + 1);
            subbuff[last - first + 1] = '\0';
            memcpy(subbuff2, &s[first+2], last - first - 2);
            subbuff2[last - first - 2] = '\0';
            if (control != 0) temp = s;
            if (getenv(subbuff2) != NULL) s = str_replace_first(s, subbuff, getenv(subbuff2));
            else s = str_replace_first(s, subbuff, subbuff2);
            free(temp);
            control++;
        }
        else break;
    }
    return s;
}

int has_whitespace(char* string)
{
    int i;
    for (i = 0; i < strlen(string); i++)
    {
        if (string[i] == '\t' || string[i] == ' ') return 1;
    }
    return 0;
}

int has_character(char* string, char ch)
{
    int i;
    for (i = 0; i < strlen(string); i++)
    {
        if (string[i] == ch) return 1;
    }
    return 0;
}

void replace_escape(char* str)
{
    char* p_read = str;
    char* p_write = str;
    while (*p_read) {
        *p_write = *p_read++;
        p_write += (*p_write != '\\' || *(p_write + 1) == '\\');
    }
    *p_write = '\0';
}

char* str_replace_first(char* string, char* substr, char* replacement)
{
    char* token = strstr(string, substr);
    if(token == NULL) return strdup(string);
    char* replaced_string = malloc(strlen(string) - strlen(substr) + strlen(replacement) + 1);
    memcpy(replaced_string, string, token - string);
    memcpy(replaced_string + (token - string), replacement, strlen(replacement));
    memcpy(replaced_string + (token - string) + strlen(replacement), token + strlen(substr), strlen(string) - strlen(substr) - (token - string));
    memset(replaced_string + strlen(string) - strlen(substr) + strlen(replacement), 0, 1);
    return replaced_string;
}

/* ARGS Linked List Stuff */
int get_args_list_size(arg_node * head)
{
    arg_node * current = head;
    int counter = 0;
    while (current != NULL)
    {
        if (strcmp(current->arg_str, ">") != 0 &&
            strcmp(current->arg_str, "<") != 0 &&
            strcmp(current->arg_str, "|") != 0 &&
            (current->arg_str[0]!='2' && current->arg_str[1]!='>') &&
            strcmp(current->arg_str, "&") != 0) {
                counter++;
                current = current->next; 
        }
        else break;
    }
    return counter;
}

arg_node* split_to_tokens(char* string, char* delimiter)
{
    char* token;
    char* tmp = strdup(string);
    token = strtok(tmp, delimiter);
    arg_node* head = malloc(sizeof(arg_node));
    head->next = NULL;
    head->arg_str = token;
    arg_node* current = head;
    token = strtok(NULL, delimiter); 
    while (token != NULL)
    {
          current->next = malloc(sizeof(arg_node));
          current = current->next;
          current->arg_str = token;
          current->next = NULL;  
          token = strtok(NULL, delimiter); 
    }
    return head;
}
/* end args stuff */

/* Exec stuff */
arg_node* nested_alias_replace(arg_node* args)
{
    int n = 0;
    int n2 = 0;
    while(n < 1000)
    {
        arg_node* original = args;
        n2 = 0;
        while(args->arg_str != alias_replace(args->arg_str) && n2 < 1000)
        {
            args->arg_str = alias_replace(args->arg_str);
            n2++;
        }
        if (n2 == 1000) break;
        if (has_whitespace(args->arg_str))
        {
            args = split_to_tokens(args->arg_str, " \t");
            arg_node* current = args;
            while (current->next != NULL) current = current->next;
            current->next = original->next;
            free(original);
        }
        else break;
        n++;
    }
    if (n != 1000 && n2 != 1000) return args;
    else
    {
        fprintf(stderr, "error at line %d: infinite alias expansion\n", yylineno);
        arg_node* prev = NULL;
        while (args != NULL)
        {
            prev = args;
            args = args->next;
            free(prev);
        }
        return NULL;
    }
}

void run_command(arg_node* args)
{
    args = nested_alias_replace(args);
    if (args == NULL) return; //infinite alias expansion
    arg_node* current = args;
    int num_pipes = 0;
    while (current != NULL)
    {
        if (strcmp(current->arg_str, "|") == 0) num_pipes++;
        current = current->next;
    }
    arg_node** arg_table = malloc(sizeof(arg_node*)*(num_pipes+1));
    arg_node* h = args;
    current = args;
    int index = 0;
    while (current->next != NULL)
    {
        arg_node* next_node = current->next;
        if (strcmp(current->next->arg_str, "|") == 0)
        {
            arg_table[index] = h;
            h = current->next->next;
            current->next = NULL;
            index++;
        }
        current = next_node;
    }
    if (h == NULL)
    {
        fprintf(stderr, "error at line %d: pipe at EOL\n", yylineno);
        free(arg_table);
        return;
    }
    arg_table[index] = h;
    /* Search on path if not path to file given */
    for (index = 0; index < num_pipes + 1; index++)
    {
        if ( !has_character(arg_table[index]->arg_str, '/') )
        {
            char* path = getenv("PATH");
            arg_node* paths = split_to_tokens(path, ":");
            arg_node* current_path = paths;
            char* fname;
            int found = 0;
            while (current_path != NULL && found == 0)
            {
                char* temp = concat(current_path->arg_str, "/");
                fname = concat(temp, arg_table[index]->arg_str);
                free(temp);
                if( access( fname, F_OK ) != -1 )
                {
                    found = 1;
                    arg_table[index]->arg_str = fname;
                }
                else
                {
                    free(fname);
                }
                current_path = current_path->next;
            }
            if (found == 0)
            {
                fprintf(stderr, "error at line %d: command '%s' not found\n", yylineno, arg_table[index]->arg_str);
                return;
            }
        }
        else
        {
            if( access( arg_table[index]->arg_str, F_OK|X_OK ) != 0 )
            {
                fprintf(stderr, "error at line %d: command '%s' not found\n", yylineno, arg_table[index]->arg_str);
                return;
            }
        }
    }
    if (num_pipes > 200) num_pipes = 200;
    int pipe_array[200][2];
    int n;
    for (n = 0; n < num_pipes; n++)
    {
        if (pipe(pipe_array[n]) < 0)
        {
            fprintf(stderr, "error at line %d: pipe failed\n", yylineno );
            return;
        }
    }
    int wait_for_comp = 1;
    for (index = 0; index < num_pipes + 1; index++)
    {
        if ( index == num_pipes ) {
            int arg_size = get_args_list_size(arg_table[index])+1;
            char *argv[ arg_size+1 ];
            char* input_file = "";
            char* output_file = "";
            char* err_file = "";
            int errisstdout = 0;
            char* curr_arg;
            int i = 0;
            arg_node* current = arg_table[index];
            while(current != NULL) {
                curr_arg = current->arg_str;
                if (i<arg_size-1) {argv[i] = curr_arg;} //get args before >,<,|,etc
                current = current->next;
                i++;
                if (strcmp(curr_arg, ">") == 0) { //new file for output
                    if (current == NULL)
                    {
                        fprintf(stderr, "error at line %d: no output file specified after >\n", yylineno );
                        return;
                    }
                    output_file = current->arg_str;
                    current = current->next;
                    i++;
                } else if (strcmp(curr_arg, "<") == 0) {//new file for input
                    if (current == NULL)
                    {
                        fprintf(stderr, "error at line %d: no input file specified after <\n", yylineno );
                        return;
                    }
                    input_file = current->arg_str;
                    current = current->next;
                    i++;
                } else if (strcmp(curr_arg, "2>$1") == 0) {
                    //set std err to std out
                    errisstdout = 1;
                } else if (curr_arg[0]=='2' && curr_arg[1]=='>') {
                    //set std err to another file
                    int k = 0;
                    char errf[strlen(curr_arg) - 2];
                    for(k = 0; k < strlen(curr_arg)-2; k++) {
                        errf[k] = curr_arg[k+2];
                    }
                    err_file = concat("", errf);
                } else if (curr_arg[0]=='&') {
                    //perform in background
                    wait_for_comp = 0;
                }
            }
            argv[arg_size-1] = NULL; //null terminated bruh

            int childPID = fork();
            if ( childPID == 0 ) {
                //child process
                if (input_file != "") {
                    FILE *fp_in = fopen(input_file, "a+");
                    dup2(fileno(fp_in), STDIN_FILENO);
                    fclose(fp_in);
                }
                else if (num_pipes > 0)
                {
                    dup2(pipe_array[index-1][0], STDIN_FILENO);
                    for (n = 0; n < num_pipes; n++)
                    {
                        close(pipe_array[n][0]);
                        close(pipe_array[n][1]);
                    }
                }
                if (err_file != "") {
                    FILE *fp_err = fopen(err_file, "a+");
                    dup2(fileno(fp_err), STDERR_FILENO);
                    fclose(fp_err);
                } else if (errisstdout == 1) {
                    dup2(fileno(stdout), fileno(stderr));
                }
                if (output_file != "") {
                    FILE *fp_out = fopen(output_file, "a+");
                    dup2(fileno(fp_out), STDOUT_FILENO);
                    fclose(fp_out);
                }
                execve( arg_table[index]->arg_str, argv, environ );
                perror("execve");
                int status;
            }
        }
        else if ( index == 0 )
        {
            int arg_size = get_args_list_size(arg_table[index]);
            char *argv[arg_size+1];
            int i;
            arg_node* current = arg_table[index];
            for (i = 0; i < arg_size; i++)
            {
                argv[i] = current->arg_str;
                current = current->next;
            }
            argv[arg_size] = NULL;
            int childPID = fork();
            if ( childPID == 0 )
            {
                dup2(pipe_array[index][1], STDOUT_FILENO);
                for (n = 0; n < num_pipes; n++)
                {
                    close(pipe_array[n][0]);
                    close(pipe_array[n][1]);
                }
                execve( arg_table[index]->arg_str, argv, environ );
                perror("execve");
            }
        }
        else
        {
            int arg_size = get_args_list_size(arg_table[index]);
            char *argv[arg_size+1];
            int i;
            arg_node* current = arg_table[index];
            for (i = 0; i < arg_size; i++)
            {
                argv[i] = current->arg_str;
                current = current->next;
            }
            argv[arg_size] = NULL;
            int childPID = fork();
            if ( childPID == 0 )
            {
                dup2(pipe_array[index-1][0], STDIN_FILENO);
                dup2(pipe_array[index][1], STDOUT_FILENO);
                for (n = 0; n < num_pipes; n++)
                {
                    close(pipe_array[n][0]);
                    close(pipe_array[n][1]);
                }
                execve( arg_table[index]->arg_str, argv, environ );
                perror("execve");
            }
        }
    }
    for (n = 0; n < num_pipes; n++)
    {
        close(pipe_array[n][0]);
        close(pipe_array[n][1]);
    }
    if (wait_for_comp)
    {
        while ( wait() > 0 ) {};
    }
}

/*YACC YACC YACC*/
void yyerror(const char *str)
{
        fprintf(stderr,"error at line %d: %s\n", yylineno, str);
}

int yywrap()
{
        return 1;
}

int main(int argc, char* argv[])
{       
        alias_head = NULL;
        yyparse();
} 

%}

%token BYE SETENV PRINTENV UNSETENV CD ALIAS UNALIAS TERMINATOR
%union
{
        char* string;
        arg_node* arg_n;
}
%token <string> WORD
%token <arg_n> ARGS
%type <arg_n> arg_list
%%
commands: /* empty */
        | commands error TERMINATOR { yyerrok; }
        | commands arg_list TERMINATOR { run_command($2); }
        | commands command TERMINATOR
        ;
arg_list:
    WORD arg_list { $$ = malloc(sizeof(arg_node));
                    $$->next = $2;
                    $$->arg_str = $1;}
    |
    ARGS arg_list {  $$ = $1;
                     arg_node* current = $1;
                     while (current->next != NULL) current = current->next;
                     current->next = $2;}
    |
    ARGS          { $$ = $1; }
    |
    WORD          { $$ = malloc(sizeof(arg_node));
                    $$->next = NULL;
                    $$->arg_str = $1; }
    ;
command:
        bye
        |
        setenv
        |
        printenv
        |
        unsetenv
        |
        cd
        |
        cd_no_args
        |
        alias
        |
        alias_print
        |
        unalias
        ;

bye:
        BYE
        {
                return 0;
        }
        ;
setenv:
        SETENV WORD WORD
        {
                setenv($2, $3, 1);
        }
        ;
printenv:
        PRINTENV
        {
                char **var;
                for(var=environ; *var!=NULL;++var)
                        printf("%s\n",*var);      
        }
        ;
unsetenv:
        UNSETENV WORD
        {
                unsetenv($2);
        }
        ;
cd:
        CD WORD
        {
                int ret;
                ret = chdir($2);
                if (ret != 0) fprintf(stderr, "error at line %d: path '%s' not found\n", yylineno, $2);
        }
        ;
cd_no_args:
        CD
        {
                chdir(getenv("HOME"));
        }
alias:
        ALIAS WORD WORD
        {
                push(&alias_head, $2, $3);
        }
        ;
alias_print:
        ALIAS
        {
                print_alias_list(alias_head);
        }
unalias:
        UNALIAS WORD
        {
                remove_by_alias(&alias_head, $2);
        }
        ;
%%