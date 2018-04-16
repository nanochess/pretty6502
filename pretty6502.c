/*
** Pretty6502
**
** by Oscar Toledo G.
**
** © Copyright 2017 Oscar Toledo G.
**
** Creation date: Nov/03/2017.
** Revision date: Nov/06/2017. Processor selection. Indents nested IF/ENDIF.
**                             Tries to preserve vertical structure of comments.
**                             Allows label in its own line. Allows to change case
**                             of mnemonics and directives.
** Revision date: Apr/16/2018. Added support for Z80 + tniASM. Solved bug in
**                             processing of apostrophe in operand.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define VERSION "v0.3"
int tabs;
int processor;

/*
** 6502 mnemonics
*/
char *mnemonics_6502[] = {
	"adc", "anc", "and", "ane", "arr", "asl", "asr", "bcc",
	"bcs", "beq", "bit", "bmi", "bne", "bpl", "brk", "bvc",
	"bvs", "clc", "cld", "cli", "clv", "cmp", "cpx", "cpy",
	"dcp", "dec", "dex", "dey", "eor", "inc", "inx", "iny",
	"isb", "jmp", "jsr", "las", "lax", "lda", "ldx", "ldy",
	"lsr", "lxa", "nop", "ora", "pha", "php", "pla", "plp",
	"rla", "rol", "ror", "rra", "rti", "rts", "sax", "sbc",
	"sbx", "sec", "sed", "sei", "sha", "shs", "shx", "shy",
	"slo", "sre", "sta", "stx", "sty", "tax", "tay", "tsx",
	"txa", "txs", "tya", NULL,
};

/*
** Z80 mnemonics
*/
char *mnemonics_z80[] = {
    "adc",  "add",  "and",  "bit",  "call", "ccf",  "cp",   "cpd",
    "cpdr", "cpi",  "cpir", "cpl",  "daa",  "dec",  "di",   "djnz",
    "ei",   "ex",   "exx",  "halt", "im",   "in",   "inc",  "ind",
    "indr", "ini",  "inir", "jp",   "jr",   "ld",   "ldd",  "lddr",
    "ldi",  "ldir", "neg",  "nop",  "or",   "otdr", "otir", "out",
    "outd", "outi", "pop",  "push", "res",  "ret",  "reti", "retn",
    "rl",   "rla",  "rlc",  "rlca", "rld",  "rr",   "rra",  "rrc",
    "rrca", "rrd",  "rst",  "sbc",  "scf",  "set",  "sla",  "sra",
    "srl",  "sub",  "xor",  NULL,
};

#define DONT_RELOCATE_LABEL	0x01
#define LEVEL_IN		0x02
#define LEVEL_OUT		0x04
#define LEVEL_MINUS		0x08

/*
** DASM directives
*/
struct {
	char *directive;
	int flags;
} directives_dasm[] = {
	"=",		DONT_RELOCATE_LABEL,
	"align",	0,
	"byte",		0,
	"dc",		0,
	"ds",		0,
	"dv",		0,
	"echo",		0,
	"eif",		LEVEL_OUT,
	"else",		LEVEL_MINUS,
	"end",		0,
	"endif",	LEVEL_OUT,
	"endm",		LEVEL_OUT,
	"eqm",		DONT_RELOCATE_LABEL,
	"equ",		DONT_RELOCATE_LABEL,
	"err",		0,
	"hex",		0,
	"if",		LEVEL_IN,
	"ifconst",	LEVEL_IN,
	"ifnconst",	LEVEL_IN,
	"incbin",	0,
	"incdir",	0,
	"include",	0,
	"list",		0,
	"long",		0,
	"mac",		LEVEL_IN,
	"mexit",	0,
	"org",		0,
	"processor",	0,
	"rend",		0,
	"repeat",	LEVEL_IN,
	"repend",	LEVEL_OUT,
	"rorg",		0,
	"seg",		0,
	"set",		DONT_RELOCATE_LABEL,
	"subroutine",	DONT_RELOCATE_LABEL,
	"trace",	0,
	"word",		0,
	NULL,		0,
};

/*
** tniASM directives
*/
struct {
    char *directive;
    int flags;
} directives_tniasm[] = {
    "cpu",      0,
    "db",       0,
    "dc",       0,
    "ds",       0,
    "dw",       0,
    "dephase",  0,
    "else",		LEVEL_MINUS,
    "endif",	LEVEL_OUT,
    "equ",		DONT_RELOCATE_LABEL,
    "fname",    0,
    "forg",     0,
    "if",		LEVEL_IN,
    "ifdef",	LEVEL_IN,
    "ifexist",	LEVEL_IN,
    "incbin",   0,
    "include",  0,
    "org",      0,
    "phase",    0,
    "rb",       0,
    "rw",       0,
    NULL,		0,
};

/*
** Comparison without case
*/
int memcmpcase(char *p1, char *p2, int size)
{
	while (size--) {
		if (tolower(*p1) != tolower(*p2))
			return 1;
		p1++;
		p2++;
	}
	return 0;
}

/*
** Check for opcode or directive
*/
int check_opcode(char *p1, char *p2)
{
	int c;
	int length;

    if (processor == 1) {
        for (c = 0; directives_dasm[c].directive != NULL; c++) {
            length = strlen(directives_dasm[c].directive);
            if ((*p1 == '.' && length == p2 - p1 - 1 && memcmpcase(p1 + 1, directives_dasm[c].directive, p2 - p1 - 1) == 0) || (length == p2 - p1 && memcmpcase(p1, directives_dasm[c].directive, p2 - p1) == 0)) {
                return c + 1;
            }
        }
        for (c = 0; mnemonics_6502[c] != NULL; c++) {
            length = strlen(mnemonics_6502[c]);
            if (length == p2 - p1 && memcmpcase(p1, mnemonics_6502[c], p2 - p1) == 0)
                return -(c + 1);
        }
    }
    if (processor == 2) {
        for (c = 0; directives_tniasm[c].directive != NULL; c++) {
            length = strlen(directives_tniasm[c].directive);
            if (length == p2 - p1 && memcmpcase(p1, directives_tniasm[c].directive, p2 - p1) == 0) {
                return c + 1;
            }
        }
        for (c = 0; mnemonics_z80[c] != NULL; c++) {
            length = strlen(mnemonics_z80[c]);
            if (length == p2 - p1 && memcmpcase(p1, mnemonics_z80[c], p2 - p1) == 0)
                return -(c + 1);
        }
    }
	return 0;
}

/*
** Request space in line
*/
void request_space(FILE *output, int *current, int new, int force)
{

	/*
	** If already exceeded space...
	*/
	if (*current >= new) {
		if (force)
			fputc(' ', output);	
		(*current)++;
		return;
	}

	/*
	** Advance one step at a time
	*/
	while (1) {
		if (tabs == 0) {
			fprintf(output, "%*s", new - *current, "");
			*current = new;
		} else {
			fputc('\t', output);
			*current = (*current + tabs) / tabs * tabs;
		}
		if (*current >= new) 
			return;
	}
}

/*
** Main program
*/
int main(int argc, char *argv[])
{
	int c;
	int style;
	int start_mnemonic;
	int start_operand;
	int start_comment;
	int align_comment;
	int nesting_space;
	int labels_own_line;
	FILE *input;
	FILE *output;
	int allocation;
	char *data;
	char *p;
	char *p1;
	char *p2;
	char *p3;
	int current_column;
	int request;
	int current_level;
	int prev_comment_original_location;
	int prev_comment_final_location;
	int flags;
	int mnemonics_case;
	int directives_case;

	/*
	** Show usage if less than 3 arguments (program name counts as one)
	*/
	if (argc < 3) {
		fprintf(stderr, "\n");
		fprintf(stderr, "Pretty6502 " VERSION " by Oscar Toledo G. http://nanochess.org/\n");
		fprintf(stderr, "\n");
		fprintf(stderr, "Usage:\n");
		fprintf(stderr, "    pretty6502 [args] input.asm output.asm\n");
		fprintf(stderr, "\n");
		fprintf(stderr, "DON'T USE SAME OUTPUT FILE AS INPUT, though it's possible,\n");
		fprintf(stderr, "you can DAMAGE YOUR SOURCE if this program has bugs.\n");
		fprintf(stderr, "\n");
		fprintf(stderr, "Arguments:\n");
		fprintf(stderr, "    -s0       Code in four columns (default)\n");
		fprintf(stderr, "              label: mnemonic operand comment\n");
		fprintf(stderr, "    -s1       Code in three columns\n");
		fprintf(stderr, "              label: mnemonic+operand comment\n");
		fprintf(stderr, "    -p0       Processor unknown\n");
        fprintf(stderr, "    -p1       Processor 6502 + DASM syntax (default)\n");
        fprintf(stderr, "    -p2       Processor Z80 + tniASM syntax\n");
		fprintf(stderr, "    -m8       Start of mnemonic column (default)\n");
		fprintf(stderr, "    -o16      Start of operand column (default)\n");
		fprintf(stderr, "    -c32      Start of comment column (default)\n");
		fprintf(stderr, "    -t8       Use tabs of size 8 to reach column\n");
		fprintf(stderr, "    -t0       Use spaces to align (default)\n");
		fprintf(stderr, "    -a0       Align comments to nearest column\n");
		fprintf(stderr, "    -a1       Comments at line start are aligned\n");
		fprintf(stderr, "              to mnemonic (default)\n");
		fprintf(stderr, "    -n4       Nesting spacing (can be any number\n");
		fprintf(stderr, "              of spaces or multiple of tab size)\n");
		fprintf(stderr, "    -l        Puts labels in its own line\n");
		fprintf(stderr, "    -dl       Change directives to lowercase\n");
		fprintf(stderr, "    -du       Change directives to uppercase\n");
		fprintf(stderr, "    -ml       Change mnemonics to lowercase\n");
		fprintf(stderr, "    -mu       Change mnemonics to uppercase\n");
		fprintf(stderr, "\n");
		fprintf(stderr, "Assumes all your labels are at start of line and there is space\n");
		fprintf(stderr, "before mnemonic.\n");
		fprintf(stderr, "\n");
		fprintf(stderr, "Accepts any assembler file where ; means comment\n");
		fprintf(stderr, "[label] mnemonic [operand] ; comment\n");
		exit(1);
	}

	/*
	** Default settings
	*/
	style = 0;
	processor = 1;
	start_mnemonic = 8;
	start_operand = 16;
	start_comment = 32;
	tabs = 0;
	align_comment = 1;
	nesting_space = 4;
	labels_own_line = 0;
	mnemonics_case = 0;
	directives_case = 0;

	/*
	** Process arguments
	*/
	c = 1;
	while (c < argc - 2) {
		if (argv[c][0] != '-') {
			fprintf(stderr, "Bad argument\n");
			exit(1);
		}
		switch (tolower(argv[c][1])) {
			case 's':	/* Style */
				style = atoi(&argv[c][2]);
				if (style != 0 && style != 1) {
					fprintf(stderr, "Bad style code: %d\n", style);	
					exit(1);
				}
				break;
			case 'p':	/* Processor */
				processor = atoi(&argv[c][2]);
				if (processor < 0 || processor > 2) {
					fprintf(stderr, "Bad processor code: %d\n", processor);	
					exit(1);
				}
				break;
			case 'm':	/* Mnemonic start */
				if (tolower(argv[c][2]) == 'l') {
					mnemonics_case = 1;
				} else if (tolower(argv[c][2]) == 'u') {
					mnemonics_case = 2;
				} else { 	
					start_mnemonic = atoi(&argv[c][2]);
				}
				break;
			case 'o':	/* Operand start */
				start_operand = atoi(&argv[c][2]);
				break;
			case 'c':	/* Comment start */
				start_comment = atoi(&argv[c][2]);
				break;
			case 't':	/* Tab size */
				tabs = atoi(&argv[c][2]);
				break;
			case 'a':	/* Comment alignment */
				align_comment = atoi(&argv[c][2]);
				if (align_comment != 0 && align_comment != 1) {
					fprintf(stderr, "Bad comment alignment: %d\n", align_comment);
					exit(1);
				}
				break;
			case 'n':	/* Nesting space */
				nesting_space = atoi(&argv[c][2]);
				break;
			case 'l':	/* Labels in own line */
				labels_own_line = 1;
				break;
			case 'd':	/* Directives */
				if (tolower(argv[c][2]) == 'l') {
					directives_case = 1;
				} else if (tolower(argv[c][2]) == 'u') {
					directives_case = 2;
				} else { 	
					fprintf(stderr, "Unknown argument: %c%c\n", argv[c][1], argv[c][2]);
				}
				break;
			default:	/* Other */
				fprintf(stderr, "Unknown argument: %c\n", argv[c][1]);
				exit(1);
		}
		c++;
	}

	/*
	** Validate constraints
	*/
	if (style == 1) {
		if (start_mnemonic > start_comment) {
			fprintf(stderr, "Operand error: -m%d > -c%d\n", start_mnemonic, start_comment);
			exit(1);
		}
		start_operand = start_mnemonic;
	} else if (style == 0) {
		if (start_mnemonic > start_operand) {
			fprintf(stderr, "Operand error: -m%d > -o%d\n", start_mnemonic, start_operand);
			exit(1);
		}
		if (start_operand > start_comment) {
			fprintf(stderr, "Operand error: -o%d > -c%d\n", start_operand, start_comment);
			exit(1);
		}
	}
	if (tabs > 0) {
		if (start_mnemonic % tabs) {
			fprintf(stderr, "Operand error: -m%d isn't a multiple of %d\n", start_mnemonic, tabs);
			exit(1);
		}
		if (start_operand % tabs) {
			fprintf(stderr, "Operand error: -m%d isn't a multiple of %d\n", start_operand, tabs);
			exit(1);
		}
		if (start_comment % tabs) {
			fprintf(stderr, "Operand error: -m%d isn't a multiple of %d\n", start_comment, tabs);
			exit(1);
		}
		if (nesting_space % tabs) {
			fprintf(stderr, "Operand error: -n%d isn't a multiple of %d\n", nesting_space, tabs);
			exit(1);
		}
	}

	/*
	** Open input file, measure it and read it into buffer
	*/
	input = fopen(argv[c], "rb");
	if (input == NULL) {
		fprintf(stderr, "Unable to open input file: %s\n", argv[c]);
		exit(1);
	}
	fprintf(stderr, "Processing %s...\n", argv[c]);
	fseek(input, 0, SEEK_END);
	allocation = ftell(input);
	data = malloc(allocation + sizeof(char));
	if (data == NULL) {
		fprintf(stderr, "Unable to allocate memory\n");
		fclose(input);
		exit(1);
	}
	fseek(input, 0, SEEK_SET);
	if (fread(data, sizeof(char), allocation, input) != allocation) {
		fprintf(stderr, "Something went wrong reading the input file\n");
		fclose(input);
		free(data);
		exit(1);
	}
	fclose(input);

	/*
	** Ease processing of input file
	*/
	request = 0;
	p1 = data;
	p2 = data;
	while (p1 < data + allocation) {
		if (*p1 == '\r') {	/* Ignore \r characters */
			p1++;
			continue;
		}
		if (*p1 == '\n') {
			p1++;
			*p2++ = '\0';	/* Break line */
			request = 1;
			continue;
		}
		*p2++ = *p1++;
		request = 0;
	}
	if (request == 0) 
		*p2++ = '\0';	/* Force line break */
	allocation = p2 - data;

	/*
	** Now generate output file
	*/
	c++;
	output = fopen(argv[c], "w");
	if (output == NULL) {
		fprintf(stderr, "Unable to open output file: %s\n", argv[c]);
		exit(1);
	}
	prev_comment_original_location = 0;
	prev_comment_final_location = 0;
	current_level = 0;
	p = data;
	while (p < data + allocation) {
		current_column = 0;
		p1 = p;
		p2 = p1;
		while (*p2 && !isspace(*p2) && *p2 != ';')
			p2++;
		if (p2 - p1) {	/* Label */
			fwrite(p1, sizeof(char), p2 - p1, output);
			current_column = p2 - p1;
			p1 = p2;
		} else {
			current_column = 0;
		}
		while (*p1 && isspace(*p1))
			p1++;
		flags = 0;
		if (*p1 && *p1 != ';') {	/* Mnemonic */
			p2 = p1;
			while (*p2 && !isspace(*p2) && *p2 != ';')
				p2++;
			if (processor != 0) {
				c = check_opcode(p1, p2);
				if (c == 0) {
					request = start_mnemonic;			
				} else if (c < 0) {
					request = start_mnemonic;
				} else {
                    if (processor == 1)
                        flags = directives_dasm[c - 1].flags;
                    else if (processor == 2)
                        flags = directives_tniasm[c - 1].flags;
					if (flags & DONT_RELOCATE_LABEL)
						request = start_operand;
					else
						request = start_mnemonic;
				}
			} else {
				request = start_mnemonic;
				c = 0;
			}
			if (c <= 0) {
				if (mnemonics_case == 1) {
					p3 = p1;
					while (p3 < p2) {
						*p3 = tolower(*p3);
						p3++;
					}
				} else if (mnemonics_case == 2) {
					p3 = p1;
					while (p3 < p2) {
						*p3 = toupper(*p3);
						p3++;
					}
				}
			} else {
				if (directives_case == 1) {
					p3 = p1;
					while (p3 < p2) {
						*p3 = tolower(*p3);
						p3++;
					}
				} else if (directives_case == 2) {
					p3 = p1;
					while (p3 < p2) {
						*p3 = toupper(*p3);
						p3++;
					}
				}
			}
				
			/*
			** Move label to own line
			*/ 
			if (current_column != 0 && labels_own_line != 0 && (flags & DONT_RELOCATE_LABEL) == 0) {
				fputc('\n', output);
				current_column = 0;
			}
			if (flags & LEVEL_OUT) {
				if (current_level > 0)
					current_level--;
			}
			request += current_level * nesting_space;
			if (flags & LEVEL_MINUS)
				request -= nesting_space;
			request_space(output, &current_column, request, 1);
			fwrite(p1, sizeof(char), p2 - p1, output);
			current_column += p2 - p1;
			p1 = p2;
			while (*p1 && isspace(*p1))
				p1++;
			if (*p1 && *p1 != ';') {	/* Operand */
				request = start_operand;
				request += current_level * nesting_space;
				request_space(output, &current_column, request, 1);
				p2 = p1;
				while (*p2 && *p2 != ';') {
					if (*p2 == '"') {
						p2++;
						while (*p2 && *p2 != '"')
							p2++;
						p2++;
					} else if (*p2 == '\'') {
						p2++;
                        if (p2 - p1 < 6 || memcmp(p2 - 6, "AF,AF'", 6) != 0) {
                            while (*p2 && *p2 != '\'')
                                p2++;
                            p2++;
                        }
					} else {
						p2++;
					}
				}
				while (p2 > p1 && isspace(*(p2 - 1)))
					p2--;
				fwrite(p1, sizeof(char), p2 - p1, output);
				current_column += p2 - p1;
				p1 = p2;
				while (*p1 && isspace(*p1))
					p1++;
			}
			if (flags & LEVEL_IN) {
				current_level++;
			}
		}
		if (*p1 == ';') {	/* Comment */

			/*
			** Try to keep comments horizontally aligned (only works
			** if spaces were used in source file)
			*/
			p2 = p1;
			while (p2 - 1 >= p && isspace(*(p2 - 1)))
				p2--;
			if (p2 == p && p1 - p == prev_comment_original_location) {
				request = prev_comment_final_location;
			} else {
				prev_comment_original_location = p1 - p;
				if (current_column == 0)
					request = 0;
				else if (current_column < start_mnemonic)
					request = start_mnemonic;
				else
					request = start_comment;
				if (current_column == 0 && align_comment == 1)
					request = start_mnemonic;
				prev_comment_final_location = request;
			}
			request_space(output, &current_column, request, 0);
			p2 = p1;
			while (*p2)
				p2++;
			while (p2 > p1 && isspace(*(p2 - 1)))
				p2--;
			fwrite(p1, sizeof(char), p2 - p1, output);
			fputc('\n', output);
			current_column += p2 - p1;
			while (*p++) ;
			continue;
		}
		fputc('\n', output);
		while (*p++) ;
	}
	fclose(output);	
	free(data);
	exit(0);
}
